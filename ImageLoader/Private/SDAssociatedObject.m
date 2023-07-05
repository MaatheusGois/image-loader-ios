/*
* This file is part of the ImageLoader package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "SDAssociatedObject.h"
#import "UIImage+Metadata.h"
#import "UIImage+ExtendedCacheData.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+ForceDecode.h"

void LoadImageCopyAssociatedObject(UIImage * _Nullable source, UIImage * _Nullable target) {
    if (!source || !target) {
        return;
    }
    // Image Metadata
    target.btg_isIncremental = source.btg_isIncremental;
    target.btg_isTransformed = source.btg_isTransformed;
    target.btg_decodeOptions = source.btg_decodeOptions;
    target.btg_imageLoopCount = source.btg_imageLoopCount;
    target.btg_imageFormat = source.btg_imageFormat;
    // Force Decode
    target.btg_isDecoded = source.btg_isDecoded;
    // Extended Cache Data
    target.btg_extendedObject = source.btg_extendedObject;
}
