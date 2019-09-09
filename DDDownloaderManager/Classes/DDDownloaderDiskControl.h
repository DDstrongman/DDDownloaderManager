//
//  DDDownloaderDiskControl.h
//  Gkid_Chinese
//
//  Created by DDLi on 2019/9/5.
//  Copyright © 2019 LittleLights. All rights reserved.
//  修改自SDWebImage,参考了YYCache

#import <Foundation/Foundation.h>

#import "DDDownloaderItemConfig.h"

typedef void(^DDWebObjectCheckDiskCompletionBlock)(BOOL isInCache, NSString * _Nullable path);
typedef void(^DDCacheQueryCompletedBlock)(NSData * _Nullable data,   NSString * _Nullable path);
typedef void(^DDWebObjectResultBlock)(BOOL result);
typedef void(^DDWebObjectCalculateAmmountAndSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);

@interface DDDownloaderDiskControl : NSObject

#pragma mark - Cache Properties
/**
 *  Disk-Cache Per Item Config object - storing all kind of settings
 */
@property (nonatomic, nonnull, readonly) DDDownloaderItemConfig *config;

#pragma mark - Singleton and initialization
/**
 * Returns global shared cache instance
 *
 * @return DDDownloaderDiskControl global instance
 */
+ (nonnull instancetype)sharedObjectCache;

/**
 * Init a new cache store with a specific dirName, default to document direction
 *
 * @param dirName The dir name to use for this disk store
 */
- (nonnull instancetype)initWithDirName:(nonnull NSString *)dirName;

/**
 * Init a new cache store with a specific namespace and directory
 *
 * @param dirName        The namespace to use for this cache store
 * @param directory Directory to cache disk images in
 */
- (nonnull instancetype)initWithDirName:(nonnull NSString *)dirName
                     diskCacheDirectory:(nonnull NSString *)directory;

#pragma mark - Query and Retrieve Ops
/**
 *  Async check if object exists in disk cache already (does not load the image)
 *
 *  @param key             the key describing the url
 *  @param completionBlock the block to be executed when the check is done.
 *  @note the completion block will be always executed on the main queue
 */
- (void)diskObjectExistsWithKey:(nullable NSString *)key
                     completion:(nullable DDWebObjectCheckDiskCompletionBlock)completionBlock;
/**
 * Operation that queries the cache asynchronously and call the completion when done.
 *
 * @param key       The unique key used to store the wanted image
 * @param doneBlock The completion block. Will not get called if the operation is cancelled
 *
 * @return a NSOperation instance containing the cache op
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key
                                               done:(nullable DDCacheQueryCompletedBlock)doneBlock;

/**
 * Query the disk cache synchronously.
 *
 * @param key The unique key used to store the data
 * @return the data of the file
 */
- (nullable NSData *)dataFromDiskCacheForKey:(nullable NSString *)key;

#pragma mark - Store Ops
/**
 * Asynchronously store an image into  disk cache at the given key.
 *
 * @param data           The data to store
 * @param key            The unique object data cache key, usually it's object absolute URL
 * @param completionBlock A block executed after the operation is finished
 */
- (void)storeData:(nullable NSData *)data
           forKey:(nullable NSString *)key
       completion:(nullable DDWebObjectResultBlock)completionBlock;

/**
 * Synchronously store object NSData into disk cache at the given key.
 *
 * @warning This method is synchronous, make sure to call it from the ioQueue
 *
 * @param data  The object data to store
 * @param key   The unique object cache key, usually it's object absolute URL
 * @return the save result YES or NO
 */
- (BOOL)storeDataToDisk:(nullable NSData *)data
                 forKey:(nullable NSString *)key;

#pragma mark - Remove Ops
/**
 * Remove the object from memory and disk cache asynchronously
 *
 * @param key             The unique object cache key
 * @param completion      A block that should be executed after the image has been removed (optional)
 */
- (void)removeObjectForKey:(nullable NSString *)key
            withCompletion:(nullable DDWebObjectResultBlock)completion;

#pragma mark - Cache clean all Ops
/**
 * Async clear all disk cached object. Non-blocking method - returns immediately.
 * @param completion    A block that should be executed after cache expiration completes (optional)
 */
- (void)clearDiskOnCompletion:(nullable DDWebObjectResultBlock)completion;

/**
 * Async remove all expired cached image from disk. Means call all the trim methods
 * @param completionBlock A block that should be executed after cache expiration completes (optional)
 */
- (void)deleteOldFilesWithCompletionBlock:(nullable DDWebObjectResultBlock)completionBlock;


#pragma mark - Cache Info
/**
 * Get the size used by the disk cache, bytes
 */
- (NSUInteger)getSize;

/**
 * Get the number of files in the disk cache
 */
- (NSUInteger)getDiskCount;

/**
 * Asynchronously calculate the disk cache's ammount of files and size.
 */
- (void)calculateSizeWithCompletionBlock:(nullable DDWebObjectCalculateAmmountAndSizeBlock)completionBlock;

#pragma mark - Cache Paths
/**
 *  Get the cache path for a certain key (needs the cache path root folder)
 *
 *  @param key  the key (can be obtained from url using cacheKeyForURL)
 *  @param path the cache path root folder, example:document path or cache path
 *
 *  @return the cache path
 */
- (nullable NSString *)cachePathForKey:(nullable NSString *)key
                                inPath:(nonnull NSString *)path;
/**
 *  Get the default cache path for a certain key
 *
 *  @param key the key (can be obtained from url using cacheKeyForURL)
 *
 *  @return the default cache path
 */
- (nullable NSString *)defaultCachePathForKey:(nullable NSString *)key;

@end
