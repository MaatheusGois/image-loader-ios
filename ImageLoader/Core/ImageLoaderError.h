/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Jamie Pinkham
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderCompat.h"

/// An error domain represent ImageLoader loading system with custom codes
FOUNDATION_EXPORT NSErrorDomain const _Nonnull ImageLoaderErrorDomain;

/// The response instance for invalid download response (NSURLResponse *)
FOUNDATION_EXPORT NSErrorUserInfoKey const _Nonnull ImageLoaderErrorDownloadResponseKey;
/// The HTTP status code for invalid download response (NSNumber *)
FOUNDATION_EXPORT NSErrorUserInfoKey const _Nonnull ImageLoaderErrorDownloadStatusCodeKey;
/// The HTTP MIME content type for invalid download response (NSString *)
FOUNDATION_EXPORT NSErrorUserInfoKey const _Nonnull ImageLoaderErrorDownloadContentTypeKey;

/// ImageLoader error domain and codes
typedef NS_ERROR_ENUM(ImageLoaderErrorDomain, ImageLoaderError) {
    ImageLoaderErrorInvalidURL = 1000, // The URL is invalid, such as nil URL or corrupted URL
    ImageLoaderErrorBadImageData = 1001, // The image data can not be decoded to image, or the image data is empty
    ImageLoaderErrorCacheNotModified = 1002, // The remote location specify that the cached image is not modified, such as the HTTP response 304 code. It's useful for `ImageLoaderRefreshCached`
    ImageLoaderErrorBlackListed = 1003, // The URL is blacklisted because of unrecoverable failure marked by downloader (such as 404), you can use `.retryFailed` option to avoid this
    ImageLoaderErrorInvalidDownloadOperation = 2000, // The image download operation is invalid, such as nil operation or unexpected error occur when operation initialized
    ImageLoaderErrorInvalidDownloadStatusCode = 2001, // The image download response a invalid status code. You can check the status code in error's userInfo under `ImageLoaderErrorDownloadStatusCodeKey`
    ImageLoaderErrorCancelled = 2002, // The image loading operation is cancelled before finished, during either async disk cache query, or waiting before actual network request. For actual network request error, check `NSURLErrorDomain` error domain and code.
    ImageLoaderErrorInvalidDownloadResponse = 2003, // When using response modifier, the modified download response is nil and marked as failed.
    ImageLoaderErrorInvalidDownloadContentType = 2004, // The image download response a invalid content type. You can check the MIME content type in error's userInfo under `ImageLoaderErrorDownloadContentTypeKey`
};
