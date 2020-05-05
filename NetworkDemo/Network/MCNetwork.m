//
//  MCNetwork.m
//  MCMoego
//
//  Created by Zhou Kang on 2017/10/11.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import "MCNetwork.h"
#import "MCEncryptor.h"
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "UIDevice+FCUUID.h"
#import "CoreLoginUser+MCExtension.h"
#import "MCJWT.h"
#import "MCCommandQueue.h"
#import "MCDomainManager.h"
#import <AdSupport/AdSupport.h>
#import "UIDevice+BTCommon.h"
#import <Bugly/Bugly.h>
#import "MCNetworkMoniter.h"

NSString *const MCNetworkMessageNotReachable = @"网络未连接 请检查网络后重试_(:з」∠)_";
NSString *const MCNetworkMessageTimedOut = @"网络不好哦 请检查网络后重试_(:з」∠)_";

@interface MCNetwork ()

@property (nonatomic, strong) MCNetworkMoniter *networkMoniter;

@end

@implementation MCNetwork

+ (instancetype)defaultManager {
    static dispatch_once_t pred = 0;
    __strong static id defaultMCNetwork = nil;
    dispatch_once( &pred, ^{
        defaultMCNetwork = [[self alloc] init];
    });
    return defaultMCNetwork;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupNetwork];
        [self loadEncryptSetting];
    }
    return self;
}

- (void)setupNetwork {
    UGJSONResponseSerializer *responseSerializer = [UGJSONResponseSerializer serializer];
    responseSerializer.acceptableContentTypes = nil;
    responseSerializer.removesKeysWithNullValues = NO;
    
    NSURL *baseURL = [NSURL URLWithString:APIDomain()];
    _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseURL];
    _sessionManager.responseSerializer = responseSerializer;
    
    NSURLCache *urlCache = [NSURLCache sharedURLCache];
    [urlCache setMemoryCapacity:50 * 1024 * 1024];
    [urlCache setDiskCapacity:200 * 1024 * 1024];
    [NSURLCache setSharedURLCache:urlCache];
    
    _networkMoniter = [[MCNetworkMoniter alloc] init];
}

- (void)loadEncryptSetting {
    NSNumber *encryptEnable = [userDefaults objectForKey:UserDefaultKey_Net_Encrypt];
    if (!encryptEnable) {
        encryptEnable = @(YES);
        [userDefaults setObject:encryptEnable forKey:UserDefaultKey_Net_Encrypt];
    }
    _encryptEnable = [encryptEnable boolValue];
}

- (void)addNetStatusChangeCallback:(void (^)(NetworkStatus))callback {
    [_networkMoniter addNetStatusChangeCallback:callback];
}

- (NetworkStatus)networkStatus {
    return _networkMoniter.networkStatus;
}

#pragma mark - HttpRequest

- (NSURLSessionDataTask *)putRequestToUrl:(NSString *)url
                                   params:(NSDictionary *)params
                                 complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"PUT"
                     useCache:NO
                       params:params
                     complete:complete];
}

- (NSURLSessionDataTask *)deleteRequestToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"DELETE"
                     useCache:NO
                       params:params
                     complete:complete];
}

- (NSURLSessionDataTask *)getRequestToUrl:(NSString *)url
                                   params:(NSDictionary *)params
                                 complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"GET"
                     useCache:NO
                       params:params
                     complete:complete];
}

- (NSURLSessionDataTask *)getCacheToUrl:(NSString *)url
                                 params:(NSDictionary *)params
                               complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"GET"
                     useCache:YES
                       params:params
                     complete:complete];
}

- (NSURLSessionDataTask *)postRequestToUrl:(NSString *)url
                                    params:(NSDictionary *)params
                                  complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"POST"
                     useCache:NO
                       params:params
                     complete:complete];
}

- (NSURLSessionDataTask *)postRequestToUrl:(NSString *)url
                                            params:(NSDictionary *)params
                                      requestConfig:(void(^)(NSMutableURLRequest*))requestConfig
                                          complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url method:@"POST" useCache:NO params:params requestConfig:requestConfig complete:complete];
}

- (NSURLSessionDataTask *)postCacheToUrl:(NSString *)url
                                  params:(NSDictionary *)params
                                complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"POST"
                     useCache:YES
                       params:params
                     complete:complete];
}

- (NSURLSessionDataTask *)requestToUrl:(NSString *)url
                                method:(NSString *)method
                              useCache:(BOOL)useCache
                                params:(NSDictionary *)params
                              complete:(HTTPTaskCompleteHandler)completeHandler {
    return [self requestToUrl:url method:method useCache:useCache params:params requestConfig:nil complete:completeHandler];
}

- (NSURLSessionDataTask *)requestToUrl:(NSString *)url
                                method:(NSString *)method
                              useCache:(BOOL)useCache
                                params:(NSDictionary *)params
                          requestConfig:(void(^)(NSMutableURLRequest*))requestConfig
                              complete:(HTTPTaskCompleteHandler)completeHandler {
    if (NetWork.networkStatus == NotReachable && !useCache) {
        [MCToast showMessage:MCNetworkMessageNotReachable];
        !completeHandler ?: completeHandler(false, nil);
        return nil;
    }
    
    static NSString *kDomianLoadUrl = nil;
    if (!kDomianLoadUrl) {
        kDomianLoadUrl = [[MCDomainManager shareInstance] domainLoadingUrl];
    }
    if (![[MCDomainManager shareInstance] alreadInited] &&
        ![kDomianLoadUrl isEqualToString: url]) {
        DLOG(@"%@ -- URL Loading is dealyed when domainManager is not inited", url);
        WEAK_SELF
        NSString *path = [url substringFromIndex:APIDomain().length];
        [_networkMoniter addNetDomainConfirmedCallBack:^{
            NSString *currentUrl = [NSString stringWithFormat:@"%@%@", APIDomain(), path];
            DLOG(@"%@ -- cached URL is loading. The original is %@", currentUrl, url);
            [weak_self requestToUrl:currentUrl method:method useCache:useCache params:params complete:completeHandler];
        }];
        return nil;
    }
    
    MCNetSession *session = [[MCNetSession alloc] initWithUrl:url
                                                       method:method
                                                       params:params
                                                   completion:completeHandler];
    session.requestConfig = requestConfig;
    return [self dataTaskWithSession:session useCache:useCache];
}

- (NSURLSessionDataTask *)dataTaskWithSession:(MCNetSession *)session useCache:(BOOL)useCache{
    NSURLSessionDataTask *dataTask = nil;
    void (^httpCompletion)(NSURLResponse *, id, NSError *) = ^(NSURLResponse *response, id responseObject, NSError *error) {
        session.response = response;
        session.responseObject = responseObject;
        session.error = error;
        HTTPResponse *mcResponse = [[HTTPResponse alloc] init];
        mcResponse.requestURL = [session httpRequest].URL;
        mcResponse.requestParams = [session sendedParams];
        mcResponse.error = error;
        [self logSessionInformation:session];
        if (error) {
            if (session.businessCompletion) { session.businessCompletion(NO, mcResponse); }
            [self handleHttpError:session];
        } else {
            [self logSessionDuration:session];
            [self parseRawResponseData:responseObject complete:^(NSDictionary *object) {
                mcResponse.payload = object;
                if (session.alreadLoadCache) { mcResponse.isCache = YES; }
                [self handleBusinessResponse:mcResponse session:session];
            }];
        }
    };
    if (useCache) {
        dataTask = [self cacheDataTaskWithSession:session httpCompletion:httpCompletion];
    } else {
        dataTask = [_sessionManager dataTaskWithRequest:[session httpRequest]
                                         uploadProgress:nil
                                       downloadProgress:nil
                                      completionHandler:httpCompletion];
    }
    [dataTask resume];
    return dataTask;
}

- (void)parseRawResponseData:(id)data complete:(void (^)(NSDictionary *object))complete {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *object = data;
        if ([data isKindOfClass:[NSData class]]) {
            object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
        }
        if ([data isKindOfClass:[NSString class]]) {
            object = [data object];
        }
        object = [object mc_cleanNull];
        dispatch_async(dispatch_get_main_queue(), ^{
            !complete ?: complete(object ?: data);
        });
    });
}

- (NSURLSessionDataTask *)cacheDataTaskWithSession:(MCNetSession*)session
                                 httpCompletion:(void (^)(NSURLResponse *response, id responseObject, NSError *error))httpCompletion {
    NSURLSessionDataTask *dataTask =
    [_sessionManager dataTaskWithRequest:[session httpRequest]
                          uploadProgress:nil
                        downloadProgress:nil
                       completionHandler:^(NSURLResponse *response, id netResponseObject, NSError *error) {
        if (error) {
            if (error.code == NSURLErrorNotConnectedToInternet ||
                error.code == NSURLErrorCannotConnectToHost) {
                NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:[session cacheRequest]];
                if (cachedResponse && [[cachedResponse data] length] > 0) {
                    NSURLResponse *response = cachedResponse.response;
                    session.alreadLoadCache = YES;
                    const id cacheResponseObject = cachedResponse.data;
                    httpCompletion(response, cacheResponseObject, nil);
                } else {
                    httpCompletion(nil, nil, error);
                }
            } else {
                httpCompletion(nil, netResponseObject, error);
            }
        } else {
            [self parseRawResponseData:netResponseObject complete:^(NSDictionary *object) {
                NSData *data = [[object ug_json] dataUsingEncoding:NSUTF8StringEncoding];
                NSCachedURLResponse *cachedURLResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data userInfo:nil storagePolicy:NSURLCacheStorageAllowed];
                [[NSURLCache sharedURLCache] storeCachedResponse:cachedURLResponse forRequest:[session cacheRequest]];
                httpCompletion(response, object, error);
            }];
        }
    }];
    return dataTask;
}

// 读取本地网络请求, 该过程没有网络交互.
- (void)localCacheToUrl:(NSString *)url
                 params:(NSDictionary *)params
               complete:(HTTPTaskCompleteHandler)businessCompletion {
    MCNetSession *localSession = [[MCNetSession alloc] initWithUrl:url method:@"GET" params:params completion:businessCompletion];
    HTTPResponse *mcResponse = [[HTTPResponse alloc] init];
    mcResponse.requestURL = [localSession cacheRequest].URL;
    mcResponse.requestParams = params;
    mcResponse.isCache = YES;
    NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:[localSession cacheRequest]];
    if (cachedResponse && [[cachedResponse data] length] > 0) {
        id cachedResObj = cachedResponse.data;
        if ([cachedResObj isKindOfClass:[NSData class]]) {
            cachedResObj = [NSJSONSerialization JSONObjectWithData:cachedResObj options:NSJSONReadingMutableLeaves error:nil];
        }
        if ([cachedResObj isKindOfClass:[NSString class]]) {
            cachedResObj = [cachedResObj object];
        }
        localSession.responseObject = cachedResObj;
        localSession.alreadLoadCache = YES;
        mcResponse.payload = cachedResObj;
        [self handleBusinessResponse:mcResponse session:localSession];
    } else {
        mcResponse.error = [NSError errorWithDomain:NSURLErrorDomain
                                           code:NSURLErrorResourceUnavailable
                                       userInfo:@{NSLocalizedDescriptionKey:@"缓存数据不存在"}];
        if (localSession.businessCompletion) { localSession.businessCompletion(NO, mcResponse); }
    }
}

#pragma mark - ResponseHandler

// Http 交互发生错误, 还未到业务层面的解析工作.
- (void)handleHttpError:(MCNetSession *)session {
    NSError *error = session.error;
    DLOG(@"%@ error :  %@", session.method, error);
    if (error.code == NSURLErrorCancelled) { return; }
    switch (error.code) {
        case kCFURLErrorTimedOut: {
            [MCToast showMessage:MCNetworkMessageTimedOut];
        } break;
        case kCFURLErrorNotConnectedToInternet: {
            [MCToast showMessage:MCNetworkMessageNotReachable];
        } break;
        default:
            if (!ENV_RELEASE) {
                [MCBannerAlertView showMessage:error.localizedDescription];
            }
            break;
    }
}

// 服务器 http 交互成功, 具体业务成功与否, 需要根据服务器的返回结果而定(例如, 权限不够, 服务器错误等等)
- (void)handleBusinessResponse:(HTTPResponse *)mcResponse session:(MCNetSession *)session{
    NSDictionary *responseObj = mcResponse.payload;
    BOOL isDataFormatError = ![responseObj isKindOfClass:[NSDictionary class]];
    if (isDataFormatError) {
        mcResponse.payload = nil;
        mcResponse.error = [NSError errorWithDomain:NSURLErrorDomain
                                           code:NSURLErrorCannotDecodeContentData
                                       userInfo:@{NSLocalizedDescriptionKey:@"返回的数据格式不正确"}];
        if (session.businessCompletion) { session.businessCompletion(NO, mcResponse); }
        return;
    }
    [self saveServerTime:mcResponse];
    
    BOOL success = [responseObj[@"success"] boolValue];
    NSDictionary *responseDataDict = mcResponse.dataDict;
    mcResponse.msg = responseDataDict[@"message"];
    if (success) {
        if (session.businessCompletion) { session.businessCompletion(YES, mcResponse); }
        [self reactBusinessSuccess:mcResponse];
    } else {
        int errorCode = [responseDataDict[@"code"] intValue];
        mcResponse.errorCode = errorCode;
        mcResponse.error = [NSError errorWithDomain:NSURLErrorDomain
                                           code:errorCode
                                       userInfo:@{NSLocalizedDescriptionKey:mcResponse.msg}];
        if (session.businessCompletion) { session.businessCompletion(NO, mcResponse); }
        [self reactBusinessError:mcResponse];
    }
}

- (void)saveServerTime:(HTTPResponse *)mcResponse {
    NSDictionary *responseObj = mcResponse.payload;
    if (responseObj[@"time_point"] && !mcResponse.isCache) {
        @try {
            CGFloat systime = [responseObj[@"time_point"] doubleValue];
            [NSDate saveServerDate:systime];
            mcResponse.date = [NSDate ug_dateWithTimestamp:systime];
        }
        @catch (NSException *exception) {}
    }
}

- (void)reactBusinessSuccess:(HTTPResponse *)response {
    if (response.isCache) { return; }
    [MCUserTaskManager showTaskAlertComplete:response];
}

- (void)reactBusinessError:(HTTPResponse *)response {
    NSInteger errorCode = response.errorCode;
    if (errorCode == 100007 || errorCode == 201020) { // 未传入token || 传入的token找不到人
        [MCLoginUserManager logoutWithHintTitle:@"" completion:nil];
    } else if (errorCode == 200021) { // token失效
        [_applicationContext.navigationController popToRootViewControllerAnimated:false];
        [_applicationContext.homeMainViewController setPageIndex:0];
        [MCLoginUserManager logoutWithHintTitle:@"账号已在其他设备登录" completion:nil];
    } else if (errorCode == 200069) { // 被封号
        [_applicationContext.navigationController popToRootViewControllerAnimated:false];
        [_applicationContext.homeMainViewController setPageIndex:0];
        [MCLoginUserManager logoutWithCompletion:nil];
    } else if (errorCode == 205000) {
        [_applicationContext.navigationController popToRootViewControllerAnimated:false];
        [_applicationContext.homeMainViewController setPageIndex:0];
        [MCLoginUserManager logoutWithHintTitle:@"账号已注销" completion:nil];
    }
    if (!ENV_RELEASE) {
        [MCBannerAlertView showMessage:response.msg];
    }
// Report biz net error to bugly for online debug
#ifndef DEBUG
    NSError *bizError = [NSError errorWithDomain:XcodeBundleID
                                            code:errorCode
                                        userInfo:@{ NSDetailedErrorsKey: safeStr(response.dataDict.modelDescription) }];
    [Bugly reportError:bizError];
#endif
}

#pragma mark - Log

- (void)logSessionInformation:(MCNetSession *)session{
    void (^logJWTParams)(NSString *jwtStr) = ^(NSString *jwtStr) {
        NSArray *strs = [jwtStr componentsSeparatedByString:@"."];
        if (strs.count == 3) {
            NSString *paramsStr = strs[1];
            paramsStr = [[paramsStr stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
                         stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
            DLOG(@"Base64Decoded Params: \n%@\n", [NSString stringWithBase64EncodedString:paramsStr]);
        }
    };
    DLOG(@"%@ request url:  %@", session.method, [[session httpRequest].URL.absoluteString ug_decode]);
    if ([session.method isEqualToString:@"GET"]) {
        NSString *getURLString = [session httpRequest].URL.absoluteString;
        NSString *paramsString = [getURLString componentsSeparatedByString:@"?"].lastObject;
        logJWTParams(paramsString);
    } else {
        DLOG(@"post params:  %@\n", [session sendedParams]);
        NSString *jwtStr = [session sendedParams][@"data"];
        logJWTParams(jwtStr);
    }
    DLOG(@"%@ responseObject:  %@", session.method, session.responseObject);
}

- (void)logSessionDuration:(MCNetSession *)session {
    if (!session) { return; }
    NSURL *url = [session httpRequest].URL;
    CGFloat beginTime = [[session sendedTime] timeIntervalSince1970];
    CGFloat endTime = [[NSDate date] timeIntervalSince1970];
    DLOG(@"接口: %@ 耗时：%.3f秒",url.ug_interface, endTime-beginTime);
}

#pragma mark - Download

- (NSURLSessionDownloadTask *)downloadWithUrl:(NSString *)url progress:(void(^)(CGFloat))progress completion:(void (^)(NSURL *, NSError *))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSURLSessionDownloadTask *task =
    [_sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        if (!progress) { return; }
        CGFloat p = downloadProgress.completedUnitCount*1.f / downloadProgress.totalUnitCount;
        p = (ceilf)(p*100) / 100.f;
        progress(p);
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSString *path = [NSCachePath() stringByAppendingPathComponent:[[response.URL.absoluteString md5String] stringByAppendingPathExtension:response.URL.pathExtension]];
        NSURL *url = [NSURL fileURLWithPath:path];
        return url;
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (!completion) { return; }
        completion(filePath, error);
    }];
    [task resume];
    return task;
}

+ (NSDictionary<NSString*,NSString*> *)encodeParamsWithJWT:(NSDictionary<NSString*,id> *)params isTestEnv:(BOOL)isTestEnv {
    return [MCJWT encodeParamsWithJWT:params isTestEnv:isTestEnv];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

