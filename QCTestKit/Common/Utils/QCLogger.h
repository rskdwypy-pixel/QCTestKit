//
//  QCLogger.h
//  QCTestKit
//
//  Created by Claude
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QCLogLevel) {
    QCLogLevelDebug = 0,
    QCLogLevelInfo,
    QCLogLevelWarning,
    QCLogLevelError
};

@interface QCLogger : NSObject

+ (instancetype)sharedLogger;

// 日志记录
- (void)log:(QCLogLevel)level format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

- (void)debug:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)info:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)warning:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)error:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

// 获取所有日志
- (NSArray<NSString *> *)getAllLogs;

// 清除日志
- (void)clearLogs;

// 导出日志
- (NSString *)exportLogs;

@end

NS_ASSUME_NONNULL_END
