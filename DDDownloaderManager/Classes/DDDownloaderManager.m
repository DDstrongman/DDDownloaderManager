//
//  DDDownloaderManager.m
//  Gkid_Chinese
//
//  Created by DDLi on 2019/9/5.
//  Copyright © 2019 LittleLights. All rights reserved.
//  修改自SDWebimage

#import "DDDownloaderManager.h"
#import <objc/message.h>

@interface DDDownloaderCombinedOperation : NSObject <DDWebObjectCancelOperation>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (copy, nonatomic, nullable) DDWebObjectResultBlock cancelBlock;
@property (strong, nonatomic, nullable) NSOperation *cacheOperation;

@end

@interface DDDownloaderManager ()

@property (strong, nonatomic, readwrite, nonnull) DDDownloaderDiskControl *objectCache;
@property (strong, nonatomic, readwrite, nonnull) DDDownloader *objectDownloader;
@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;
@property (strong, nonatomic, nonnull) NSMutableArray<DDDownloaderCombinedOperation *> *runningOperations;

@end

@implementation DDDownloaderManager

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    DDDownloaderDiskControl *cache = [DDDownloaderDiskControl sharedObjectCache];
    DDDownloader *downloader = [DDDownloader sharedDownloader];
    return [self initWithCache:cache
                    downloader:downloader];
}

- (nonnull instancetype)initWithCache:(nonnull DDDownloaderDiskControl *)cache
                           downloader:(nonnull DDDownloader *)downloader {
    if ((self = [super init])) {
        _objectCache = cache;
        _objectDownloader = downloader;
        _failedURLs = [NSMutableSet new];
        _diskCache = [DDDownloaderDiskControl new];
        _runningOperations = [NSMutableArray new];
    }
    return self;
}

- (nullable NSString *)diskPathForURL:(nullable NSURL *)url {
    return [_diskCache defaultCachePathForKey:[self cacheKeyForURL:url]];
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }
    
    if (self.cacheKeyFilter) {
        return self.cacheKeyFilter(url);
    } else {
        return url.absoluteString;
    }
}

- (void)diskObjectExistsForURL:(nullable NSURL *)url
                    completion:(nullable DDWebObjectCheckDiskCompletionBlock)completionBlock {
    if ([url isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    NSString *key = [self cacheKeyForURL:url];
    
    [self.objectCache diskObjectExistsWithKey:key completion:^(BOOL isInCache, NSString * _Nullable path) {
        // the completion block of diskObjectExistsWithKey:completion: is always called on the main queue, no need to further dispatch
        if (completionBlock) {
            completionBlock(isInCache,path);
        }
    }];
}

- (nullable NSMutableArray <id <DDWebObjectCancelOperation>> *)downloadObjectWithURLS:(nullable NSMutableArray <NSURL *> *)urls
                                                           options:(DDDownloaderOptions)options
                                                          progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                                      singleCompleted:(nullable DDDownloadCompletionBlock)completedBlock
                                                                         allCompleted:(nullable DDDownloadAllCompletionBlock)allCompleteBlock {
    NSMutableArray <DDDownloaderRequest *> *requests = [NSMutableArray array];
    for (id URL in urls) {
        DDDownloaderRequest *request = [DDDownloaderRequest new];
        if ([URL isKindOfClass:[NSURL class]]) {
            request.url = ((NSURL *)URL).absoluteString;
        } else if ([URL isKindOfClass:[NSString class]]) {
            request.url = (NSString *)URL;
        }
        request.urlVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        [requests addObject:request];
    }
    return [self downloadObjectWithRequests:requests
                                    options:options
                                   progress:progressBlock
                            singleCompleted:completedBlock
                               allCompleted:allCompleteBlock];
}

- (nullable NSMutableArray <id <DDWebObjectCancelOperation>> *)downloadObjectWithRequests:(nullable NSMutableArray <DDDownloaderRequest *> *)requests
                                                                                            options:(DDDownloaderOptions)options
                                                                                           progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                                          singleCompleted:(nullable DDDownloadCompletionBlock)completedBlock
                                                                             allCompleted:(nullable DDDownloadAllCompletionBlock)allCompleteBlock {
    NSMutableArray <id <DDWebObjectCancelOperation>> *Operations = [NSMutableArray array];
    __block NSMutableArray *allRequests = requests.mutableCopy;
    for (DDDownloaderRequest *request in requests) {
        if ([request compareVersionString:self.minVersion requestVersion:request.urlVersion]) {
            id<DDWebObjectCancelOperation> operTemp = [self downloadObjectWithURL:[NSURL URLWithString:request.url] options:options progress:progressBlock
              completed:^(NSData * _Nullable data, NSError * _Nullable error, BOOL finished, NSURL * _Nullable objectURL, NSString * _Nullable filePath) {
                  //此处为主线程
                  if (completedBlock) {
                      completedBlock(data,error,finished,objectURL,filePath);
                  }
                  if (error) {
                      if (allCompleteBlock) {
                          allCompleteBlock(NO);
                      }
                  } else {
                      [allRequests removeObject:request];
                      if (allRequests.count == 0) {
                          if (allCompleteBlock) {
                              allCompleteBlock(YES);
                          }
                      }
                  }
               }];
            operTemp ? [Operations addObject:operTemp] : @"";
        }
    }
    return Operations;
}

- (nullable id <DDWebObjectCancelOperation>)downloadObjectWithRequest:(nullable DDDownloaderRequest *)request
                                                              options:(DDDownloaderOptions)options
                                                             progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                            completed:(nullable DDDownloadCompletionBlock)completedBlock {
    if ([request compareVersionString:self.minVersion requestVersion:request.urlVersion]) {
        return [self downloadObjectWithURL:[NSURL URLWithString:request.url]
                                   options:options
                                  progress:progressBlock
                                 completed:completedBlock];
    }
    return nil;
}

- (id <DDWebObjectCancelOperation>)downloadObjectWithURL:(nullable NSURL *)url
                                                 options:(DDDownloaderOptions)options
                                                progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                               completed:(nullable DDDownloadCompletionBlock)completedBlock {
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[SDWebImagePrefetcher prefetchURLs] instead");
    
    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, Xcode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    
    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }
    
    __block DDDownloaderCombinedOperation *operation = [DDDownloaderCombinedOperation new];
    __weak DDDownloaderCombinedOperation *weakOperation = operation;
    
    BOOL isFailedUrl = NO;
    if (url) {
        @synchronized (self.failedURLs) {
            isFailedUrl = [self.failedURLs containsObject:url];
        }
    }
    
    if (url.absoluteString.length == 0 || (!(options & DDDownloaderRetryFailed) && isFailedUrl)) {
        [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] url:url];
        return operation;
    }
    
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    NSString *key = [self cacheKeyForURL:url];
    
    operation.cacheOperation = [self.objectCache queryCacheOperationForKey:key done:^(NSData * _Nullable data,   NSString * _Nullable path) {
        if (operation.isCancelled) {
            [self safelyRemoveOperationFromRunning:operation];
            return;
        }
        
        if ((!data || options & DDDownloaderRefreshCached) && (![self.delegate respondsToSelector:@selector(objectManager:shouldDownloadObjectForURL:)] || [self.delegate objectManager:self shouldDownloadObjectForURL:url])) {
            if (data && options & DDDownloaderRefreshCached) {
                // If image was found in the cache but SDWebImageRefreshCached is provided, notify about the cached image
                // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
                [self callCompletionBlockForOperation:weakOperation
                                           completion:completedBlock
                                                 data:data
                                                error:nil
                                             finished:YES
                                                  url:url];
            }
            
            // download if no image or requested to refresh anyway, and download allowed by delegate
            DDWebObjectDownloaderOptions downloaderOptions = 0;
            if (options & DDDownloaderLowPriority) downloaderOptions |= DDWebObjectDownloaderLowPriority;
            if (options & DDDownloaderProgressiveDownload) downloaderOptions |= DDWebObjectDownloaderProgressiveDownload;
            if (options & DDDownloaderRefreshCached) downloaderOptions |= DDWebObjectDownloaderUseNSURLCache;
            if (options & DDDownloaderContinueInBackground) downloaderOptions |= DDWebObjectDownloaderContinueInBackground;
            if (options & DDDownloaderHandleCookies) downloaderOptions |= DDWebObjectDownloaderHandleCookies;
            if (options & DDDownloaderAllowInvalidSSLCertificates) downloaderOptions |= DDWebObjectDownloaderAllowInvalidSSLCertificates;
            if (options & DDDownloaderHighPriority) downloaderOptions |= DDWebObjectDownloaderHighPriority;
            
            if (data && options & DDDownloaderRefreshCached) {
                // force progressive off if image already cached but forced refreshing
                downloaderOptions &= ~DDWebObjectDownloaderProgressiveDownload;
                // ignore image read from NSURLCache if image if cached but force refreshing
                downloaderOptions |= DDWebObjectDownloaderIgnoreCachedResponse;
            }
            
            DDWebObjectDownloadToken *subOperationToken = [self.objectDownloader downloadImageWithURL:url options:downloaderOptions progress:progressBlock completed:^(NSData * _Nullable downloadedData, NSError * _Nullable error, BOOL finished) {
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                if (!strongOperation || strongOperation.isCancelled) {
                    // Do nothing if the operation was cancelled
                    // See #699 for more details
                    // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                } else if (error) {
                    [self callCompletionBlockForOperation:strongOperation completion:completedBlock error:error url:url];
                    
                    if (   error.code != NSURLErrorNotConnectedToInternet
                        && error.code != NSURLErrorCancelled
                        && error.code != NSURLErrorTimedOut
                        && error.code != NSURLErrorInternationalRoamingOff
                        && error.code != NSURLErrorDataNotAllowed
                        && error.code != NSURLErrorCannotFindHost
                        && error.code != NSURLErrorCannotConnectToHost) {
                        @synchronized (self.failedURLs) {
                            [self.failedURLs addObject:url];
                        }
                    }
                }
                else {
                    if ((options & DDDownloaderRetryFailed)) {
                        @synchronized (self.failedURLs) {
                            [self.failedURLs removeObject:url];
                        }
                    }
                    
                    if (options & DDDownloaderRefreshCached && data && !downloadedData) {
                        // Image refresh hit the NSURLCache cache, do not call the completion block
                    } else if (downloadedData && [self.delegate respondsToSelector:@selector(objectManager:transformDownloadedObject:withURL:)]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            NSData *objectData = [self.delegate objectManager:self transformDownloadedObject:nil withURL:url];
                            
                            if (objectData && finished) {
                                BOOL objectWasTransformed = ![objectData isEqual:downloadedData];
                                // pass nil if the image was transformed, so we can recalculate the data from the image
                                [self.objectCache storeData:(objectWasTransformed ? nil : downloadedData)
                                                     forKey:key
                                                 completion:nil];
                            }
                            
                            [self callCompletionBlockForOperation:strongOperation
                                                       completion:completedBlock
                                                             data:downloadedData
                                                            error:nil
                                                         finished:finished
                                                              url:url];
                        });
                    } else if (downloadedData && (!downloadedData || (options)) && [self.delegate respondsToSelector:@selector(objectManager:transformDownloadedObject:withURL:)]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            NSData *transformedData = [self.delegate objectManager:self transformDownloadedObject:downloadedData withURL:url];
                            
                            if (transformedData && finished) {
                                BOOL imageWasTransformed = ![transformedData isEqual:downloadedData];
                                // pass nil if the image was transformed, so we can recalculate the data from the image
                                [self.objectCache storeData:(imageWasTransformed ? nil : downloadedData)
                                                     forKey:key
                                                 completion:nil];
                            }
                            
                            [self callCompletionBlockForOperation:strongOperation
                                                       completion:completedBlock
                                                             data:downloadedData
                                                            error:nil
                                                         finished:finished
                                                              url:url];
                        });
                    }  else {
                        if (downloadedData && finished) {
                            [self.objectCache storeData:downloadedData
                                                 forKey:key
                                             completion:nil];
                        }
                        [self callCompletionBlockForOperation:strongOperation
                                                   completion:completedBlock
                                                         data:downloadedData
                                                        error:nil
                                                     finished:finished
                                                          url:url];
                    }
                }
                
                if (finished) {
                    [self safelyRemoveOperationFromRunning:strongOperation];
                }
            }];
            operation.cancelBlock = ^(BOOL result) {
                [self.objectDownloader cancel:subOperationToken];
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                [self safelyRemoveOperationFromRunning:strongOperation];
            };
        }
        else if (data) {
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock data:data error:nil finished:YES url:url];
            [self safelyRemoveOperationFromRunning:operation];
        } else {
            // Image not in cache and download disallowed by delegate
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            [self callCompletionBlockForOperation:strongOperation
                                       completion:completedBlock
                                             data:nil
                                            error:nil
                                         finished:YES
                                              url:url];
            [self safelyRemoveOperationFromRunning:operation];
        }
    }];
    
    return operation;
}

- (void)cancelAll {
    @synchronized (self.runningOperations) {
        NSArray<DDDownloaderCombinedOperation *> *copiedOperations = [self.runningOperations copy];
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isRunning {
    BOOL isRunning = NO;
    @synchronized (self.runningOperations) {
        isRunning = (self.runningOperations.count > 0);
    }
    return isRunning;
}

- (void)safelyRemoveOperationFromRunning:(nullable DDDownloaderCombinedOperation*)operation {
    @synchronized (self.runningOperations) {
        if (operation) {
            [self.runningOperations removeObject:operation];
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable DDDownloaderCombinedOperation*)operation
                             completion:(nullable DDDownloadCompletionBlock)completionBlock
                                  error:(nullable NSError *)error
                                    url:(nullable NSURL *)url {
    [self callCompletionBlockForOperation:operation
                               completion:completionBlock
                                     data:nil
                                    error:error
                                 finished:YES
                                      url:url];
}

- (void)callCompletionBlockForOperation:(nullable DDDownloaderCombinedOperation*)operation
                             completion:(nullable DDDownloadCompletionBlock)completionBlock
                                   data:(nullable NSData *)data
                                  error:(nullable NSError *)error
                               finished:(BOOL)finished
                                    url:(nullable NSURL *)url {
    dispatch_main_async_safe(^{
        if (operation && !operation.isCancelled && completionBlock) {
            completionBlock(data, error, finished, url, [self.objectCache defaultCachePathForKey:url.absoluteString]);
        }
    });
}

@end

@implementation DDDownloaderCombinedOperation

- (void)setCancelBlock:(nullable DDWebObjectResultBlock)cancelBlock {
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock(NO);
        }
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock(NO);
        
        // TODO: this is a temporary fix to #809.
        // Until we can figure the exact cause of the crash, going with the ivar instead of the setter
        //        self.cancelBlock = nil;
        _cancelBlock = nil;
    }
}

@end
