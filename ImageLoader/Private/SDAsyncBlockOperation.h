/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCompat.h"

@class SDAsyncBlockOperation;
typedef void (^SDAsyncBlock)(SDAsyncBlockOperation * __nonnull asyncOperation);

/// A async block operation, success after you call `completer` (not like `NSBlockOperation` which is for sync block, success on return)
@interface SDAsyncBlockOperation : NSOperation

- (nonnull instancetype)initWithBlock:(nonnull SDAsyncBlock)block;
+ (nonnull instancetype)blockOperationWithBlock:(nonnull SDAsyncBlock)block;
- (void)complete;

@end
