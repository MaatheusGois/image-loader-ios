/*
* This file is part of the ImageLoader package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "ImageLoaderDownloaderDecryptor.h"

@interface ImageLoaderDownloaderDecryptor ()

@property (nonatomic, copy, nonnull) ImageLoaderDownloaderDecryptorBlock block;

@end

@implementation ImageLoaderDownloaderDecryptor

- (instancetype)initWithBlock:(ImageLoaderDownloaderDecryptorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)decryptorWithBlock:(ImageLoaderDownloaderDecryptorBlock)block {
    ImageLoaderDownloaderDecryptor *decryptor = [[ImageLoaderDownloaderDecryptor alloc] initWithBlock:block];
    return decryptor;
}

- (nullable NSData *)decryptedDataWithData:(nonnull NSData *)data response:(nullable NSURLResponse *)response {
    if (!self.block) {
        return nil;
    }
    return self.block(data, response);
}

@end

@implementation ImageLoaderDownloaderDecryptor (Conveniences)

+ (ImageLoaderDownloaderDecryptor *)base64Decryptor {
    static ImageLoaderDownloaderDecryptor *decryptor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        decryptor = [ImageLoaderDownloaderDecryptor decryptorWithBlock:^NSData * _Nullable(NSData * _Nonnull data, NSURLResponse * _Nullable response) {
            NSData *modifiedData = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
            return modifiedData;
        }];
    });
    return decryptor;
}

@end
