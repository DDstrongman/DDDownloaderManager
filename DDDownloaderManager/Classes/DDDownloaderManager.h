//
//  DDDownloaderManager.h
//  Gkid_Chinese
//
//  Created by DDLi on 2019/9/5.
//  Copyright © 2019 LittleLights. All rights reserved.
//  修改自SDWebimage

#import <Foundation/Foundation.h>

#import "DDDownloader.h"
#import "DDDownloaderRequest.h"
#import "DDDownloaderDiskControl.h"

@protocol DDWebObjectCancelOperation <NSObject>

- (void)cancel;

@end

typedef NS_OPTIONS(NSUInteger, DDDownloaderOptions) {
    /**
     * By default, when a URL fail to be downloaded, the URL is blacklisted so the library won't keep trying.
     * This flag disable this blacklisting.
     */
    DDDownloaderRetryFailed = 1 << 0,
    
    /**
     * By default, object downloads are started during UI interactions, this flags disable this feature,
     * leading to delayed download on UIScrollView deceleration for instance.
     */
    DDDownloaderLowPriority = 1 << 1,
    /**
     * This flag enables progressive download, the object is displayed progressively during download as a browser would do.
     * By default, the object is only displayed once completely downloaded.
     */
    DDDownloaderProgressiveDownload = 1 << 2,
    
    /**
     * Even if the object is cached, respect the HTTP response cache control, and refresh the object from remote location if needed.
     * The disk caching will be handled by NSURLCache instead of DDDowloader leading to slight performance degradation.
     * This option helps deal with objects changing behind the same request URL, e.g. Facebook graph api profile pics.
     * If a cached object is refreshed, the completion block is called once with the cached object and again with the final object.
     *
     * Use this flag only if you can't make your URLs static with embedded cache busting parameter.
     */
    DDDownloaderRefreshCached = 1 << 3,
    
    /**
     * In iOS 4+, continue the download of the object if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    DDDownloaderContinueInBackground = 1 << 4,
    
    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    DDDownloaderHandleCookies = 1 << 5,
    
    /**
     * Enable to allow untrusted SSL certificates.
     * Useful for testing purposes. Use with caution in production.
     */
    DDDownloaderAllowInvalidSSLCertificates = 1 << 6,
    
    /**
     * By default, object are loaded in the order in which they were queued. This flag moves them to
     * the front of the queue.
     */
    DDDownloaderHighPriority = 1 << 7
};

typedef void(^DDDownloadCompletionBlock)(NSData * _Nullable data, NSError * _Nullable error, BOOL finished, NSURL * _Nullable objectURL, NSString *  _Nullable filePath);
typedef void(^DDDownloadAllCompletionBlock)(BOOL finished);

typedef NSString * _Nullable (^DDWebObjectCacheKeyFilterBlock)(NSURL * _Nullable url);

@class DDDownloaderManager;

@protocol DDWebObjectManagerDelegate <NSObject>

@optional

/**
 * Controls which object should be downloaded when the object is not found in the cache.
 *
 * @param objectManager The current `DDDownloaderManager`
 * @param objectURL     The url of the object to be downloaded
 *
 * @return Return NO to prevent the downloading of the object on cache misses. If not implemented, YES is implied.
 */
- (BOOL)objectManager:(nonnull DDDownloaderManager *)objectManager
shouldDownloadObjectForURL:(nullable NSURL *)objectURL;

/**
 * Allows to transform the object immediately after it has been downloaded and just before to cache it on disk
 * NOTE: This method is called from a global queue in order to not to block the main thread.
 *
 * @param objectManager The current `DDDownloaderManager`
 * @param object        The object to transform
 * @param objectURL     The url of the object to transform
 *
 * @return The transformed data object.
 */
- (nullable NSData *)objectManager:(nonnull DDDownloaderManager *)objectManager
         transformDownloadedObject:(nullable NSData *)object
                           withURL:(nullable NSURL *)objectURL;

@end

@interface DDDownloaderManager : NSObject

@property (weak, nonatomic, nullable) id <DDWebObjectManagerDelegate> delegate;
@property (strong, nonatomic, readonly, nullable) DDDownloaderDiskControl *diskCache;
@property (strong, nonatomic, readonly, nullable) DDDownloader *objectDownloader;

@property (nonatomic, copy, nullable) DDWebObjectCacheKeyFilterBlock cacheKeyFilter;

@property (nonatomic, copy, nullable) NSString *minVersion;///< the min version to control requests
/**
 * Returns global DDDownloaderManager instance.
 *
 * @return DDDownloaderManager shared instance
 */
+ (nonnull instancetype)sharedManager;

/**
 * Allows to specify instance of cache and object downloader used with object manager.
 * @return new instance of `DDDownloaderManager` with specified cache and downloader.
 */
- (nonnull instancetype)initWithCache:(nonnull DDDownloaderDiskControl *)cache
                           downloader:(nonnull DDDownloader *)downloader NS_DESIGNATED_INITIALIZER;

/**
 * Downloads the object at the given URL if not present in cache or return the cached version otherwise.
 *
 * @param requests       The URLS(can be string but better not) request classes to the object, see DDDownloaderRequest for more info
 * @param options        A mask to specify options to use for this request
 * @param progressBlock  A block called while object is downloading
 *                       @note the progress block is executed on a background queue
 * @param completedBlock A block called when one operation has been completed.
 *
 *   This parameter is required.
 *
 *   This block has no return value and takes the requested the NSData representation as first parameter.
 *   In case of error the image parameter is nil and the second parameter may contain an NSError.
 *
 *
 *   The third parameter is set to NO when the DDDownloaderProgressiveDownload option is used and the object is
 *   downloading. This block is thus called repeatedly with a partial object. When object is fully downloaded, the
 *   block is called a last time with the full object and the last parameter set to YES.
 *
 *   The fourth parameter is the original object URL
 *   The last parameter is the disk file path of the download object
 *
 * @param allCompleteBlock A block called when all the operations has been completed with only one parameter
 *
 *   parameter YES if all download complete successfully, otherwise return NO
 *
 * @return Returns an NSObject conforming to DDWebObjectCancelOperation. Should be an instance of DDDownloaderOperation
 */
- (nullable NSMutableArray <id <DDWebObjectCancelOperation>> *)downloadObjectWithRequests:(nullable NSMutableArray <DDDownloaderRequest *> *)requests
                                                                                  options:(DDDownloaderOptions)options
                                                                                 progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                                          singleCompleted:(nullable DDDownloadCompletionBlock)completedBlock
                                                                             allCompleted:(nullable DDDownloadAllCompletionBlock)allCompleteBlock;
- (nullable id <DDWebObjectCancelOperation>)downloadObjectWithURL:(nullable NSURL *)url
                                                          options:(DDDownloaderOptions)options
                                                         progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                        completed:(nullable DDDownloadCompletionBlock)completedBlock;
- (nullable id <DDWebObjectCancelOperation>)downloadObjectWithRequest:(nullable DDDownloaderRequest *)request
                                                              options:(DDDownloaderOptions)options
                                                             progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                            completed:(nullable DDDownloadCompletionBlock)completedBlock;
- (nullable NSMutableArray <id <DDWebObjectCancelOperation>> *)downloadObjectWithURLS:(nullable NSMutableArray <NSURL *> *)urls
                                                           options:(DDDownloaderOptions)options
                                                          progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                                      singleCompleted:(nullable DDDownloadCompletionBlock)completedBlock
                                                                         allCompleted:(nullable DDDownloadAllCompletionBlock)allCompleteBlock;

/**
 * Cancel all current operations
 */
- (void)cancelAll;

/**
 * Check one or more operations running
 */
- (BOOL)isRunning;

/**
 *  Async check if object has already been cached on disk only
 *
 *  @param url              object url (can be string but better not)
 *  @param completionBlock  the block to be executed when the check is finished
 *  return two parameters. first parameter is check result bool
 *  second parameter is the url file's path in the disk
 *
 *  @note the completion block is always executed on the main queue
 */
- (void)diskObjectExistsForURL:(nullable NSURL *)url
                    completion:(nullable DDWebObjectCheckDiskCompletionBlock)completionBlock;

/**
 * Return the cache key for a given URL
 */
- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url;

@end
