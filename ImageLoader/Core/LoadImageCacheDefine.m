/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "LoadImageCacheDefine.h"
#import "LoadImageCodersManager.h"
#import "LoadImageCoderHelper.h"
#import "SDAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "SDInternalMacros.h"

#import <CoreServices/CoreServices.h>

LoadImageCoderOptions * _Nonnull SDGetDecodeOptionsFromContext(ImageLoaderContext * _Nullable context, ImageLoaderOptions options, NSString * _Nonnull cacheKey) {
    BOOL decodeFirstFrame = SD_OPTIONS_CONTAINS(options, ImageLoaderDecodeFirstFrameOnly);
    NSNumber *scaleValue = context[ImageLoaderContextImageScaleFactor];
    CGFloat scale = scaleValue.doubleValue >= 1 ? scaleValue.doubleValue : LoadImageScaleFactorForKey(cacheKey); // Use cache key to detect scale
    NSNumber *preserveAspectRatioValue = context[ImageLoaderContextImagePreserveAspectRatio];
    NSValue *thumbnailSizeValue;
    BOOL shouldScaleDown = SD_OPTIONS_CONTAINS(options, ImageLoaderScaleDownLargeImages);
    NSNumber *scaleDownLimitBytesValue = context[ImageLoaderContextImageScaleDownLimitBytes];
    if (!scaleDownLimitBytesValue && shouldScaleDown) {
        // Use the default limit bytes
        scaleDownLimitBytesValue = @(LoadImageCoderHelper.defaultScaleDownLimitBytes);
    }
    if (context[ImageLoaderContextImageThumbnailPixelSize]) {
        thumbnailSizeValue = context[ImageLoaderContextImageThumbnailPixelSize];
    }
    NSString *typeIdentifierHint = context[ImageLoaderContextImageTypeIdentifierHint];
    NSString *fileExtensionHint;
    if (!typeIdentifierHint) {
        // UTI has high priority
        fileExtensionHint = cacheKey.pathExtension; // without dot
        if (fileExtensionHint.length == 0) {
            // Ignore file extension which is empty
            fileExtensionHint = nil;
        }
    }
    
    // First check if user provided decode options
    LoadImageCoderMutableOptions *mutableCoderOptions;
    if (context[ImageLoaderContextImageDecodeOptions] != nil) {
        mutableCoderOptions = [NSMutableDictionary dictionaryWithDictionary:context[ImageLoaderContextImageDecodeOptions]];
    } else {
        mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:6];
    }
    
    // Override individual options
    mutableCoderOptions[LoadImageCoderDecodeFirstFrameOnly] = @(decodeFirstFrame);
    mutableCoderOptions[LoadImageCoderDecodeScaleFactor] = @(scale);
    mutableCoderOptions[LoadImageCoderDecodePreserveAspectRatio] = preserveAspectRatioValue;
    mutableCoderOptions[LoadImageCoderDecodeThumbnailPixelSize] = thumbnailSizeValue;
    mutableCoderOptions[LoadImageCoderDecodeTypeIdentifierHint] = typeIdentifierHint;
    mutableCoderOptions[LoadImageCoderDecodeFileExtensionHint] = fileExtensionHint;
    mutableCoderOptions[LoadImageCoderDecodeScaleDownLimitBytes] = scaleDownLimitBytesValue;
    
    return [mutableCoderOptions copy];
}

void SDSetDecodeOptionsToContext(ImageLoaderMutableContext * _Nonnull mutableContext, ImageLoaderOptions * _Nonnull mutableOptions, LoadImageCoderOptions * _Nonnull decodeOptions) {
    if ([decodeOptions[LoadImageCoderDecodeFirstFrameOnly] boolValue]) {
        *mutableOptions |= ImageLoaderDecodeFirstFrameOnly;
    } else {
        *mutableOptions &= ~ImageLoaderDecodeFirstFrameOnly;
    }
    
    mutableContext[ImageLoaderContextImageScaleFactor] = decodeOptions[LoadImageCoderDecodeScaleFactor];
    mutableContext[ImageLoaderContextImagePreserveAspectRatio] = decodeOptions[LoadImageCoderDecodePreserveAspectRatio];
    mutableContext[ImageLoaderContextImageThumbnailPixelSize] = decodeOptions[LoadImageCoderDecodeThumbnailPixelSize];
    mutableContext[ImageLoaderContextImageScaleDownLimitBytes] = decodeOptions[LoadImageCoderDecodeScaleDownLimitBytes];
    
    NSString *typeIdentifierHint = decodeOptions[LoadImageCoderDecodeTypeIdentifierHint];
    if (!typeIdentifierHint) {
        NSString *fileExtensionHint = decodeOptions[LoadImageCoderDecodeFileExtensionHint];
        if (fileExtensionHint) {
            typeIdentifierHint = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtensionHint, kUTTypeImage);
            // Ignore dynamic UTI
            if (UTTypeIsDynamic((__bridge CFStringRef)typeIdentifierHint)) {
                typeIdentifierHint = nil;
            }
        }
    }
    mutableContext[ImageLoaderContextImageTypeIdentifierHint] = typeIdentifierHint;
}

UIImage * _Nullable LoadImageCacheDecodeImageData(NSData * _Nonnull imageData, NSString * _Nonnull cacheKey, ImageLoaderOptions options, ImageLoaderContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(cacheKey);
    UIImage *image;
    LoadImageCoderOptions *coderOptions = SDGetDecodeOptionsFromContext(context, options, cacheKey);
    BOOL decodeFirstFrame = SD_OPTIONS_CONTAINS(options, ImageLoaderDecodeFirstFrameOnly);
    CGFloat scale = [coderOptions[LoadImageCoderDecodeScaleFactor] doubleValue];
    
    // Grab the image coder
    id<LoadImageCoder> imageCoder = context[ImageLoaderContextImageCoder];
    if (!imageCoder) {
        imageCoder = [LoadImageCodersManager sharedManager];
    }
    
    if (!decodeFirstFrame) {
        Class animatedImageClass = context[ImageLoaderContextAnimatedImageClass];
        // check whether we should use `SDAnimatedImage`
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(SDAnimatedImage)]) {
            image = [[animatedImageClass alloc] initWithData:imageData scale:scale options:coderOptions];
            if (image) {
                // Preload frames if supported
                if (options & ImageLoaderPreloadAllFrames && [image respondsToSelector:@selector(preloadAllFrames)]) {
                    [((id<SDAnimatedImage>)image) preloadAllFrames];
                }
            } else {
                // Check image class matching
                if (options & ImageLoaderMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [imageCoder decodedImageWithData:imageData options:coderOptions];
    }
    if (image) {
        BOOL shouldDecode = !SD_OPTIONS_CONTAINS(options, ImageLoaderAvoidDecodeImage);
        BOOL lazyDecode = [coderOptions[LoadImageCoderDecodeUseLazyDecoding] boolValue];
        if (lazyDecode) {
            // lazyDecode = NO means we should not forceDecode, highest priority
            shouldDecode = NO;
        }
        if (shouldDecode) {
            image = [LoadImageCoderHelper decodedImageWithImage:image];
        }
        // assign the decode options, to let manager check whether to re-decode if needed
        image._decodeOptions = coderOptions;
    }
    
    return image;
}
