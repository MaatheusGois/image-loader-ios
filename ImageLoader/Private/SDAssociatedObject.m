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
    target._isIncremental = source._isIncremental;
    target._isTransformed = source._isTransformed;
    target._decodeOptions = source._decodeOptions;
    target._imageLoopCount = source._imageLoopCount;
    target._imageFormat = source._imageFormat;
    // Force Decode
    target._isDecoded = source._isDecoded;
    // Extended Cache Data
    target._extendedObject = source._extendedObject;
}
