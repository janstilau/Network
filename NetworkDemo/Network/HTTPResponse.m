//
//  HTTPResponse.m
//  MCMoego
//
//  Created by JustinLau on 2019/10/10.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import "HTTPResponse.h"

@implementation HTTPResponse

- (NSDictionary *)dataDict {
    if (![self.payload isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    id data = self.payload[@"data"];
    if ([data isKindOfClass:[NSArray class]]) {
        NSDictionary *newDataDict = @{ @"list": data };
        return newDataDict;
    }
    if (![data isKindOfClass:[NSDictionary class]]) {
        return [NSDictionary dictionary];
    }
    return data;
}

@end

@implementation UGJSONResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing _Nullable *)error {
    id responseObject = [super responseObjectForResponse:response data:data error:error];
    if (!responseObject && *error && data && [data length]) {
        responseObject = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return responseObject;
}

@end
