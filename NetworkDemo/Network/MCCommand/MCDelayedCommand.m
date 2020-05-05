//
//  MCDelayedCommand.m
//  MCMoego
//
//  Created by JustinLau on 2019/7/1.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import "MCDelayedCommand.h"

@interface MCDelayedCommand()

@property (nonatomic, strong) MCDelayedTask task;

@end

@implementation MCDelayedCommand

- (instancetype)init {
    return [self initWithTask:nil];
}

- (instancetype)initWithTask:(MCDelayedTask)aTask {
    self = [super init];
    if (!aTask) { self = nil; }
    if (self) {
        static int taskIdCounter = 0;
        ++taskIdCounter;
        _identifier = [NSString stringWithFormat:@"%@", @(taskIdCounter)];
        _task = aTask;
    }
    return self;
}

- (void)execute {
    if (!_task) { return; }
    _task();
}

@end
