//
//  QCLocalHTTPServer.h
//  QCTestKit
//
//  Created by Claude
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 响应配置
@interface QCHTTPMockResponse : NSObject

@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy, nullable) NSData *body;
@property (nonatomic, assign) NSTimeInterval delay;  // 响应延迟(秒)

@end

// 本地HTTP服务器
@interface QCLocalHTTPServer : NSObject

+ (instancetype)sharedServer;

@property (nonatomic, assign, readonly) NSInteger port;
@property (nonatomic, assign, readonly) BOOL isRunning;

// 启动/停止服务器
- (void)startServerWithPort:(NSInteger)port
                 completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)stopServer;

// 注册模拟端点
- (void)registerEndpoint:(NSString *)endpoint response:(QCHTTPMockResponse *)response;
- (void)unregisterEndpoint:(NSString *)endpoint;

// 获取测试URL
- (NSURL *)testURLForEndpoint:(NSString *)endpoint;

// 快速注册预设场景
- (void)registerPresetScenarios;

@end

NS_ASSUME_NONNULL_END
