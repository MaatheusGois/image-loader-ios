/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "ImageLoaderCompat.h"

/**
 This class is used for creating animated images via `animatedImageWithFrames` in `LoadImageCoderHelper`.
 @note If you need to specify animated images loop count, use `_imageLoopCount` property in `UIImage+Metadata.h`.
 */
@interface LoadImageFrame : NSObject

/**
 The image of current frame. You should not set an animated image.
 */
@property (nonatomic, strong, readonly, nonnull) UIImage *image;
/**
 The duration of current frame to be displayed. The number is seconds but not milliseconds. You should not set this to zero.
 */
@property (nonatomic, readonly, assign) NSTimeInterval duration;

/// Create a frame instance with specify image and duration
/// @param image current frame's image
/// @param duration current frame's duration
- (nonnull instancetype)initWithImage:(nonnull UIImage *)image duration:(NSTimeInterval)duration;

/**
 Create a frame instance with specify image and duration

 @param image current frame's image
 @param duration current frame's duration
 @return frame instance
 */
+ (nonnull instancetype)frameWithImage:(nonnull UIImage *)image duration:(NSTimeInterval)duration;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new  NS_UNAVAILABLE;

@end
