/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Florent Vilmart
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <ImageLoader/SDWebImageCompat.h>

//! Project version number for ImageLoader.
FOUNDATION_EXPORT double SDWebImageVersionNumber;

//! Project version string for ImageLoader.
FOUNDATION_EXPORT const unsigned char SDWebImageVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <ImageLoader/PublicHeader.h>

#import <ImageLoader/SDWebImageManager.h>
#import <ImageLoader/SDCallbackQueue.h>
#import <ImageLoader/SDWebImageCacheKeyFilter.h>
#import <ImageLoader/SDWebImageCacheSerializer.h>
#import <ImageLoader/SDImageCacheConfig.h>
#import <ImageLoader/SDImageCache.h>
#import <ImageLoader/SDMemoryCache.h>
#import <ImageLoader/SDDiskCache.h>
#import <ImageLoader/SDImageCacheDefine.h>
#import <ImageLoader/SDImageCachesManager.h>
#import <ImageLoader/UIView+WebCache.h>
#import <ImageLoader/UIImageView+WebCache.h>
#import <ImageLoader/UIImageView+HighlightedWebCache.h>
#import <ImageLoader/SDWebImageDownloaderConfig.h>
#import <ImageLoader/SDWebImageDownloaderOperation.h>
#import <ImageLoader/SDWebImageDownloaderRequestModifier.h>
#import <ImageLoader/SDWebImageDownloaderResponseModifier.h>
#import <ImageLoader/SDWebImageDownloaderDecryptor.h>
#import <ImageLoader/SDImageLoader.h>
#import <ImageLoader/SDImageLoadersManager.h>
#import <ImageLoader/UIButton+WebCache.h>
#import <ImageLoader/SDWebImagePrefetcher.h>
#import <ImageLoader/UIView+WebCacheOperation.h>
#import <ImageLoader/UIImage+Metadata.h>
#import <ImageLoader/UIImage+MultiFormat.h>
#import <ImageLoader/UIImage+MemoryCacheCost.h>
#import <ImageLoader/UIImage+ExtendedCacheData.h>
#import <ImageLoader/SDWebImageOperation.h>
#import <ImageLoader/SDWebImageDownloader.h>
#import <ImageLoader/SDWebImageTransition.h>
#import <ImageLoader/SDWebImageIndicator.h>
#import <ImageLoader/SDImageTransformer.h>
#import <ImageLoader/UIImage+Transform.h>
#import <ImageLoader/SDAnimatedImage.h>
#import <ImageLoader/SDAnimatedImageView.h>
#import <ImageLoader/SDAnimatedImageView+WebCache.h>
#import <ImageLoader/SDAnimatedImagePlayer.h>
#import <ImageLoader/SDImageCodersManager.h>
#import <ImageLoader/SDImageCoder.h>
#import <ImageLoader/SDImageAPNGCoder.h>
#import <ImageLoader/SDImageGIFCoder.h>
#import <ImageLoader/SDImageIOCoder.h>
#import <ImageLoader/SDImageFrame.h>
#import <ImageLoader/SDImageCoderHelper.h>
#import <ImageLoader/SDImageGraphics.h>
#import <ImageLoader/SDGraphicsImageRenderer.h>
#import <ImageLoader/UIImage+GIF.h>
#import <ImageLoader/UIImage+ForceDecode.h>
#import <ImageLoader/NSData+ImageContentType.h>
#import <ImageLoader/SDWebImageDefine.h>
#import <ImageLoader/SDWebImageError.h>
#import <ImageLoader/SDWebImageOptionsProcessor.h>
#import <ImageLoader/SDImageIOAnimatedCoder.h>
#import <ImageLoader/SDImageHEICCoder.h>
#import <ImageLoader/SDImageAWebPCoder.h>

// Mac
#if __has_include(<ImageLoader/NSImage+Compatibility.h>)
#import <ImageLoader/NSImage+Compatibility.h>
#endif
#if __has_include(<ImageLoader/NSButton+WebCache.h>)
#import <ImageLoader/NSButton+WebCache.h>
#endif
#if __has_include(<ImageLoader/SDAnimatedImageRep.h>)
#import <ImageLoader/SDAnimatedImageRep.h>
#endif

// MapKit
#if __has_include(<ImageLoader/MKAnnotationView+WebCache.h>)
#import <ImageLoader/MKAnnotationView+WebCache.h>
#endif
