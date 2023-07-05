/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderDownloader.h"
#import "ImageLoaderDownloaderConfig.h"
#import "ImageLoaderDownloaderOperation.h"
#import "ImageLoaderError.h"
#import "ImageLoaderCacheKeyFilter.h"
#import "LoadImageCacheDefine.h"
#import "SDInternalMacros.h"
#import "objc/runtime.h"

NSNotificationName const ImageLoaderDownloadStartNotification = @"ImageLoaderDownloadStartNotification";
NSNotificationName const ImageLoaderDownloadReceiveResponseNotification = @"ImageLoaderDownloadReceiveResponseNotification";
NSNotificationName const ImageLoaderDownloadStopNotification = @"ImageLoaderDownloadStopNotification";
NSNotificationName const ImageLoaderDownloadFinishNotification = @"ImageLoaderDownloadFinishNotification";

static void * ImageLoaderDownloaderContext = &ImageLoaderDownloaderContext;
static void * ImageLoaderDownloaderOperationKey = &ImageLoaderDownloaderOperationKey;

BOOL ImageLoaderDownloaderOperationGetCompleted(id<ImageLoaderDownloaderOperation> operation) {
    NSCParameterAssert(operation);
    NSNumber *value = objc_getAssociatedObject(operation, ImageLoaderDownloaderOperationKey);
    if (value != nil) {
        return value.boolValue;
    } else {
        return NO;
    }
}

void ImageLoaderDownloaderOperationSetCompleted(id<ImageLoaderDownloaderOperation> operation, BOOL isCompleted) {
    NSCParameterAssert(operation);
    objc_setAssociatedObject(operation, ImageLoaderDownloaderOperationKey, @(isCompleted), OBJC_ASSOCIATION_RETAIN);
}

@interface ImageLoaderDownloadToken ()

@property (nonatomic, strong, nullable, readwrite) NSURL *url;
@property (nonatomic, strong, nullable, readwrite) NSURLRequest *request;
@property (nonatomic, strong, nullable, readwrite) NSURLResponse *response;
@property (nonatomic, strong, nullable, readwrite) NSURLSessionTaskMetrics *metrics API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0));
@property (nonatomic, weak, nullable, readwrite) id downloadOperationCancelToken;
@property (nonatomic, weak, nullable) NSOperation<ImageLoaderDownloaderOperation> *downloadOperation;
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new  NS_UNAVAILABLE;
- (nonnull instancetype)initWithDownloadOperation:(nullable NSOperation<ImageLoaderDownloaderOperation> *)downloadOperation;

@end

@interface ImageLoaderDownloader () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, NSOperation<ImageLoaderDownloaderOperation> *> *URLOperations;
@property (strong, nonatomic, nullable) NSMutableDictionary<NSString *, NSString *> *HTTPHeaders;

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation ImageLoaderDownloader {
    SD_LOCK_DECLARE(_HTTPHeadersLock); // A lock to keep the access to `HTTPHeaders` thread-safe
    SD_LOCK_DECLARE(_operationsLock); // A lock to keep the access to `URLOperations` thread-safe
}

+ (void)initialize {
    // Bind SDNetworkActivityIndicator if available (download it here: http://github.com/rs/SDNetworkActivityIndicator )
    // To use it, just add #import "SDNetworkActivityIndicator.h" in addition to the ImageLoader import
    if (NSClassFromString(@"SDNetworkActivityIndicator")) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id activityIndicator = [NSClassFromString(@"SDNetworkActivityIndicator") performSelector:NSSelectorFromString(@"sharedActivityIndicator")];
#pragma clang diagnostic pop

        // Remove observer in case it was previously added.
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:ImageLoaderDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:ImageLoaderDownloadStopNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"startActivity")
                                                     name:ImageLoaderDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"stopActivity")
                                                     name:ImageLoaderDownloadStopNotification object:nil];
    }
}

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithConfig:ImageLoaderDownloaderConfig.defaultDownloaderConfig];
}

- (instancetype)initWithConfig:(ImageLoaderDownloaderConfig *)config {
    self = [super init];
    if (self) {
        if (!config) {
            config = ImageLoaderDownloaderConfig.defaultDownloaderConfig;
        }
        _config = [config copy];
        [_config addObserver:self forKeyPath:NSStringFromSelector(@selector(maxConcurrentDownloads)) options:0 context:ImageLoaderDownloaderContext];
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = _config.maxConcurrentDownloads;
        _downloadQueue.name = @"com.hackemist.ImageLoaderDownloader.downloadQueue";
        _URLOperations = [NSMutableDictionary new];
        NSMutableDictionary<NSString *, NSString *> *headerDictionary = [NSMutableDictionary dictionary];
        NSString *userAgent = nil;
#if SD_UIKIT
        // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
        userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
#elif SD_WATCH
        // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
        userAgent = [NSString stringWithFormat:@"%@/%@ (%@; watchOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[WKInterfaceDevice currentDevice] model], [[WKInterfaceDevice currentDevice] systemVersion], [[WKInterfaceDevice currentDevice] screenScale]];
#elif SD_MAC
        userAgent = [NSString stringWithFormat:@"%@/%@ (Mac OS X %@)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
        if (userAgent) {
            if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
                NSMutableString *mutableUserAgent = [userAgent mutableCopy];
                if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCII; [:^ASCII:] Remove", false)) {
                    userAgent = mutableUserAgent;
                }
            }
            headerDictionary[@"User-Agent"] = userAgent;
        }
        headerDictionary[@"Accept"] = @"image/*,*/*;q=0.8";
        _HTTPHeaders = headerDictionary;
        SD_LOCK_INIT(_HTTPHeadersLock);
        SD_LOCK_INIT(_operationsLock);
        NSURLSessionConfiguration *sessionConfiguration = _config.sessionConfiguration;
        if (!sessionConfiguration) {
            sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
         */
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                 delegate:self
                                            delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    [self.downloadQueue cancelAllOperations];
    [self.config removeObserver:self forKeyPath:NSStringFromSelector(@selector(maxConcurrentDownloads)) context:ImageLoaderDownloaderContext];
    
    // Invalide the URLSession after all operations been cancelled
    [self.session invalidateAndCancel];
    self.session = nil;
}

- (void)invalidateSessionAndCancel:(BOOL)cancelPendingOperations {
    if (self == [ImageLoaderDownloader sharedDownloader]) {
        return;
    }
    if (cancelPendingOperations) {
        [self.session invalidateAndCancel];
    } else {
        [self.session finishTasksAndInvalidate];
    }
}

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    if (!field) {
        return;
    }
    SD_LOCK(_HTTPHeadersLock);
    [self.HTTPHeaders setValue:value forKey:field];
    SD_UNLOCK(_HTTPHeadersLock);
}

- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    if (!field) {
        return nil;
    }
    SD_LOCK(_HTTPHeadersLock);
    NSString *value = [self.HTTPHeaders objectForKey:field];
    SD_UNLOCK(_HTTPHeadersLock);
    return value;
}

- (nullable ImageLoaderDownloadToken *)downloadImageWithURL:(NSURL *)url
                                                 completed:(ImageLoaderDownloaderCompletedBlock)completedBlock {
    return [self downloadImageWithURL:url options:0 progress:nil completed:completedBlock];
}

- (nullable ImageLoaderDownloadToken *)downloadImageWithURL:(NSURL *)url
                                                   options:(ImageLoaderDownloaderOptions)options
                                                  progress:(ImageLoaderDownloaderProgressBlock)progressBlock
                                                 completed:(ImageLoaderDownloaderCompletedBlock)completedBlock {
    return [self downloadImageWithURL:url options:options context:nil progress:progressBlock completed:completedBlock];
}

- (nullable ImageLoaderDownloadToken *)downloadImageWithURL:(nullable NSURL *)url
                                                   options:(ImageLoaderDownloaderOptions)options
                                                   context:(nullable ImageLoaderContext *)context
                                                  progress:(nullable ImageLoaderDownloaderProgressBlock)progressBlock
                                                 completed:(nullable ImageLoaderDownloaderCompletedBlock)completedBlock {
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (url == nil) {
        if (completedBlock) {
            NSError *error = [NSError errorWithDomain:ImageLoaderErrorDomain code:ImageLoaderErrorInvalidURL userInfo:@{NSLocalizedDescriptionKey : @"Image url is nil"}];
            completedBlock(nil, nil, error, YES);
        }
        return nil;
    }
    
    id downloadOperationCancelToken;
    // When different thumbnail size download with same url, we need to make sure each callback called with desired size
    id<ImageLoaderCacheKeyFilter> cacheKeyFilter = context[ImageLoaderContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        cacheKey = url.absoluteString;
    }
    LoadImageCoderOptions *decodeOptions = SDGetDecodeOptionsFromContext(context, [self.class imageOptionsFromDownloaderOptions:options], cacheKey);
    SD_LOCK(_operationsLock);
    NSOperation<ImageLoaderDownloaderOperation> *operation = [self.URLOperations objectForKey:url];
    // There is a case that the operation may be marked as finished or cancelled, but not been removed from `self.URLOperations`.
    BOOL shouldNotReuseOperation;
    if (operation) {
        @synchronized (operation) {
            shouldNotReuseOperation = operation.isFinished || operation.isCancelled || ImageLoaderDownloaderOperationGetCompleted(operation);
        }
    } else {
        shouldNotReuseOperation = YES;
    }
    if (shouldNotReuseOperation) {
        operation = [self createDownloaderOperationWithUrl:url options:options context:context];
        if (!operation) {
            SD_UNLOCK(_operationsLock);
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:ImageLoaderErrorDomain code:ImageLoaderErrorInvalidDownloadOperation userInfo:@{NSLocalizedDescriptionKey : @"Downloader operation is nil"}];
                completedBlock(nil, nil, error, YES);
            }
            return nil;
        }
        @weakify(self);
        operation.completionBlock = ^{
            @strongify(self);
            if (!self) {
                return;
            }
            SD_LOCK(self->_operationsLock);
            [self.URLOperations removeObjectForKey:url];
            SD_UNLOCK(self->_operationsLock);
        };
        [self.URLOperations setObject:operation forKey:url];
        // Add the handlers before submitting to operation queue, avoid the race condition that operation finished before setting handlers.
        downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock completed:completedBlock decodeOptions:decodeOptions];
        // Add operation to operation queue only after all configuration done according to Apple's doc.
        // `addOperation:` does not synchronously execute the `operation.completionBlock` so this will not cause deadlock.
        [self.downloadQueue addOperation:operation];
    } else {
        // When we reuse the download operation to attach more callbacks, there may be thread safe issue because the getter of callbacks may in another queue (decoding queue or delegate queue)
        // So we lock the operation here, and in `ImageLoaderDownloaderOperation`, we use `@synchonzied (self)`, to ensure the thread safe between these two classes.
        @synchronized (operation) {
            downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock completed:completedBlock decodeOptions:decodeOptions];
        }
    }
    SD_UNLOCK(_operationsLock);
    
    ImageLoaderDownloadToken *token = [[ImageLoaderDownloadToken alloc] initWithDownloadOperation:operation];
    token.url = url;
    token.request = operation.request;
    token.downloadOperationCancelToken = downloadOperationCancelToken;
    
    return token;
}

#pragma mark Helper methods
+ (ImageLoaderOptions)imageOptionsFromDownloaderOptions:(ImageLoaderDownloaderOptions)downloadOptions {
    ImageLoaderOptions options = 0;
    if (downloadOptions & ImageLoaderDownloaderScaleDownLargeImages) options |= ImageLoaderScaleDownLargeImages;
    if (downloadOptions & ImageLoaderDownloaderDecodeFirstFrameOnly) options |= ImageLoaderDecodeFirstFrameOnly;
    if (downloadOptions & ImageLoaderDownloaderPreloadAllFrames) options |= ImageLoaderPreloadAllFrames;
    if (downloadOptions & ImageLoaderDownloaderAvoidDecodeImage) options |= ImageLoaderAvoidDecodeImage;
    if (downloadOptions & ImageLoaderDownloaderMatchAnimatedImageClass) options |= ImageLoaderMatchAnimatedImageClass;
    
    return options;
}

- (nullable NSOperation<ImageLoaderDownloaderOperation> *)createDownloaderOperationWithUrl:(nonnull NSURL *)url
                                                                                  options:(ImageLoaderDownloaderOptions)options
                                                                                  context:(nullable ImageLoaderContext *)context {
    NSTimeInterval timeoutInterval = self.config.downloadTimeout;
    if (timeoutInterval == 0.0) {
        timeoutInterval = 15.0;
    }
    
    // In order to prevent from potential duplicate caching (NSURLCache + LoadImageCache) we disable the cache for image requests if told otherwise
    NSURLRequestCachePolicy cachePolicy = options & ImageLoaderDownloaderUseNSURLCache ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData;
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:cachePolicy timeoutInterval:timeoutInterval];
    mutableRequest.HTTPShouldHandleCookies = SD_OPTIONS_CONTAINS(options, ImageLoaderDownloaderHandleCookies);
    mutableRequest.HTTPShouldUsePipelining = YES;
    SD_LOCK(_HTTPHeadersLock);
    mutableRequest.allHTTPHeaderFields = self.HTTPHeaders;
    SD_UNLOCK(_HTTPHeadersLock);
    
    // Context Option
    ImageLoaderMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    
    // Request Modifier
    id<ImageLoaderDownloaderRequestModifier> requestModifier;
    if ([context valueForKey:ImageLoaderContextDownloadRequestModifier]) {
        requestModifier = [context valueForKey:ImageLoaderContextDownloadRequestModifier];
    } else {
        requestModifier = self.requestModifier;
    }
    
    NSURLRequest *request;
    if (requestModifier) {
        NSURLRequest *modifiedRequest = [requestModifier modifiedRequestWithRequest:[mutableRequest copy]];
        // If modified request is nil, early return
        if (!modifiedRequest) {
            return nil;
        } else {
            request = [modifiedRequest copy];
        }
    } else {
        request = [mutableRequest copy];
    }
    // Response Modifier
    id<ImageLoaderDownloaderResponseModifier> responseModifier;
    if ([context valueForKey:ImageLoaderContextDownloadResponseModifier]) {
        responseModifier = [context valueForKey:ImageLoaderContextDownloadResponseModifier];
    } else {
        responseModifier = self.responseModifier;
    }
    if (responseModifier) {
        mutableContext[ImageLoaderContextDownloadResponseModifier] = responseModifier;
    }
    // Decryptor
    id<ImageLoaderDownloaderDecryptor> decryptor;
    if ([context valueForKey:ImageLoaderContextDownloadDecryptor]) {
        decryptor = [context valueForKey:ImageLoaderContextDownloadDecryptor];
    } else {
        decryptor = self.decryptor;
    }
    if (decryptor) {
        mutableContext[ImageLoaderContextDownloadDecryptor] = decryptor;
    }
    
    context = [mutableContext copy];
    
    // Operation Class
    Class operationClass = self.config.operationClass;
    if (!operationClass) {
        operationClass = [ImageLoaderDownloaderOperation class];
    }
    NSOperation<ImageLoaderDownloaderOperation> *operation = [[operationClass alloc] initWithRequest:request inSession:self.session options:options context:context];
    
    if ([operation respondsToSelector:@selector(setCredential:)]) {
        if (self.config.urlCredential) {
            operation.credential = self.config.urlCredential;
        } else if (self.config.username && self.config.password) {
            operation.credential = [NSURLCredential credentialWithUser:self.config.username password:self.config.password persistence:NSURLCredentialPersistenceForSession];
        }
    }
        
    if ([operation respondsToSelector:@selector(setMinimumProgressInterval:)]) {
        operation.minimumProgressInterval = MIN(MAX(self.config.minimumProgressInterval, 0), 1);
    }
    
    if ([operation respondsToSelector:@selector(setAcceptableStatusCodes:)]) {
        operation.acceptableStatusCodes = self.config.acceptableStatusCodes;
    }
    
    if ([operation respondsToSelector:@selector(setAcceptableContentTypes:)]) {
        operation.acceptableContentTypes = self.config.acceptableContentTypes;
    }
    
    if (options & ImageLoaderDownloaderHighPriority) {
        operation.queuePriority = NSOperationQueuePriorityHigh;
    } else if (options & ImageLoaderDownloaderLowPriority) {
        operation.queuePriority = NSOperationQueuePriorityLow;
    }
    
    if (self.config.executionOrder == ImageLoaderDownloaderLIFOExecutionOrder) {
        // Emulate LIFO execution order by systematically, each previous adding operation can dependency the new operation
        // This can gurantee the new operation to be execulated firstly, even if when some operations finished, meanwhile you appending new operations
        // Just make last added operation dependents new operation can not solve this problem. See test case #test15DownloaderLIFOExecutionOrder
        for (NSOperation *pendingOperation in self.downloadQueue.operations) {
            [pendingOperation addDependency:operation];
        }
    }
    
    return operation;
}

- (void)cancelAllDownloads {
    [self.downloadQueue cancelAllOperations];
}

#pragma mark - Properties

- (BOOL)isSuspended {
    return self.downloadQueue.isSuspended;
}

- (void)setSuspended:(BOOL)suspended {
    self.downloadQueue.suspended = suspended;
}

- (NSUInteger)currentDownloadCount {
    return self.downloadQueue.operationCount;
}

- (NSURLSessionConfiguration *)sessionConfiguration {
    return self.session.configuration;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == ImageLoaderDownloaderContext) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(maxConcurrentDownloads))]) {
            self.downloadQueue.maxConcurrentOperationCount = self.config.maxConcurrentDownloads;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Helper methods

- (NSOperation<ImageLoaderDownloaderOperation> *)operationWithTask:(NSURLSessionTask *)task {
    NSOperation<ImageLoaderDownloaderOperation> *returnOperation = nil;
    for (NSOperation<ImageLoaderDownloaderOperation> *operation in self.downloadQueue.operations) {
        if ([operation respondsToSelector:@selector(dataTask)]) {
            // So we lock the operation here, and in `ImageLoaderDownloaderOperation`, we use `@synchonzied (self)`, to ensure the thread safe between these two classes.
            NSURLSessionTask *operationTask;
            @synchronized (operation) {
                operationTask = operation.dataTask;
            }
            if (operationTask.taskIdentifier == task.taskIdentifier) {
                returnOperation = operation;
                break;
            }
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
    NSOperation<ImageLoaderDownloaderOperation> *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [dataOperation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {

    // Identify the operation that runs this task and pass it the delegate method
    NSOperation<ImageLoaderDownloaderOperation> *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [dataOperation URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    NSOperation<ImageLoaderDownloaderOperation> *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:willCacheResponse:completionHandler:)]) {
        [dataOperation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(proposedResponse);
        }
    }
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    // Identify the operation that runs this task and pass it the delegate method
    NSOperation<ImageLoaderDownloaderOperation> *dataOperation = [self operationWithTask:task];
    if (dataOperation) {
        @synchronized (dataOperation) {
            // Mark the downloader operation `isCompleted = YES`, no longer re-use this operation when new request comes in
            ImageLoaderDownloaderOperationSetCompleted(dataOperation, YES);
        }
    }
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [dataOperation URLSession:session task:task didCompleteWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    NSOperation<ImageLoaderDownloaderOperation> *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [dataOperation URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(request);
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    NSOperation<ImageLoaderDownloaderOperation> *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [dataOperation URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)) {
    
    // Identify the operation that runs this task and pass it the delegate method
    NSOperation<ImageLoaderDownloaderOperation> *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]) {
        [dataOperation URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}

@end

@implementation ImageLoaderDownloadToken

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ImageLoaderDownloadReceiveResponseNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ImageLoaderDownloadStopNotification object:nil];
}

- (instancetype)initWithDownloadOperation:(NSOperation<ImageLoaderDownloaderOperation> *)downloadOperation {
    self = [super init];
    if (self) {
        _downloadOperation = downloadOperation;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadDidReceiveResponse:) name:ImageLoaderDownloadReceiveResponseNotification object:downloadOperation];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadDidStop:) name:ImageLoaderDownloadStopNotification object:downloadOperation];
    }
    return self;
}

- (void)downloadDidReceiveResponse:(NSNotification *)notification {
    NSOperation<ImageLoaderDownloaderOperation> *downloadOperation = notification.object;
    if (downloadOperation && downloadOperation == self.downloadOperation) {
        self.response = downloadOperation.response;
    }
}

- (void)downloadDidStop:(NSNotification *)notification {
    NSOperation<ImageLoaderDownloaderOperation> *downloadOperation = notification.object;
    if (downloadOperation && downloadOperation == self.downloadOperation) {
        if ([downloadOperation respondsToSelector:@selector(metrics)]) {
            if (@available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)) {
                self.metrics = downloadOperation.metrics;
            }
        }
    }
}

- (void)cancel {
    @synchronized (self) {
        if (self.isCancelled) {
            return;
        }
        self.cancelled = YES;
        [self.downloadOperation cancel:self.downloadOperationCancelToken];
        self.downloadOperationCancelToken = nil;
    }
}

@end

@implementation ImageLoaderDownloader (LoadImageLoader)

- (BOOL)canRequestImageForURL:(NSURL *)url {
    return [self canRequestImageForURL:url options:0 context:nil];
}

- (BOOL)canRequestImageForURL:(NSURL *)url options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context {
    if (!url) {
        return NO;
    }
    // Always pass YES to let URLSession or custom download operation to determine
    return YES;
}

- (id<ImageLoaderOperation>)requestImageWithURL:(NSURL *)url options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context progress:(LoadImageLoaderProgressBlock)progressBlock completed:(LoadImageLoaderCompletedBlock)completedBlock {
    UIImage *cachedImage = context[ImageLoaderContextLoaderCachedImage];
    
    ImageLoaderDownloaderOptions downloaderOptions = 0;
    if (options & ImageLoaderLowPriority) downloaderOptions |= ImageLoaderDownloaderLowPriority;
    if (options & ImageLoaderProgressiveLoad) downloaderOptions |= ImageLoaderDownloaderProgressiveLoad;
    if (options & ImageLoaderRefreshCached) downloaderOptions |= ImageLoaderDownloaderUseNSURLCache;
    if (options & ImageLoaderContinueInBackground) downloaderOptions |= ImageLoaderDownloaderContinueInBackground;
    if (options & ImageLoaderHandleCookies) downloaderOptions |= ImageLoaderDownloaderHandleCookies;
    if (options & ImageLoaderAllowInvalidSSLCertificates) downloaderOptions |= ImageLoaderDownloaderAllowInvalidSSLCertificates;
    if (options & ImageLoaderHighPriority) downloaderOptions |= ImageLoaderDownloaderHighPriority;
    if (options & ImageLoaderScaleDownLargeImages) downloaderOptions |= ImageLoaderDownloaderScaleDownLargeImages;
    if (options & ImageLoaderAvoidDecodeImage) downloaderOptions |= ImageLoaderDownloaderAvoidDecodeImage;
    if (options & ImageLoaderDecodeFirstFrameOnly) downloaderOptions |= ImageLoaderDownloaderDecodeFirstFrameOnly;
    if (options & ImageLoaderPreloadAllFrames) downloaderOptions |= ImageLoaderDownloaderPreloadAllFrames;
    if (options & ImageLoaderMatchAnimatedImageClass) downloaderOptions |= ImageLoaderDownloaderMatchAnimatedImageClass;
    
    if (cachedImage && options & ImageLoaderRefreshCached) {
        // force progressive off if image already cached but forced refreshing
        downloaderOptions &= ~ImageLoaderDownloaderProgressiveLoad;
        // ignore image read from NSURLCache if image if cached but force refreshing
        downloaderOptions |= ImageLoaderDownloaderIgnoreCachedResponse;
    }
    
    return [self downloadImageWithURL:url options:downloaderOptions context:context progress:progressBlock completed:completedBlock];
}

- (BOOL)shouldBlockFailedURLWithURL:(NSURL *)url error:(NSError *)error {
    return [self shouldBlockFailedURLWithURL:url error:error options:0 context:nil];
}

- (BOOL)shouldBlockFailedURLWithURL:(NSURL *)url error:(NSError *)error options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context {
    BOOL shouldBlockFailedURL;
    // Filter the error domain and check error codes
    if ([error.domain isEqualToString:ImageLoaderErrorDomain]) {
        shouldBlockFailedURL = (   error.code == ImageLoaderErrorInvalidURL
                                || error.code == ImageLoaderErrorBadImageData);
    } else if ([error.domain isEqualToString:NSURLErrorDomain]) {
        shouldBlockFailedURL = (   error.code != NSURLErrorNotConnectedToInternet
                                && error.code != NSURLErrorCancelled
                                && error.code != NSURLErrorTimedOut
                                && error.code != NSURLErrorInternationalRoamingOff
                                && error.code != NSURLErrorDataNotAllowed
                                && error.code != NSURLErrorCannotFindHost
                                && error.code != NSURLErrorCannotConnectToHost
                                && error.code != NSURLErrorNetworkConnectionLost);
    } else {
        shouldBlockFailedURL = NO;
    }
    return shouldBlockFailedURL;
}

@end
