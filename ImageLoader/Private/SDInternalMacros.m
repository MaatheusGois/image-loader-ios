/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDInternalMacros.h"

void _executeCleanupBlock (__strong _cleanupBlock_t *block) {
    (*block)();
}
