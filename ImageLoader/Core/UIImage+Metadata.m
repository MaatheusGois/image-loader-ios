/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+Metadata.h"
#import "NSImage+Compatibility.h"
#import "SDInternalMacros.h"
#import "objc/runtime.h"

@implementation UIImage (Metadata)

#if SD_UIKIT || SD_WATCH

- (NSUInteger)_imageLoopCount {
    NSUInteger imageLoopCount = 0;
    NSNumber *value = objc_getAssociatedObject(self, @selector(_imageLoopCount));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageLoopCount = value.unsignedIntegerValue;
    }
    return imageLoopCount;
}

- (void)set_imageLoopCount:(NSUInteger)_imageLoopCount {
    NSNumber *value = @(_imageLoopCount);
    objc_setAssociatedObject(self, @selector(_imageLoopCount), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)_imageFrameCount {
    NSArray<UIImage *> *animatedImages = self.images;
    if (!animatedImages || animatedImages.count <= 1) {
        return 1;
    }
    NSNumber *value = objc_getAssociatedObject(self, @selector(_imageFrameCount));
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value unsignedIntegerValue];
    }
    __block NSUInteger frameCount = 1;
    __block UIImage *previousImage = animatedImages.firstObject;
    [animatedImages enumerateObjectsUsingBlock:^(UIImage * _Nonnull image, NSUInteger idx, BOOL * _Nonnull stop) {
        // ignore first
        if (idx == 0) {
            return;
        }
        if (![image isEqual:previousImage]) {
            frameCount++;
        }
        previousImage = image;
    }];
    objc_setAssociatedObject(self, @selector(_imageFrameCount), @(frameCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return frameCount;
}

- (BOOL)_isAnimated {
    return (self.images != nil);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
- (BOOL)_isVector {
    if (@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
        // Xcode 11 supports symbol image, keep Xcode 10 compatible currently
        SEL SymbolSelector = NSSelectorFromString(@"isSymbolImage");
        if ([self respondsToSelector:SymbolSelector] && [self performSelector:SymbolSelector]) {
            return YES;
        }
        // SVG
        SEL SVGSelector = SD_SEL_SPI(CGSVGDocument);
        if ([self respondsToSelector:SVGSelector] && [self performSelector:SVGSelector]) {
            return YES;
        }
    }
    if (@available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        // PDF
        SEL PDFSelector = SD_SEL_SPI(CGPDFPage);
        if ([self respondsToSelector:PDFSelector] && [self performSelector:PDFSelector]) {
            return YES;
        }
    }
    return NO;
}
#pragma clang diagnostic pop

#else

- (NSUInteger)_imageLoopCount {
    NSUInteger imageLoopCount = 0;
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        imageLoopCount = [[bitmapImageRep valueForProperty:NSImageLoopCount] unsignedIntegerValue];
    }
    return imageLoopCount;
}

- (void)set_imageLoopCount:(NSUInteger)_imageLoopCount {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        [bitmapImageRep setProperty:NSImageLoopCount withValue:@(_imageLoopCount)];
    }
}

- (NSUInteger)_imageFrameCount {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        return [[bitmapImageRep valueForProperty:NSImageFrameCount] unsignedIntegerValue];
    }
    return 1;
}

- (BOOL)_isAnimated {
    BOOL isAnimated = NO;
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        NSUInteger frameCount = [[bitmapImageRep valueForProperty:NSImageFrameCount] unsignedIntegerValue];
        isAnimated = frameCount > 1 ? YES : NO;
    }
    return isAnimated;
}

- (BOOL)_isVector {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    if ([imageRep isKindOfClass:[NSPDFImageRep class]]) {
        return YES;
    }
    if ([imageRep isKindOfClass:[NSEPSImageRep class]]) {
        return YES;
    }
    if ([NSStringFromClass(imageRep.class) hasSuffix:@"NSSVGImageRep"]) {
        return YES;
    }
    return NO;
}

#endif

- (LoadImageFormat)_imageFormat {
    LoadImageFormat imageFormat = LoadImageFormatUndefined;
    NSNumber *value = objc_getAssociatedObject(self, @selector(_imageFormat));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageFormat = value.integerValue;
        return imageFormat;
    }
    // Check CGImage's UTType, may return nil for non-Image/IO based image
    CFStringRef uttype = CGImageGetUTType(self.CGImage);
    imageFormat = [NSData _imageFormatFromUTType:uttype];
    return imageFormat;
}

- (void)set_imageFormat:(LoadImageFormat)_imageFormat {
    objc_setAssociatedObject(self, @selector(_imageFormat), @(_imageFormat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)set_isIncremental:(BOOL)_isIncremental {
    objc_setAssociatedObject(self, @selector(_isIncremental), @(_isIncremental), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)_isIncremental {
    NSNumber *value = objc_getAssociatedObject(self, @selector(_isIncremental));
    return value.boolValue;
}

- (void)set_isTransformed:(BOOL)_isTransformed {
    objc_setAssociatedObject(self, @selector(_isTransformed), @(_isTransformed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)_isTransformed {
    NSNumber *value = objc_getAssociatedObject(self, @selector(_isTransformed));
    return value.boolValue;
}

- (void)set_decodeOptions:(LoadImageCoderOptions *)_decodeOptions {
    objc_setAssociatedObject(self, @selector(_decodeOptions), _decodeOptions, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

-(BOOL)_isThumbnail {
    CGSize thumbnailSize = CGSizeZero;
    NSValue *thumbnailSizeValue = self._decodeOptions[LoadImageCoderDecodeThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
    #if SD_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
    }
    return thumbnailSize.width > 0 && thumbnailSize.height > 0;
}

- (LoadImageCoderOptions *)_decodeOptions {
    LoadImageCoderOptions *value = objc_getAssociatedObject(self, @selector(_decodeOptions));
    if ([value isKindOfClass:NSDictionary.class]) {
        return value;
    }
    return nil;
}

@end
