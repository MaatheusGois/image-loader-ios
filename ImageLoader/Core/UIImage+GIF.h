/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Laurin Brandner
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCompat.h"

/**
 This category is just use as a convenience method. For more detail control, use methods in `UIImage+MultiFormat.h` or directly use `LoadImageCoder`.
 */
@interface UIImage (GIF)

/**
 Creates an animated UIImage from an NSData.
 This will create animated image if the data is Animated GIF. And will create a static image is the data is Static GIF.

 @param data The GIF data
 @return The created image
 */
+ (nullable UIImage *)_imageWithGIFData:(nullable NSData *)data;

@end
