//
//  DDDownloadManager.h
//  DDCardView
//
//  Created by DDLi on 2019/9/2.
//  Copyright © 2019 LittleLights. All rights reserved.
//
//  修改自SDWebImage
//

#import <Foundation/Foundation.h>
#import "DDWebObjectOperation.h"

#import "DDDownloaderRequest.h"

typedef NS_OPTIONS(NSUInteger, DDWebObjectDownloaderOptions) {
    DDWebObjectDownloaderLowPriority = 1 << 0,
    DDWebObjectDownloaderProgressiveDownload = 1 << 1,
    
    /**
     * By default, request prevent the use of NSURLCache. With this flag, NSURLCache
     * is used with default policies.
     */
    DDWebObjectDownloaderUseNSURLCache = 1 << 2,
    
    /**
     * Call completion block with nil image/imageData if the image was read from NSURLCache
     * (to be combined with `DDWebObjectDownloaderUseNSURLCache`).
     */
    
    DDWebObjectDownloaderIgnoreCachedResponse = 1 << 3,
    /**
     * In iOS 4+, continue the download of the image if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    
    DDWebObjectDownloaderContinueInBackground = 1 << 4,
    
    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    DDWebObjectDownloaderHandleCookies = 1 << 5,
    
    /**
     * Enable to allow untrusted SSL certificates.
     * Useful for testing purposes. Use with caution in production.
     */
    DDWebObjectDownloaderAllowInvalidSSLCertificates = 1 << 6,
    
    /**
     * Put the object in the high priority queue.
     */
    DDWebObjectDownloaderHighPriority = 1 << 7,
};

typedef NS_ENUM(NSInteger, DDWebObjectDownloaderExecutionOrder) {
    /**
     * Default value. All download operations will execute in queue style (first-in-first-out).
     */
    DDWebObjectDownloaderFIFOExecutionOrder,
    
    /**
     * All download operations will execute in stack style (last-in-first-out).
     */
    DDWebObjectDownloaderLIFOExecutionOrder
};

typedef void(^DDWebObjectDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL);

typedef void(^DDWebObjectDownloaderCompletedBlock)(NSData * _Nullable data, NSError * _Nullable error, BOOL finished);

typedef NSDictionary<NSString *, NSString *> SDHTTPHeadersDictionary;
typedef NSMutableDictionary<NSString *, NSString *> SDHTTPHeadersMutableDictionary;

typedef SDHTTPHeadersDictionary * _Nullable (^DDWebObjectDownloaderHeadersFilterBlock)(NSURL * _Nullable url, SDHTTPHeadersDictionary * _Nullable headers);

/**
 *  A token associated with each download. Can be used to cancel a download
 */
@interface DDWebObjectDownloadToken : NSObject

@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, strong, nullable) id downloadOperationCancelToken;

@end


/**
 * Asynchronous downloader dedicated and optimized for image loading.
 */
@interface DDDownloader : NSObject

/**
 * Decompressing images that are downloaded and cached can improve performance but can consume lot of memory.
 * Defaults to YES. Set this to NO if you are experiencing a crash due to excessive memory consumption.
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 *  The maximum number of concurrent downloads
 */
@property (assign, nonatomic) NSInteger maxConcurrentDownloads;

/**
 * Shows the current amount of downloads that still need to be downloaded
 */
@property (readonly, nonatomic) NSUInteger currentDownloadCount;


/**
 *  The timeout value (in seconds) for the download operation. Default: 15.0.
 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;


/**
 * Changes download operations execution order. Default value is `DDWebObjectDownloaderFIFOExecutionOrder`.
 */
@property (assign, nonatomic) DDWebObjectDownloaderExecutionOrder executionOrder;

/**
 *  Singleton method, returns the shared instance
 *
 *  @return global shared instance of downloader class
 */
+ (nonnull instancetype)sharedDownloader;

/**
 *  Set the default URL credential to be set for request operations.
 */
@property (strong, nonatomic, nullable) NSURLCredential *urlCredential;

/**
 * Set username
 */
@property (strong, nonatomic, nullable) NSString *username;

/**
 * Set password
 */
@property (strong, nonatomic, nullable) NSString *password;

/**
 download Version Control,combine with the DDDownloadRequest to control download version,default to nil
 */
@property (nonatomic, copy, nullable) NSString *minVersion;

/**
 * Set filter to pick headers for downloading image HTTP request.
 *
 * This block will be invoked for each downloading image request, returned
 * NSDictionary will be used as headers in corresponding HTTP request.
 */
@property (nonatomic, copy, nullable) DDWebObjectDownloaderHeadersFilterBlock headersFilter;

/**
 * Creates an instance of a downloader with specified session configuration.
 * *Note*: `timeoutIntervalForRequest` is going to be overwritten.
 * @return new instance of downloader class
 */
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration NS_DESIGNATED_INITIALIZER;

/**
 * Set a value for a HTTP header to be appended to each download HTTP request.
 *
 * @param value The value for the header field. Use `nil` value to remove the header.
 * @param field The name of the header field to set.
 */
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field;

/**
 * Returns the value of the specified HTTP header field.
 *
 * @return The value associated with the header field field, or `nil` if there is no corresponding header field.
 */
- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field;

/**
 * Sets a subclass of `DDWebObjectDownloaderOperation` as the default
 * `NSOperation` to be used each time DDWebObject constructs a request
 * operation to download an image.
 *
 * @param operationClass The subclass of `DDWebObjectDownloaderOperation` to set
 *        as default. Passing `nil` will revert to `DDWebObjectDownloaderOperation`.
 */
- (void)setOperationClass:(nullable Class)operationClass;

/**
 * Creates a DDWebObjectDownloader async downloader instance with a given request class or NSURL or NSString,better request class,this will control the version
 *
 *
 * @param request        The request class or NSURL or NSString,better request class,this will control the version
 * @param options        The options to be used for this download
 * @param progressBlock  A block called repeatedly while the image is downloading
 *                       @note the progress block is executed on a background queue
 * @param completedBlock A block called once the download is completed.
 *                       If the download succeeded, the image parameter is set, in case of error,
 *                       error parameter is set with the error. The last parameter is always YES
 *                       if DDWebObjectDownloaderProgressiveDownload isn't use. With the
 *                       DDWebObjectDownloaderProgressiveDownload option, this block is called
 *                       repeatedly with the partial image object and the finished argument set to NO
 *                       before to be called a last time with the full image and finished argument
 *                       set to YES. In case of error, the finished argument is always YES.
 *
 * @return A token (DDWebObjectDownloadToken) that can be passed to -cancel: to cancel this operation
 */
- (nullable DDWebObjectDownloadToken *)downloadImageWithRequest:(nullable DDDownloaderRequest *)request
                                                        options:(DDWebObjectDownloaderOptions)options
                                                       progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                      completed:(nullable DDWebObjectDownloaderCompletedBlock)completedBlock;
- (nullable DDWebObjectDownloadToken *)downloadImageWithURLString:(nullable NSString *)url
                                                          options:(DDWebObjectDownloaderOptions)options
                                                         progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                        completed:(nullable DDWebObjectDownloaderCompletedBlock)completedBlock;

- (nullable DDWebObjectDownloadToken *)downloadImageWithURL:(nullable NSURL *)url
                                                   options:(DDWebObjectDownloaderOptions)options
                                                  progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                 completed:(nullable DDWebObjectDownloaderCompletedBlock)completedBlock;

/**
 * Cancels a download that was previously queued using -downloadImageWithURL:options:progress:completed:
 *
 * @param token The token received from -downloadImageWithURL:options:progress:completed: that should be canceled.
 */
- (void)cancel:(nullable DDWebObjectDownloadToken *)token;

/**
 * Sets the download queue suspension state
 */
- (void)setSuspended:(BOOL)suspended;

/**
 * Cancels all download operations in the queue
 */
- (void)cancelAllDownloads;

@end
