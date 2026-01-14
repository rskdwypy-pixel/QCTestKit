//
//  QCCrashTestItem.h
//  QCTestKit
//
//  Created by Claude
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QCCrashType) {
    // 基础崩溃
    QCCrashTypeAbort = 0,
    QCCrashTypeExit,
    QCCrashTypeNSException,
    QCCrashTypeUnrecognizedSelector,
    QCCrashTypeNilPointer,

    // 性能问题
    QCCrashTypeMainThreadBlocking,
    QCCrashTypeUICatton,
    QCCrashTypeMemoryLeak,
    QCCrashTypeHighCPU,

    // 专项测试
    QCCrashTypeWildPointer,
    QCCrashTypeArrayOutOfBounds,
    QCCrashTypeMemoryOverflow,
    QCCrashTypeDeadlock
};

@interface QCCrashTestItem : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) QCCrashType type;
@property (nonatomic, assign) BOOL isDestructive;  // 是否会立即崩溃
@property (nonatomic, assign) NSString *category;  // 分类

+ (instancetype)itemWithName:(NSString *)name
                      detail:(NSString *)detail
                        type:(QCCrashType)type
                isDestructive:(BOOL)isDestructive
                    category:(NSString *)category;

@end

NS_ASSUME_NONNULL_END
