/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "LoadImageCacheConfig.h"
#import "SDMemoryCache.h"
#import "SDDiskCache.h"

static LoadImageCacheConfig *_defaultCacheConfig;
static const NSInteger kDefaultCacheMaxDiskAge = 60 * 60 * 24 * 7; // 1 week

@implementation LoadImageCacheConfig

+ (LoadImageCacheConfig *)defaultCacheConfig {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultCacheConfig = [LoadImageCacheConfig new];
    });
    return _defaultCacheConfig;
}

- (instancetype)init {
    if (self = [super init]) {
        _shouldDisableiCloud = YES;
        _shouldCacheImagesInMemory = YES;
        _shouldUseWeakMemoryCache = NO;
        _shouldRemoveExpiredDataWhenEnterBackground = YES;
        _shouldRemoveExpiredDataWhenTerminate = YES;
        _diskCacheReadingOptions = 0;
        _diskCacheWritingOptions = NSDataWritingAtomic;
        _maxDiskAge = kDefaultCacheMaxDiskAge;
        _maxDiskSize = 0;
        _diskCacheExpireType = LoadImageCacheConfigExpireTypeModificationDate;
        _fileManager = nil;
        _ioQueueAttributes = DISPATCH_QUEUE_SERIAL; // NULL
        _memoryCacheClass = [SDMemoryCache class];
        _diskCacheClass = [SDDiskCache class];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LoadImageCacheConfig *config = [[[self class] allocWithZone:zone] init];
    config.shouldDisableiCloud = self.shouldDisableiCloud;
    config.shouldCacheImagesInMemory = self.shouldCacheImagesInMemory;
    config.shouldUseWeakMemoryCache = self.shouldUseWeakMemoryCache;
    config.shouldRemoveExpiredDataWhenEnterBackground = self.shouldRemoveExpiredDataWhenEnterBackground;
    config.shouldRemoveExpiredDataWhenTerminate = self.shouldRemoveExpiredDataWhenTerminate;
    config.diskCacheReadingOptions = self.diskCacheReadingOptions;
    config.diskCacheWritingOptions = self.diskCacheWritingOptions;
    config.maxDiskAge = self.maxDiskAge;
    config.maxDiskSize = self.maxDiskSize;
    config.maxMemoryCost = self.maxMemoryCost;
    config.maxMemoryCount = self.maxMemoryCount;
    config.diskCacheExpireType = self.diskCacheExpireType;
    config.fileManager = self.fileManager; // NSFileManager does not conform to NSCopying, just pass the reference
    config.ioQueueAttributes = self.ioQueueAttributes; // Pass the reference
    config.memoryCacheClass = self.memoryCacheClass;
    config.diskCacheClass = self.diskCacheClass;
    
    return config;
}

@end
