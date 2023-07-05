/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderDefine.h"
#import "UIImage+Metadata.h"
#import "NSImage+Compatibility.h"
#import "SDAnimatedImage.h"
#import "SDAssociatedObject.h"

#pragma mark - Image scale

static inline NSArray<NSNumber *> * _Nonnull LoadImageScaleFactors(void) {
    return @[@2, @3];
}

inline CGFloat LoadImageScaleFactorForKey(NSString * _Nullable key) {
    CGFloat scale = 1;
    if (!key) {
        return scale;
    }
    // Check if target OS support scale
#if SD_WATCH
    if ([[WKInterfaceDevice currentDevice] respondsToSelector:@selector(screenScale)])
#elif SD_UIKIT
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
#elif SD_MAC
    NSScreen *mainScreen = nil;
    if (@available(macOS 10.12, *)) {
        mainScreen = [NSScreen mainScreen];
    } else {
        mainScreen = [NSScreen screens].firstObject;
    }
    if ([mainScreen respondsToSelector:@selector(backingScaleFactor)])
#endif
    {
        // a@2x.png -> 8
        if (key.length >= 8) {
            // Fast check
            BOOL isURL = [key hasPrefix:@"http://"] || [key hasPrefix:@"https://"];
            for (NSNumber *scaleFactor in LoadImageScaleFactors()) {
                // @2x. for file name and normal url
                NSString *fileScale = [NSString stringWithFormat:@"@%@x.", scaleFactor];
                if ([key containsString:fileScale]) {
                    scale = scaleFactor.doubleValue;
                    return scale;
                }
                if (isURL) {
                    // %402x. for url encode
                    NSString *urlScale = [NSString stringWithFormat:@"%%40%@x.", scaleFactor];
                    if ([key containsString:urlScale]) {
                        scale = scaleFactor.doubleValue;
                        return scale;
                    }
                }
            }
        }
    }
    return scale;
}

inline UIImage * _Nullable SDScaledImageForKey(NSString * _Nullable key, UIImage * _Nullable image) {
    if (!image) {
        return nil;
    }
    CGFloat scale = LoadImageScaleFactorForKey(key);
    return SDScaledImageForScaleFactor(scale, image);
}

inline UIImage * _Nullable SDScaledImageForScaleFactor(CGFloat scale, UIImage * _Nullable image) {
    if (!image) {
        return nil;
    }
    if (scale <= 1) {
        return image;
    }
    if (scale == image.scale) {
        return image;
    }
    UIImage *scaledImage;
    // Check SDAnimatedImage support for shortcut
    if ([image.class conformsToProtocol:@protocol(SDAnimatedImage)]) {
        if ([image respondsToSelector:@selector(animatedCoder)]) {
            id<SDAnimatedImageCoder> coder = [(id<SDAnimatedImage>)image animatedCoder];
            if (coder) {
                scaledImage = [[image.class alloc] initWithAnimatedCoder:coder scale:scale];
            }
        } else {
            // Some class impl does not support `animatedCoder`, keep for compatibility
            NSData *data = [(id<SDAnimatedImage>)image animatedImageData];
            if (data) {
                scaledImage = [[image.class alloc] initWithData:data scale:scale];
            }
        }
        if (scaledImage) {
            return scaledImage;
        }
    }
    if (image.btg_isAnimated) {
        UIImage *animatedImage;
#if SD_UIKIT || SD_WATCH
        // `UIAnimatedImage` images share the same size and scale.
        NSArray<UIImage *> *images = image.images;
        NSMutableArray<UIImage *> *scaledImages = [NSMutableArray arrayWithCapacity:images.count];
        
        for (UIImage *tempImage in images) {
            UIImage *tempScaledImage = [[UIImage alloc] initWithCGImage:tempImage.CGImage scale:scale orientation:tempImage.imageOrientation];
            [scaledImages addObject:tempScaledImage];
        }
        
        animatedImage = [UIImage animatedImageWithImages:scaledImages duration:image.duration];
        animatedImage.btg_imageLoopCount = image.btg_imageLoopCount;
#else
        // Animated GIF for `NSImage` need to grab `NSBitmapImageRep`;
        NSRect imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
        NSImageRep *imageRep = [image bestRepresentationForRect:imageRect context:nil hints:nil];
        NSBitmapImageRep *bitmapImageRep;
        if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmapImageRep = (NSBitmapImageRep *)imageRep;
        }
        if (bitmapImageRep) {
            NSSize size = NSMakeSize(image.size.width / scale, image.size.height / scale);
            animatedImage = [[NSImage alloc] initWithSize:size];
            bitmapImageRep.size = size;
            [animatedImage addRepresentation:bitmapImageRep];
        }
#endif
        scaledImage = animatedImage;
    } else {
#if SD_UIKIT || SD_WATCH
        scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
#else
        scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:kCGImagePropertyOrientationUp];
#endif
    }
    LoadImageCopyAssociatedObject(image, scaledImage);
    
    return scaledImage;
}

#pragma mark - Context option

ImageLoaderContextOption const ImageLoaderContextSetImageOperationKey = @"setImageOperationKey";
ImageLoaderContextOption const ImageLoaderContextCustomManager = @"customManager";
ImageLoaderContextOption const ImageLoaderContextCallbackQueue = @"callbackQueue";
ImageLoaderContextOption const ImageLoaderContextImageCache = @"imageCache";
ImageLoaderContextOption const ImageLoaderContextImageLoader = @"imageLoader";
ImageLoaderContextOption const ImageLoaderContextImageCoder = @"imageCoder";
ImageLoaderContextOption const ImageLoaderContextImageTransformer = @"imageTransformer";
ImageLoaderContextOption const ImageLoaderContextImageDecodeOptions = @"imageDecodeOptions";
ImageLoaderContextOption const ImageLoaderContextImageScaleFactor = @"imageScaleFactor";
ImageLoaderContextOption const ImageLoaderContextImagePreserveAspectRatio = @"imagePreserveAspectRatio";
ImageLoaderContextOption const ImageLoaderContextImageThumbnailPixelSize = @"imageThumbnailPixelSize";
ImageLoaderContextOption const ImageLoaderContextImageTypeIdentifierHint = @"imageTypeIdentifierHint";
ImageLoaderContextOption const ImageLoaderContextImageScaleDownLimitBytes = @"imageScaleDownLimitBytes";
ImageLoaderContextOption const ImageLoaderContextImageEncodeOptions = @"imageEncodeOptions";
ImageLoaderContextOption const ImageLoaderContextQueryCacheType = @"queryCacheType";
ImageLoaderContextOption const ImageLoaderContextStoreCacheType = @"storeCacheType";
ImageLoaderContextOption const ImageLoaderContextOriginalQueryCacheType = @"originalQueryCacheType";
ImageLoaderContextOption const ImageLoaderContextOriginalStoreCacheType = @"originalStoreCacheType";
ImageLoaderContextOption const ImageLoaderContextOriginalImageCache = @"originalImageCache";
ImageLoaderContextOption const ImageLoaderContextAnimatedImageClass = @"animatedImageClass";
ImageLoaderContextOption const ImageLoaderContextDownloadRequestModifier = @"downloadRequestModifier";
ImageLoaderContextOption const ImageLoaderContextDownloadResponseModifier = @"downloadResponseModifier";
ImageLoaderContextOption const ImageLoaderContextDownloadDecryptor = @"downloadDecryptor";
ImageLoaderContextOption const ImageLoaderContextCacheKeyFilter = @"cacheKeyFilter";
ImageLoaderContextOption const ImageLoaderContextCacheSerializer = @"cacheSerializer";
