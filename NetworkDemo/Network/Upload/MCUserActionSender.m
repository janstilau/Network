//
//  MCDingTaskSender.m
//  MCMoego
//
//  Created by JustinLau on 2019/10/3.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import "MCUserActionSender.h"

@interface MCUserActionItem : NSObject
@property (nonatomic, strong) NSString *action;
@property (nonatomic, strong) NSDictionary *params;
@property (nonatomic, strong) MCUserActionItem *next;
@end
@implementation MCUserActionItem
@end

static MCUserActionItem *head_ = nil;
static MCUserActionItem *tail_ = nil;
static MCUserActionItem *sending_ = nil;

@implementation MCUserActionSender

+ (void)sendContent:(NSString *)content params:(NSDictionary *)params {
    MCUserActionItem *item = [[MCUserActionItem alloc] init];
    item.action = content;
    item.params = params;
    if (!head_) {
        head_ = item;
        tail_ = item;
    } else {
        tail_.next = item;
        tail_ = item;
    }
    [self startSendAction];
}

+ (void)startSendAction {
    if (!head_) { return; }
    if (sending_) { return; }
    sending_ = head_;
    [self requestToSend];
}

+ (void)requestToSend {
    NSMutableDictionary *paramsM = [NSMutableDictionary dictionaryWithCapacity:3];
    paramsM[@"action_name"] = safeStr(sending_.action);
    if (sending_.params) {
        paramsM[@"action_params"] = sending_.params;
    }
    if (_loginUser) {
        paramsM[@"user_mogecode"] = _loginUser.moegoCode;
    }
    NSDictionary *resultParams = @{
        @"content": [paramsM jsonStringEncoded]
    };
    DLOG(@"发送用户行为消息 %@", resultParams);
    [NetWork postRequestToUrl:[self sendUrl] params:resultParams complete:^(BOOL successed, HTTPResponse *response) {
        [self updateActionList];
    }];
}

+ (NSString *)sendUrl {
    return @"";
}

+ (void)updateActionList {
    head_ = sending_.next;
    sending_ = nil;
    [self startSendAction];
}

@end
