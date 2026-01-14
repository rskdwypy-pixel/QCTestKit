//
//  QCCrashSimulator.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCCrashSimulator.h"
#import "QCConstants.h"
#import <mach/mach.h>
#import <sys/sysctl.h>

@implementation QCCrashSimulator

+ (instancetype)sharedSimulator {
    static QCCrashSimulator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 启动时检查崩溃标志
        [self checkCrashFlag];
    }
    return self;
}

- (void)checkCrashFlag {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:QCCrashRecoveryKey]) {
        [defaults setBool:NO forKey:QCCrashRecoveryKey];
        NSLog(@"[QCTestKit] 检测到应用上次异常退出（可能是崩溃测试导致）");
    }
}

#pragma mark - Trigger Crash

- (void)triggerCrash:(QCCrashType)type {
    [self triggerCrash:type parameters:nil];
}

- (void)triggerCrash:(QCCrashType)type parameters:(NSDictionary *)params {
    // 设置恢复标记
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:QCCrashRecoveryKey];
    [[NSUserDefaults standardUserDefaults] setInteger:type forKey:QCLastCrashTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"[QCTestKit] 准备触发崩溃类型: %ld", (long)type);

    switch (type) {
        case QCCrashTypeAbort:
            [self triggerAbort];
            break;

        case QCCrashTypeExit:
            [self triggerExit];
            break;

        case QCCrashTypeNSException:
            [self triggerNSException];
            break;

        case QCCrashTypeUnrecognizedSelector:
            [self triggerUnrecognizedSelector];
            break;

        case QCCrashTypeNilPointer:
            [self triggerNilPointer];
            break;

        case QCCrashTypeMainThreadBlocking:
            [self triggerMainThreadBlocking];
            break;

        case QCCrashTypeUICatton:
            [self triggerUICatton];
            break;

        case QCCrashTypeMemoryLeak:
            [self triggerMemoryLeak];
            break;

        case QCCrashTypeHighCPU:
            [self triggerHighCPU];
            break;

        case QCCrashTypeWildPointer:
            [self triggerWildPointer];
            break;

        case QCCrashTypeArrayOutOfBounds:
            [self triggerArrayOutOfBounds];
            break;

        case QCCrashTypeMemoryOverflow:
            [self triggerMemoryOverflow];
            break;

        case QCCrashTypeDeadlock:
            [self triggerDeadlock];
            break;

        default:
            NSLog(@"[QCTestKit] 未知的崩溃类型");
            break;
    }
}

#pragma mark - Basic Crashes

- (void)triggerAbort {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 触发 abort()");
        abort();
    });
}

- (void)triggerExit {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 触发 exit(1)");
        exit(1);
    });
}

- (void)triggerNSException {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 触发 NSException");
        @throw [NSException exceptionWithName:@"QCTestKitCrash"
                                       reason:@"这是测试崩溃异常"
                                     userInfo:nil];
    });
}

- (void)triggerUnrecognizedSelector {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 触发 unrecognized selector");
        NSString *str = @"test";
        [str performSelector:@selector(thisMethodDoesNotExist)];
    });
}

- (void)triggerNilPointer {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 触发 nil pointer access");
        NSArray *arr = nil;
        [arr objectAtIndex:0];
    });
}

#pragma mark - Performance Issues

- (void)triggerMainThreadBlocking {
    NSLog(@"[QCTestKit] 触发主线程阻塞 (5秒)");
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSThread sleepForTimeInterval:5.0];
        NSLog(@"[QCTestKit] 主线程阻塞完成");
    });
}

- (void)triggerUICatton {
    NSLog(@"[QCTestKit] 触发UI卡顿（连续操作）");
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < 10; i++) {
            [NSThread sleepForTimeInterval:0.3];
        }
        NSLog(@"[QCTestKit] UI卡顿完成");
    });
}

- (void)triggerMemoryLeak {
    NSLog(@"[QCTestKit] 触发内存泄漏（分配10MB）");
    static NSMutableArray *leakedObjects = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        leakedObjects = [NSMutableArray array];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            for (int i = 0; i < 10; i++) {
                NSData *data = [NSData dataWithBytes:malloc(1024 * 1024) length:1024 * 1024];
                [leakedObjects addObject:data];
                NSLog(@"[QCTestKit] 已分配 %lu MB", (unsigned long)(leakedObjects.count));
                [NSThread sleepForTimeInterval:0.1];
            }
        }
    });
}

- (void)triggerHighCPU {
    NSLog(@"[QCTestKit] 触发高CPU占用（后台计算5秒）");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSDate *start = [NSDate date];
        while ([[NSDate date] timeIntervalSinceDate:start] < 5.0) {
            // 密集计算
            double result = 0;
            for (int i = 0; i < 100000; i++) {
                result += sqrt(i);
            }
        }
        NSLog(@"[QCTestKit] 高CPU占用完成");
    });
}

#pragma mark - Advanced Tests

- (void)triggerWildPointer {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 触发野指针");
        __unsafe_unretained NSString *weakStr = nil;
        @autoreleasepool {
            NSString *strongStr = @"test";
            weakStr = strongStr;
        }
        // 此时 weakStr 指向已释放的内存
        NSString *crash = weakStr;
        NSLog(@"野指针测试: %@", crash);
    });
}

- (void)triggerArrayOutOfBounds {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 触发数组越界");
        NSArray *arr = @[@"1", @"2", @"3"];
        [arr objectAtIndex:10];
    });
}

- (void)triggerMemoryOverflow {
    NSLog(@"[QCTestKit] 触发内存溢出警告（连续分配）");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableArray *chunks = [NSMutableArray array];
        for (int i = 0; i < 50; i++) {
            @autoreleasepool {
                NSData *chunk = [NSData dataWithBytes:malloc(5 * 1024 * 1024) length:5 * 1024 * 1024];
                [chunks addObject:chunk];
                NSLog(@"[QCTestKit] 已分配 %d * 5MB", i + 1);
                [NSThread sleepForTimeInterval:0.2];
            }
        }
    });
}

- (void)triggerDeadlock {
    NSLog(@"[QCTestKit] 触发死锁（3秒后超时）");
    dispatch_semaphore_t sem1 = dispatch_semaphore_create(0);
    dispatch_semaphore_t sem2 = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_semaphore_wait(sem1, DISPATCH_TIME_FOREVER);
        [NSThread sleepForTimeInterval:0.1];
        dispatch_semaphore_signal(sem2);
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_semaphore_wait(sem2, DISPATCH_TIME_FOREVER);
        [NSThread sleepForTimeInterval:0.1];
        dispatch_semaphore_signal(sem1);
    });

    // 3秒后超时
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[QCTestKit] 死锁测试超时（模拟）");
    });
}

#pragma mark - Crash Info

- (BOOL)hasPreviousCrash {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:QCCrashRecoveryKey];
}

- (NSString *)getPreviousCrashInfo {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger crashType = [defaults integerForKey:QCLastCrashTypeKey];

    NSString *typeString;
    switch (crashType) {
        case QCCrashTypeAbort:
            typeString = @"Abort崩溃";
            break;
        case QCCrashTypeExit:
            typeString = @"Exit退出";
            break;
        case QCCrashTypeNSException:
            typeString = @"NSException异常";
            break;
        default:
            typeString = [NSString stringWithFormat:@"类型 %ld", (long)crashType];
            break;
    }

    return [NSString stringWithFormat:@"上一次崩溃: %@", typeString];
}

#pragma mark - Performance Monitoring

- (CGFloat)currentMemoryUsage {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    task_info(mach_task_self(),
              TASK_BASIC_INFO,
              (task_info_t)&info,
              &size);
    return info.resident_size / 1024.0 / 1024.0; // MB
}

- (CGFloat)currentCPUUsage {
    // 简化的CPU监控实现 - 返回一个模拟值
    // 实际项目中可以使用 host_processor_info 等API
    static float cpuUsage = 5.0; // 默认5%

    // 模拟CPU波动
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 启动一个定时器来模拟CPU变化
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            while (YES) {
                [NSThread sleepForTimeInterval:2.0];
                // 模拟CPU在5-30%之间波动
                cpuUsage = 5.0 + (arc4random() % 25);
            }
        });
    });

    return cpuUsage;
}

@end
