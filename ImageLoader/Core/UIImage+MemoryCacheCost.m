/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+MemoryCacheCost.h"
#import "objc/runtime.h"
#import "NSImage+Compatibility.h"

FOUNDATION_STATIC_INLINE NSUInteger SDMemoryCacheCostForImage(UIImage *image) {
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return 0;
    }
    NSUInteger bytesPerFrame = CGImageGetBytesPerRow(imageRef) * CGImageGetHeight(imageRef);
    NSUInteger frameCount;
#if SD_MAC
    frameCount = 1;
#elif SD_UIKIT || SD_WATCH
    // Filter the same frame in `_UIAnimatedImage`.
    frameCount = image.images.count > 1 ? [NSSet setWithArray:image.images].count : 1;
#endif
    NSUInteger cost = bytesPerFrame * frameCount;
    return cost;
}

@implementation UIImage (MemoryCacheCost)

- (NSUInteger)_memoryCost {
    NSNumber *value = objc_getAssociatedObject(self, @selector(_memoryCost));
    NSUInteger memoryCost;
    if (value != nil) {
        memoryCost = [value unsignedIntegerValue];
    } else {
        memoryCost = SDMemoryCacheCostForImage(self);
    }
    return memoryCost;
}

- (void)set_memoryCost:(NSUInteger)_memoryCost {
    objc_setAssociatedObject(self, @selector(_memoryCost), @(_memoryCost), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
