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

+ (nullable UIImage *)btg_imageWithData:(nullable NSData *)data {
    return [self btg_imageWithData:data scale:1];
}

+ (nullable UIImage *)btg_imageWithData:(nullable NSData *)data scale:(CGFloat)scale {
    return [self btg_imageWithData:data scale:scale firstFrameOnly:NO];
}

+ (nullable UIImage *)btg_imageWithData:(nullable NSData *)data scale:(CGFloat)scale firstFrameOnly:(BOOL)firstFrameOnly {
    if (!data) {
        return nil;
    }
    LoadImageCoderOptions *options = @{LoadImageCoderDecodeScaleFactor : @(MAX(scale, 1)), LoadImageCoderDecodeFirstFrameOnly : @(firstFrameOnly)};
    return [[LoadImageCodersManager sharedManager] decodedImageWithData:data options:options];
}

- (nullable NSData *)btg_imageData {
    return [self btg_imageDataAsFormat:LoadImageFormatUndefined];
}

- (nullable NSData *)btg_imageDataAsFormat:(LoadImageFormat)imageFormat {
    return [self btg_imageDataAsFormat:imageFormat compressionQuality:1];
}

- (nullable NSData *)btg_imageDataAsFormat:(LoadImageFormat)imageFormat compressionQuality:(double)compressionQuality {
    return [self btg_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:NO];
}

- (nullable NSData *)btg_imageDataAsFormat:(LoadImageFormat)imageFormat compressionQuality:(double)compressionQuality firstFrameOnly:(BOOL)firstFrameOnly {
    LoadImageCoderOptions *options = @{LoadImageCoderEncodeCompressionQuality : @(compressionQuality), LoadImageCoderEncodeFirstFrameOnly : @(firstFrameOnly)};
    return [[LoadImageCodersManager sharedManager] encodedDataWithImage:self format:imageFormat options:options];
}

@end
