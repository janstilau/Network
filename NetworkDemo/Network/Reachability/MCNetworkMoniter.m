//
//  MCNetworkMoniter.m
//  MCMoego
//
//  Created by JustinLau on 2019/10/10.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import "MCNetworkMoniter.h"
#import "MCDomainManager.h"

@interface MCNetworkMoniter()

@property (nonatomic, strong) Reachability *reachability;
@property (nonatomic, strong) MCCommandQueue *cachedCommandQueue;
@property (nonatomic, strong) NSMutableArray<MCNetStatusChangeAction> *netChanggeCallbacks;

@end

@implementation MCNetworkMoniter

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _netChanggeCallbacks = [NSMutableArray arrayWithCapacity:10];
    _reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [_reachability startNotifier];
    
    _cachedCommandQueue = [[MCCommandQueue alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppDomainDidConfirmed:) name:MCDomainManagerInitDoneNotification object:nil];
}

- (void)addNetStatusChangeCallback:(MCNetStatusChangeAction)callBack {
    [_netChanggeCallbacks addObject:callBack];
}

- (void)addNetDomainConfirmedCallBack:(MCDelayedTask)callBack {
    MCDelayedCommand *delayedCommand = [[MCDelayedCommand alloc] initWithTask:callBack];
    [_cachedCommandQueue push:delayedCommand];
}

- (NetworkStatus)networkStatus {
    return [_reachability currentReachabilityStatus];
}

#pragma mark - Observer

- (void)reachabilityChanged:(NSNotification *)noti {
    NetworkStatus status = _reachability.currentReachabilityStatus;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *promptMap = @{
            @(NotReachable): @"Network Not Reachable",
            @(ReachableViaWWAN): @"Network Reachs To WWAN",
            @(ReachableViaWiFi): @"Network Reachs To WIFI"
        };
        DLOG(@"%@", promptMap[@(status)]);
        [_netChanggeCallbacks enumerateObjectsUsingBlock:^(MCNetStatusChangeAction aAction, NSUInteger idx, BOOL *stop) {
            aAction(status);
        }];
    });
}

- (void)handleAppDomainDidConfirmed:(NSNotification *)noti {
    [_cachedCommandQueue execute];
}

@end
