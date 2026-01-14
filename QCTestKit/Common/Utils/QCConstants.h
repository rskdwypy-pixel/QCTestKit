//
//  QCConstants.h
//  QCTestKit
//
//  Created by Claude
//

#import <Foundation/Foundation.h>

// 应用通知名称
extern NSString * const QCDidCrashNotification;
extern NSString * const QCDidCompleteNetworkTestNotification;

// UserDefaults Keys
extern NSString * const QCCrashRecoveryKey;
extern NSString * const QCLastCrashTypeKey;
extern NSString * const QCWeakNetworkEnabledKey;

// 本地服务器配置
static NSString * const kQCLocalServerHost = @"localhost";
static const NSInteger kQCLocalServerPort = 8080;

// 网络测试超时时间
static const NSTimeInterval kQCNetworkTimeoutInterval = 30.0;
