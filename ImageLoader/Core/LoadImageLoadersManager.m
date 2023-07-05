/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "LoadImageLoadersManager.h"
#import "ImageLoaderDownloader.h"
#import "SDInternalMacros.h"

@interface LoadImageLoadersManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<LoadImageLoader>> *imageLoaders;

@end

@implementation LoadImageLoadersManager {
    SD_LOCK_DECLARE(_loadersLock);
}

+ (LoadImageLoadersManager *)sharedManager {
    static dispatch_once_t onceToken;
    static LoadImageLoadersManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[LoadImageLoadersManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // initialize with default image loaders
        _imageLoaders = [NSMutableArray arrayWithObject:[ImageLoaderDownloader sharedDownloader]];
        SD_LOCK_INIT(_loadersLock);
    }
    return self;
}

- (NSArray<id<LoadImageLoader>> *)loaders {
    SD_LOCK(_loadersLock);
    NSArray<id<LoadImageLoader>>* loaders = [_imageLoaders copy];
    SD_UNLOCK(_loadersLock);
    return loaders;
}

- (void)setLoaders:(NSArray<id<LoadImageLoader>> *)loaders {
    SD_LOCK(_loadersLock);
    [_imageLoaders removeAllObjects];
    if (loaders.count) {
        [_imageLoaders addObjectsFromArray:loaders];
    }
    SD_UNLOCK(_loadersLock);
}

#pragma mark - Loader Property

- (void)addLoader:(id<LoadImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(LoadImageLoader)]) {
        return;
    }
    SD_LOCK(_loadersLock);
    [_imageLoaders addObject:loader];
    SD_UNLOCK(_loadersLock);
}

- (void)removeLoader:(id<LoadImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(LoadImageLoader)]) {
        return;
    }
    SD_LOCK(_loadersLock);
    [_imageLoaders removeObject:loader];
    SD_UNLOCK(_loadersLock);
}

#pragma mark - LoadImageLoader

- (BOOL)canRequestImageForURL:(nullable NSURL *)url {
    return [self canRequestImageForURL:url options:0 context:nil];
}

- (BOOL)canRequestImageForURL:(NSURL *)url options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context {
    NSArray<id<LoadImageLoader>> *loaders = self.loaders;
    for (id<LoadImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader respondsToSelector:@selector(canRequestImageForURL:options:context:)]) {
            if ([loader canRequestImageForURL:url options:options context:context]) {
                return YES;
            }
        } else {
            if ([loader canRequestImageForURL:url]) {
                return YES;
            }
        }
    }
    return NO;
}

- (id<ImageLoaderOperation>)requestImageWithURL:(NSURL *)url options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context progress:(LoadImageLoaderProgressBlock)progressBlock completed:(LoadImageLoaderCompletedBlock)completedBlock {
    if (!url) {
        return nil;
    }
    NSArray<id<LoadImageLoader>> *loaders = self.loaders;
    for (id<LoadImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader requestImageWithURL:url options:options context:context progress:progressBlock completed:completedBlock];
        }
    }
    return nil;
}

- (BOOL)shouldBlockFailedURLWithURL:(NSURL *)url error:(NSError *)error {
    NSArray<id<LoadImageLoader>> *loaders = self.loaders;
    for (id<LoadImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader shouldBlockFailedURLWithURL:url error:error];
        }
    }
    return NO;
}

@end
