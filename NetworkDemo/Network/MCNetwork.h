//
//  MCNetwork.h
//  MCMoego
//
//  Created by Zhou Kang on 2017/10/11.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"
#import "MCNetSupporting.h"
#import "Reachability.h"
#import "HTTPResponse.h"
#import "MCNetSession.h"

#define NetWork            [MCNetwork defaultManager]
#define NetWorkJWTEnabled  ([[MCNetwork defaultManager] encryptEnable])

@interface MCNetwork : NSObject

@property(nonatomic, strong, readonly) AFHTTPSessionManager *sessionManager;
@property (nonatomic, assign, readonly) BOOL encryptEnable;

+ (instancetype)defaultManager;

- (NetworkStatus)networkStatus;

- (void)addNetStatusChangeCallback:(void(^)(NetworkStatus status))callback;

- (NSURLSessionDataTask *)getRequestToUrl:(NSString *)url
                                   params:(NSDictionary *)params
                                 complete:(HTTPTaskCompleteHandler)complete;
- (NSURLSessionDataTask *)postRequestToUrl:(NSString *)url
                                    params:(NSDictionary *)params
                                  complete:(HTTPTaskCompleteHandler)complete;
- (NSURLSessionDataTask *)postRequestToUrl:(NSString *)url
                                    params:(NSDictionary *)params
                              requestConfig:(void(^)(NSMutableURLRequest*))requestConfig
                                  complete:(HTTPTaskCompleteHandler)complete;
- (NSURLSessionDataTask *)putRequestToUrl:(NSString *)url
                                   params:(NSDictionary *)params
                                 complete:(HTTPTaskCompleteHandler)complete;
- (NSURLSessionDataTask *)deleteRequestToUrl:(NSString *)url
                                      params:(NSDictionary *)params
                                    complete:(HTTPTaskCompleteHandler)complete;
- (NSURLSessionDataTask *)getCacheToUrl:(NSString *)url
                                 params:(NSDictionary *)params
                               complete:(HTTPTaskCompleteHandler)complete;
- (void)localCacheToUrl:(NSString *)url
                 params:(NSDictionary *)params
               complete:(HTTPTaskCompleteHandler)complete;
- (NSURLSessionDownloadTask *)downloadWithUrl:(NSString *)url
               progress:(void(^)(CGFloat progress))progress
             completion:(void (^)(NSURL *savedPath, NSError *error))completion ;

/**
 * Encode params with jwt, h5 api request also use this encryption.
 */
+ (NSDictionary <NSString *, NSString *> *)encodeParamsWithJWT:(NSDictionary <NSString *, id> *)params isTestEnv:(BOOL)isTestEnv;

@end

// ------


// const string

UIKIT_EXTERN NSString *const MCNetworkMessageNotReachable; // 网络未连接
