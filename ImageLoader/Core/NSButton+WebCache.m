/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSButton+WebCache.h"

#if SD_MAC

#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "UIView+WebCache.h"
#import "SDInternalMacros.h"

static NSString * const SDAlternateImageOperationKey = @"NSButtonAlternateImageOperation";

@implementation NSButton (WebCache)

#pragma mark - Image

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
    self._currentImageURL = url;
    [self _internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:context
                       setImageBlock:nil
                            progress:progressBlock
                           completed:^(NSImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, LoadImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Alternate Image

- (void)_setAlternateImageWithURL:(nullable NSURL *)url {
    [self _setAlternateImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder {
    [self _setAlternateImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options {
    [self _setAlternateImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options context:(nullable ImageLoaderContext *)context {
    [self _setAlternateImageWithURL:url placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setAlternateImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setAlternateImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setAlternateImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(ImageLoaderOptions)options progress:(nullable LoadImageLoaderProgressBlock)progressBlock completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self _setAlternateImageWithURL:url placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)_setAlternateImageWithURL:(nullable NSURL *)url
                   placeholderImage:(nullable UIImage *)placeholder
                            options:(ImageLoaderOptions)options
                            context:(nullable ImageLoaderContext *)context
                           progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                          completed:(nullable SDExternalCompletionBlock)completedBlock {
    self._currentAlternateImageURL = url;
    
    ImageLoaderMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[ImageLoaderContextSetImageOperationKey] = SDAlternateImageOperationKey;
    @weakify(self);
    [self _internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(NSImage * _Nullable image, NSData * _Nullable imageData, LoadImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           self.alternateImage = image;
                       }
                            progress:progressBlock
                           completed:^(NSImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, LoadImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Cancel

- (void)_cancelCurrentImageLoad {
    [self _cancelImageLoadOperationWithKey:NSStringFromClass([self class])];
}

- (void)_cancelCurrentAlternateImageLoad {
    [self _cancelImageLoadOperationWithKey:SDAlternateImageOperationKey];
}

#pragma mark - Private

- (NSURL *)_currentImageURL {
    return objc_getAssociatedObject(self, @selector(_currentImageURL));
}

- (void)set_currentImageURL:(NSURL *)_currentImageURL {
    objc_setAssociatedObject(self, @selector(_currentImageURL), _currentImageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)_currentAlternateImageURL {
    return objc_getAssociatedObject(self, @selector(_currentAlternateImageURL));
}

- (void)set_currentAlternateImageURL:(NSURL *)_currentAlternateImageURL {
    objc_setAssociatedObject(self, @selector(_currentAlternateImageURL), _currentAlternateImageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#endif
