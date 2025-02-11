/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCompat.h"

typedef void(^ImageLoaderNoParamsBlock)(void);
typedef NSString * ImageLoaderContextOption NS_EXTENSIBLE_STRING_ENUM;
typedef NSDictionary<ImageLoaderContextOption, id> ImageLoaderContext;
typedef NSMutableDictionary<ImageLoaderContextOption, id> ImageLoaderMutableContext;

#pragma mark - Image scale

/**
 Return the image scale factor for the specify key, supports file name and url key.
 This is the built-in way to check the scale factor when we have no context about it. Because scale factor is not stored in image data (It's typically from filename).
 However, you can also provide custom scale factor as well, see `ImageLoaderContextImageScaleFactor`.

 @param key The image cache key
 @return The scale factor for image
 */
FOUNDATION_EXPORT CGFloat LoadImageScaleFactorForKey(NSString * _Nullable key);

/**
 Scale the image with the scale factor for the specify key. If no need to scale, return the original image.
 This works for `UIImage`(UIKit) or `NSImage`(AppKit). And this function also preserve the associated value in `UIImage+Metadata.h`.
 @note This is actually a convenience function, which firstly call `LoadImageScaleFactorForKey` and then call `SDScaledImageForScaleFactor`, kept for backward compatibility.

 @param key The image cache key
 @param image The image
 @return The scaled image
 */
FOUNDATION_EXPORT UIImage * _Nullable SDScaledImageForKey(NSString * _Nullable key, UIImage * _Nullable image);

/**
 Scale the image with the scale factor. If no need to scale, return the original image.
 This works for `UIImage`(UIKit) or `NSImage`(AppKit). And this function also preserve the associated value in `UIImage+Metadata.h`.
 
 @param scale The image scale factor
 @param image The image
 @return The scaled image
 */
FOUNDATION_EXPORT UIImage * _Nullable SDScaledImageForScaleFactor(CGFloat scale, UIImage * _Nullable image);

#pragma mark - WebCache Options

/// WebCache options
typedef NS_OPTIONS(NSUInteger, ImageLoaderOptions) {
    /**
     * By default, when a URL fail to be downloaded, the URL is blacklisted so the library won't keep trying.
     * This flag disable this blacklisting.
     */
    ImageLoaderRetryFailed = 1 << 0,
    
    /**
     * By default, image downloads are started during UI interactions, this flags disable this feature,
     * leading to delayed download on UIScrollView deceleration for instance.
     */
    ImageLoaderLowPriority = 1 << 1,
    
    /**
     * This flag enables progressive download, the image is displayed progressively during download as a browser would do.
     * By default, the image is only displayed once completely downloaded.
     */
    ImageLoaderProgressiveLoad = 1 << 2,
    
    /**
     * Even if the image is cached, respect the HTTP response cache control, and refresh the image from remote location if needed.
     * The disk caching will be handled by NSURLCache instead of ImageLoader leading to slight performance degradation.
     * This option helps deal with images changing behind the same request URL, e.g. Facebook graph api profile pics.
     * If a cached image is refreshed, the completion block is called once with the cached image and again with the final image.
     *
     * Use this flag only if you can't make your URLs static with embedded cache busting parameter.
     */
    ImageLoaderRefreshCached = 1 << 3,
    
    /**
     * In iOS 4+, continue the download of the image if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    ImageLoaderContinueInBackground = 1 << 4,
    
    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    ImageLoaderHandleCookies = 1 << 5,
    
    /**
     * Enable to allow untrusted SSL certificates.
     * Useful for testing purposes. Use with caution in production.
     */
    ImageLoaderAllowInvalidSSLCertificates = 1 << 6,
    
    /**
     * By default, images are loaded in the order in which they were queued. This flag moves them to
     * the front of the queue.
     */
    ImageLoaderHighPriority = 1 << 7,
    
    /**
     * By default, placeholder images are loaded while the image is loading. This flag will delay the loading
     * of the placeholder image until after the image has finished loading.
     * @note This is used to treate placeholder as an **Error Placeholder** but not **Loading Placeholder** by defaults. if the image loading is cancelled or error, the placeholder will be always set.
     * @note Therefore, if you want both **Error Placeholder** and **Loading Placeholder** exist, use `ImageLoaderAvoidAutoSetImage` to manually set the two placeholders and final loaded image by your hand depends on loading result.
     */
    ImageLoaderDelayPlaceholder = 1 << 8,
    
    /**
     * We usually don't apply transform on animated images as most transformers could not manage animated images.
     * Use this flag to transform them anyway.
     */
    ImageLoaderTransformAnimatedImage = 1 << 9,
    
    /**
     * By default, image is added to the imageView after download. But in some cases, we want to
     * have the hand before setting the image (apply a filter or add it with cross-fade animation for instance)
     * Use this flag if you want to manually set the image in the completion when success
     */
    ImageLoaderAvoidAutoSetImage = 1 << 10,
    
    /**
     * By default, images are decoded respecting their original size.
     * This flag will scale down the images to a size compatible with the constrained memory of devices.
     * To control the limit memory bytes, check `LoadImageCoderHelper.defaultScaleDownLimitBytes` (Defaults to 60MB on iOS)
     * (from 5.16.0) This will actually translate to use context option `ImageLoaderContextImageScaleDownLimitBytes`, which check and calculate the thumbnail pixel size occupied small than limit bytes (including animated image)
     * (from 5.5.0) This flags effect the progressive and animated images as well
     * @note If you need detail controls, it's better to use context option `imageScaleDownBytes` instead.
     * @warning This does not effect the cache key. So which means, this will effect the global cache even next time you query without this option. Pay attention when you use this on global options (It's always recommended to use request-level option for different pipeline)
     */
    ImageLoaderScaleDownLargeImages = 1 << 11,
    
    /**
     * By default, we do not query image data when the image is already cached in memory. This mask can force to query image data at the same time. However, this query is asynchronously unless you specify `ImageLoaderQueryMemoryDataSync`
     */
    ImageLoaderQueryMemoryData = 1 << 12,
    
    /**
     * By default, when you only specify `ImageLoaderQueryMemoryData`, we query the memory image data asynchronously. Combined this mask as well to query the memory image data synchronously.
     * @note Query data synchronously is not recommend, unless you want to ensure the image is loaded in the same runloop to avoid flashing during cell reusing.
     */
    ImageLoaderQueryMemoryDataSync = 1 << 13,
    
    /**
     * By default, when the memory cache miss, we query the disk cache asynchronously. This mask can force to query disk cache (when memory cache miss) synchronously.
     * @note These 3 query options can be combined together. For the full list about these masks combination, see wiki page.
     * @note Query data synchronously is not recommend, unless you want to ensure the image is loaded in the same runloop to avoid flashing during cell reusing.
     */
    ImageLoaderQueryDiskDataSync = 1 << 14,
    
    /**
     * By default, when the cache missed, the image is load from the loader. This flag can prevent this to load from cache only.
     */
    ImageLoaderFromCacheOnly = 1 << 15,
    
    /**
     * By default, we query the cache before the image is load from the loader. This flag can prevent this to load from loader only.
     */
    ImageLoaderFromLoaderOnly = 1 << 16,
    
    /**
     * By default, when you use `ImageLoaderTransition` to do some view transition after the image load finished, this transition is only applied for image when the callback from manager is asynchronous (from network, or disk cache query)
     * This mask can force to apply view transition for any cases, like memory cache query, or sync disk cache query.
     */
    ImageLoaderForceTransition = 1 << 17,
    
    /**
     * By default, we will decode the image in the background during cache query and download from the network. This can help to improve performance because when rendering image on the screen, it need to be firstly decoded. But this happen on the main queue by Core Animation.
     * However, this process may increase the memory usage as well. If you are experiencing an issue due to excessive memory consumption, This flag can prevent decode the image.
     * @note 5.14.0 introduce `LoadImageCoderDecodeUseLazyDecoding`, use that for better control from codec, instead of post-processing. Which acts the similar like this option but works for SDAnimatedImage as well (this one does not)
     */
    ImageLoaderAvoidDecodeImage = 1 << 18,
    
    /**
     * By default, we decode the animated image. This flag can force decode the first frame only and produce the static image.
     */
    ImageLoaderDecodeFirstFrameOnly = 1 << 19,
    
    /**
     * By default, for `SDAnimatedImage`, we decode the animated image frame during rendering to reduce memory usage. However, you can specify to preload all frames into memory to reduce CPU usage when the animated image is shared by lots of imageViews.
     * This will actually trigger `preloadAllAnimatedImageFrames` in the background queue(Disk Cache & Download only).
     */
    ImageLoaderPreloadAllFrames = 1 << 20,
    
    /**
     * By default, when you use `ImageLoaderContextAnimatedImageClass` context option (like using `SDAnimatedImageView` which designed to use `SDAnimatedImage`), we may still use `UIImage` when the memory cache hit, or image decoder is not available to produce one exactlly matching your custom class as a fallback solution.
     * Using this option, can ensure we always callback image with your provided class. If failed to produce one, a error with code `ImageLoaderErrorBadImageData` will been used.
     * Note this options is not compatible with `ImageLoaderDecodeFirstFrameOnly`, which always produce a UIImage/NSImage.
     */
    ImageLoaderMatchAnimatedImageClass = 1 << 21,
    
    /**
     * By default, when we load the image from network, the image will be written to the cache (memory and disk, controlled by your `storeCacheType` context option)
     * This maybe an asynchronously operation and the final `SDInternalCompletionBlock` callback does not guarantee the disk cache written is finished and may cause logic error. (For example, you modify the disk data just in completion block, however, the disk cache is not ready)
     * If you need to process with the disk cache in the completion block, you should use this option to ensure the disk cache already been written when callback.
     * Note if you use this when using the custom cache serializer, or using the transformer, we will also wait until the output image data written is finished.
     */
    ImageLoaderWaitStoreCache = 1 << 22,
    
    /**
     * We usually don't apply transform on vector images, because vector images supports dynamically changing to any size, rasterize to a fixed size will loss details. To modify vector images, you can process the vector data at runtime (such as modifying PDF tag / SVG element).
     * Use this flag to transform them anyway.
     */
    ImageLoaderTransformVectorImage = 1 << 23
};


#pragma mark - Manager Context Options

/**
 A String to be used as the operation key for view category to store the image load operation. This is used for view instance which supports different image loading process. If nil, will use the class name as operation key. (NSString *)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextSetImageOperationKey;

/**
 A ImageLoaderManager instance to control the image download and cache process using in UIImageView+WebCache category and likes. If not provided, use the shared manager (ImageLoaderManager *)
 @deprecated Deprecated in the future. This context options can be replaced by other context option control like `.imageCache`, `.imageLoader`, `.imageTransformer` (See below), which already matches all the properties in ImageLoaderManager.
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextCustomManager API_DEPRECATED("Use individual context option like .imageCache, .imageLoader and .imageTransformer instead", macos(10.10, API_TO_BE_DEPRECATED), ios(8.0, API_TO_BE_DEPRECATED), tvos(9.0, API_TO_BE_DEPRECATED), watchos(2.0, API_TO_BE_DEPRECATED));

/**
 A `SDCallbackQueue` instance which controls the `Cache`/`Manager`/`Loader`'s callback queue for their completionBlock.
 This is useful for user who call these 3 components in non-main queue and want to avoid callback in main queue.
 @note For UI callback (`_setImageWithURL`), we will still use main queue to dispatch, means if you specify a global queue, it will enqueue from the global queue to main queue.
 @note This does not effect the components' working queue (for example, `Cache` still query disk on internal ioQueue, `Loader` still do network on URLSessionConfiguration.delegateQueue), change those config if you need.
 Defaults to nil. Which means main queue.
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextCallbackQueue;

/**
 A id<LoadImageCache> instance which conforms to `LoadImageCache` protocol. It's used to override the image manager's cache during the image loading pipeline.
 In other word, if you just want to specify a custom cache during image loading, you don't need to re-create a dummy ImageLoaderManager instance with the cache. If not provided, use the image manager's cache (id<LoadImageCache>)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageCache;

/**
 A id<LoadImageLoader> instance which conforms to `LoadImageLoader` protocol. It's used to override the image manager's loader during the image loading pipeline.
 In other word, if you just want to specify a custom loader during image loading, you don't need to re-create a dummy ImageLoaderManager instance with the loader. If not provided, use the image manager's cache (id<LoadImageLoader>)
*/
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageLoader;

/**
 A id<LoadImageCoder> instance which conforms to `LoadImageCoder` protocol. It's used to override the default image coder for image decoding(including progressive) and encoding during the image loading process.
 If you use this context option, we will not always use `LoadImageCodersManager.shared` to loop through all registered coders and find the suitable one. Instead, we will arbitrarily use the exact provided coder without extra checking (We may not call `canDecodeFromData:`).
 @note This is only useful for cases which you can ensure the loading url matches your coder, or you find it's too hard to write a common coder which can used for generic usage. This will bind the loading url with the coder logic, which is not always a good design, but possible. (id<LoadImageCache>)
*/
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageCoder;

/**
 A id<LoadImageTransformer> instance which conforms `LoadImageTransformer` protocol. It's used for image transform after the image load finished and store the transformed image to cache. If you provide one, it will ignore the `transformer` in manager and use provided one instead. If you pass NSNull, the transformer feature will be disabled. (id<LoadImageTransformer>)
 @note When this value is used, we will trigger image transform after downloaded, and the callback's data **will be nil** (because this time the data saved to disk does not match the image return to you. If you need full size data, query the cache with full size url key)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageTransformer;

#pragma mark - Image Decoder Context Options

/**
 A Dictionary (LoadImageCoderOptions) value, which pass the extra decoding options to the LoadImageCoder. Introduced in ImageLoader 5.14.0
 You can pass additional decoding related options to the decoder, extensible and control by you. And pay attention this dictionary may be retained by decoded image via `UIImage._decodeOptions` 
 This context option replace the deprecated `LoadImageCoderWebImageContext`, which may cause retain cycle (cache -> image -> options -> context -> cache)
 @note There are already individual options below like `.imageScaleFactor`, `.imagePreserveAspectRatio`, each of individual options will override the same filed for this dictionary.
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageDecodeOptions;

/**
 A CGFloat raw value which specify the image scale factor. The number should be greater than or equal to 1.0. If not provide or the number is invalid, we will use the cache key to specify the scale factor. (NSNumber)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageScaleFactor;

/**
 A Boolean value indicating whether to keep the original aspect ratio when generating thumbnail images (or bitmap images from vector format).
 Defaults to YES. (NSNumber)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImagePreserveAspectRatio;

/**
 A CGSize raw value indicating whether or not to generate the thumbnail images (or bitmap images from vector format). When this value is provided, the decoder will generate a thumbnail image which pixel size is smaller than or equal to (depends the `.imagePreserveAspectRatio`) the value size.
 @note When you pass `.preserveAspectRatio == NO`, the thumbnail image is stretched to match each dimension. When `.preserveAspectRatio == YES`, the thumbnail image's width is limited to pixel size's width, the thumbnail image's height is limited to pixel size's height. For common cases, you can just pass a square size to limit both.
 Defaults to CGSizeZero, which means no thumbnail generation at all. (NSValue)
 @note When this value is used, we will trigger thumbnail decoding for url, and the callback's data **will be nil** (because this time the data saved to disk does not match the image return to you. If you need full size data, query the cache with full size url key)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageThumbnailPixelSize;

/**
 A NSString value (UTI) indicating the source image's file extension. Example: "public.jpeg-2000", "com.nikon.raw-image", "public.tiff"
 Some image file format share the same data structure but has different tag explanation, like TIFF and NEF/SRW, see https://en.wikipedia.org/wiki/TIFF
 Changing the file extension cause the different image result. The coder (like ImageIO) may use file extension to choose the correct parser
 @note If you don't provide this option, we will use the `URL.path` as file extension to calculate the UTI hint
 @note If you really don't want any hint which effect the image result, pass `NSNull.null` instead
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageTypeIdentifierHint;

/**
 A NSUInteger value to provide the limit bytes during decoding. This can help to avoid OOM on large frame count animated image or large pixel static image when you don't know how much RAM it occupied before decoding
 The decoder will do these logic based on limit bytes:
 1. Get the total frame count (static image means 1)
 2. Calculate the `framePixelSize` width/height to `sqrt(limitBytes / frameCount / bytesPerPixel)`, keeping aspect ratio (at least 1x1)
 3. If the `framePixelSize < originalImagePixelSize`, then do thumbnail decoding (see `LoadImageCoderDecodeThumbnailPixelSize`) use the `framePixelSize` and `preseveAspectRatio = YES`
 4. Else, use the full pixel decoding (small than limit bytes)
 5. Whatever result, this does not effect the animated/static behavior of image. So even if you set `limitBytes = 1 && frameCount = 100`, we will stll create animated image with each frame `1x1` pixel size.
 @note This option has higher priority than `.imageThumbnailPixelSize`
 @warning This does not effect the cache key. So which means, this will effect the global cache even next time you query without this option. Pay attention when you use this on global options (It's always recommended to use request-level option for different pipeline)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageScaleDownLimitBytes;

#pragma mark - Cache Context Options

/**
 A Dictionary (LoadImageCoderOptions) value, which pass the extra encode options to the LoadImageCoder. Introduced in ImageLoader 5.15.0
 You can pass encode options like `compressionQuality`, `maxFileSize`, `maxPixelSize` to control the encoding related thing, this is used inside `LoadImageCache` during store logic.
 @note For developer who use custom cache protocol (not LoadImageCache instance), they need to upgrade and use these options for encoding.
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextImageEncodeOptions;

/**
 A LoadImageCacheType raw value which specify the source of cache to query. Specify `LoadImageCacheTypeDisk` to query from disk cache only; `LoadImageCacheTypeMemory` to query from memory only. And `LoadImageCacheTypeAll` to query from both memory cache and disk cache. Specify `LoadImageCacheTypeNone` is invalid and totally ignore the cache query.
 If not provide or the value is invalid, we will use `LoadImageCacheTypeAll`. (NSNumber)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextQueryCacheType;

/**
 A LoadImageCacheType raw value which specify the store cache type when the image has just been downloaded and will be stored to the cache. Specify `LoadImageCacheTypeNone` to disable cache storage; `LoadImageCacheTypeDisk` to store in disk cache only; `LoadImageCacheTypeMemory` to store in memory only. And `LoadImageCacheTypeAll` to store in both memory cache and disk cache.
 If you use image transformer feature, this actually apply for the transformed image, but not the original image itself. Use `ImageLoaderContextOriginalStoreCacheType` if you want to control the original image's store cache type at the same time.
 If not provide or the value is invalid, we will use `LoadImageCacheTypeAll`. (NSNumber)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextStoreCacheType;

/**
 The same behavior like `ImageLoaderContextQueryCacheType`, but control the query cache type for the original image when you use image transformer feature. This allows the detail control of cache query for these two images. For example, if you want to query the transformed image from both memory/disk cache, query the original image from disk cache only, use `[.queryCacheType : .all, .originalQueryCacheType : .disk]`
 If not provide or the value is invalid, we will use `LoadImageCacheTypeDisk`, which query the original full image data from disk cache after transformed image cache miss. This is suitable for most common cases to avoid re-downloading the full data for different transform variants. (NSNumber)
 @note Which means, if you set this value to not be `.none`, we will query the original image from cache, then do transform with transformer, instead of actual downloading, which can save bandwidth usage.
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextOriginalQueryCacheType;

/**
 The same behavior like `ImageLoaderContextStoreCacheType`, but control the store cache type for the original image when you use image transformer feature. This allows the detail control of cache storage for these two images. For example, if you want to store the transformed image into both memory/disk cache, store the original image into disk cache only, use `[.storeCacheType : .all, .originalStoreCacheType : .disk]`
 If not provide or the value is invalid, we will use `LoadImageCacheTypeDisk`, which store the original full image data into disk cache after storing the transformed image. This is suitable for most common cases to avoid re-downloading the full data for different transform variants. (NSNumber)
 @note This only store the original image, if you want to use the original image without downloading in next query, specify `ImageLoaderContextOriginalQueryCacheType` as well.
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextOriginalStoreCacheType;

/**
 A id<LoadImageCache> instance which conforms to `LoadImageCache` protocol. It's used to control the cache for original image when using the transformer. If you provide one, the original image (full size image) will query and write from that cache instance instead, the transformed image will query and write from the default `ImageLoaderContextImageCache` instead. (id<LoadImageCache>)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextOriginalImageCache;

/**
 A Class object which the instance is a `UIImage/NSImage` subclass and adopt `SDAnimatedImage` protocol. We will call `initWithData:scale:options:` to create the instance (or `initWithAnimatedCoder:scale:` when using progressive download) . If the instance create failed, fallback to normal `UIImage/NSImage`.
 This can be used to improve animated images rendering performance (especially memory usage on big animated images) with `SDAnimatedImageView` (Class).
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextAnimatedImageClass;

#pragma mark - Download Context Options

/**
 A id<ImageLoaderDownloaderRequestModifier> instance to modify the image download request. It's used for downloader to modify the original request from URL and options. If you provide one, it will ignore the `requestModifier` in downloader and use provided one instead. (id<ImageLoaderDownloaderRequestModifier>)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextDownloadRequestModifier;

/**
 A id<ImageLoaderDownloaderResponseModifier> instance to modify the image download response. It's used for downloader to modify the original response from URL and options.  If you provide one, it will ignore the `responseModifier` in downloader and use provided one instead. (id<ImageLoaderDownloaderResponseModifier>)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextDownloadResponseModifier;

/**
 A id<ImageLoaderContextDownloadDecryptor> instance to decrypt the image download data. This can be used for image data decryption, such as Base64 encoded image. If you provide one, it will ignore the `decryptor` in downloader and use provided one instead. (id<ImageLoaderContextDownloadDecryptor>)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextDownloadDecryptor;

/**
 A id<ImageLoaderCacheKeyFilter> instance to convert an URL into a cache key. It's used when manager need cache key to use image cache. If you provide one, it will ignore the `cacheKeyFilter` in manager and use provided one instead. (id<ImageLoaderCacheKeyFilter>)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextCacheKeyFilter;

/**
 A id<ImageLoaderCacheSerializer> instance to convert the decoded image, the source downloaded data, to the actual data. It's used for manager to store image to the disk cache. If you provide one, it will ignore the `cacheSerializer` in manager and use provided one instead. (id<ImageLoaderCacheSerializer>)
 */
FOUNDATION_EXPORT ImageLoaderContextOption _Nonnull const ImageLoaderContextCacheSerializer;
