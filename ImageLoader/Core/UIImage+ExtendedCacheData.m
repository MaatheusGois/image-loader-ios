/*
* This file is part of the ImageLoader package.
* (c) Olivier Poitrey <rs@dailymotion.com>
* (c) Fabrice Aneche
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "UIImage+ExtendedCacheData.h"
#import <objc/runtime.h>

@implementation UIImage (ExtendedCacheData)

- (id<NSObject, NSCoding>)btg_extendedObject {
    return objc_getAssociatedObject(self, @selector(btg_extendedObject));
}

- (void)setBtg_extendedObject:(id<NSObject, NSCoding>)btg_extendedObject {
    objc_setAssociatedObject(self, @selector(btg_extendedObject), btg_extendedObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
