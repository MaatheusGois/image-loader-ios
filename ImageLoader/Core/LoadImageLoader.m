/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "LoadImageLoader.h"
#import "ImageLoaderCacheKeyFilter.h"
#import "LoadImageCodersManager.h"
#import "LoadImageCoderHelper.h"
#import "SDAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "SDInternalMacros.h"
#import "LoadImageCacheDefine.h"
#import "objc/runtime.h"

ImageLoaderContextOption const ImageLoaderContextLoaderCachedImage = @"loaderCachedImage";

static void * LoadImageLoaderProgressiveCoderKey = &LoadImageLoaderProgressiveCoderKey;

id<SDProgressiveImageCoder> LoadImageLoaderGetProgressiveCoder(id<ImageLoaderOperation> operation) {
    NSCParameterAssert(operation);
    return objc_getAssociatedObject(operation, LoadImageLoaderProgressiveCoderKey);
}

void LoadImageLoaderSetProgressiveCoder(id<ImageLoaderOperation> operation, id<SDProgressiveImageCoder> progressiveCoder) {
    NSCParameterAssert(operation);
    objc_setAssociatedObject(operation, LoadImageLoaderProgressiveCoderKey, progressiveCoder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

UIImage * _Nullable LoadImageLoaderDecodeImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, ImageLoaderOptions options, ImageLoaderContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    
    UIImage *image;
    id<ImageLoaderCacheKeyFilter> cacheKeyFilter = context[ImageLoaderContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
    LoadImageCoderOptions *coderOptions = SDGetDecodeOptionsFromContext(context, options, cacheKey);
    BOOL decodeFirstFrame = SD_OPTIONS_CONTAINS(options, ImageLoaderDecodeFirstFrameOnly);
    CGFloat scale = [coderOptions[LoadImageCoderDecodeScaleFactor] doubleValue];
    
    // Grab the image coder
    id<LoadImageCoder> imageCoder = context[ImageLoaderContextImageCoder];
    if (!imageCoder) {
        imageCoder = [LoadImageCodersManager sharedManager];
    }
    
    if (!decodeFirstFrame) {
        // check whether we should use `SDAnimatedImage`
        Class animatedImageClass = context[ImageLoaderContextAnimatedImageClass];
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
        image.btg_decodeOptions = coderOptions;
    }
    
    return image;
}

UIImage * _Nullable LoadImageLoaderDecodeProgressiveImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, BOOL finished,  id<ImageLoaderOperation> _Nonnull operation, ImageLoaderOptions options, ImageLoaderContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    NSCParameterAssert(operation);
    
    UIImage *image;
    id<ImageLoaderCacheKeyFilter> cacheKeyFilter = context[ImageLoaderContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
    LoadImageCoderOptions *coderOptions = SDGetDecodeOptionsFromContext(context, options, cacheKey);
    BOOL decodeFirstFrame = SD_OPTIONS_CONTAINS(options, ImageLoaderDecodeFirstFrameOnly);
    CGFloat scale = [coderOptions[LoadImageCoderDecodeScaleFactor] doubleValue];
    
    // Grab the progressive image coder
    id<SDProgressiveImageCoder> progressiveCoder = LoadImageLoaderGetProgressiveCoder(operation);
    if (!progressiveCoder) {
        id<SDProgressiveImageCoder> imageCoder = context[ImageLoaderContextImageCoder];
        // Check the progressive coder if provided
        if ([imageCoder respondsToSelector:@selector(initIncrementalWithOptions:)]) {
            progressiveCoder = [[[imageCoder class] alloc] initIncrementalWithOptions:coderOptions];
        } else {
            // We need to create a new instance for progressive decoding to avoid conflicts
            for (id<LoadImageCoder> coder in [LoadImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
                if ([coder conformsToProtocol:@protocol(SDProgressiveImageCoder)] &&
                    [((id<SDProgressiveImageCoder>)coder) canIncrementalDecodeFromData:imageData]) {
                    progressiveCoder = [[[coder class] alloc] initIncrementalWithOptions:coderOptions];
                    break;
                }
            }
        }
        LoadImageLoaderSetProgressiveCoder(operation, progressiveCoder);
    }
    // If we can't find any progressive coder, disable progressive download
    if (!progressiveCoder) {
        return nil;
    }
    
    [progressiveCoder updateIncrementalData:imageData finished:finished];
    if (!decodeFirstFrame) {
        // check whether we should use `SDAnimatedImage`
        Class animatedImageClass = context[ImageLoaderContextAnimatedImageClass];
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(SDAnimatedImage)] && [progressiveCoder respondsToSelector:@selector(animatedImageFrameAtIndex:)]) {
            image = [[animatedImageClass alloc] initWithAnimatedCoder:(id<SDAnimatedImageCoder>)progressiveCoder scale:scale];
            if (image) {
                // Progressive decoding does not preload frames
            } else {
                // Check image class matching
                if (options & ImageLoaderMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [progressiveCoder incrementalDecodedImageWithOptions:coderOptions];
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
        image.btg_decodeOptions = coderOptions;
        // mark the image as progressive (completed one are not mark as progressive)
        image.btg_isIncremental = !finished;
    }
    
    return image;
}
