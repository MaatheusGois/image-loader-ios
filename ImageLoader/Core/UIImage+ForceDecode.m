/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+ForceDecode.h"
#import "LoadImageCoderHelper.h"
#import "objc/runtime.h"
#import "NSImage+Compatibility.h"

@implementation UIImage (ForceDecode)

- (BOOL)_isDecoded {
    NSNumber *value = objc_getAssociatedObject(self, @selector(_isDecoded));
    if (value != nil) {
        return value.boolValue;
    } else {
        // Assume only CGImage based can use lazy decoding
        CGImageRef cgImage = self.CGImage;
        if (cgImage) {
            CFStringRef uttype = CGImageGetUTType(self.CGImage);
            if (uttype) {
                // Only ImageIO can set `com.apple.ImageIO.imageSourceTypeIdentifier`
                return NO;
            } else {
                // Thumbnail or CGBitmapContext drawn image
                return YES;
            }
        }
    }
    // Assume others as non-decoded
    return NO;
}

- (void)set_isDecoded:(BOOL)_isDecoded {
    objc_setAssociatedObject(self, @selector(_isDecoded), @(_isDecoded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (nullable UIImage *)_decodedImageWithImage:(nullable UIImage *)image {
    if (!image) {
        return nil;
    }
    return [LoadImageCoderHelper decodedImageWithImage:image];
}

+ (nullable UIImage *)_decodedAndScaledDownImageWithImage:(nullable UIImage *)image {
    return [self _decodedAndScaledDownImageWithImage:image limitBytes:0];
}

+ (nullable UIImage *)_decodedAndScaledDownImageWithImage:(nullable UIImage *)image limitBytes:(NSUInteger)bytes {
    if (!image) {
        return nil;
    }
    return [LoadImageCoderHelper decodedAndScaledDownImageWithImage:image limitBytes:bytes];
}

@end
