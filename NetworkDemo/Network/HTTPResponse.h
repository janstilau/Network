//
//  HTTPResponse.h
//  MCMoego
//
//  Created by JustinLau on 2019/10/10.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HTTPResponse : NSObject

@property (nonatomic, strong, readonly) NSDictionary *dataDict;      //!< 返回的data数据, 即 response.payload[@"data"];
@property (nonatomic, assign) BOOL         isCache;        //!< 是否是缓存链接
@property (nonatomic, strong) NSURL        *requestURL;    //!< 请求URL
@property (nonatomic, strong) NSDictionary *requestParams; //!< 请求参数
@property (nonatomic, strong, nullable) id payload;        //!< 响应体（已解密）
@property (nonatomic, strong) NSString     *msg;
@property (nonatomic, strong) NSError      *error;
@property (nonatomic, strong) NSDate       *date;
@property (nonatomic, assign) NSInteger     errorCode;

@end

@interface UGJSONResponseSerializer : AFJSONResponseSerializer

@end

NS_ASSUME_NONNULL_END
