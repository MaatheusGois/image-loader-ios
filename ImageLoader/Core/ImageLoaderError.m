/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Jamie Pinkham
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderError.h"

NSErrorDomain const _Nonnull ImageLoaderErrorDomain = @"ImageLoaderErrorDomain";

NSErrorUserInfoKey const _Nonnull ImageLoaderErrorDownloadResponseKey = @"ImageLoaderErrorDownloadResponseKey";
NSErrorUserInfoKey const _Nonnull ImageLoaderErrorDownloadStatusCodeKey = @"ImageLoaderErrorDownloadStatusCodeKey";
NSErrorUserInfoKey const _Nonnull ImageLoaderErrorDownloadContentTypeKey = @"ImageLoaderErrorDownloadContentTypeKey";
