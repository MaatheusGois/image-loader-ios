/*
* This file is part of the ImageLoader package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/


#import "ImageLoaderDownloaderResponseModifier.h"

@interface ImageLoaderDownloaderResponseModifier ()

@property (nonatomic, copy, nonnull) ImageLoaderDownloaderResponseModifierBlock block;

@end

@implementation ImageLoaderDownloaderResponseModifier

- (instancetype)initWithBlock:(ImageLoaderDownloaderResponseModifierBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)responseModifierWithBlock:(ImageLoaderDownloaderResponseModifierBlock)block {
    ImageLoaderDownloaderResponseModifier *responseModifier = [[ImageLoaderDownloaderResponseModifier alloc] initWithBlock:block];
    return responseModifier;
}

- (nullable NSURLResponse *)modifiedResponseWithResponse:(nonnull NSURLResponse *)response {
    if (!self.block) {
        return nil;
    }
    return self.block(response);
}

@end

@implementation ImageLoaderDownloaderResponseModifier (Conveniences)

- (instancetype)initWithStatusCode:(NSInteger)statusCode {
    return [self initWithStatusCode:statusCode version:nil headers:nil];
}

- (instancetype)initWithVersion:(NSString *)version {
    return [self initWithStatusCode:200 version:version headers:nil];
}

- (instancetype)initWithHeaders:(NSDictionary<NSString *,NSString *> *)headers {
    return [self initWithStatusCode:200 version:nil headers:headers];
}

- (instancetype)initWithStatusCode:(NSInteger)statusCode version:(NSString *)version headers:(NSDictionary<NSString *,NSString *> *)headers {
    version = version ? [version copy] : @"HTTP/1.1";
    headers = [headers copy];
    return [self initWithBlock:^NSURLResponse * _Nullable(NSURLResponse * _Nonnull response) {
        if (![response isKindOfClass:NSHTTPURLResponse.class]) {
            return response;
        }
        NSMutableDictionary *mutableHeaders = [((NSHTTPURLResponse *)response).allHeaderFields mutableCopy];
        for (NSString *header in headers) {
            NSString *value = headers[header];
            mutableHeaders[header] = value;
        }
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:response.URL statusCode:statusCode HTTPVersion:version headerFields:[mutableHeaders copy]];
        return httpResponse;
    }];
}

@end
