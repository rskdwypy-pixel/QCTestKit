//
//  QCLogger.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCLogger.h"

@interface QCLogger ()

@property (nonatomic, strong) NSMutableArray<NSString *> *logs;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation QCLogger

+ (instancetype)sharedLogger {
    static QCLogger *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logs = [NSMutableArray array];
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

        // 输出到控制台
        [self log:QCLogLevelInfo format:@"QCTestKit Logger initialized"];
    }
    return self;
}

#pragma mark - Logging Methods

- (void)log:(QCLogLevel)level format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *levelStr = [self levelString:level];
    NSString *timestamp = [self.dateFormatter stringFromDate:[NSDate date]];
    NSString *logEntry = [NSString stringWithFormat:@"[%@] [%@] %@", timestamp, levelStr, message];

    // 存储日志（限制数量）
    @synchronized(self.logs) {
        [self.logs addObject:logEntry];
        if (self.logs.count > 1000) {
            [self.logs removeObjectsInRange:NSMakeRange(0, 100)];
        }
    }

    // 输出到控制台
    NSLog(@"[QCTestKit] %@", logEntry);
}

- (void)debug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:QCLogLevelDebug format:format arguments:args];
    va_end(args);
}

- (void)info:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:QCLogLevelInfo format:format arguments:args];
    va_end(args);
}

- (void)warning:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:QCLogLevelWarning format:format arguments:args];
    va_end(args);
}

- (void)error:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:QCLogLevelError format:format arguments:args];
    va_end(args);
}

- (void)log:(QCLogLevel)level format:(NSString *)format arguments:(va_list)args {
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    [self log:level format:@"%@", message];
}

#pragma mark - Helper Methods

- (NSString *)levelString:(QCLogLevel)level {
    switch (level) {
        case QCLogLevelDebug:
            return @"DEBUG";
        case QCLogLevelInfo:
            return @"INFO";
        case QCLogLevelWarning:
            return @"WARN";
        case QCLogLevelError:
            return @"ERROR";
        default:
            return @"UNKNOWN";
    }
}

#pragma mark - Log Management

- (NSArray<NSString *> *)getAllLogs {
    @synchronized(self.logs) {
        return [self.logs copy];
    }
}

- (void)clearLogs {
    @synchronized(self.logs) {
        [self.logs removeAllObjects];
    }
    [self info:@"Logs cleared"];
}

- (NSString *)exportLogs {
    NSArray *allLogs = [self getAllLogs];
    return [allLogs componentsJoinedByString:@"\n"];
}

@end
