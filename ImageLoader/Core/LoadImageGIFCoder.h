/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "LoadImageIOAnimatedCoder.h"

/**
 Built in coder using ImageIO that supports animated GIF encoding/decoding
 @note `LoadImageIOCoder` supports GIF but only as static (will use the 1st frame).
 @note Use `LoadImageGIFCoder` for fully animated GIFs. For `UIImageView`, it will produce animated `UIImage`(`NSImage` on macOS) for rendering. For `SDAnimatedImageView`, it will use `SDAnimatedImage` for rendering.
 @note The recommended approach for animated GIFs is using `SDAnimatedImage` with `SDAnimatedImageView`. It's more performant than `UIImageView` for GIF displaying(especially on memory usage)
 */
@interface LoadImageGIFCoder : LoadImageIOAnimatedCoder <SDProgressiveImageCoder, SDAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) LoadImageGIFCoder *sharedCoder;

@end
