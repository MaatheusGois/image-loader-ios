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
 This coder is used for HEIC (HEIF with HEVC container codec) image format.
 Image/IO provide the static HEIC (.heic) support in iOS 11/macOS 10.13/tvOS 11/watchOS 4+.
 Image/IO provide the animated HEIC (.heics) support in iOS 13/macOS 10.15/tvOS 13/watchOS 6+.
 See https://nokiatech.github.io/heif/technical.html for the standard.
 @note This coder is not in the default coder list for now, since HEIC animated image is really rare, and Apple's implementation still contains performance issues. You can enable if you need this.
 @note If you need to support lower firmware version for HEIF, you can have a try at https://github.com/ImageLoader/ImageLoaderHEIFCoder
 */
API_AVAILABLE(ios(13.0), tvos(13.0), macos(10.15), watchos(6.0))
@interface LoadImageHEICCoder : LoadImageIOAnimatedCoder <SDProgressiveImageCoder, SDAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) LoadImageHEICCoder *sharedCoder;

@end
