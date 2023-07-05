/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderOptionsProcessor.h"

@interface ImageLoaderOptionsResult ()

@property (nonatomic, assign) ImageLoaderOptions options;
@property (nonatomic, copy, nullable) ImageLoaderContext *context;

@end

@implementation ImageLoaderOptionsResult

- (instancetype)initWithOptions:(ImageLoaderOptions)options context:(ImageLoaderContext *)context {
    self = [super init];
    if (self) {
        self.options = options;
        self.context = context;
    }
    return self;
}

@end

@interface ImageLoaderOptionsProcessor ()

@property (nonatomic, copy, nonnull) ImageLoaderOptionsProcessorBlock block;

@end

@implementation ImageLoaderOptionsProcessor

- (instancetype)initWithBlock:(ImageLoaderOptionsProcessorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)optionsProcessorWithBlock:(ImageLoaderOptionsProcessorBlock)block {
    ImageLoaderOptionsProcessor *optionsProcessor = [[ImageLoaderOptionsProcessor alloc] initWithBlock:block];
    return optionsProcessor;
}

- (ImageLoaderOptionsResult *)processedResultForURL:(NSURL *)url options:(ImageLoaderOptions)options context:(ImageLoaderContext *)context {
    if (!self.block) {
        return nil;
    }
    return self.block(url, options, context);
}

@end
