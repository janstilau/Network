//
//  MCCommandQueue.h
//  MCMoego
//
//  Created by JustinLau on 2019/7/1.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCDelayedCommand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 This is not a undo-redo cmomand stack.
 Only in a tool Applicaiton, the undo-redo pattern should be used. So here we just want to cache tasks and invoke them in a particular timepoint.
 All task is a wrapper for block, as for block, you need pay attention to memory leak issue.
 */

@interface MCCommandQueue : NSObject

@property (nonatomic, assign, readonly) NSUInteger count;

- (void)push:(MCDelayedCommand *)aCommand; //!< cache task.
- (MCDelayedCommand *)pop; //!< pop the first command.
- (MCDelayedCommand *)popWithIdentifier:(NSString *)commandIdentifier; //< pop the first command with id info.
- (void)execute; //!< perform cached task and clear.
- (void)clear; //!< clear without perform tasks.

@end

NS_ASSUME_NONNULL_END
