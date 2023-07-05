/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "LoadImageCachesManager.h"
#import "LoadImageCachesManagerOperation.h"
#import "LoadImageCache.h"
#import "SDInternalMacros.h"

@interface LoadImageCachesManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<LoadImageCache>> *imageCaches;

@end

@implementation LoadImageCachesManager {
    SD_LOCK_DECLARE(_cachesLock);
}

+ (LoadImageCachesManager *)sharedManager {
    static dispatch_once_t onceToken;
    static LoadImageCachesManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[LoadImageCachesManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryOperationPolicy = LoadImageCachesManagerOperationPolicySerial;
        self.storeOperationPolicy = LoadImageCachesManagerOperationPolicyHighestOnly;
        self.removeOperationPolicy = LoadImageCachesManagerOperationPolicyConcurrent;
        self.containsOperationPolicy = LoadImageCachesManagerOperationPolicySerial;
        self.clearOperationPolicy = LoadImageCachesManagerOperationPolicyConcurrent;
        // initialize with default image caches
        _imageCaches = [NSMutableArray arrayWithObject:[LoadImageCache sharedImageCache]];
        SD_LOCK_INIT(_cachesLock);
    }
    return self;
}

- (NSArray<id<LoadImageCache>> *)caches {
    SD_LOCK(_cachesLock);
    NSArray<id<LoadImageCache>> *caches = [_imageCaches copy];
    SD_UNLOCK(_cachesLock);
    return caches;
}

- (void)setCaches:(NSArray<id<LoadImageCache>> *)caches {
    SD_LOCK(_cachesLock);
    [_imageCaches removeAllObjects];
    if (caches.count) {
        [_imageCaches addObjectsFromArray:caches];
    }
    SD_UNLOCK(_cachesLock);
}

#pragma mark - Cache IO operations

- (void)addCache:(id<LoadImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(LoadImageCache)]) {
        return;
    }
    SD_LOCK(_cachesLock);
    [_imageCaches addObject:cache];
    SD_UNLOCK(_cachesLock);
}

- (void)removeCache:(id<LoadImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(LoadImageCache)]) {
        return;
    }
    SD_LOCK(_cachesLock);
    [_imageCaches removeObject:cache];
    SD_UNLOCK(_cachesLock);
}

#pragma mark - LoadImageCache

- (id<ImageLoaderOperation>)queryImageForKey:(NSString *)key options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context completion:(LoadImageCacheQueryCompletionBlock)completionBlock {
    return [self queryImageForKey:key options:options context:context cacheType:LoadImageCacheTypeAll completion:completionBlock];
}

- (id<ImageLoaderOperation>)queryImageForKey:(NSString *)key options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context cacheType:(LoadImageCacheType)cacheType completion:(LoadImageCacheQueryCompletionBlock)completionBlock {
    if (!key) {
        return nil;
    }
    NSArray<id<LoadImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return nil;
    } else if (count == 1) {
        return [caches.firstObject queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
    }
    switch (self.queryOperationPolicy) {
        case LoadImageCachesManagerOperationPolicyHighestOnly: {
            id<LoadImageCache> cache = caches.lastObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyLowestOnly: {
            id<LoadImageCache> cache = caches.firstObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyConcurrent: {
            LoadImageCachesManagerOperation *operation = [LoadImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        case LoadImageCachesManagerOperationPolicySerial: {
            LoadImageCachesManagerOperation *operation = [LoadImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        default:
            return nil;
            break;
    }
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock {
    [self storeImage:image imageData:imageData forKey:key options:0 context:nil cacheType:cacheType completion:completionBlock];
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context cacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<LoadImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.storeOperationPolicy) {
        case LoadImageCachesManagerOperationPolicyHighestOnly: {
            id<LoadImageCache> cache = caches.lastObject;
            [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyLowestOnly: {
            id<LoadImageCache> cache = caches.firstObject;
            [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyConcurrent: {
            LoadImageCachesManagerOperation *operation = [LoadImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentStoreImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case LoadImageCachesManagerOperationPolicySerial: {
            [self serialStoreImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)removeImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<LoadImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject removeImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.removeOperationPolicy) {
        case LoadImageCachesManagerOperationPolicyHighestOnly: {
            id<LoadImageCache> cache = caches.lastObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyLowestOnly: {
            id<LoadImageCache> cache = caches.firstObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyConcurrent: {
            LoadImageCachesManagerOperation *operation = [LoadImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case LoadImageCachesManagerOperationPolicySerial: {
            [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(LoadImageCacheContainsCompletionBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<LoadImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject containsImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case LoadImageCachesManagerOperationPolicyHighestOnly: {
            id<LoadImageCache> cache = caches.lastObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyLowestOnly: {
            id<LoadImageCache> cache = caches.firstObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyConcurrent: {
            LoadImageCachesManagerOperation *operation = [LoadImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case LoadImageCachesManagerOperationPolicySerial: {
            LoadImageCachesManagerOperation *operation = [LoadImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        default:
            break;
    }
}

- (void)clearWithCacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock {
    NSArray<id<LoadImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject clearWithCacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case LoadImageCachesManagerOperationPolicyHighestOnly: {
            id<LoadImageCache> cache = caches.lastObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyLowestOnly: {
            id<LoadImageCache> cache = caches.firstObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case LoadImageCachesManagerOperationPolicyConcurrent: {
            LoadImageCachesManagerOperation *operation = [LoadImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case LoadImageCachesManagerOperationPolicySerial: {
            [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

#pragma mark - Concurrent Operation

- (void)concurrentQueryImageForKey:(NSString *)key options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context cacheType:(LoadImageCacheType)queryCacheType completion:(LoadImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator operation:(LoadImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<LoadImageCache> cache in enumerator) {
        [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, LoadImageCacheType cacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (image) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(image, data, cacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(nil, nil, LoadImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context cacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator operation:(LoadImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<LoadImageCache> cache in enumerator) {
        [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentRemoveImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator operation:(LoadImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<LoadImageCache> cache in enumerator) {
        [cache removeImageForKey:key cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentContainsImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(LoadImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator operation:(LoadImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<LoadImageCache> cache in enumerator) {
        [cache containsImageForKey:key cacheType:cacheType completion:^(LoadImageCacheType containsCacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (containsCacheType != LoadImageCacheTypeNone) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(containsCacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(LoadImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentClearWithCacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator operation:(LoadImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<LoadImageCache> cache in enumerator) {
        [cache clearWithCacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

#pragma mark - Serial Operation

- (void)serialQueryImageForKey:(NSString *)key options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context cacheType:(LoadImageCacheType)queryCacheType completion:(LoadImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator operation:(LoadImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<LoadImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(nil, nil, LoadImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, LoadImageCacheType cacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (image) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(image, data, cacheType);
            }
            return;
        }
        // Next
        [self serialQueryImageForKey:key options:options context:context cacheType:queryCacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context cacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<LoadImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialStoreImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialRemoveImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<LoadImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache removeImageForKey:key cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialContainsImageForKey:(NSString *)key cacheType:(LoadImageCacheType)cacheType completion:(LoadImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator operation:(LoadImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<LoadImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(LoadImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache containsImageForKey:key cacheType:cacheType completion:^(LoadImageCacheType containsCacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (containsCacheType != LoadImageCacheTypeNone) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(containsCacheType);
            }
            return;
        }
        // Next
        [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialClearWithCacheType:(LoadImageCacheType)cacheType completion:(ImageLoaderNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<LoadImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<LoadImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache clearWithCacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

@end
