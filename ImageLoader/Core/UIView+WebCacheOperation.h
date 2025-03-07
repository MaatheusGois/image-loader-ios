/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCompat.h"
#import "ImageLoaderOperation.h"

/**
 These methods are used to support canceling for UIView image loading, it's designed to be used internal but not external.
 All the stored operations are weak, so it will be dealloced after image loading finished. If you need to store operations, use your own class to keep a strong reference for them.
 */
@interface UIView (WebCacheOperation)

/**
 *  Get the image load operation for key
 *
 *  @param key key for identifying the operations
 *  @return the image load operation
 */
- (nullable id<ImageLoaderOperation>)_imageLoadOperationForKey:(nullable NSString *)key;

/**
 *  Set the image load operation (storage in a UIView based weak map table)
 *
 *  @param operation the operation
 *  @param key       key for storing the operation
 */
- (void)_setImageLoadOperation:(nullable id<ImageLoaderOperation>)operation forKey:(nullable NSString *)key;

/**
 *  Cancel the operation for the current UIView and key
 *
 *  @param key key for identifying the operations
 */
- (void)_cancelImageLoadOperationWithKey:(nullable NSString *)key;

/**
 *  Just remove the operation corresponding to the current UIView and key without cancelling them
 *
 *  @param key key for identifying the operations
 */
- (void)_removeImageLoadOperationWithKey:(nullable NSString *)key;

@end
