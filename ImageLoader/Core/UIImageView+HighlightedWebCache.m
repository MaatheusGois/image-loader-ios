/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImageView+HighlightedWebCache.h"

#if SD_UIKIT

#import "UIView+WebCacheOperation.h"
#import "UIView+WebCache.h"
#import "SDInternalMacros.h"

static NSString * const SDHighlightedImageOperationKey = @"UIImageViewImageOperationHighlighted";

@implementation UIImageView (HighlightedWebCache)

- (void)_setHighlightedImageWithURL:(nullable NSURL *)url {
    [self _setHighlightedImageWithURL:url options:0 progress:nil completed:nil];
}

- (void)_setHighlightedImageWithURL:(nullable NSURL *)url options:(ImageLoaderOptions)options {
    [self _setHighlightedImageWithURL:url options:options progress:nil completed:nil];
}

- (void)_setHighlightedImageWithURL:(nullable NSURL *)url options:(ImageLoaderOptions)options context:(nullable ImageLoaderContext *)context {
    [self _setHighlightedImageWithURL:url options:options context:context progress:nil completed:nil];
}

- (void)_setHighlightedImageWithURL:(nullable NSURL *)url completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setHighlightedImageWithURL:url options:0 progress:nil completed:completedBlock];
}

- (void)_setHighlightedImageWithURL:(nullable NSURL *)url options:(ImageLoaderOptions)options completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setHighlightedImageWithURL:url options:options progress:nil completed:completedBlock];
}

- (void)_setHighlightedImageWithURL:(NSURL *)url options:(ImageLoaderOptions)options progress:(nullable LoadImageLoaderProgressBlock)progressBlock completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setHighlightedImageWithURL:url options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(ImageLoaderOptions)options
                              context:(nullable ImageLoaderContext *)context
                             progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                            completed:(nullable SDExternalCompletionBlock)completedBlock {
    @weakify(self);
    ImageLoaderMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[ImageLoaderContextSetImageOperationKey] = SDHighlightedImageOperationKey;
    [self _internalSetImageWithURL:url
                    placeholderImage:nil
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, LoadImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           self.highlightedImage = image;
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, LoadImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

@end

#endif
