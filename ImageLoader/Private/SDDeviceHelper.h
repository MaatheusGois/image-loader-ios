/*
* This file is part of the ImageLoader package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import <Foundation/Foundation.h>
#import "ImageLoaderCompat.h"

/// Device information helper methods
@interface SDDeviceHelper : NSObject

+ (NSUInteger)totalMemory;
+ (NSUInteger)freeMemory;

@end
