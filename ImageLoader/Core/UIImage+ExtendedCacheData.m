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

- (id<NSObject, NSCoding>)_extendedObject {
    return objc_getAssociatedObject(self, @selector(_extendedObject));
}

- (void)set_extendedObject:(id<NSObject, NSCoding>)_extendedObject {
    objc_setAssociatedObject(self, @selector(_extendedObject), _extendedObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
