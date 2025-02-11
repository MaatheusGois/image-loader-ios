/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCompat.h"

#if SD_MAC

#import "UIImage+Transform.h"

@interface NSBezierPath (SDRoundedCorners)

/**
 Convenience way to create a bezier path with the specify rounding corners on macOS. Same as the one on `UIBezierPath`.
 */
+ (nonnull instancetype)_bezierPathWithRoundedRect:(NSRect)rect byRoundingCorners:(SDRectCorner)corners cornerRadius:(CGFloat)cornerRadius;

@end

#endif
