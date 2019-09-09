//
//  DDDownloaderDiskControl.m
//  Gkid_Chinese
//
//  Created by DDLi on 2019/9/5.
//  Copyright © 2019 LittleLights. All rights reserved.
//  修改自SDWebimage + YYCache

#import "DDDownloaderDiskControl.h"
#import "DDWebObjectOperation.h"
#import <CommonCrypto/CommonDigest.h>

@interface DDDownloaderDiskControl ()

#pragma mark - Properties
@property (strong, nonatomic, nonnull) NSString *diskCachePath;
@property (strong, nonatomic, nonnull) NSString *fullDirName;///< real dir name
@property (strong, nonatomic, nullable) NSMutableArray<NSString *> *customPaths;
@property (SDDispatchQueueSetterSementics, nonatomic, nullable) dispatch_queue_t ioQueue;

@end

@implementation DDDownloaderDiskControl {
    NSFileManager *_fileManager;
}

#pragma mark - Singleton, init, dealloc
+ (nonnull instancetype)sharedObjectCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    return [self initWithDirName:@"DDDownloaderDefault"];
}

- (nonnull instancetype)initWithDirName:(nonnull NSString *)dirName {
    NSString *path = [self makeDiskCachePath];
    return [self initWithDirName:dirName diskCacheDirectory:path];
}

- (nonnull instancetype)initWithDirName:(nonnull NSString *)dirName
                     diskCacheDirectory:(nonnull NSString *)directory {
    if ((self = [super init])) {
        _fullDirName = [@"com.littlelights.DDWebObjectCache" stringByAppendingString:dirName];
        
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.littlelights.DDWebObjectCache", DISPATCH_QUEUE_SERIAL);
        
        _config = [[DDDownloaderItemConfig alloc] init];
        
        // Init the disk cache
        if (directory != nil) {
            _diskCachePath = [directory stringByAppendingPathComponent:_fullDirName];
        } else {
            NSString *path = [self makeDiskCachePath];
            _diskCachePath = [path stringByAppendingPathComponent:_fullDirName];
        }
        
        dispatch_sync(_ioQueue, ^{
            self->_fileManager = [NSFileManager new];
        });
        
        // Subscribe to app events
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deleteOldFiles)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundDeleteOldFiles)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SDDispatchQueueRelease(_ioQueue);
}

- (void)checkIfQueueIsIOQueue {
    const char *currentQueueLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    const char *ioQueueLabel = dispatch_queue_get_label(self.ioQueue);
    if (strcmp(currentQueueLabel, ioQueueLabel) != 0) {
        NSLog(@"This method should be called from the ioQueue");
    }
}

#pragma mark - Disk Cache Settings


#pragma mark - Cache paths
- (nullable NSString *)cachePathForKey:(nullable NSString *)key
                                inPath:(nonnull NSString *)path {
    NSString *filename = [self cachedFileNameForKey:key];
    return [[path stringByAppendingPathComponent:_fullDirName] stringByAppendingPathComponent:filename];
}

- (nullable NSString *)defaultCachePathForKey:(nullable NSString *)key {
    NSString *filename = [self cachedFileNameForKey:key];
    return [self.diskCachePath stringByAppendingPathComponent:filename];
}

- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [key.pathExtension isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", key.pathExtension]];
    
    return filename;
}

- (nullable NSString *)makeDiskCachePath {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return paths[0];
}

#pragma mark - Store Ops
- (void)storeData:(nullable NSData *)data
           forKey:(nullable NSString *)key
       completion:(nullable DDWebObjectResultBlock)completionBlock {
    if (!data || !key) {
        if (completionBlock) {
            completionBlock(NO);
        }
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        BOOL result = [self storeDataToDisk:data forKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(result);
            });
        }
    });
}

- (BOOL)storeDataToDisk:(nullable NSData *)data
                 forKey:(nullable NSString *)key {
    if (!data || !key) {
        return NO;
    }

    [self checkIfQueueIsIOQueue];
    
    if (![_fileManager fileExistsAtPath:_diskCachePath]) {
        [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    // get cache Path for object key
    NSString *cachePathForKey = [self defaultCachePathForKey:key];
    // transform to NSUrl
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
    
    BOOL result = [_fileManager createFileAtPath:cachePathForKey contents:data attributes:nil];
    
    // disable iCloud backup
    if (self.config.shouldDisableiCloud) {
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    return result;
}

#pragma mark - Query and Retrieve Ops
- (void)diskObjectExistsWithKey:(nullable NSString *)key
                     completion:(nullable DDWebObjectCheckDiskCompletionBlock)completionBlock {
    dispatch_async(_ioQueue, ^{
        BOOL exists = [self->_fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
        
        // checking the key with and without the extension
        if (!exists) {
            exists = [self->_fileManager fileExistsAtPath:[self defaultCachePathForKey:key].stringByDeletingPathExtension];
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists,[self defaultCachePathForKey:key]);
            });
        }
    });
}

- (nullable NSData *)dataFromDiskCacheForKey:(nullable NSString *)key {
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data) {
        return data;
    }
    
    // checking the key with and without the extension
    data = [NSData dataWithContentsOfFile:defaultPath.stringByDeletingPathExtension];
    if (data) {
        return data;
    }
    
    if (!self.customPaths) {
        self.customPaths = [NSMutableArray array];
    }
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (![self.customPaths containsObject:paths[0]]) {
        [self.customPaths addObject:paths[0]];
    }
    
    NSArray<NSString *> *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *customData = [NSData dataWithContentsOfFile:filePath];
        if (customData) {
            return customData;
        }
        
        // checking the key with and without the extension
        customData = [NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension];
        if (customData) {
            return customData;
        }
    }
    
    return nil;
}

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key
                                               done:(nullable DDCacheQueryCompletedBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, @"");
        }
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            // do not call the completion if cancelled
            return;
        }
        
        @autoreleasepool {
            NSData *diskData = [self dataFromDiskCacheForKey:key];
            
            if (doneBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    doneBlock(diskData, self.diskCachePath);
                });
            }
        }
    });
    
    return operation;
}

#pragma mark - Remove Ops
- (void)removeObjectForKey:(nullable NSString *)key
            withCompletion:(nullable DDWebObjectResultBlock)completion {
    [self removeObjectForKey:key
                    fromDisk:YES
              withCompletion:completion];
}

- (void)removeObjectForKey:(nullable NSString *)key
                  fromDisk:(BOOL)fromDisk
            withCompletion:(nullable DDWebObjectResultBlock)completion {
    if (key == nil) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            BOOL result = [self->_fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(result);
                });
            }
        });
    } else if (completion){
        completion(NO);
    }
    
}

#pragma mark - Cache clean Ops
- (void)clearDiskOnCompletion:(nullable DDWebObjectResultBlock)completion {
    dispatch_async(self.ioQueue, ^{
        [self->_fileManager removeItemAtPath:self.diskCachePath error:nil];
        BOOL result = [self->_fileManager createDirectoryAtPath:self.diskCachePath
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:NULL];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(result);
            });
        }
    });
}

- (void)deleteOldFiles {
    [self deleteOldFilesWithCompletionBlock:nil];
}

- (void)deleteOldFilesWithCompletionBlock:(nullable DDWebObjectResultBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [self->_fileManager enumeratorAtURL:diskCacheURL
                                                         includingPropertiesForKeys:resourceKeys
                                                                            options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                       errorHandler:NULL];
        
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;
        NSUInteger currentCacheCount = 0;
        
        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSError *error;
            NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
            
            // Skip directories and errors.
            if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }
            
            // Remove files that are older than the expiration date;
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            NSDate *expirationDate = [NSDate dateWithTimeInterval:self.config.maxCacheAge sinceDate:modificationDate];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate] && self.config.maxCacheAge > 0) {
                [urlsToDelete addObject:fileURL];
                continue;
            }
            
            // Store a reference to this file and account for its total size.
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
            cacheFiles[fileURL] = resourceValues;
            currentCacheCount++;
        }
        
        for (NSURL *fileURL in urlsToDelete) {
            [self->_fileManager removeItemAtURL:fileURL error:nil];
        }
        
        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([self->_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([self->_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([self->_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (self.config.maxCount > 0 && currentCacheCount > self.config.maxCount) {
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([self->_fileManager removeItemAtURL:fileURL error:nil]) {
                    currentCacheCount--;
                    
                    if (currentCacheCount < self.config.maxCount) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(YES);
            });
        }
    });
}

- (void)backgroundDeleteOldFiles {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^(BOOL result) {
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

#pragma mark - Cache Info
- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self->_fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self->_fileManager enumeratorAtPath:self.diskCachePath];
        count = fileEnumerator.allObjects.count;
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(nullable DDWebObjectCalculateAmmountAndSizeBlock)completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator = [self->_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

@end
