/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCompat.h"

#if SD_UIKIT

#import "ImageLoaderManager.h"

/**
 * Integrates ImageLoader async downloading and caching of remote images with UIImageView for highlighted state.
 */
@interface UIImageView (HighlightedWebCache)

/**
 * Set the imageView `highlightedImage` with an `url`.
 *
 * The download is asynchronous and cached.
 *
 * @param url The url for the image.
 */
- (void)_setHighlightedImageWithURL:(nullable NSURL *)url NS_REFINED_FOR_SWIFT;

/**
 * Set the imageView `highlightedImage` with an `url` and custom options.
 *
 * The download is asynchronous and cached.
 *
 * @param url     The url for the image.
 * @param options The options to use when downloading the image. @see ImageLoaderOptions for the possible values.
 */
- (void)_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(ImageLoaderOptions)options NS_REFINED_FOR_SWIFT;

/**
 * Set the imageView `highlightedImage` with an `url`, custom options and context.
 *
 * The download is asynchronous and cached.
 *
 * @param url     The url for the image.
 * @param options The options to use when downloading the image. @see ImageLoaderOptions for the possible values.
 * @param context     A context contains different options to perform specify changes or processes, see `ImageLoaderContextOption`. This hold the extra objects which `options` enum can not hold.
 */
- (void)_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(ImageLoaderOptions)options
                              context:(nullable ImageLoaderContext *)context;

/**
 * Set the imageView `highlightedImage` with an `url`.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)_setHighlightedImageWithURL:(nullable NSURL *)url
                            completed:(nullable SDExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;

/**
 * Set the imageView `highlightedImage` with an `url` and custom options.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param options        The options to use when downloading the image. @see ImageLoaderOptions for the possible values.
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(ImageLoaderOptions)options
                            completed:(nullable SDExternalCompletionBlock)completedBlock;

/**
 * Set the imageView `highlightedImage` with an `url` and custom options.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param options        The options to use when downloading the image. @see ImageLoaderOptions for the possible values.
 * @param progressBlock  A block called while image is downloading
 *                       @note the progress block is executed on a background queue
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(ImageLoaderOptions)options
                             progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                            completed:(nullable SDExternalCompletionBlock)completedBlock;

/**
 * Set the imageView `highlightedImage` with an `url`, custom options and context.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param options        The options to use when downloading the image. @see ImageLoaderOptions for the possible values.
 * @param context     A context contains different options to perform specify changes or processes, see `ImageLoaderContextOption`. This hold the extra objects which `options` enum can not hold.
 * @param progressBlock  A block called while image is downloading
 *                       @note the progress block is executed on a background queue
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(ImageLoaderOptions)options
                              context:(nullable ImageLoaderContext *)context
                             progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                            completed:(nullable SDExternalCompletionBlock)completedBlock;

@end

#endif
