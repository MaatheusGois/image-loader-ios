/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Laurin Brandner
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+GIF.h"
#import "LoadImageGIFCoder.h"

@implementation UIImage (GIF)

+ (nullable UIImage *)btg_imageWithGIFData:(nullable NSData *)data {
    if (!data) {
        return nil;
    }
    return [[LoadImageGIFCoder sharedCoder] decodedImageWithData:data options:0];
}

@end
