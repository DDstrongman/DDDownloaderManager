//
//  DDDownloader.m
//
//  Created by DDLi on 2019/9/2.
//  Copyright © 2019 LittleLights. All rights reserved.
//
//  修改自DDWebObject
//

#import "DDDownloader.h"

#import "DDDownloaderOperation.h"

@implementation DDWebObjectDownloadToken

@end

@interface DDDownloader () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;
@property (weak, nonatomic, nullable) NSOperation *lastAddedOperation;
@property (assign, nonatomic, nullable) Class operationClass;
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, DDDownloaderOperation *> *URLOperations;
@property (strong, nonatomic, nullable) SDHTTPHeadersMutableDictionary *HTTPHeaders;
// This queue is used to serialize the handling of the network responses of all the download operation in a single queue
@property (SDDispatchQueueSetterSementics, nonatomic, nullable) dispatch_queue_t barrierQueue;

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation DDDownloader

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    if ((self = [super init])) {
        _operationClass = [DDDownloaderOperation class];
        _shouldDecompressImages = YES;
        _executionOrder = DDWebObjectDownloaderFIFOExecutionOrder;
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 6;
        _downloadQueue.name = @"com.hackemist.DDWebObjectDownloader";
        _URLOperations = [NSMutableDictionary new];
#ifdef SD_WEBP
        _HTTPHeaders = [@{@"Accept": @"image/webp,image/*;q=0.8"} mutableCopy];
#else
        _HTTPHeaders = [@{@"Accept": @"image/*;q=0.8"} mutableCopy];
#endif
        _barrierQueue = dispatch_queue_create("com.hackemist.DDWebObjectDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;
        
        sessionConfiguration.timeoutIntervalForRequest = _downloadTimeout;
        
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
         */
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                     delegate:self
                                                delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;
    
    [self.downloadQueue cancelAllOperations];
    SDDispatchQueueRelease(_barrierQueue);
}

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    if (value) {
        self.HTTPHeaders[field] = value;
    }
    else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
}

- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    return self.HTTPHeaders[field];
}

- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

- (NSUInteger)currentDownloadCount {
    return _downloadQueue.operationCount;
}

- (NSInteger)maxConcurrentDownloads {
    return _downloadQueue.maxConcurrentOperationCount;
}

- (void)setOperationClass:(nullable Class)operationClass {
    if (operationClass && [operationClass isSubclassOfClass:[NSOperation class]] && [operationClass conformsToProtocol:@protocol(DDWebObjectDownloaderOperationInterface)]) {
        _operationClass = operationClass;
    } else {
        _operationClass = [DDDownloaderOperation class];
    }
}

- (nullable DDWebObjectDownloadToken *)downloadImageWithRequest:(nullable DDDownloaderRequest *)request
                                                        options:(DDWebObjectDownloaderOptions)options
                                                       progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                      completed:(nullable DDWebObjectDownloaderCompletedBlock)completedBlock {
    if ([request compareVersionString:self.minVersion requestVersion:request.urlVersion]) {
        return [self downloadImageWithURLString:request.url
                                        options:options
                                       progress:progressBlock
                                      completed:completedBlock];
    }
    return nil;
}

- (nullable DDWebObjectDownloadToken *)downloadImageWithURLString:(nullable NSString *)url
                                                          options:(DDWebObjectDownloaderOptions)options
                                                         progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                        completed:(nullable DDWebObjectDownloaderCompletedBlock)completedBlock {
    NSLog(@"Better to Use \"downloadImageWithRequest\" to Control download version");
    return [self downloadImageWithURL:[NSURL URLWithString:url]
                              options:options
                             progress:progressBlock
                            completed:completedBlock];
}

- (nullable DDWebObjectDownloadToken *)downloadImageWithURL:(nullable NSURL *)url
                                                   options:(DDWebObjectDownloaderOptions)options
                                                  progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
                                                 completed:(nullable DDWebObjectDownloaderCompletedBlock)completedBlock {
    NSLog(@"Better to Use \"downloadImageWithRequest\" to Control download version");
    __weak DDDownloader *wself = self;
    
    return [self addProgressCallback:progressBlock completedBlock:completedBlock forURL:url createCallback:^DDDownloaderOperation *{
        __strong __typeof (wself) sself = wself;
        NSTimeInterval timeoutInterval = sself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }
        
        // In order to prevent from potential duplicate caching (NSURLCache + SDImageCache) we disable the cache for image requests if told otherwise
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:(options & DDWebObjectDownloaderUseNSURLCache ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData) timeoutInterval:timeoutInterval];
        request.HTTPShouldHandleCookies = (options & DDWebObjectDownloaderHandleCookies);
        request.HTTPShouldUsePipelining = YES;
        if (sself.headersFilter) {
            request.allHTTPHeaderFields = sself.headersFilter(url, [sself.HTTPHeaders copy]);
        } else {
            request.allHTTPHeaderFields = sself.HTTPHeaders;
        }
        DDDownloaderOperation *operation = [[sself.operationClass alloc] initWithRequest:request inSession:sself.session options:options];
        operation.shouldDecompressImages = sself.shouldDecompressImages;
        
        if (sself.urlCredential) {
            operation.credential = sself.urlCredential;
        } else if (sself.username && sself.password) {
            operation.credential = [NSURLCredential credentialWithUser:sself.username password:sself.password persistence:NSURLCredentialPersistenceForSession];
        }
        
        if (options & DDWebObjectDownloaderHighPriority) {
            operation.queuePriority = NSOperationQueuePriorityHigh;
        } else if (options & DDWebObjectDownloaderLowPriority) {
            operation.queuePriority = NSOperationQueuePriorityLow;
        }
        
        [sself.downloadQueue addOperation:operation];
        if (sself.executionOrder == DDWebObjectDownloaderLIFOExecutionOrder) {
            // Emulate LIFO execution order by systematically adding new operations as last operation's dependency
            [sself.lastAddedOperation addDependency:operation];
            sself.lastAddedOperation = operation;
        }
        
        return operation;
    }];
}

- (void)cancel:(nullable DDWebObjectDownloadToken *)token {
    dispatch_barrier_async(self.barrierQueue, ^{
        DDDownloaderOperation *operation = self.URLOperations[token.url];
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
            [self.URLOperations removeObjectForKey:token.url];
        }
    });
}

- (nullable DDWebObjectDownloadToken *)addProgressCallback:(DDWebObjectDownloaderProgressBlock)progressBlock
                                           completedBlock:(DDWebObjectDownloaderCompletedBlock)completedBlock
                                                   forURL:(nullable NSURL *)url
                                            createCallback:(DDDownloaderOperation *(^)(void))createCallback {
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, nil, NO);
        }
        return nil;
    }
    
    __block DDWebObjectDownloadToken *token = nil;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        DDDownloaderOperation *operation = self.URLOperations[url];
        if (!operation) {
            operation = createCallback();
            self.URLOperations[url] = operation;
            
            __weak DDDownloaderOperation *woperation = operation;
            operation.completionBlock = ^{
                DDDownloaderOperation *soperation = woperation;
                if (!soperation) return;
                if (self.URLOperations[url] == soperation) {
                    [self.URLOperations removeObjectForKey:url];
                };
            };
        }
        id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock completed:completedBlock];
        
        token = [DDWebObjectDownloadToken new];
        token.url = url;
        token.downloadOperationCancelToken = downloadOperationCancelToken;
    });
    
    return token;
}

- (void)setSuspended:(BOOL)suspended {
    (self.downloadQueue).suspended = suspended;
}

- (void)cancelAllDownloads {
    [self.downloadQueue cancelAllOperations];
}

#pragma mark Helper methods
- (DDDownloaderOperation *)operationWithTask:(NSURLSessionTask *)task {
    DDDownloaderOperation *returnOperation = nil;
    for (DDDownloaderOperation *operation in self.downloadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    DDDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    // Identify the operation that runs this task and pass it the delegate method
    DDDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    DDDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    // Identify the operation that runs this task and pass it the delegate method
    DDDownloaderOperation *dataOperation = [self operationWithTask:task];
    
    [dataOperation URLSession:session task:task didCompleteWithError:error];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    
    completionHandler(request);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    DDDownloaderOperation *dataOperation = [self operationWithTask:task];
    
    [dataOperation URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
}

@end
