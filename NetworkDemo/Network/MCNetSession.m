//
//  MCRequestConfiguration.m
//  MCMoego
//
//  Created by JustinLau on 2019/10/10.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import "MCNetSession.h"
#import "UIDevice+FCUUID.h"
#import "UIDevice+Common.h"
#import "MCJWT.h"

@interface MCNetSession()

@property (nonatomic, strong, readwrite) NSString *url;
@property (nonatomic, strong, readwrite) NSString *method;
@property (nonatomic, strong, readwrite) NSDictionary *params;
@property (nonatomic, strong, readwrite) HTTPTaskCompleteHandler businessCompletion;

@property (nonatomic, strong) NSURLRequest *sendedRequest;
@property (nonatomic, strong) NSDictionary *sendedParams;
@property (nonatomic, strong) NSDate *sendedTime;

@end

@implementation MCNetSession

- (instancetype)initWithUrl:(NSString *)url
                     method:(NSString *)method
                     params:(NSDictionary *)params
                 completion:(HTTPTaskCompleteHandler) completion {
    if (isEmptyString(url)) {
        NSAssert(NO, @"Error:Url must not be nil string. %@", [NSThread callStackSymbols]);
        return nil;
    }
    self = [super init];
    if (self) {
        _url = [url copy];
        _method = [method copy];
        _params = [params copy];
        _businessCompletion = completion;
    }
    return self;
}

- (BOOL)needEncrypt {
    return NetWorkJWTEnabled;
}

#pragma mark - Request

- (NSString *)requestUrl {
    if (![self needEncrypt]) { return [_url stringByAppendingString:@"?__debug__=1"];}
    return _url;
}

// HttpRequest 中, 有着 timeStamp, 所以多次调用会造成值属性的变化, 所以进行了缓存.
- (NSURLRequest *)httpRequest {
    if (_sendedRequest) { return _sendedRequest; }
    NSDictionary *httpParams = [self httpRequestParams];
    NSURLRequest *result = [self requestWithParams:httpParams];
    _sendedRequest = result;
    _sendedParams = httpParams;
    _sendedTime = [NSDate date];
    return result;
}

// cacheRequest 多次调用, 应该返回具有相同值意义的对象.
- (NSURLRequest *)cacheRequest {
    if (![_method isEqualToString:@"GET"]) {
        NSAssert(NO, @"Error:Only get method can be cached. %@", [NSThread callStackSymbols]);
        return nil;
    }
    return [self requestWithParams:[self cacheRequestParams]];
}

- (NSURLRequest *)requestWithParams:(NSDictionary *)params {
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    // 为了兼容萌股后端PUT不能接收Body体中的参数, 所以手动拼到URL后
    NSString *requestUrl = [self requestUrl];
    if ([[_method uppercaseString] isEqualToString:@"PUT"]) {
        if (![self needEncrypt]) {
            requestUrl = [NSString stringWithFormat:@"%@&%@", _url, [params mc_sortedEncodedQueryStr]];
        } else {
            requestUrl = [NSString stringWithFormat:@"%@?%@", _url, [params mc_sortedEncodedQueryStr]];
        }
        params = nil;
    }
    NSMutableURLRequest *request = [serializer requestWithMethod:_method URLString:requestUrl parameters:params error:nil];
    [request setTimeoutInterval:20];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [self addDefaultHeaderFileds:request];
    if (_requestConfig) {
        _requestConfig(request);
    }
    return request;
}

- (void)addDefaultHeaderFileds:(NSMutableURLRequest *)requestM {
    NSArray *availableCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSDictionary* headers = [NSHTTPCookie requestHeaderFieldsWithCookies:availableCookies];
    [requestM setAllHTTPHeaderFields:headers];
    UIDevice *device = [UIDevice currentDevice];
    NSDictionary *headerParams = @{
        
    };
    [requestM setAllHTTPHeaderFields:headerParams];
}

- (NSDictionary *)cacheRequestParams {
    NSMutableDictionary *cachedDictM = [self unEncryptunCacheParams];
    [cachedDictM removeObjectForKey:@"timestamp"];
    return cachedDictM;
}

- (NSDictionary *)httpRequestParams {
    NSMutableDictionary *requestDictM = [self unEncryptunCacheParams];
    if (!NetWorkJWTEnabled) {
       return requestDictM;
    }
    return [self encryptedParams:requestDictM];
}

- (NSDictionary *)sendedParams {
    return _sendedParams;
}

- (NSDate *)sendedTime {
    return _sendedTime;
}

#pragma mark - Encrypt

- (NSMutableDictionary *)unEncryptunCacheParams {
    NSMutableDictionary *requestBody = [NSMutableDictionary dictionaryWithCapacity:20];
    [requestBody addEntriesFromDictionary:_params];
    return requestBody;
}

- (NSDictionary*)encryptedParams:(NSDictionary<NSString*,id> *)params {
    /**
    * JWT key should follow with URL. If URL start with test domain, use the testKey. vice versa.
    */
    BOOL isTestEnv = [_url containsString: DOMAIN_TEST];
    return [MCJWT encodeParamsWithJWT:params isTestEnv:isTestEnv];
}

@end
