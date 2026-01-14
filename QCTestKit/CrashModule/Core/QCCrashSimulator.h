//
//  QCCrashSimulator.h
//  QCTestKit
//
//  Created by Claude
//

#import <Foundation/Foundation.h>
#import "QCCrashTestItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface QCCrashSimulator : NSObject

+ (instancetype)sharedSimulator;

// 执行崩溃测试
- (void)triggerCrash:(QCCrashType)type;
- (void)triggerCrash:(QCCrashType)type parameters:(nullable NSDictionary *)params;

// 检查上一次崩溃
- (BOOL)hasPreviousCrash;
- (NSString *)getPreviousCrashInfo;

// 性能监控（用于非破坏性测试）
- (CGFloat)currentMemoryUsage;
- (CGFloat)currentCPUUsage;

@end

NS_ASSUME_NONNULL_END
