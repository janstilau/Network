//
//  MCDingTaskSender.h
//  MCMoego
//
//  Created by JustinLau on 2019/10/3.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCUserActionSender : NSObject

+ (void)sendContent:(NSString *)content params:(NSDictionary *)params;

@end

NS_ASSUME_NONNULL_END
