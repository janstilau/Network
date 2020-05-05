//
//  MCNetworkMoniter.h
//  MCMoego
//
//  Created by JustinLau on 2019/10/10.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"
#import "MCCommandQueue.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^MCNetStatusChangeAction)(NetworkStatus status);

@interface MCNetworkMoniter : NSObject

@property (nonatomic, assign) NetworkStatus networkStatus;

- (void)addNetStatusChangeCallback:(MCNetStatusChangeAction)callBack;
- (void)addNetDomainConfirmedCallBack:(MCDelayedTask)callBack;

@end

NS_ASSUME_NONNULL_END
