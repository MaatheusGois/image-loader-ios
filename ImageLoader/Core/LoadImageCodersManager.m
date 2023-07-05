/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "LoadImageCodersManager.h"
#import "LoadImageIOCoder.h"
#import "LoadImageGIFCoder.h"
#import "LoadImageAPNGCoder.h"
#import "LoadImageHEICCoder.h"
#import "SDInternalMacros.h"

@interface LoadImageCodersManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<LoadImageCoder>> *imageCoders;

@end

@implementation LoadImageCodersManager {
    SD_LOCK_DECLARE(_codersLock);
}

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // initialize with default coders
        _imageCoders = [NSMutableArray arrayWithArray:@[[LoadImageIOCoder sharedCoder], [LoadImageGIFCoder sharedCoder], [LoadImageAPNGCoder sharedCoder]]];
        SD_LOCK_INIT(_codersLock);
    }
    return self;
}

- (NSArray<id<LoadImageCoder>> *)coders {
    SD_LOCK(_codersLock);
    NSArray<id<LoadImageCoder>> *coders = [_imageCoders copy];
    SD_UNLOCK(_codersLock);
    return coders;
}

- (void)setCoders:(NSArray<id<LoadImageCoder>> *)coders {
    SD_LOCK(_codersLock);
    [_imageCoders removeAllObjects];
    if (coders.count) {
        [_imageCoders addObjectsFromArray:coders];
    }
    SD_UNLOCK(_codersLock);
}

#pragma mark - Coder IO operations

- (void)addCoder:(nonnull id<LoadImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(LoadImageCoder)]) {
        return;
    }
    SD_LOCK(_codersLock);
    [_imageCoders addObject:coder];
    SD_UNLOCK(_codersLock);
}

- (void)removeCoder:(nonnull id<LoadImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(LoadImageCoder)]) {
        return;
    }
    SD_LOCK(_codersLock);
    [_imageCoders removeObject:coder];
    SD_UNLOCK(_codersLock);
}

#pragma mark - LoadImageCoder
- (BOOL)canDecodeFromData:(NSData *)data {
    NSArray<id<LoadImageCoder>> *coders = self.coders;
    for (id<LoadImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canEncodeToFormat:(LoadImageFormat)format {
    NSArray<id<LoadImageCoder>> *coders = self.coders;
    for (id<LoadImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return YES;
        }
    }
    return NO;
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(nullable LoadImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    UIImage *image;
    NSArray<id<LoadImageCoder>> *coders = self.coders;
    for (id<LoadImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            image = [coder decodedImageWithData:data options:options];
            break;
        }
    }
    
    return image;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(LoadImageFormat)format options:(nullable LoadImageCoderOptions *)options {
    if (!image) {
        return nil;
    }
    NSArray<id<LoadImageCoder>> *coders = self.coders;
    for (id<LoadImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return [coder encodedDataWithImage:image format:format options:options];
        }
    }
    return nil;
}

- (NSData *)encodedDataWithFrames:(NSArray<LoadImageFrame *> *)frames loopCount:(NSUInteger)loopCount format:(LoadImageFormat)format options:(LoadImageCoderOptions *)options {
    if (!frames || frames.count < 1) {
        return nil;
    }
    NSArray<id<LoadImageCoder>> *coders = self.coders;
    for (id<LoadImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            if ([coder respondsToSelector:@selector(encodedDataWithFrames:loopCount:format:options:)]) {
                return [coder encodedDataWithFrames:frames loopCount:loopCount format:format options:options];
            }
        }
    }
    return nil;
}

@end
