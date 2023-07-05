/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Fabrice Aneche
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "ImageLoaderCompat.h"

/**
 You can use switch case like normal enum. It's also recommended to add a default case. You should not assume anything about the raw value.
 For custom coder plugin, it can also extern the enum for supported format. See `LoadImageCoder` for more detailed information.
 */
typedef NSInteger LoadImageFormat NS_TYPED_EXTENSIBLE_ENUM;
static const LoadImageFormat LoadImageFormatUndefined = -1;
static const LoadImageFormat LoadImageFormatJPEG      = 0;
static const LoadImageFormat LoadImageFormatPNG       = 1;
static const LoadImageFormat LoadImageFormatGIF       = 2;
static const LoadImageFormat LoadImageFormatTIFF      = 3;
static const LoadImageFormat LoadImageFormatWebP      = 4;
static const LoadImageFormat LoadImageFormatHEIC      = 5;
static const LoadImageFormat LoadImageFormatHEIF      = 6;
static const LoadImageFormat LoadImageFormatPDF       = 7;
static const LoadImageFormat LoadImageFormatSVG       = 8;
static const LoadImageFormat LoadImageFormatBMP       = 9;
static const LoadImageFormat LoadImageFormatRAW       = 10;

/**
 NSData category about the image content type and UTI.
 */
@interface NSData (ImageContentType)

/**
 *  Return image format
 *
 *  @param data the input image data
 *
 *  @return the image format as `LoadImageFormat` (enum)
 */
+ (LoadImageFormat)btg_imageFormatForImageData:(nullable NSData *)data;

/**
 *  Convert LoadImageFormat to UTType
 *
 *  @param format Format as LoadImageFormat
 *  @return The UTType as CFStringRef
 *  @note For unknown format, `kSDUTTypeImage` abstract type will return
 */
+ (nonnull CFStringRef)btg_UTTypeFromImageFormat:(LoadImageFormat)format CF_RETURNS_NOT_RETAINED NS_SWIFT_NAME(btg_UTType(from:));

/**
 *  Convert UTType to LoadImageFormat
 *
 *  @param uttype The UTType as CFStringRef
 *  @return The Format as LoadImageFormat
 *  @note For unknown type, `LoadImageFormatUndefined` will return
 */
+ (LoadImageFormat)btg_imageFormatFromUTType:(nonnull CFStringRef)uttype;

@end
