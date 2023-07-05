/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Fabrice Aneche
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSData+ImageContentType.h"
#if SD_MAC
#import <CoreServices/CoreServices.h>
#else
#import <MobileCoreServices/MobileCoreServices.h>
#endif
#import "LoadImageIOAnimatedCoderInternal.h"

#define kSVGTagEnd @"</svg>"

@implementation NSData (ImageContentType)

+ (LoadImageFormat)sd_imageFormatForImageData:(nullable NSData *)data {
    if (!data) {
        return LoadImageFormatUndefined;
    }
    
    // File signatures table: http://www.garykessler.net/library/file_sigs.html
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return LoadImageFormatJPEG;
        case 0x89:
            return LoadImageFormatPNG;
        case 0x47:
            return LoadImageFormatGIF;
        case 0x49:
        case 0x4D:
            return LoadImageFormatTIFF;
        case 0x42:
            return LoadImageFormatBMP;
        case 0x52: {
            if (data.length >= 12) {
                //RIFF....WEBP
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
                if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                    return LoadImageFormatWebP;
                }
            }
            break;
        }
        case 0x00: {
            if (data.length >= 12) {
                //....ftypheic ....ftypheix ....ftyphevc ....ftyphevx
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(4, 8)] encoding:NSASCIIStringEncoding];
                if ([testString isEqualToString:@"ftypheic"]
                    || [testString isEqualToString:@"ftypheix"]
                    || [testString isEqualToString:@"ftyphevc"]
                    || [testString isEqualToString:@"ftyphevx"]) {
                    return LoadImageFormatHEIC;
                }
                //....ftypmif1 ....ftypmsf1
                if ([testString isEqualToString:@"ftypmif1"] || [testString isEqualToString:@"ftypmsf1"]) {
                    return LoadImageFormatHEIF;
                }
            }
            break;
        }
        case 0x25: {
            if (data.length >= 4) {
                //%PDF
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(1, 3)] encoding:NSASCIIStringEncoding];
                if ([testString isEqualToString:@"PDF"]) {
                    return LoadImageFormatPDF;
                }
            }
        }
        case 0x3C: {
            // Check end with SVG tag
            if ([data rangeOfData:[kSVGTagEnd dataUsingEncoding:NSUTF8StringEncoding] options:NSDataSearchBackwards range: NSMakeRange(data.length - MIN(100, data.length), MIN(100, data.length))].location != NSNotFound) {
                return LoadImageFormatSVG;
            }
        }
    }
    return LoadImageFormatUndefined;
}

+ (nonnull CFStringRef)sd_UTTypeFromImageFormat:(LoadImageFormat)format {
    CFStringRef UTType;
    switch (format) {
        case LoadImageFormatJPEG:
            UTType = kSDUTTypeJPEG;
            break;
        case LoadImageFormatPNG:
            UTType = kSDUTTypePNG;
            break;
        case LoadImageFormatGIF:
            UTType = kSDUTTypeGIF;
            break;
        case LoadImageFormatTIFF:
            UTType = kSDUTTypeTIFF;
            break;
        case LoadImageFormatWebP:
            UTType = kSDUTTypeWebP;
            break;
        case LoadImageFormatHEIC:
            UTType = kSDUTTypeHEIC;
            break;
        case LoadImageFormatHEIF:
            UTType = kSDUTTypeHEIF;
            break;
        case LoadImageFormatPDF:
            UTType = kSDUTTypePDF;
            break;
        case LoadImageFormatSVG:
            UTType = kSDUTTypeSVG;
            break;
        case LoadImageFormatBMP:
            UTType = kSDUTTypeBMP;
            break;
        case LoadImageFormatRAW:
            UTType = kSDUTTypeRAW;
            break;
        default:
            // default is kUTTypeImage abstract type
            UTType = kSDUTTypeImage;
            break;
    }
    return UTType;
}

+ (LoadImageFormat)sd_imageFormatFromUTType:(CFStringRef)uttype {
    if (!uttype) {
        return LoadImageFormatUndefined;
    }
    LoadImageFormat imageFormat;
    if (CFStringCompare(uttype, kSDUTTypeJPEG, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatJPEG;
    } else if (CFStringCompare(uttype, kSDUTTypePNG, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatPNG;
    } else if (CFStringCompare(uttype, kSDUTTypeGIF, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatGIF;
    } else if (CFStringCompare(uttype, kSDUTTypeTIFF, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatTIFF;
    } else if (CFStringCompare(uttype, kSDUTTypeWebP, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatWebP;
    } else if (CFStringCompare(uttype, kSDUTTypeHEIC, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatHEIC;
    } else if (CFStringCompare(uttype, kSDUTTypeHEIF, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatHEIF;
    } else if (CFStringCompare(uttype, kSDUTTypePDF, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatPDF;
    } else if (CFStringCompare(uttype, kSDUTTypeSVG, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatSVG;
    } else if (CFStringCompare(uttype, kSDUTTypeBMP, 0) == kCFCompareEqualTo) {
        imageFormat = LoadImageFormatBMP;
    } else if (UTTypeConformsTo(uttype, kSDUTTypeRAW)) {
        imageFormat = LoadImageFormatRAW;
    } else {
        imageFormat = LoadImageFormatUndefined;
    }
    return imageFormat;
}

@end
