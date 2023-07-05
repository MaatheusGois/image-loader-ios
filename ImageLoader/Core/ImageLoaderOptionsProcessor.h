/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "ImageLoaderCompat.h"
#import "ImageLoaderDefine.h"

@class ImageLoaderOptionsResult;

typedef ImageLoaderOptionsResult * _Nullable(^ImageLoaderOptionsProcessorBlock)(NSURL * _Nullable url, ImageLoaderOptions options, ImageLoaderContext * _Nullable context);

/**
 The options result contains both options and context.
 */
@interface ImageLoaderOptionsResult : NSObject

/**
 WebCache options.
 */
@property (nonatomic, assign, readonly) ImageLoaderOptions options;

/**
 Context options.
 */
@property (nonatomic, copy, readonly, nullable) ImageLoaderContext *context;

/**
 Create a new options result.

 @param options options
 @param context context
 @return The options result contains both options and context.
 */
- (nonnull instancetype)initWithOptions:(ImageLoaderOptions)options context:(nullable ImageLoaderContext *)context;

@end

/**
 This is the protocol for options processor.
 Options processor can be used, to control the final result for individual image request's `ImageLoaderOptions` and `ImageLoaderContext`
 Implements the protocol to have a global control for each indivadual image request's option.
 */
@protocol ImageLoaderOptionsProcessor <NSObject>

/**
 Return the processed options result for specify image URL, with its options and context

 @param url The URL to the image
 @param options A mask to specify options to use for this request
 @param context A context contains different options to perform specify changes or processes, see `ImageLoaderContextOption`. This hold the extra objects which `options` enum can not hold.
 @return The processed result, contains both options and context
 */
- (nullable ImageLoaderOptionsResult *)processedResultForURL:(nullable NSURL *)url
                                                    options:(ImageLoaderOptions)options
                                                    context:(nullable ImageLoaderContext *)context;

@end

/**
 A options processor class with block.
 */
@interface ImageLoaderOptionsProcessor : NSObject<ImageLoaderOptionsProcessor>

- (nonnull instancetype)initWithBlock:(nonnull ImageLoaderOptionsProcessorBlock)block;
+ (nonnull instancetype)optionsProcessorWithBlock:(nonnull ImageLoaderOptionsProcessorBlock)block;

@end
