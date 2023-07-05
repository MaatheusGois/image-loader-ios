/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImageView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "UIView+WebCache.h"

@implementation UIImageView (WebCache)

- (void)_setImageWithURL:(nullable NSURL *)url {
    [self _setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder {
    [self _setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options {
    [self _setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options context:(nullable ImageLoaderContext *)context {
    [self _setImageWithURL:url placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)_setImageWithURL:(nullable NSURL *)url completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options progress:(nullable LoadImageLoaderProgressBlock)progressBlock completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setImageWithURL:url placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(ImageLoaderOptions)options
                   context:(nullable ImageLoaderContext *)context
                  progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                 completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:context
                       setImageBlock:nil
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, LoadImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

@end
