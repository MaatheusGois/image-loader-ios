/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderTransition.h"

#if SD_UIKIT || SD_MAC

#if SD_MAC
#import "ImageLoaderTransitionInternal.h"
#import "SDInternalMacros.h"

CAMediaTimingFunction * SDTimingFunctionFromAnimationOptions(ImageLoaderAnimationOptions options) {
    if (SD_OPTIONS_CONTAINS(ImageLoaderAnimationOptionCurveLinear, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    } else if (SD_OPTIONS_CONTAINS(ImageLoaderAnimationOptionCurveEaseIn, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    } else if (SD_OPTIONS_CONTAINS(ImageLoaderAnimationOptionCurveEaseOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    } else if (SD_OPTIONS_CONTAINS(ImageLoaderAnimationOptionCurveEaseInOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    } else {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    }
}

CATransition * SDTransitionFromAnimationOptions(ImageLoaderAnimationOptions options) {
    if (SD_OPTIONS_CONTAINS(options, ImageLoaderAnimationOptionTransitionCrossDissolve)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionFade;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, ImageLoaderAnimationOptionTransitionFlipFromLeft)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromLeft;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, ImageLoaderAnimationOptionTransitionFlipFromRight)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromRight;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, ImageLoaderAnimationOptionTransitionFlipFromTop)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, ImageLoaderAnimationOptionTransitionFlipFromBottom)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, ImageLoaderAnimationOptionTransitionCurlUp)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, ImageLoaderAnimationOptionTransitionCurlDown)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else {
        return nil;
    }
}
#endif

@implementation ImageLoaderTransition

- (instancetype)init {
    self = [super init];
    if (self) {
        self.duration = 0.5;
    }
    return self;
}

@end

@implementation ImageLoaderTransition (Conveniences)

+ (ImageLoaderTransition *)fadeTransition {
    return [self fadeTransitionWithDuration:0.5];
}

+ (ImageLoaderTransition *)fadeTransitionWithDuration:(NSTimeInterval)duration {
    ImageLoaderTransition *transition = [ImageLoaderTransition new];
    transition.duration = duration;
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = ImageLoaderAnimationOptionTransitionCrossDissolve;
#endif
    return transition;
}

+ (ImageLoaderTransition *)flipFromLeftTransition {
    return [self flipFromLeftTransitionWithDuration:0.5];
}

+ (ImageLoaderTransition *)flipFromLeftTransitionWithDuration:(NSTimeInterval)duration {
    ImageLoaderTransition *transition = [ImageLoaderTransition new];
    transition.duration = duration;
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = ImageLoaderAnimationOptionTransitionFlipFromLeft;
#endif
    return transition;
}

+ (ImageLoaderTransition *)flipFromRightTransition {
    return [self flipFromRightTransitionWithDuration:0.5];
}

+ (ImageLoaderTransition *)flipFromRightTransitionWithDuration:(NSTimeInterval)duration {
    ImageLoaderTransition *transition = [ImageLoaderTransition new];
    transition.duration = duration;
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromRight | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = ImageLoaderAnimationOptionTransitionFlipFromRight;
#endif
    return transition;
}

+ (ImageLoaderTransition *)flipFromTopTransition {
    return [self flipFromTopTransitionWithDuration:0.5];
}

+ (ImageLoaderTransition *)flipFromTopTransitionWithDuration:(NSTimeInterval)duration {
    ImageLoaderTransition *transition = [ImageLoaderTransition new];
    transition.duration = duration;
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromTop | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = ImageLoaderAnimationOptionTransitionFlipFromTop;
#endif
    return transition;
}

+ (ImageLoaderTransition *)flipFromBottomTransition {
    return [self flipFromBottomTransitionWithDuration:0.5];
}

+ (ImageLoaderTransition *)flipFromBottomTransitionWithDuration:(NSTimeInterval)duration {
    ImageLoaderTransition *transition = [ImageLoaderTransition new];
    transition.duration = duration;
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromBottom | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = ImageLoaderAnimationOptionTransitionFlipFromBottom;
#endif
    return transition;
}

+ (ImageLoaderTransition *)curlUpTransition {
    return [self curlUpTransitionWithDuration:0.5];
}

+ (ImageLoaderTransition *)curlUpTransitionWithDuration:(NSTimeInterval)duration {
    ImageLoaderTransition *transition = [ImageLoaderTransition new];
    transition.duration = duration;
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlUp | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = ImageLoaderAnimationOptionTransitionCurlUp;
#endif
    return transition;
}

+ (ImageLoaderTransition *)curlDownTransition {
    return [self curlDownTransitionWithDuration:0.5];
}

+ (ImageLoaderTransition *)curlDownTransitionWithDuration:(NSTimeInterval)duration {
    ImageLoaderTransition *transition = [ImageLoaderTransition new];
    transition.duration = duration;
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlDown | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = ImageLoaderAnimationOptionTransitionCurlDown;
#endif
    transition.duration = duration;
    return transition;
}

@end

#endif
