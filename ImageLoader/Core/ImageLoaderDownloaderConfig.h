/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "ImageLoaderCompat.h"

/// Operation execution order
typedef NS_ENUM(NSInteger, ImageLoaderDownloaderExecutionOrder) {
    /**
     * Default value. All download operations will execute in queue style (first-in-first-out).
     */
    ImageLoaderDownloaderFIFOExecutionOrder,
    
    /**
     * All download operations will execute in stack style (last-in-first-out).
     */
    ImageLoaderDownloaderLIFOExecutionOrder
};

/**
 The class contains all the config for image downloader
 @note This class conform to NSCopying, make sure to add the property in `copyWithZone:` as well.
 */
@interface ImageLoaderDownloaderConfig : NSObject <NSCopying>

/**
 Gets the default downloader config used for shared instance or initialization when it does not provide any downloader config. Such as `ImageLoaderDownloader.sharedDownloader`.
 @note You can modify the property on default downloader config, which can be used for later created downloader instance. The already created downloader instance does not get affected.
 */
@property (nonatomic, class, readonly, nonnull) ImageLoaderDownloaderConfig *defaultDownloaderConfig;

/**
 * The maximum number of concurrent downloads.
 * Defaults to 6.
 */
@property (nonatomic, assign) NSInteger maxConcurrentDownloads;

/**
 * The timeout value (in seconds) for each download operation.
 * Defaults to 15.0.
 */
@property (nonatomic, assign) NSTimeInterval downloadTimeout;

/**
 * The minimum interval about progress percent during network downloading. Which means the next progress callback and current progress callback's progress percent difference should be larger or equal to this value. However, the final finish download progress callback does not get effected.
 * The value should be 0.0-1.0.
 * @note If you're using progressive decoding feature, this will also effect the image refresh rate.
 * @note This value may enhance the performance if you don't want progress callback too frequently.
 * Defaults to 0, which means each time we receive the new data from URLSession, we callback the progressBlock immediately.
 */
@property (nonatomic, assign) double minimumProgressInterval;

/**
 * The custom session configuration in use by NSURLSession. If you don't provide one, we will use `defaultSessionConfiguration` instead.
 * Defatuls to nil.
 * @note This property does not support dynamic changes, means it's immutable after the downloader instance initialized.
 */
@property (nonatomic, strong, nullable) NSURLSessionConfiguration *sessionConfiguration;

/**
 * Gets/Sets a subclass of `ImageLoaderDownloaderOperation` as the default
 * `NSOperation` to be used each time ImageLoader constructs a request
 * operation to download an image.
 * Defaults to nil.
 * @note Passing `NSOperation<ImageLoaderDownloaderOperation>` to set as default. Passing `nil` will revert to `ImageLoaderDownloaderOperation`.
 */
@property (nonatomic, assign, nullable) Class operationClass;

/**
 * Changes download operations execution order.
 * Defaults to `ImageLoaderDownloaderFIFOExecutionOrder`.
 */
@property (nonatomic, assign) ImageLoaderDownloaderExecutionOrder executionOrder;

/**
 * Set the default URL credential to be set for request operations.
 * Defaults to nil.
 */
@property (nonatomic, copy, nullable) NSURLCredential *urlCredential;

/**
 * Set username using for HTTP Basic authentication.
 * Defaults to nil.
 */
@property (nonatomic, copy, nullable) NSString *username;

/**
 * Set password using for HTTP Basic authentication.
 * Defaults to nil.
 */
@property (nonatomic, copy, nullable) NSString *password;

/**
 * Set the acceptable HTTP Response status code. The status code which beyond the range will mark the download operation failed.
 * For example, if we config [200, 400) but server response is 503, the download will fail with error code `ImageLoaderErrorInvalidDownloadStatusCode`.
 * Defaults to [200,400). Nil means no validation at all.
 */
@property (nonatomic, copy, nullable) NSIndexSet *acceptableStatusCodes;

/**
 * Set the acceptable HTTP Response content type. The content type beyond the set will mark the download operation failed.
 * For example, if we config ["image/png"] but server response is "application/json", the download will fail with error code `ImageLoaderErrorInvalidDownloadContentType`.
 * Normally you don't need this for image format detection because we use image's data file signature magic bytes: https://en.wikipedia.org/wiki/List_of_file_signatures
 * Defaults to nil. Nil means no validation at all.
 */
@property (nonatomic, copy, nullable) NSSet<NSString *> *acceptableContentTypes;

@end
