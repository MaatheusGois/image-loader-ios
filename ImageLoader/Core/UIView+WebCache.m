/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "ImageLoaderError.h"
#import "SDInternalMacros.h"
#import "ImageLoaderTransitionInternal.h"
#import "LoadImageCache.h"

const int64_t ImageLoaderProgressUnitCountUnknown = 1LL;

@implementation UIView (WebCache)

- (nullable NSURL *)btg_imageURL {
    return objc_getAssociatedObject(self, @selector(btg_imageURL));
}

- (void)setBtg_imageURL:(NSURL * _Nullable)btg_imageURL {
    objc_setAssociatedObject(self, @selector(btg_imageURL), btg_imageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (nullable NSString *)btg_latestOperationKey {
    return objc_getAssociatedObject(self, @selector(btg_latestOperationKey));
}

- (void)setBtg_latestOperationKey:(NSString * _Nullable)btg_latestOperationKey {
    objc_setAssociatedObject(self, @selector(btg_latestOperationKey), btg_latestOperationKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSProgress *)btg_imageProgress {
    NSProgress *progress = objc_getAssociatedObject(self, @selector(btg_imageProgress));
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        self.btg_imageProgress = progress;
    }
    return progress;
}

- (void)setBtg_imageProgress:(NSProgress *)btg_imageProgress {
    objc_setAssociatedObject(self, @selector(btg_imageProgress), btg_imageProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (nullable id<ImageLoaderOperation>)btg_internalSetImageWithURL:(nullable NSURL *)url
                                              placeholderImage:(nullable UIImage *)placeholder
                                                       options:(ImageLoaderOptions)options
                                                       context:(nullable ImageLoaderContext *)context
                                                 setImageBlock:(nullable SDSetImageBlock)setImageBlock
                                                      progress:(nullable LoadImageLoaderProgressBlock)progressBlock
                                                     completed:(nullable SDInternalCompletionBlock)completedBlock {
    if (context) {
        // copy to avoid mutable object
        context = [context copy];
    } else {
        context = [NSDictionary dictionary];
    }
    NSString *validOperationKey = context[ImageLoaderContextSetImageOperationKey];
    if (!validOperationKey) {
        // pass through the operation key to downstream, which can used for tracing operation or image view class
        validOperationKey = NSStringFromClass([self class]);
        ImageLoaderMutableContext *mutableContext = [context mutableCopy];
        mutableContext[ImageLoaderContextSetImageOperationKey] = validOperationKey;
        context = [mutableContext copy];
    }
    self.btg_latestOperationKey = validOperationKey;
    [self btg_cancelImageLoadOperationWithKey:validOperationKey];
    self.btg_imageURL = url;
    
    ImageLoaderManager *manager = context[ImageLoaderContextCustomManager];
    if (!manager) {
        manager = [ImageLoaderManager sharedManager];
    } else {
        // remove this manager to avoid retain cycle (manger -> loader -> operation -> context -> manager)
        ImageLoaderMutableContext *mutableContext = [context mutableCopy];
        mutableContext[ImageLoaderContextCustomManager] = nil;
        context = [mutableContext copy];
    }
    
    BOOL shouldUseWeakCache = NO;
    if ([manager.imageCache isKindOfClass:LoadImageCache.class]) {
        shouldUseWeakCache = ((LoadImageCache *)manager.imageCache).config.shouldUseWeakMemoryCache;
    }
    if (!(options & ImageLoaderDelayPlaceholder)) {
        if (shouldUseWeakCache) {
            NSString *key = [manager cacheKeyForURL:url context:context];
            // call memory cache to trigger weak cache sync logic, ignore the return value and go on normal query
            // this unfortunately will cause twice memory cache query, but it's fast enough
            // in the future the weak cache feature may be re-design or removed
            [((LoadImageCache *)manager.imageCache) imageFromMemoryCacheForKey:key];
        }
        dispatch_main_async_safe(^{
            [self btg_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:LoadImageCacheTypeNone imageURL:url];
        });
    }
    
    id <ImageLoaderOperation> operation = nil;
    
    if (url) {
        // reset the progress
        NSProgress *imageProgress = objc_getAssociatedObject(self, @selector(btg_imageProgress));
        if (imageProgress) {
            imageProgress.totalUnitCount = 0;
            imageProgress.completedUnitCount = 0;
        }
        
#if SD_UIKIT || SD_MAC
        // check and start image indicator
        [self btg_startImageIndicator];
        id<ImageLoaderIndicator> imageIndicator = self.btg_imageIndicator;
#endif
        
        LoadImageLoaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
            if (imageProgress) {
                imageProgress.totalUnitCount = expectedSize;
                imageProgress.completedUnitCount = receivedSize;
            }
#if SD_UIKIT || SD_MAC
            if ([imageIndicator respondsToSelector:@selector(updateIndicatorProgress:)]) {
                double progress = 0;
                if (expectedSize != 0) {
                    progress = (double)receivedSize / expectedSize;
                }
                progress = MAX(MIN(progress, 1), 0); // 0.0 - 1.0
                dispatch_async(dispatch_get_main_queue(), ^{
                    [imageIndicator updateIndicatorProgress:progress];
                });
            }
#endif
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        @weakify(self);
        operation = [manager loadImageWithURL:url options:options context:context progress:combinedProgressBlock completed:^(UIImage *image, NSData *data, NSError *error, LoadImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            @strongify(self);
            if (!self) { return; }
            // if the progress not been updated, mark it to complete state
            if (imageProgress && finished && !error && imageProgress.totalUnitCount == 0 && imageProgress.completedUnitCount == 0) {
                imageProgress.totalUnitCount = ImageLoaderProgressUnitCountUnknown;
                imageProgress.completedUnitCount = ImageLoaderProgressUnitCountUnknown;
            }
            
#if SD_UIKIT || SD_MAC
            // check and stop image indicator
            if (finished) {
                [self btg_stopImageIndicator];
            }
#endif
            
            BOOL shouldCallCompletedBlock = finished || (options & ImageLoaderAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & ImageLoaderAvoidAutoSetImage)) ||
                                      (!image && !(options & ImageLoaderDelayPlaceholder)));
            ImageLoaderNoParamsBlock callCompletedBlockClosure = ^{
                if (!self) { return; }
                if (!shouldNotSetImage) {
                    [self btg_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    completedBlock(image, data, error, cacheType, finished, url);
                }
            };
            
            // case 1a: we got an image, but the ImageLoaderAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the ImageLoaderDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClosure);
                return;
            }
            
            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the ImageLoaderAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & ImageLoaderDelayPlaceholder) {
                // case 2b: we got no image and the ImageLoaderDelayPlaceholder flag is set
                targetImage = placeholder;
                targetData = nil;
            }
            
#if SD_UIKIT || SD_MAC
            // check whether we should use the image transition
            ImageLoaderTransition *transition = nil;
            BOOL shouldUseTransition = NO;
            if (options & ImageLoaderForceTransition) {
                // Always
                shouldUseTransition = YES;
            } else if (cacheType == LoadImageCacheTypeNone) {
                // From network
                shouldUseTransition = YES;
            } else {
                // From disk (and, user don't use sync query)
                if (cacheType == LoadImageCacheTypeMemory) {
                    shouldUseTransition = NO;
                } else if (cacheType == LoadImageCacheTypeDisk) {
                    if (options & ImageLoaderQueryMemoryDataSync || options & ImageLoaderQueryDiskDataSync) {
                        shouldUseTransition = NO;
                    } else {
                        shouldUseTransition = YES;
                    }
                } else {
                    // Not valid cache type, fallback
                    shouldUseTransition = NO;
                }
            }
            if (finished && shouldUseTransition) {
                transition = self.btg_imageTransition;
            }
#endif
            dispatch_main_async_safe(^{
#if SD_UIKIT || SD_MAC
                [self btg_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
#else
                [self btg_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:cacheType imageURL:imageURL];
#endif
                callCompletedBlockClosure();
            });
        }];
        [self btg_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
#if SD_UIKIT || SD_MAC
        [self btg_stopImageIndicator];
#endif
        if (completedBlock) {
            dispatch_main_async_safe(^{
                NSError *error = [NSError errorWithDomain:ImageLoaderErrorDomain code:ImageLoaderErrorInvalidURL userInfo:@{NSLocalizedDescriptionKey : @"Image url is nil"}];
                completedBlock(nil, nil, error, LoadImageCacheTypeNone, YES, url);
            });
        }
    }
    
    return operation;
}

- (void)btg_cancelCurrentImageLoad {
    [self btg_cancelImageLoadOperationWithKey:self.btg_latestOperationKey];
    self.btg_latestOperationKey = nil;
}

- (void)btg_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock cacheType:(LoadImageCacheType)cacheType imageURL:(NSURL *)imageURL {
#if SD_UIKIT || SD_MAC
    [self btg_setImage:image imageData:imageData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:nil cacheType:cacheType imageURL:imageURL];
#else
    // watchOS does not support view transition. Simplify the logic
    if (setImageBlock) {
        setImageBlock(image, imageData, cacheType, imageURL);
    } else if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        [imageView setImage:image];
    }
#endif
}

#if SD_UIKIT || SD_MAC
- (void)btg_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock transition:(ImageLoaderTransition *)transition cacheType:(LoadImageCacheType)cacheType imageURL:(NSURL *)imageURL {
    UIView *view = self;
    SDSetImageBlock finalSetImageBlock;
    if (setImageBlock) {
        finalSetImageBlock = setImageBlock;
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, LoadImageCacheType setCacheType, NSURL *setImageURL) {
            imageView.image = setImage;
        };
    }
#if SD_UIKIT
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, LoadImageCacheType setCacheType, NSURL *setImageURL) {
            [button setImage:setImage forState:UIControlStateNormal];
        };
    }
#endif
#if SD_MAC
    else if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, LoadImageCacheType setCacheType, NSURL *setImageURL) {
            button.image = setImage;
        };
    }
#endif
    
    if (transition) {
        NSString *originalOperationKey = view.btg_latestOperationKey;

#if SD_UIKIT
        [UIView transitionWithView:view duration:0 options:0 animations:^{
            if (!view.btg_latestOperationKey || ![originalOperationKey isEqualToString:view.btg_latestOperationKey]) {
                return;
            }
            // 0 duration to let UIKit render placeholder and prepares block
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completion:^(BOOL tempFinished) {
            [UIView transitionWithView:view duration:transition.duration options:transition.animationOptions animations:^{
                if (!view.btg_latestOperationKey || ![originalOperationKey isEqualToString:view.btg_latestOperationKey]) {
                    return;
                }
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completion:^(BOOL finished) {
                if (!view.btg_latestOperationKey || ![originalOperationKey isEqualToString:view.btg_latestOperationKey]) {
                    return;
                }
                if (transition.completion) {
                    transition.completion(finished);
                }
            }];
        }];
#elif SD_MAC
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull prepareContext) {
            if (!view.btg_latestOperationKey || ![originalOperationKey isEqualToString:view.btg_latestOperationKey]) {
                return;
            }
            // 0 duration to let AppKit render placeholder and prepares block
            prepareContext.duration = 0;
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                if (!view.btg_latestOperationKey || ![originalOperationKey isEqualToString:view.btg_latestOperationKey]) {
                    return;
                }
                context.duration = transition.duration;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                CAMediaTimingFunction *timingFunction = transition.timingFunction;
#pragma clang diagnostic pop
                if (!timingFunction) {
                    timingFunction = SDTimingFunctionFromAnimationOptions(transition.animationOptions);
                }
                context.timingFunction = timingFunction;
                context.allowsImplicitAnimation = SD_OPTIONS_CONTAINS(transition.animationOptions, ImageLoaderAnimationOptionAllowsImplicitAnimation);
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                CATransition *trans = SDTransitionFromAnimationOptions(transition.animationOptions);
                if (trans) {
                    [view.layer addAnimation:trans forKey:kCATransition];
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completionHandler:^{
                if (!view.btg_latestOperationKey || ![originalOperationKey isEqualToString:view.btg_latestOperationKey]) {
                    return;
                }
                if (transition.completion) {
                    transition.completion(YES);
                }
            }];
        }];
#endif
    } else {
        if (finalSetImageBlock) {
            finalSetImageBlock(image, imageData, cacheType, imageURL);
        }
    }
}
#endif

- (void)btg_setNeedsLayout {
#if SD_UIKIT
    [self setNeedsLayout];
#elif SD_MAC
    [self setNeedsLayout:YES];
#elif SD_WATCH
    // Do nothing because WatchKit automatically layout the view after property change
#endif
}

#if SD_UIKIT || SD_MAC

#pragma mark - Image Transition
- (ImageLoaderTransition *)btg_imageTransition {
    return objc_getAssociatedObject(self, @selector(btg_imageTransition));
}

- (void)setBtg_imageTransition:(ImageLoaderTransition *)btg_imageTransition {
    objc_setAssociatedObject(self, @selector(btg_imageTransition), btg_imageTransition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Indicator
- (id<ImageLoaderIndicator>)btg_imageIndicator {
    return objc_getAssociatedObject(self, @selector(btg_imageIndicator));
}

- (void)setBtg_imageIndicator:(id<ImageLoaderIndicator>)btg_imageIndicator {
    // Remove the old indicator view
    id<ImageLoaderIndicator> previousIndicator = self.btg_imageIndicator;
    [previousIndicator.indicatorView removeFromSuperview];
    
    objc_setAssociatedObject(self, @selector(btg_imageIndicator), btg_imageIndicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add the new indicator view
    UIView *view = btg_imageIndicator.indicatorView;
    if (CGRectEqualToRect(view.frame, CGRectZero)) {
        view.frame = self.bounds;
    }
    // Center the indicator view
#if SD_MAC
    [view setFrameOrigin:CGPointMake(round((NSWidth(self.bounds) - NSWidth(view.frame)) / 2), round((NSHeight(self.bounds) - NSHeight(view.frame)) / 2))];
#else
    view.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
#endif
    view.hidden = NO;
    [self addSubview:view];
}

- (void)btg_startImageIndicator {
    id<ImageLoaderIndicator> imageIndicator = self.btg_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator startAnimatingIndicator];
    });
}

- (void)btg_stopImageIndicator {
    id<ImageLoaderIndicator> imageIndicator = self.btg_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator stopAnimatingIndicator];
    });
}

#endif

@end
