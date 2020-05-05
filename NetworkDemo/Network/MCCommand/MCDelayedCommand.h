//
//  MCDelayedCommand.h
//  MCMoego
//
//  Created by JustinLau on 2019/7/1.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^MCDelayedTask)(void);

@interface MCDelayedCommand : NSObject

@property (nonatomic, strong) NSString *identifier;

- (instancetype)initWithTask:(MCDelayedTask _Nullable)aTask NS_DESIGNATED_INITIALIZER;
- (void)execute;

@end

NS_ASSUME_NONNULL_END
