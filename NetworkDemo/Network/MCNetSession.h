//
//  MCRequestConfiguration.h
//  MCMoego
//
//  Created by JustinLau on 2019/10/10.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^HTTPTaskCompleteHandler)(BOOL successed, HTTPResponse *_Nullable response);

@interface MCNetSession : NSObject

@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, strong, readonly) NSString *method;
@property (nonatomic, strong, readonly) NSDictionary *params;
@property (nonatomic, strong, readonly) HTTPTaskCompleteHandler businessCompletion;
@property (nonatomic, strong) void(^requestConfig)(NSMutableURLRequest *request);
@property (nonatomic, assign) BOOL alreadLoadCache;

@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) id responseObject;
@property (nonatomic, strong) NSError *error;

- (instancetype)initWithUrl:(NSString *)url
                     method:(NSString *)method
                     params:(NSDictionary *)params
                 completion:(HTTPTaskCompleteHandler)completion;

- (NSURLRequest *)httpRequest;
- (NSURLRequest *)cacheRequest;
- (NSDictionary *)sendedParams;
- (NSDate *)sendedTime;

@end

NS_ASSUME_NONNULL_END
