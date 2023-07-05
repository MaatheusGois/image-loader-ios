/*
* This file is part of the ImageLoader package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "LoadImageHEICCoder.h"
#import "LoadImageIOAnimatedCoderInternal.h"

// These constants are available from iOS 13+ and Xcode 11. This raw value is used for toolchain and firmware compatibility
static NSString * kSDCGImagePropertyHEICSDictionary = @"{HEICS}";
static NSString * kSDCGImagePropertyHEICSLoopCount = @"LoopCount";
static NSString * kSDCGImagePropertyHEICSDelayTime = @"DelayTime";
static NSString * kSDCGImagePropertyHEICSUnclampedDelayTime = @"UnclampedDelayTime";

@implementation LoadImageHEICCoder

+ (void)initialize {
    if (@available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)) {
        // Use SDK instead of raw value
        kSDCGImagePropertyHEICSDictionary = (__bridge NSString *)kCGImagePropertyHEICSDictionary;
        kSDCGImagePropertyHEICSLoopCount = (__bridge NSString *)kCGImagePropertyHEICSLoopCount;
        kSDCGImagePropertyHEICSDelayTime = (__bridge NSString *)kCGImagePropertyHEICSDelayTime;
        kSDCGImagePropertyHEICSUnclampedDelayTime = (__bridge NSString *)kCGImagePropertyHEICSUnclampedDelayTime;
    }
}

+ (instancetype)sharedCoder {
    static LoadImageHEICCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[LoadImageHEICCoder alloc] init];
    });
    return coder;
}

#pragma mark - LoadImageCoder

- (BOOL)canDecodeFromData:(nullable NSData *)data {
    switch ([NSData _imageFormatForImageData:data]) {
        case LoadImageFormatHEIC:
            // Check HEIC decoding compatibility
            return [self.class canDecodeFromFormat:LoadImageFormatHEIC];
        case LoadImageFormatHEIF:
            // Check HEIF decoding compatibility
            return [self.class canDecodeFromFormat:LoadImageFormatHEIF];
        default:
            return NO;
    }
}

- (BOOL)canIncrementalDecodeFromData:(NSData *)data {
    return [self canDecodeFromData:data];
}

- (BOOL)canEncodeToFormat:(LoadImageFormat)format {
    switch (format) {
        case LoadImageFormatHEIC:
            // Check HEIC encoding compatibility
            return [self.class canEncodeToFormat:LoadImageFormatHEIC];
        case LoadImageFormatHEIF:
            // Check HEIF encoding compatibility
            return [self.class canEncodeToFormat:LoadImageFormatHEIF];
        default:
            return NO;
    }
}

#pragma mark - Subclass Override

+ (LoadImageFormat)imageFormat {
    return LoadImageFormatHEIC;
}

+ (NSString *)imageUTType {
    return (__bridge NSString *)kSDUTTypeHEIC;
}

+ (NSString *)dictionaryProperty {
    return kSDCGImagePropertyHEICSDictionary;
}

+ (NSString *)unclampedDelayTimeProperty {
    return kSDCGImagePropertyHEICSUnclampedDelayTime;
}

+ (NSString *)delayTimeProperty {
    return kSDCGImagePropertyHEICSDelayTime;
}

+ (NSString *)loopCountProperty {
    return kSDCGImagePropertyHEICSLoopCount;
}

+ (NSUInteger)defaultLoopCount {
    return 0;
}

@end
