/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCacheSerializer.h"

@interface ImageLoaderCacheSerializer ()

@property (nonatomic, copy, nonnull) ImageLoaderCacheSerializerBlock block;

@end

@implementation ImageLoaderCacheSerializer

- (instancetype)initWithBlock:(ImageLoaderCacheSerializerBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)cacheSerializerWithBlock:(ImageLoaderCacheSerializerBlock)block {
    ImageLoaderCacheSerializer *cacheSerializer = [[ImageLoaderCacheSerializer alloc] initWithBlock:block];
    return cacheSerializer;
}

- (NSData *)cacheDataWithImage:(UIImage *)image originalData:(NSData *)data imageURL:(nullable NSURL *)imageURL {
    if (!self.block) {
        return nil;
    }
    return self.block(image, data, imageURL);
}

@end
