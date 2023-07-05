/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+MultiFormat.h"
#import "LoadImageCodersManager.h"

@implementation UIImage (MultiFormat)

+ (nullable UIImage *)_imageWithData:(nullable NSData *)data {
    return [self _imageWithData:data scale:1];
}

+ (nullable UIImage *)_imageWithData:(nullable NSData *)data scale:(CGFloat)scale {
    return [self _imageWithData:data scale:scale firstFrameOnly:NO];
}

+ (nullable UIImage *)_imageWithData:(nullable NSData *)data scale:(CGFloat)scale firstFrameOnly:(BOOL)firstFrameOnly {
    if (!data) {
        return nil;
    }
    LoadImageCoderOptions *options = @{LoadImageCoderDecodeScaleFactor : @(MAX(scale, 1)), LoadImageCoderDecodeFirstFrameOnly : @(firstFrameOnly)};
    return [[LoadImageCodersManager sharedManager] decodedImageWithData:data options:options];
}

- (nullable NSData *)_imageData {
    return [self _imageDataAsFormat:LoadImageFormatUndefined];
}

- (nullable NSData *)_imageDataAsFormat:(LoadImageFormat)imageFormat {
    return [self _imageDataAsFormat:imageFormat compressionQuality:1];
}

- (nullable NSData *)_imageDataAsFormat:(LoadImageFormat)imageFormat compressionQuality:(double)compressionQuality {
    return [self _imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:NO];
}

- (nullable NSData *)_imageDataAsFormat:(LoadImageFormat)imageFormat compressionQuality:(double)compressionQuality firstFrameOnly:(BOOL)firstFrameOnly {
    LoadImageCoderOptions *options = @{LoadImageCoderEncodeCompressionQuality : @(compressionQuality), LoadImageCoderEncodeFirstFrameOnly : @(firstFrameOnly)};
    return [[LoadImageCodersManager sharedManager] encodedDataWithImage:self format:imageFormat options:options];
}

@end
