/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "LoadImageCache.h"
#import "NSImage+Compatibility.h"
#import "LoadImageCodersManager.h"
#import "LoadImageCoderHelper.h"
#import "SDAnimatedImage.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+Metadata.h"
#import "UIImage+ExtendedCacheData.h"
#import "SDCallbackQueue.h"

@interface LoadImageCacheToken ()

@property (nonatomic, strong, nullable, readwrite) NSString *key;
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, copy, nullable) LoadImageCacheQueryCompletionBlock doneBlock;
@property (nonatomic, strong, nullable) SDCallbackQueue *callbackQueue;

@end

@implementation LoadImageCacheToken

-(instancetype)initWithDoneBlock:(nullable LoadImageCacheQueryCompletionBlock)doneBlock {
    self = [super init];
    if (self) {
        self.doneBlock = doneBlock;
    }
    return self;
}

- (void)cancel {
    @synchronized (self) {
        if (self.isCancelled) {
            return;
        }
        self.cancelled = YES;
        
        LoadImageCacheQueryCompletionBlock doneBlock = self.doneBlock;
        self.doneBlock = nil;
        if (doneBlock) {
            [(self.callbackQueue ?: SDCallbackQueue.mainQueue) async:^{
                doneBlock(nil, nil, LoadImageCacheTypeNone);
            }];
        }
    }
}

@end

static NSString * _defaultDiskCacheDirectory;

@interface LoadImageCache ()

#pragma mark - Properties
@property (nonatomic, strong, readwrite, nonnull) id<SDMemoryCache> memoryCache;
@property (nonatomic, strong, readwrite, nonnull) id<SDDiskCache> diskCache;
@property (nonatomic, copy, readwrite, nonnull) LoadImageCacheConfig *config;
@property (nonatomic, copy, readwrite, nonnull) NSString *diskCachePath;
@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

@end


@implementation LoadImageCache

#pragma mark - Singleton, init, dealloc

+ (nonnull instancetype)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

+ (NSString *)defaultDiskCacheDirectory {
    if (!_defaultDiskCacheDirectory) {
        _defaultDiskCacheDirectory = [[self userCacheDirectory] stringByAppendingPathComponent:@"com.hackemist.LoadImageCache"];
    }
    return _defaultDiskCacheDirectory;
}

+ (void)setDefaultDiskCacheDirectory:(NSString *)defaultDiskCacheDirectory {
    _defaultDiskCacheDirectory = [defaultDiskCacheDirectory copy];
}

- (instancetype)init {
    return [self initWithNamespace:@"default"];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns {
    return [self initWithNamespace:ns diskCacheDirectory:nil];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory {
    return [self initWithNamespace:ns diskCacheDirectory:directory config:LoadImageCacheConfig.defaultCacheConfig];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory
                                   config:(nullable LoadImageCacheConfig *)config {
    if ((self = [super init])) {
        NSAssert(ns, @"Cache namespace should not be nil");
        
        if (!config) {
            config = LoadImageCacheConfig.defaultCacheConfig;
        }
        _config = [config copy];
        
        // Create IO queue
        dispatch_queue_attr_t ioQueueAttributes = _config.ioQueueAttributes;
        _ioQueue = dispatch_queue_create("com.hackemist.LoadImageCache.ioQueue", ioQueueAttributes);
        NSAssert(_ioQueue, @"The IO queue should not be nil. Your configured `ioQueueAttributes` may be wrong");
        
        // Init the memory cache
        NSAssert([config.memoryCacheClass conformsToProtocol:@protocol(SDMemoryCache)], @"Custom memory cache class must conform to `SDMemoryCache` protocol");
        _memoryCache = [[config.memoryCacheClass alloc] initWithConfig:_config];
        
        // Init the disk cache
        if (!directory) {
            // Use default disk cache directory
            directory = [self.class defaultDiskCacheDirectory];
        }
        _diskCachePath = [directory stringByAppendingPathComponent:ns];
        
        NSAssert([config.diskCacheClass conformsToProtocol:@protocol(SDDiskCache)], @"Custom disk cache class must conform to `SDDiskCache` protocol");
        _diskCache = [[config.diskCacheClass alloc] initWithCachePath:_diskCachePath config:_config];
        
        // Check and migrate disk cache directory if need
        [self migrateDiskCacheDirectory];

#if SD_UIKIT
        // Subscribe to app events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
#if SD_MAC
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
#endif
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Cache paths

- (nullable NSString *)cachePathForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    return [self.diskCache cachePathForKey:key];
}

+ (nullable NSString *)userCacheDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths.firstObject;
}

- (void)migrateDiskCacheDirectory {
    if ([self.diskCache isKindOfClass:[SDDiskCache class]]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // ~/Library/Caches/com.hackemist.LoadImageCache/default/
            NSString *newDefaultPath = [[[self.class userCacheDirectory] stringByAppendingPathComponent:@"com.hackemist.LoadImageCache"] stringByAppendingPathComponent:@"default"];
            // ~/Library/Caches/default/com.hackemist.ImageLoaderCache.default/
            NSString *oldDefaultPath = [[[self.class userCacheDirectory] stringByAppendingPathComponent:@"default"] stringByAppendingPathComponent:@"com.hackemist.ImageLoaderCache.default"];
            dispatch_async(self.ioQueue, ^{
                [((SDDiskCache *)self.diskCache) moveCacheDirectoryFromPath:oldDefaultPath toPath:newDefaultPath];
            });
        });
    }
}

#pragma mark - Store Ops

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable ImageLoaderNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key options:0 context:nil cacheType:LoadImageCacheTypeAll completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable ImageLoaderNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key options:0 context:nil cacheType:(toDisk ? LoadImageCacheTypeAll : LoadImageCacheTypeMemory) completion:completionBlock];
}

- (void)storeImageData:(nullable NSData *)imageData
                forKey:(nullable NSString *)key
            completion:(nullable ImageLoaderNoParamsBlock)completionBlock {
    [self storeImage:nil imageData:imageData forKey:key options:0 context:nil cacheType:LoadImageCacheTypeAll completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable ImageLoaderNoParamsBlock)completionBlock {
    [self storeImage:image imageData:imageData forKey:key options:0 context:nil cacheType:(toDisk ? LoadImageCacheTypeAll : LoadImageCacheTypeMemory) completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
           options:(ImageLoaderOptions)options
           context:(nullable ImageLoaderContext *)context
         cacheType:(LoadImageCacheType)cacheType
        completion:(nullable ImageLoaderNoParamsBlock)completionBlock {
    if ((!image && !imageData) || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    BOOL toMemory = cacheType == LoadImageCacheTypeMemory || cacheType == LoadImageCacheTypeAll;
    BOOL toDisk = cacheType == LoadImageCacheTypeDisk || cacheType == LoadImageCacheTypeAll;
    // if memory cache is enabled
    if (image && toMemory && self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = image.btg_memoryCost;
        [self.memoryCache setObject:image forKey:key cost:cost];
    }
    
    if (!toDisk) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    NSData *data = imageData;
    if (!data && [image respondsToSelector:@selector(animatedImageData)]) {
        // If image is custom animated image class, prefer its original animated data
        data = [((id<SDAnimatedImage>)image) animatedImageData];
    }
    SDCallbackQueue *queue = context[ImageLoaderContextCallbackQueue];
    if (!data && image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // Check image's associated image format, may return .undefined
            LoadImageFormat format = image.btg_imageFormat;
            if (format == LoadImageFormatUndefined) {
                // If image is animated, use GIF (APNG may be better, but has bugs before macOS 10.14)
                if (image.btg_imageFrameCount > 1) {
                    format = LoadImageFormatGIF;
                } else {
                    // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
                    format = [LoadImageCoderHelper CGImageContainsAlpha:image.CGImage] ? LoadImageFormatPNG : LoadImageFormatJPEG;
                }
            }
            NSData *data = [[LoadImageCodersManager sharedManager] encodedDataWithImage:image format:format options:context[ImageLoaderContextImageEncodeOptions]];
            dispatch_async(self.ioQueue, ^{
                [self _storeImageDataToDisk:data forKey:key];
                [self _archivedDataWithImage:image forKey:key];
                if (completionBlock) {
                    [(queue ?: SDCallbackQueue.mainQueue) async:^{
                        completionBlock();
                    }];
                }
            });
        });
    } else {
        dispatch_async(self.ioQueue, ^{
            [self _storeImageDataToDisk:data forKey:key];
            [self _archivedDataWithImage:image forKey:key];
            if (completionBlock) {
                [(queue ?: SDCallbackQueue.mainQueue) async:^{
                    completionBlock();
                }];
            }
        });
    }
}

- (void)_archivedDataWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    // Check extended data
    id extendedObject = image.btg_extendedObject;
    if (![extendedObject conformsToProtocol:@protocol(NSCoding)]) {
        return;
    }
    NSData *extendedData;
    if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
        NSError *error;
        extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject requiringSecureCoding:NO error:&error];
        if (error) {
            NSLog(@"NSKeyedArchiver archive failed with error: %@", error);
        }
    } else {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject];
#pragma clang diagnostic pop
        } @catch (NSException *exception) {
            NSLog(@"NSKeyedArchiver archive failed with exception: %@", exception);
        }
    }
    if (extendedData) {
        [self.diskCache setExtendedData:extendedData forKey:key];
    }
}

- (void)storeImageToMemory:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    NSUInteger cost = image.btg_memoryCost;
    [self.memoryCache setObject:image forKey:key cost:cost];
}

- (void)storeImageDataToDisk:(nullable NSData *)imageData
                      forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    dispatch_sync(self.ioQueue, ^{
        [self _storeImageDataToDisk:imageData forKey:key];
    });
}

// Make sure to call from io queue by caller
- (void)_storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    [self.diskCache setData:imageData forKey:key];
}

#pragma mark - Query and Retrieve Ops

- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable LoadImageCacheCheckCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        BOOL exists = [self _diskImageDataExistsWithKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (BOOL)diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    
    __block BOOL exists = NO;
    dispatch_sync(self.ioQueue, ^{
        exists = [self _diskImageDataExistsWithKey:key];
    });
    
    return exists;
}

// Make sure to call from io queue by caller
- (BOOL)_diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    
    return [self.diskCache containsDataForKey:key];
}

- (void)diskImageDataQueryForKey:(NSString *)key completion:(LoadImageCacheQueryDataCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSData *imageData = [self diskImageDataBySearchingAllPathsForKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(imageData);
            });
        }
    });
}

- (nullable NSData *)diskImageDataForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    __block NSData *imageData = nil;
    dispatch_sync(self.ioQueue, ^{
        imageData = [self diskImageDataBySearchingAllPathsForKey:key];
    });
    
    return imageData;
}

- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key {
    return [self.memoryCache objectForKey:key];
}

- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key {
    return [self imageFromDiskCacheForKey:key options:0 context:nil];
}

- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key options:(LoadImageCacheOptions)options context:(nullable ImageLoaderContext *)context {
    if (!key) {
        return nil;
    }
    NSData *data = [self diskImageDataForKey:key];
    UIImage *diskImage = [self diskImageForKey:key data:data options:options context:context];
    
    BOOL shouldCacheToMomery = YES;
    if (context[ImageLoaderContextStoreCacheType]) {
        LoadImageCacheType cacheType = [context[ImageLoaderContextStoreCacheType] integerValue];
        shouldCacheToMomery = (cacheType == LoadImageCacheTypeAll || cacheType == LoadImageCacheTypeMemory);
    }
    CGSize thumbnailSize = CGSizeZero;
    NSValue *thumbnailSizeValue = context[ImageLoaderContextImageThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
#if SD_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
#else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
#endif
    }
    if (thumbnailSize.width > 0 && thumbnailSize.height > 0) {
        // Query full size cache key which generate a thumbnail, should not write back to full size memory cache
        shouldCacheToMomery = NO;
    }
    if (shouldCacheToMomery && diskImage && self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = diskImage.btg_memoryCost;
        [self.memoryCache setObject:diskImage forKey:key cost:cost];
    }

    return diskImage;
}

- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key {
    return [self imageFromCacheForKey:key options:0 context:nil];
}

- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key options:(LoadImageCacheOptions)options context:(nullable ImageLoaderContext *)context {
    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        if (options & LoadImageCacheDecodeFirstFrameOnly) {
            // Ensure static image
            if (image.btg_imageFrameCount > 1) {
#if SD_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & LoadImageCacheMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[ImageLoaderContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }
    
    // Since we don't need to query imageData, return image if exist
    if (image) {
        return image;
    }
    
    // Second check the disk cache...
    image = [self imageFromDiskCacheForKey:key options:options context:context];
    return image;
}

- (nullable NSData *)diskImageDataBySearchingAllPathsForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    
    NSData *data = [self.diskCache dataForKey:key];
    if (data) {
        return data;
    }
    
    // Addtional cache path for custom pre-load cache
    if (self.additionalCachePathBlock) {
        NSString *filePath = self.additionalCachePathBlock(key);
        if (filePath) {
            data = [NSData dataWithContentsOfFile:filePath options:self.config.diskCacheReadingOptions error:nil];
        }
    }

    return data;
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    NSData *data = [self diskImageDataForKey:key];
    return [self diskImageForKey:key data:data options:0 context:nil];
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key data:(nullable NSData *)data options:(LoadImageCacheOptions)options context:(ImageLoaderContext *)context {
    if (!data) {
        return nil;
    }
    UIImage *image = LoadImageCacheDecodeImageData(data, key, [[self class] imageOptionsFromCacheOptions:options], context);
    [self _unarchiveObjectWithImage:image forKey:key];
    return image;
}

- (void)_unarchiveObjectWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    // Check extended data
    NSData *extendedData = [self.diskCache extendedDataForKey:key];
    if (!extendedData) {
        return;
    }
    id extendedObject;
    if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
        NSError *error;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:extendedData error:&error];
        unarchiver.requiresSecureCoding = NO;
        extendedObject = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
        if (error) {
            NSLog(@"NSKeyedUnarchiver unarchive failed with error: %@", error);
        }
    } else {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            extendedObject = [NSKeyedUnarchiver unarchiveObjectWithData:extendedData];
#pragma clang diagnostic pop
        } @catch (NSException *exception) {
            NSLog(@"NSKeyedUnarchiver unarchive failed with exception: %@", exception);
        }
    }
    image.btg_extendedObject = extendedObject;
}

- (nullable LoadImageCacheToken *)queryCacheOperationForKey:(NSString *)key done:(LoadImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:0 done:doneBlock];
}

- (nullable LoadImageCacheToken *)queryCacheOperationForKey:(NSString *)key options:(LoadImageCacheOptions)options done:(LoadImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:options context:nil done:doneBlock];
}

- (nullable LoadImageCacheToken *)queryCacheOperationForKey:(nullable NSString *)key options:(LoadImageCacheOptions)options context:(nullable ImageLoaderContext *)context done:(nullable LoadImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:options context:context cacheType:LoadImageCacheTypeAll done:doneBlock];
}

- (nullable LoadImageCacheToken *)queryCacheOperationForKey:(nullable NSString *)key options:(LoadImageCacheOptions)options context:(nullable ImageLoaderContext *)context cacheType:(LoadImageCacheType)queryCacheType done:(nullable LoadImageCacheQueryCompletionBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, LoadImageCacheTypeNone);
        }
        return nil;
    }
    // Invalid cache type
    if (queryCacheType == LoadImageCacheTypeNone) {
        if (doneBlock) {
            doneBlock(nil, nil, LoadImageCacheTypeNone);
        }
        return nil;
    }
    
    // First check the in-memory cache...
    UIImage *image;
    if (queryCacheType != LoadImageCacheTypeDisk) {
        image = [self imageFromMemoryCacheForKey:key];
    }
    
    if (image) {
        if (options & LoadImageCacheDecodeFirstFrameOnly) {
            // Ensure static image
            if (image.btg_imageFrameCount > 1) {
#if SD_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & LoadImageCacheMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[ImageLoaderContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }

    BOOL shouldQueryMemoryOnly = (queryCacheType == LoadImageCacheTypeMemory) || (image && !(options & LoadImageCacheQueryMemoryData));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, LoadImageCacheTypeMemory);
        }
        return nil;
    }
    
    // Second check the disk cache...
    SDCallbackQueue *queue = context[ImageLoaderContextCallbackQueue];
    LoadImageCacheToken *operation = [[LoadImageCacheToken alloc] initWithDoneBlock:doneBlock];
    operation.key = key;
    operation.callbackQueue = queue;
    // Check whether we need to synchronously query disk
    // 1. in-memory cache hit & memoryDataSync
    // 2. in-memory cache miss & diskDataSync
    BOOL shouldQueryDiskSync = ((image && options & LoadImageCacheQueryMemoryDataSync) ||
                                (!image && options & LoadImageCacheQueryDiskDataSync));
    NSData* (^queryDiskDataBlock)(void) = ^NSData* {
        @synchronized (operation) {
            if (operation.isCancelled) {
                return nil;
            }
        }
        
        return [self diskImageDataBySearchingAllPathsForKey:key];
    };
    
    UIImage* (^queryDiskImageBlock)(NSData*) = ^UIImage*(NSData* diskData) {
        @synchronized (operation) {
            if (operation.isCancelled) {
                return nil;
            }
        }
        
        UIImage *diskImage;
        if (image) {
            // the image is from in-memory cache, but need image data
            diskImage = image;
        } else if (diskData) {
            BOOL shouldCacheToMomery = YES;
            if (context[ImageLoaderContextStoreCacheType]) {
                LoadImageCacheType cacheType = [context[ImageLoaderContextStoreCacheType] integerValue];
                shouldCacheToMomery = (cacheType == LoadImageCacheTypeAll || cacheType == LoadImageCacheTypeMemory);
            }
            CGSize thumbnailSize = CGSizeZero;
            NSValue *thumbnailSizeValue = context[ImageLoaderContextImageThumbnailPixelSize];
            if (thumbnailSizeValue != nil) {
        #if SD_MAC
                thumbnailSize = thumbnailSizeValue.sizeValue;
        #else
                thumbnailSize = thumbnailSizeValue.CGSizeValue;
        #endif
            }
            if (thumbnailSize.width > 0 && thumbnailSize.height > 0) {
                // Query full size cache key which generate a thumbnail, should not write back to full size memory cache
                shouldCacheToMomery = NO;
            }
            // Special case: If user query image in list for the same URL, to avoid decode and write **same** image object into disk cache multiple times, we query and check memory cache here again.
            if (shouldCacheToMomery && self.config.shouldCacheImagesInMemory) {
                diskImage = [self.memoryCache objectForKey:key];
            }
            // decode image data only if in-memory cache missed
            if (!diskImage) {
                diskImage = [self diskImageForKey:key data:diskData options:options context:context];
                if (shouldCacheToMomery && diskImage && self.config.shouldCacheImagesInMemory) {
                    NSUInteger cost = diskImage.btg_memoryCost;
                    [self.memoryCache setObject:diskImage forKey:key cost:cost];
                }
            }
        }
        return diskImage;
    };
    
    // Query in ioQueue to keep IO-safe
    if (shouldQueryDiskSync) {
        __block NSData* diskData;
        __block UIImage* diskImage;
        dispatch_sync(self.ioQueue, ^{
            diskData = queryDiskDataBlock();
            diskImage = queryDiskImageBlock(diskData);
        });
        if (doneBlock) {
            doneBlock(diskImage, diskData, LoadImageCacheTypeDisk);
        }
    } else {
        dispatch_async(self.ioQueue, ^{
            NSData* diskData = queryDiskDataBlock();
            UIImage* diskImage = queryDiskImageBlock(diskData);
            @synchronized (operation) {
                if (operation.isCancelled) {
                    return;
                }
            }
            if (doneBlock) {
                [(queue ?: SDCallbackQueue.mainQueue) async:^{
                    // Dispatch from IO queue to main queue need time, user may call cancel during the dispatch timing
                    // This check is here to avoid double callback (one is from `LoadImageCacheToken` in sync)
                    @synchronized (operation) {
                        if (operation.isCancelled) {
                            return;
                        }
                    }
                    doneBlock(diskImage, diskData, LoadImageCacheTypeDisk);
                }];
            }
        });
    }
    
    return operation;
}

#pragma mark - Remove Ops

- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable ImageLoaderNoParamsBlock)completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable ImageLoaderNoParamsBlock)completion {
    [self removeImageForKey:key fromMemory:YES fromDisk:fromDisk withCompletion:completion];
}

- (void)removeImageForKey:(nullable NSString *)key fromMemory:(BOOL)fromMemory fromDisk:(BOOL)fromDisk withCompletion:(nullable ImageLoaderNoParamsBlock)completion {
    if (!key) {
        return;
    }

    if (fromMemory && self.config.shouldCacheImagesInMemory) {
        [self.memoryCache removeObjectForKey:key];
    }

    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            [self.diskCache removeDataForKey:key];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion) {
        completion();
    }
}

- (void)removeImageFromMemoryForKey:(NSString *)key {
    if (!key) {
        return;
    }
    
    [self.memoryCache removeObjectForKey:key];
}

- (void)removeImageFromDiskForKey:(NSString *)key {
    if (!key) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self _removeImageFromDiskForKey:key];
    });
}

// Make sure to call from io queue by caller
- (void)_removeImageFromDiskForKey:(NSString *)key {
    if (!key) {
        return;
    }
    
    [self.diskCache removeDataForKey:key];
}

#pragma mark - Cache clean Ops

- (void)clearMemory {
    [self.memoryCache removeAllObjects];
}

- (void)clearDiskOnCompletion:(nullable ImageLoaderNoParamsBlock)completion {
    dispatch_async(self.ioQueue, ^{
        [self.diskCache removeAllData];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)deleteOldFilesWithCompletionBlock:(nullable ImageLoaderNoParamsBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        [self.diskCache removeExpiredData];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

#pragma mark - UIApplicationWillTerminateNotification

#if SD_UIKIT || SD_MAC
- (void)applicationWillTerminate:(NSNotification *)notification {
    // On iOS/macOS, the async opeartion to remove exipred data will be terminated quickly
    // Try using the sync operation to ensure we reomve the exipred data
    if (!self.config.shouldRemoveExpiredDataWhenTerminate) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self.diskCache removeExpiredData];
    });
}
#endif

#pragma mark - UIApplicationDidEnterBackgroundNotification

#if SD_UIKIT
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (!self.config.shouldRemoveExpiredDataWhenEnterBackground) {
        return;
    }
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
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}
#endif

#pragma mark - Cache Info

- (NSUInteger)totalDiskSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        size = [self.diskCache totalSize];
    });
    return size;
}

- (NSUInteger)totalDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        count = [self.diskCache totalCount];
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(nullable LoadImageCacheCalculateSizeBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = [self.diskCache totalCount];
        NSUInteger totalSize = [self.diskCache totalSize];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

#pragma mark - Helper
+ (ImageLoaderOptions)imageOptionsFromCacheOptions:(LoadImageCacheOptions)cacheOptions {
    ImageLoaderOptions options = 0;
    if (cacheOptions & LoadImageCacheScaleDownLargeImages) options |= ImageLoaderScaleDownLargeImages;
    if (cacheOptions & LoadImageCacheDecodeFirstFrameOnly) options |= ImageLoaderDecodeFirstFrameOnly;
    if (cacheOptions & LoadImageCachePreloadAllFrames) options |= ImageLoaderPreloadAllFrames;
    if (cacheOptions & LoadImageCacheAvoidDecodeImage) options |= ImageLoaderAvoidDecodeImage;
    if (cacheOptions & LoadImageCacheMatchAnimatedImageClass) options |= ImageLoaderMatchAnimatedImageClass;
    
    return options;
}

@end

@implementation LoadImageCache (LoadImageCache)

#pragma mark - LoadImageCache

- (id<ImageLoaderOperation>)queryImageForKey:(NSString *)key options:(ImageLoaderOptions)options context:(nullable ImageLoaderContext *)context completion:(nullable LoadImageCacheQueryCompletionBlock)completionBlock {
    return [self queryImageForKey:key options:options context:context cacheType:LoadImageCacheTypeAll completion:completionBlock];
}

- (id<ImageLoaderOperation>)queryImageForKey:(NSString *)key options:(ImageLoaderOptions)options context:(nullable ImageLoaderContext *)context cacheType:(LoadImageCacheType)cacheType completion:(nullable LoadImageCacheQueryCompletionBlock)completionBlock {
    LoadImageCacheOptions cacheOptions = 0;
    if (options & ImageLoaderQueryMemoryData) cacheOptions |= LoadImageCacheQueryMemoryData;
    if (options & ImageLoaderQueryMemoryDataSync) cacheOptions |= LoadImageCacheQueryMemoryDataSync;
    if (options & ImageLoaderQueryDiskDataSync) cacheOptions |= LoadImageCacheQueryDiskDataSync;
    if (options & ImageLoaderScaleDownLargeImages) cacheOptions |= LoadImageCacheScaleDownLargeImages;
    if (options & ImageLoaderAvoidDecodeImage) cacheOptions |= LoadImageCacheAvoidDecodeImage;
    if (options & ImageLoaderDecodeFirstFrameOnly) cacheOptions |= LoadImageCacheDecodeFirstFrameOnly;
    if (options & ImageLoaderPreloadAllFrames) cacheOptions |= LoadImageCachePreloadAllFrames;
    if (options & ImageLoaderMatchAnimatedImageClass) cacheOptions |= LoadImageCacheMatchAnimatedImageClass;
    
    return [self queryCacheOperationForKey:key options:cacheOptions context:context cacheType:cacheType done:completionBlock];
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(nullable NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(nullable ImageLoaderNoParamsBlock)completionBlock {
    [self storeImage:image imageData:imageData forKey:key options:0 context:nil cacheType:cacheType completion:completionBlock];
}

- (void)removeImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(nullable ImageLoaderNoParamsBlock)completionBlock {
    switch (cacheType) {
        case LoadImageCacheTypeNone: {
            [self removeImageForKey:key fromMemory:NO fromDisk:NO withCompletion:completionBlock];
        }
            break;
        case LoadImageCacheTypeMemory: {
            [self removeImageForKey:key fromMemory:YES fromDisk:NO withCompletion:completionBlock];
        }
            break;
        case LoadImageCacheTypeDisk: {
            [self removeImageForKey:key fromMemory:NO fromDisk:YES withCompletion:completionBlock];
        }
            break;
        case LoadImageCacheTypeAll: {
            [self removeImageForKey:key fromMemory:YES fromDisk:YES withCompletion:completionBlock];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(nullable LoadImageCacheContainsCompletionBlock)completionBlock {
    switch (cacheType) {
        case LoadImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock(LoadImageCacheTypeNone);
            }
        }
            break;
        case LoadImageCacheTypeMemory: {
            BOOL isInMemoryCache = ([self imageFromMemoryCacheForKey:key] != nil);
            if (completionBlock) {
                completionBlock(isInMemoryCache ? LoadImageCacheTypeMemory : LoadImageCacheTypeNone);
            }
        }
            break;
        case LoadImageCacheTypeDisk: {
            [self diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
                if (completionBlock) {
                    completionBlock(isInDiskCache ? LoadImageCacheTypeDisk : LoadImageCacheTypeNone);
                }
            }];
        }
            break;
        case LoadImageCacheTypeAll: {
            BOOL isInMemoryCache = ([self imageFromMemoryCacheForKey:key] != nil);
            if (isInMemoryCache) {
                if (completionBlock) {
                    completionBlock(LoadImageCacheTypeMemory);
                }
                return;
            }
            [self diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
                if (completionBlock) {
                    completionBlock(isInDiskCache ? LoadImageCacheTypeDisk : LoadImageCacheTypeNone);
                }
            }];
        }
            break;
        default:
            if (completionBlock) {
                completionBlock(LoadImageCacheTypeNone);
            }
            break;
    }
}

- (void)clearWithCacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock {
    switch (cacheType) {
        case LoadImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case LoadImageCacheTypeMemory: {
            [self clearMemory];
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case LoadImageCacheTypeDisk: {
            [self clearDiskOnCompletion:completionBlock];
        }
            break;
        case LoadImageCacheTypeAll: {
            [self clearMemory];
            [self clearDiskOnCompletion:completionBlock];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

@end

