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

- (NSUInteger)btg_imageLoopCount {
    NSUInteger imageLoopCount = 0;
    NSNumber *value = objc_getAssociatedObject(self, @selector(btg_imageLoopCount));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageLoopCount = value.unsignedIntegerValue;
    }
    return imageLoopCount;
}

- (void)setBtg_imageLoopCount:(NSUInteger)btg_imageLoopCount {
    NSNumber *value = @(btg_imageLoopCount);
    objc_setAssociatedObject(self, @selector(btg_imageLoopCount), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)btg_imageFrameCount {
    NSArray<UIImage *> *animatedImages = self.images;
    if (!animatedImages || animatedImages.count <= 1) {
        return 1;
    }
    NSNumber *value = objc_getAssociatedObject(self, @selector(btg_imageFrameCount));
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
    objc_setAssociatedObject(self, @selector(btg_imageFrameCount), @(frameCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return frameCount;
}

- (BOOL)btg_isAnimated {
    return (self.images != nil);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
- (BOOL)btg_isVector {
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

- (NSUInteger)btg_imageLoopCount {
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

- (void)setBtg_imageLoopCount:(NSUInteger)btg_imageLoopCount {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        [bitmapImageRep setProperty:NSImageLoopCount withValue:@(btg_imageLoopCount)];
    }
}

- (NSUInteger)btg_imageFrameCount {
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

- (BOOL)btg_isAnimated {
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

- (BOOL)btg_isVector {
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

- (LoadImageFormat)btg_imageFormat {
    LoadImageFormat imageFormat = LoadImageFormatUndefined;
    NSNumber *value = objc_getAssociatedObject(self, @selector(btg_imageFormat));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageFormat = value.integerValue;
        return imageFormat;
    }
    // Check CGImage's UTType, may return nil for non-Image/IO based image
    CFStringRef uttype = CGImageGetUTType(self.CGImage);
    imageFormat = [NSData btg_imageFormatFromUTType:uttype];
    return imageFormat;
}

- (void)setBtg_imageFormat:(LoadImageFormat)btg_imageFormat {
    objc_setAssociatedObject(self, @selector(btg_imageFormat), @(btg_imageFormat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setBtg_isIncremental:(BOOL)btg_isIncremental {
    objc_setAssociatedObject(self, @selector(btg_isIncremental), @(btg_isIncremental), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)btg_isIncremental {
    NSNumber *value = objc_getAssociatedObject(self, @selector(btg_isIncremental));
    return value.boolValue;
}

- (void)setBtg_isTransformed:(BOOL)btg_isTransformed {
    objc_setAssociatedObject(self, @selector(btg_isTransformed), @(btg_isTransformed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)btg_isTransformed {
    NSNumber *value = objc_getAssociatedObject(self, @selector(btg_isTransformed));
    return value.boolValue;
}

- (void)setBtg_decodeOptions:(LoadImageCoderOptions *)btg_decodeOptions {
    objc_setAssociatedObject(self, @selector(btg_decodeOptions), btg_decodeOptions, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

-(BOOL)btg_isThumbnail {
    CGSize thumbnailSize = CGSizeZero;
    NSValue *thumbnailSizeValue = self.btg_decodeOptions[LoadImageCoderDecodeThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
    #if SD_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
    }
    return thumbnailSize.width > 0 && thumbnailSize.height > 0;
}

- (LoadImageCoderOptions *)btg_decodeOptions {
    LoadImageCoderOptions *value = objc_getAssociatedObject(self, @selector(btg_decodeOptions));
    if ([value isKindOfClass:NSDictionary.class]) {
        return value;
    }
    return nil;
}

@end
