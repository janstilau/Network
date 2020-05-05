//
//  MCCommandQueue.m
//  MCMoego
//
//  Created by JustinLau on 2019/7/1.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import "MCCommandQueue.h"

@interface MCCommandQueue()

@property (nonatomic, strong) NSMutableArray *commandCache;

@end

@implementation MCCommandQueue

- (instancetype)init {
    self = [super init];
    if (self) {
        _commandCache = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (NSUInteger)count {
    return _commandCache.count;
}

- (void)push:(MCDelayedCommand *)aCommand {
    if (!aCommand) { return; }
    if (![aCommand isKindOfClass:[MCDelayedCommand class]]) { return; }
    [_commandCache addObject:aCommand];
}

- (MCDelayedCommand *)pop {
    if (!_commandCache.count) { return nil; }
    MCDelayedCommand *result = [_commandCache firstObject];
    [_commandCache removeObjectAtIndex:0];
    return result;
}

- (MCDelayedCommand *)popWithIdentifier:(NSString *)commandIdentifier {
    if (!_commandCache.count) { return nil; }
    for (int i = 0; i < _commandCache.count; ++i) {
        MCDelayedCommand *aCommand = _commandCache[i];
        if ([aCommand.identifier isEqualToString:commandIdentifier]) {
            [_commandCache removeObjectAtIndex:i];
            return aCommand;
        }
    }
    return nil;
}

- (void)execute {
    NSArray *copiedCommands = [_commandCache copy];
    [_commandCache removeAllObjects];
    for (MCDelayedCommand *aCommand in copiedCommands) {
        [aCommand execute];
    }
}

- (void)clear {
    [_commandCache removeAllObjects];
}

@end
