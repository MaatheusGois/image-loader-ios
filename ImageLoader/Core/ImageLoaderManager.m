/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderManager.h"
#import "LoadImageCache.h"
#import "ImageLoaderDownloader.h"
#import "UIImage+Metadata.h"
#import "SDAssociatedObject.h"
#import "ImageLoaderError.h"
#import "SDInternalMacros.h"
#import "SDCallbackQueue.h"

static id<LoadImageCache> _defaultImageCache;
static id<LoadImageLoader> _defaultImageLoader;

@interface ImageLoaderCombinedOperation ()

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (strong, nonatomic, readwrite, nullable) id<ImageLoaderOperation> loaderOperation;
@property (strong, nonatomic, readwrite, nullable) id<ImageLoaderOperation> cacheOperation;
@property (weak, nonatomic, nullable) ImageLoaderManager *manager;

@end

@interface ImageLoaderManager () {
    SD_LOCK_DECLARE(_failedURLsLock); // a lock to keep the access to `failedURLs` thread-safe
    SD_LOCK_DECLARE(_runningOperationsLock); // a lock to keep the access to `runningOperations` thread-safe
}

@property (strong, nonatomic, readwrite, nonnull) LoadImageCache *imageCache;
@property (strong, nonatomic, readwrite, nonnull) id<LoadImageLoader> imageLoader;
@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;
@property (strong, nonatomic, nonnull) NSMutableSet<ImageLoaderCombinedOperation *> *runningOperations;

@end

@implementation ImageLoaderManager

+ (id<LoadImageCache>)defaultImageCache {
    return _defaultImageCache;
}

+ (void)setDefaultImageCache:(id<LoadImageCache>)defaultImageCache {
    if (defaultImageCache && ![defaultImageCache conformsToProtocol:@protocol(LoadImageCache)]) {
        return;
    }
    _defaultImageCache = defaultImageCache;
}

+ (id<LoadImageLoader>)defaultImageLoader {
    return _defaultImageLoader;
}

+ (void)setDefaultImageLoader:(id<LoadImageLoader>)defaultImageLoader {
    if (defaultImageLoader && ![defaultImageLoader conformsToProtocol:@protocol(LoadImageLoader)]) {
        return;
    }
    _defaultImageLoader = defaultImageLoader;
}

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    id<LoadImageCache> cache = [[self class] defaultImageCache];
    if (!cache) {
        cache = [LoadImageCache sharedImageCache];
    }
    id<LoadImageLoader> loader = [[self class] defaultImageLoader];
    if (!loader) {
        loader = [ImageLoaderDownloader sharedDownloader];
    }
    return [self initWithCache:cache loader:loader];
}

- (nonnull instancetype)initWithCache:(nonnull id<LoadImageCache>)cache loader:(nonnull id<LoadImageLoader>)loader {
    if ((self = [super init])) {
        _imageCache = cache;
        _imageLoader = loader;
        _failedURLs = [NSMutableSet new];
        SD_LOCK_INIT(_failedURLsLock);
        _runningOperations = [NSMutableSet new];
        SD_LOCK_INIT(_runningOperationsLock);
    }
    return self;
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<ImageLoaderCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    return key;
}

- (nullable NSString *)originalCacheKeyForURL:(nullable NSURL *)url context:(nullable ImageLoaderContext *)context {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<ImageLoaderCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (context[ImageLoaderContextCacheKeyFilter]) {
        cacheKeyFilter = context[ImageLoaderContextCacheKeyFilter];
    }
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    return key;
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url context:(nullable ImageLoaderContext *)context {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<ImageLoaderCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (context[ImageLoaderContextCacheKeyFilter]) {
        cacheKeyFilter = context[ImageLoaderContextCacheKeyFilter];
    }
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    // Thumbnail Key Appending
    NSValue *thumbnailSizeValue = context[ImageLoaderContextImageThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
        CGSize thumbnailSize = CGSizeZero;
#if SD_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
#else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
#endif
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = context[ImageLoaderContextImagePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        key = SDThumbnailedKeyForKey(key, thumbnailSize, preserveAspectRatio);
    }
    
    // Transformer Key Appending
    id<LoadImageTransformer> transformer = self.transformer;
    if (context[ImageLoaderContextImageTransformer]) {
        transformer = context[ImageLoaderContextImageTransformer];
        if ([transformer isEqual:NSNull.null]) {
            transformer = nil;
        }
    }
    if (transformer) {
        key = SDTransformedKeyForKey(key, transformer.transformerKey);
    }
    
    return key;
}

- (ImageLoaderCombinedOperation *)loadImageWithURL:(NSURL *)url options:(ImageLoaderOptions)options progress:(LoadImageLoaderProgressBlock)progressBlock completed:(SDInternalCompletionBlock)completedBlock {
    return [self loadImageWithURL:url options:options context:nil progress:progressBlock completed:completedBlock];
}

- (ImageLoaderCombinedOperation *)loadImageWithURL:(nullable NSURL *)url
                                          options:(ImageLoaderOptions)options
                                          context:(nullable ImageLoaderContext *)context
                                         progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                                        completed:(nonnull SDInternalCompletionBlock)completedBlock {
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[ImageLoaderPrefetcher prefetchURLs] instead");

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, Xcode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    ImageLoaderCombinedOperation *operation = [ImageLoaderCombinedOperation new];
    operation.manager = self;

    BOOL isFailedUrl = NO;
    if (url) {
        SD_LOCK(_failedURLsLock);
        isFailedUrl = [self.failedURLs containsObject:url];
        SD_UNLOCK(_failedURLsLock);
    }
    
    // Preprocess the options and context arg to decide the final the result for manager
    ImageLoaderOptionsResult *result = [self processedResultForURL:url options:options context:context];

    if (url.absoluteString.length == 0 || (!(options & ImageLoaderRetryFailed) && isFailedUrl)) {
        NSString *description = isFailedUrl ? @"Image url is blacklisted" : @"Image url is nil";
        NSInteger code = isFailedUrl ? ImageLoaderErrorBlackListed : ImageLoaderErrorInvalidURL;
        [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:ImageLoaderErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : description}] queue:result.context[ImageLoaderContextCallbackQueue] url:url];
        return operation;
    }

    SD_LOCK(_runningOperationsLock);
    [self.runningOperations addObject:operation];
    SD_UNLOCK(_runningOperationsLock);
    
    // Start the entry to load image from cache, the longest steps are below
    // Steps without transformer:
    // 1. query image from cache, miss
    // 2. download data and image
    // 3. store image to cache
    
    // Steps with transformer:
    // 1. query transformed image from cache, miss
    // 2. query original image from cache, miss
    // 3. download data and image
    // 4. do transform in CPU
    // 5. store original image to cache
    // 6. store transformed image to cache
    [self callCacheProcessForOperation:operation url:url options:result.options context:result.context progress:progressBlock completed:completedBlock];

    return operation;
}

- (void)cancelAll {
    SD_LOCK(_runningOperationsLock);
    NSSet<ImageLoaderCombinedOperation *> *copiedOperations = [self.runningOperations copy];
    SD_UNLOCK(_runningOperationsLock);
    [copiedOperations makeObjectsPerformSelector:@selector(cancel)]; // This will call `safelyRemoveOperationFromRunning:` and remove from the array
}

- (BOOL)isRunning {
    BOOL isRunning = NO;
    SD_LOCK(_runningOperationsLock);
    isRunning = (self.runningOperations.count > 0);
    SD_UNLOCK(_runningOperationsLock);
    return isRunning;
}

- (void)removeFailedURL:(NSURL *)url {
    if (!url) {
        return;
    }
    SD_LOCK(_failedURLsLock);
    [self.failedURLs removeObject:url];
    SD_UNLOCK(_failedURLsLock);
}

- (void)removeAllFailedURLs {
    SD_LOCK(_failedURLsLock);
    [self.failedURLs removeAllObjects];
    SD_UNLOCK(_failedURLsLock);
}

#pragma mark - Private

// Query normal cache process
- (void)callCacheProcessForOperation:(nonnull ImageLoaderCombinedOperation *)operation
                                 url:(nonnull NSURL *)url
                             options:(ImageLoaderOptions)options
                             context:(nullable ImageLoaderContext *)context
                            progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                           completed:(nullable SDInternalCompletionBlock)completedBlock {
    // Grab the image cache to use
    id<LoadImageCache> imageCache = context[ImageLoaderContextImageCache];
    if (!imageCache) {
        imageCache = self.imageCache;
    }
    // Get the query cache type
    LoadImageCacheType queryCacheType = LoadImageCacheTypeAll;
    if (context[ImageLoaderContextQueryCacheType]) {
        queryCacheType = [context[ImageLoaderContextQueryCacheType] integerValue];
    }
    
    // Check whether we should query cache
    BOOL shouldQueryCache = !SD_OPTIONS_CONTAINS(options, ImageLoaderFromLoaderOnly);
    if (shouldQueryCache) {
        // transformed cache key
        NSString *key = [self cacheKeyForURL:url context:context];
        @weakify(operation);
        operation.cacheOperation = [imageCache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable cachedImage, NSData * _Nullable cachedData, LoadImageCacheType cacheType) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:ImageLoaderErrorDomain code:ImageLoaderErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during querying the cache"}] queue:context[ImageLoaderContextCallbackQueue] url:url];
                [self safelyRemoveOperationFromRunning:operation];
                return;
            } else if (!cachedImage) {
                NSString *originKey = [self originalCacheKeyForURL:url context:context];
                BOOL mayInOriginalCache = ![key isEqualToString:originKey];
                // Have a chance to query original cache instead of downloading, then applying transform
                // Thumbnail decoding is done inside LoadImageCache's decoding part, which does not need post processing for transform
                if (mayInOriginalCache) {
                    [self callOriginalCacheProcessForOperation:operation url:url options:options context:context progress:progressBlock completed:completedBlock];
                    return;
                }
            }
            // Continue download process
            [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:cachedImage cachedData:cachedData cacheType:cacheType progress:progressBlock completed:completedBlock];
        }];
    } else {
        // Continue download process
        [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:LoadImageCacheTypeNone progress:progressBlock completed:completedBlock];
    }
}

// Query original cache process
- (void)callOriginalCacheProcessForOperation:(nonnull ImageLoaderCombinedOperation *)operation
                                         url:(nonnull NSURL *)url
                                     options:(ImageLoaderOptions)options
                                     context:(nullable ImageLoaderContext *)context
                                    progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                                   completed:(nullable SDInternalCompletionBlock)completedBlock {
    // Grab the image cache to use, choose standalone original cache firstly
    id<LoadImageCache> imageCache = context[ImageLoaderContextOriginalImageCache];
    if (!imageCache) {
        // if no standalone cache available, use default cache
        imageCache = context[ImageLoaderContextImageCache];
        if (!imageCache) {
            imageCache = self.imageCache;
        }
    }
    // Get the original query cache type
    LoadImageCacheType originalQueryCacheType = LoadImageCacheTypeDisk;
    if (context[ImageLoaderContextOriginalQueryCacheType]) {
        originalQueryCacheType = [context[ImageLoaderContextOriginalQueryCacheType] integerValue];
    }
    
    // Check whether we should query original cache
    BOOL shouldQueryOriginalCache = (originalQueryCacheType != LoadImageCacheTypeNone);
    if (shouldQueryOriginalCache) {
        // Get original cache key generation without transformer
        NSString *key = [self originalCacheKeyForURL:url context:context];
        @weakify(operation);
        operation.cacheOperation = [imageCache queryImageForKey:key options:options context:context cacheType:originalQueryCacheType completion:^(UIImage * _Nullable cachedImage, NSData * _Nullable cachedData, LoadImageCacheType cacheType) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:ImageLoaderErrorDomain code:ImageLoaderErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during querying the cache"}] queue:context[ImageLoaderContextCallbackQueue] url:url];
                [self safelyRemoveOperationFromRunning:operation];
                return;
            } else if (!cachedImage) {
                // Original image cache miss. Continue download process
                [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:LoadImageCacheTypeNone progress:progressBlock completed:completedBlock];
                return;
            }
                        
            // Skip downloading and continue transform process, and ignore .refreshCached option for now
            [self callTransformProcessForOperation:operation url:url options:options context:context originalImage:cachedImage originalData:cachedData cacheType:cacheType finished:YES completed:completedBlock];
            
            [self safelyRemoveOperationFromRunning:operation];
        }];
    } else {
        // Continue download process
        [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:LoadImageCacheTypeNone progress:progressBlock completed:completedBlock];
    }
}

// Download process
- (void)callDownloadProcessForOperation:(nonnull ImageLoaderCombinedOperation *)operation
                                    url:(nonnull NSURL *)url
                                options:(ImageLoaderOptions)options
                                context:(ImageLoaderContext *)context
                            cachedImage:(nullable UIImage *)cachedImage
                             cachedData:(nullable NSData *)cachedData
                              cacheType:(LoadImageCacheType)cacheType
                               progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                              completed:(nullable SDInternalCompletionBlock)completedBlock {
    // Mark the cache operation end
    @synchronized (operation) {
        operation.cacheOperation = nil;
    }
    
    // Grab the image loader to use
    id<LoadImageLoader> imageLoader = context[ImageLoaderContextImageLoader];
    if (!imageLoader) {
        imageLoader = self.imageLoader;
    }
    
    // Check whether we should download image from network
    BOOL shouldDownload = !SD_OPTIONS_CONTAINS(options, ImageLoaderFromCacheOnly);
    shouldDownload &= (!cachedImage || options & ImageLoaderRefreshCached);
    shouldDownload &= (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url]);
    if ([imageLoader respondsToSelector:@selector(canRequestImageForURL:options:context:)]) {
        shouldDownload &= [imageLoader canRequestImageForURL:url options:options context:context];
    } else {
        shouldDownload &= [imageLoader canRequestImageForURL:url];
    }
    if (shouldDownload) {
        if (cachedImage && options & ImageLoaderRefreshCached) {
            // If image was found in the cache but ImageLoaderRefreshCached is provided, notify about the cached image
            // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
            [self callCompletionBlockForOperation:operation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES queue:context[ImageLoaderContextCallbackQueue] url:url];
            // Pass the cached image to the image loader. The image loader should check whether the remote image is equal to the cached image.
            ImageLoaderMutableContext *mutableContext;
            if (context) {
                mutableContext = [context mutableCopy];
            } else {
                mutableContext = [NSMutableDictionary dictionary];
            }
            mutableContext[ImageLoaderContextLoaderCachedImage] = cachedImage;
            context = [mutableContext copy];
        }
        
        @weakify(operation);
        operation.loaderOperation = [imageLoader requestImageWithURL:url options:options context:context progress:progressBlock completed:^(UIImage *downloadedImage, NSData *downloadedData, NSError *error, BOOL finished) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:ImageLoaderErrorDomain code:ImageLoaderErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during sending the request"}] queue:context[ImageLoaderContextCallbackQueue] url:url];
            } else if (cachedImage && options & ImageLoaderRefreshCached && [error.domain isEqualToString:ImageLoaderErrorDomain] && error.code == ImageLoaderErrorCacheNotModified) {
                // Image refresh hit the NSURLCache cache, do not call the completion block
            } else if ([error.domain isEqualToString:ImageLoaderErrorDomain] && error.code == ImageLoaderErrorCancelled) {
                // Download operation cancelled by user before sending the request, don't block failed URL
                [self callCompletionBlockForOperation:operation completion:completedBlock error:error queue:context[ImageLoaderContextCallbackQueue] url:url];
            } else if (error) {
                [self callCompletionBlockForOperation:operation completion:completedBlock error:error queue:context[ImageLoaderContextCallbackQueue] url:url];
                BOOL shouldBlockFailedURL = [self shouldBlockFailedURLWithURL:url error:error options:options context:context];
                
                if (shouldBlockFailedURL) {
                    SD_LOCK(self->_failedURLsLock);
                    [self.failedURLs addObject:url];
                    SD_UNLOCK(self->_failedURLsLock);
                }
            } else {
                if ((options & ImageLoaderRetryFailed)) {
                    SD_LOCK(self->_failedURLsLock);
                    [self.failedURLs removeObject:url];
                    SD_UNLOCK(self->_failedURLsLock);
                }
                // Continue transform process
                [self callTransformProcessForOperation:operation url:url options:options context:context originalImage:downloadedImage originalData:downloadedData cacheType:LoadImageCacheTypeNone finished:finished completed:completedBlock];
            }
            
            if (finished) {
                [self safelyRemoveOperationFromRunning:operation];
            }
        }];
    } else if (cachedImage) {
        [self callCompletionBlockForOperation:operation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES queue:context[ImageLoaderContextCallbackQueue] url:url];
        [self safelyRemoveOperationFromRunning:operation];
    } else {
        // Image not in cache and download disallowed by delegate
        [self callCompletionBlockForOperation:operation completion:completedBlock image:nil data:nil error:nil cacheType:LoadImageCacheTypeNone finished:YES queue:context[ImageLoaderContextCallbackQueue] url:url];
        [self safelyRemoveOperationFromRunning:operation];
    }
}

// Transform process
- (void)callTransformProcessForOperation:(nonnull ImageLoaderCombinedOperation *)operation
                                     url:(nonnull NSURL *)url
                                 options:(ImageLoaderOptions)options
                                 context:(ImageLoaderContext *)context
                           originalImage:(nullable UIImage *)originalImage
                            originalData:(nullable NSData *)originalData
                               cacheType:(LoadImageCacheType)cacheType
                                finished:(BOOL)finished
                               completed:(nullable SDInternalCompletionBlock)completedBlock {
    id<LoadImageTransformer> transformer = context[ImageLoaderContextImageTransformer];
    if ([transformer isEqual:NSNull.null]) {
        transformer = nil;
    }
    // transformer check
    BOOL shouldTransformImage = originalImage && transformer;
    shouldTransformImage = shouldTransformImage && (!originalImage._isAnimated || (options & ImageLoaderTransformAnimatedImage));
    shouldTransformImage = shouldTransformImage && (!originalImage._isVector || (options & ImageLoaderTransformVectorImage));
    // thumbnail check
    BOOL isThumbnail = originalImage._isThumbnail;
    NSData *cacheData = originalData;
    UIImage *cacheImage = originalImage;
    if (isThumbnail) {
        cacheData = nil; // thumbnail don't store full size data
        originalImage = nil; // thumbnail don't have full size image
    }
    
    if (shouldTransformImage) {
        // transformed cache key
        NSString *key = [self cacheKeyForURL:url context:context];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // Case that transformer on thumbnail, which this time need full pixel image
            UIImage *transformedImage = [transformer transformedImageWithImage:cacheImage forKey:key];
            if (transformedImage) {
                transformedImage._isTransformed = YES;
                [self callStoreOriginCacheProcessForOperation:operation url:url options:options context:context originalImage:originalImage cacheImage:transformedImage originalData:originalData cacheData:nil cacheType:cacheType finished:finished completed:completedBlock];
            } else {
                [self callStoreOriginCacheProcessForOperation:operation url:url options:options context:context originalImage:originalImage cacheImage:cacheImage originalData:originalData cacheData:cacheData cacheType:cacheType finished:finished completed:completedBlock];
            }
        });
    } else {
        [self callStoreOriginCacheProcessForOperation:operation url:url options:options context:context originalImage:originalImage cacheImage:cacheImage originalData:originalData cacheData:cacheData cacheType:cacheType finished:finished completed:completedBlock];
    }
}

// Store origin cache process
- (void)callStoreOriginCacheProcessForOperation:(nonnull ImageLoaderCombinedOperation *)operation
                                            url:(nonnull NSURL *)url
                                        options:(ImageLoaderOptions)options
                                        context:(ImageLoaderContext *)context
                                  originalImage:(nullable UIImage *)originalImage
                                     cacheImage:(nullable UIImage *)cacheImage
                                   originalData:(nullable NSData *)originalData
                                      cacheData:(nullable NSData *)cacheData
                                      cacheType:(LoadImageCacheType)cacheType
                                       finished:(BOOL)finished
                                      completed:(nullable SDInternalCompletionBlock)completedBlock {
    // Grab the image cache to use, choose standalone original cache firstly
    id<LoadImageCache> imageCache = context[ImageLoaderContextOriginalImageCache];
    if (!imageCache) {
        // if no standalone cache available, use default cache
        imageCache = context[ImageLoaderContextImageCache];
        if (!imageCache) {
            imageCache = self.imageCache;
        }
    }
    // the original store image cache type
    LoadImageCacheType originalStoreCacheType = LoadImageCacheTypeDisk;
    if (context[ImageLoaderContextOriginalStoreCacheType]) {
        originalStoreCacheType = [context[ImageLoaderContextOriginalStoreCacheType] integerValue];
    }
    id<ImageLoaderCacheSerializer> cacheSerializer = context[ImageLoaderContextCacheSerializer];
    
    // If the original cacheType is disk, since we don't need to store the original data again
    // Strip the disk from the originalStoreCacheType
    if (cacheType == LoadImageCacheTypeDisk) {
        if (originalStoreCacheType == LoadImageCacheTypeDisk) originalStoreCacheType = LoadImageCacheTypeNone;
        if (originalStoreCacheType == LoadImageCacheTypeAll) originalStoreCacheType = LoadImageCacheTypeMemory;
    }
    
    // Get original cache key generation without transformer
    NSString *key = [self originalCacheKeyForURL:url context:context];
    if (finished && cacheSerializer && (originalStoreCacheType == LoadImageCacheTypeDisk || originalStoreCacheType == LoadImageCacheTypeAll)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSData *newOriginalData = [cacheSerializer cacheDataWithImage:originalImage originalData:originalData imageURL:url];
            // Store original image and data
            [self storeImage:originalImage imageData:newOriginalData forKey:key options:options context:context imageCache:imageCache cacheType:originalStoreCacheType finished:finished completion:^{
                // Continue store cache process, transformed data is nil
                [self callStoreCacheProcessForOperation:operation url:url options:options context:context image:cacheImage data:cacheData cacheType:cacheType finished:finished completed:completedBlock];
            }];
        });
    } else {
        // Store original image and data
        [self storeImage:originalImage imageData:originalData forKey:key options:options context:context imageCache:imageCache cacheType:originalStoreCacheType finished:finished completion:^{
            // Continue store cache process, transformed data is nil
            [self callStoreCacheProcessForOperation:operation url:url options:options context:context image:cacheImage data:cacheData cacheType:cacheType finished:finished completed:completedBlock];
        }];
    }
}

// Store normal cache process
- (void)callStoreCacheProcessForOperation:(nonnull ImageLoaderCombinedOperation *)operation
                                      url:(nonnull NSURL *)url
                                  options:(ImageLoaderOptions)options
                                  context:(ImageLoaderContext *)context
                                    image:(nullable UIImage *)image
                                     data:(nullable NSData *)data
                                cacheType:(LoadImageCacheType)cacheType
                                 finished:(BOOL)finished
                                completed:(nullable SDInternalCompletionBlock)completedBlock {
    // Grab the image cache to use
    id<LoadImageCache> imageCache = context[ImageLoaderContextImageCache];
    if (!imageCache) {
        imageCache = self.imageCache;
    }
    // the target image store cache type
    LoadImageCacheType storeCacheType = LoadImageCacheTypeAll;
    if (context[ImageLoaderContextStoreCacheType]) {
        storeCacheType = [context[ImageLoaderContextStoreCacheType] integerValue];
    }
    id<ImageLoaderCacheSerializer> cacheSerializer = context[ImageLoaderContextCacheSerializer];
    
    // transformed cache key
    NSString *key = [self cacheKeyForURL:url context:context];
    if (finished && cacheSerializer && (storeCacheType == LoadImageCacheTypeDisk || storeCacheType == LoadImageCacheTypeAll)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSData *newData = [cacheSerializer cacheDataWithImage:image originalData:data imageURL:url];
            // Store image and data
            [self storeImage:image imageData:newData forKey:key options:options context:context imageCache:imageCache cacheType:storeCacheType finished:finished completion:^{
                [self callCompletionBlockForOperation:operation completion:completedBlock image:image data:data error:nil cacheType:cacheType finished:finished queue:context[ImageLoaderContextCallbackQueue] url:url];
            }];
        });
    } else {
        // Store image and data
        [self storeImage:image imageData:data forKey:key options:options context:context imageCache:imageCache cacheType:storeCacheType finished:finished completion:^{
            [self callCompletionBlockForOperation:operation completion:completedBlock image:image data:data error:nil cacheType:cacheType finished:finished queue:context[ImageLoaderContextCallbackQueue] url:url];
        }];
    }
}

#pragma mark - Helper

- (void)safelyRemoveOperationFromRunning:(nullable ImageLoaderCombinedOperation*)operation {
    if (!operation) {
        return;
    }
    SD_LOCK(_runningOperationsLock);
    [self.runningOperations removeObject:operation];
    SD_UNLOCK(_runningOperationsLock);
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)data
            forKey:(nullable NSString *)key
           options:(ImageLoaderOptions)options
           context:(nullable ImageLoaderContext *)context
        imageCache:(nonnull id<LoadImageCache>)imageCache
         cacheType:(LoadImageCacheType)cacheType
          finished:(BOOL)finished
        completion:(nullable ImageLoaderNoParamsBlock)completion {
    BOOL waitStoreCache = SD_OPTIONS_CONTAINS(options, ImageLoaderWaitStoreCache);
    // Ignore progressive data cache
    if (!finished) {
        if (completion) {
            completion();
        }
        return;
    }
    // Check whether we should wait the store cache finished. If not, callback immediately
    if ([imageCache respondsToSelector:@selector(storeImage:imageData:forKey:options:context:cacheType:completion:)]) {
        [imageCache storeImage:image imageData:data forKey:key options:options context:context cacheType:cacheType completion:^{
            if (waitStoreCache) {
                if (completion) {
                    completion();
                }
            }
        }];
    } else {
        [imageCache storeImage:image imageData:data forKey:key cacheType:cacheType completion:^{
            if (waitStoreCache) {
                if (completion) {
                    completion();
                }
            }
        }];
    }
    if (!waitStoreCache) {
        if (completion) {
            completion();
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable ImageLoaderCombinedOperation*)operation
                             completion:(nullable SDInternalCompletionBlock)completionBlock
                                  error:(nullable NSError *)error
                                  queue:(nullable SDCallbackQueue *)queue
                                    url:(nullable NSURL *)url {
    [self callCompletionBlockForOperation:operation completion:completionBlock image:nil data:nil error:error cacheType:LoadImageCacheTypeNone finished:YES queue:queue url:url];
}

- (void)callCompletionBlockForOperation:(nullable ImageLoaderCombinedOperation*)operation
                             completion:(nullable SDInternalCompletionBlock)completionBlock
                                  image:(nullable UIImage *)image
                                   data:(nullable NSData *)data
                                  error:(nullable NSError *)error
                              cacheType:(LoadImageCacheType)cacheType
                               finished:(BOOL)finished
                                  queue:(nullable SDCallbackQueue *)queue
                                    url:(nullable NSURL *)url {
    if (completionBlock) {
        [(queue ?: SDCallbackQueue.mainQueue) async:^{
            completionBlock(image, data, error, cacheType, finished, url);
        }];
    }
}

- (BOOL)shouldBlockFailedURLWithURL:(nonnull NSURL *)url
                              error:(nonnull NSError *)error
                            options:(ImageLoaderOptions)options
                            context:(nullable ImageLoaderContext *)context {
    id<LoadImageLoader> imageLoader = context[ImageLoaderContextImageLoader];
    if (!imageLoader) {
        imageLoader = self.imageLoader;
    }
    // Check whether we should block failed url
    BOOL shouldBlockFailedURL;
    if ([self.delegate respondsToSelector:@selector(imageManager:shouldBlockFailedURL:withError:)]) {
        shouldBlockFailedURL = [self.delegate imageManager:self shouldBlockFailedURL:url withError:error];
    } else {
        if ([imageLoader respondsToSelector:@selector(shouldBlockFailedURLWithURL:error:options:context:)]) {
            shouldBlockFailedURL = [imageLoader shouldBlockFailedURLWithURL:url error:error options:options context:context];
        } else {
            shouldBlockFailedURL = [imageLoader shouldBlockFailedURLWithURL:url error:error];
        }
    }
    
    return shouldBlockFailedURL;
}

- (ImageLoaderOptionsResult *)processedResultForURL:(NSURL *)url options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context {
    ImageLoaderOptionsResult *result;
    ImageLoaderMutableContext *mutableContext = [ImageLoaderMutableContext dictionary];
    
    // Image Transformer from manager
    if (!context[ImageLoaderContextImageTransformer]) {
        id<LoadImageTransformer> transformer = self.transformer;
        [mutableContext setValue:transformer forKey:ImageLoaderContextImageTransformer];
    }
    // Cache key filter from manager
    if (!context[ImageLoaderContextCacheKeyFilter]) {
        id<ImageLoaderCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
        [mutableContext setValue:cacheKeyFilter forKey:ImageLoaderContextCacheKeyFilter];
    }
    // Cache serializer from manager
    if (!context[ImageLoaderContextCacheSerializer]) {
        id<ImageLoaderCacheSerializer> cacheSerializer = self.cacheSerializer;
        [mutableContext setValue:cacheSerializer forKey:ImageLoaderContextCacheSerializer];
    }
    
    if (mutableContext.count > 0) {
        if (context) {
            [mutableContext addEntriesFromDictionary:context];
        }
        context = [mutableContext copy];
    }
    
    // Apply options processor
    if (self.optionsProcessor) {
        result = [self.optionsProcessor processedResultForURL:url options:options context:context];
    }
    if (!result) {
        // Use default options result
        result = [[ImageLoaderOptionsResult alloc] initWithOptions:options context:context];
    }
    
    return result;
}

@end


@implementation ImageLoaderCombinedOperation

- (BOOL)isCancelled {
    // Need recursive lock (user's cancel block may check isCancelled), do not use SD_LOCK
    @synchronized (self) {
        return _cancelled;
    }
}

- (void)cancel {
    // Need recursive lock (user's cancel block may check isCancelled), do not use SD_LOCK
    @synchronized(self) {
        if (_cancelled) {
            return;
        }
        _cancelled = YES;
        if (self.cacheOperation) {
            [self.cacheOperation cancel];
            self.cacheOperation = nil;
        }
        if (self.loaderOperation) {
            [self.loaderOperation cancel];
            self.loaderOperation = nil;
        }
        [self.manager safelyRemoveOperationFromRunning:self];
    }
}

@end
