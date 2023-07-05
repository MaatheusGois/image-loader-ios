/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCacheKeyFilter.h"

@interface ImageLoaderCacheKeyFilter ()

@property (nonatomic, copy, nonnull) ImageLoaderCacheKeyFilterBlock block;

@end

@implementation ImageLoaderCacheKeyFilter

- (instancetype)initWithBlock:(ImageLoaderCacheKeyFilterBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)cacheKeyFilterWithBlock:(ImageLoaderCacheKeyFilterBlock)block {
    ImageLoaderCacheKeyFilter *cacheKeyFilter = [[ImageLoaderCacheKeyFilter alloc] initWithBlock:block];
    return cacheKeyFilter;
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!self.block) {
        return nil;
    }
    return self.block(url);
}

@end
