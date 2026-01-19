//
//  QCNetworkCapture.h
//  QCTestKit
//
//  Created by Claude
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 网络请求类型
typedef NS_ENUM(NSInteger, QCNetworkRequestType) {
    QCNetworkRequestTypeUnknown = 0,
    QCNetworkRequestTypeMainDocument,  // 主文档
    QCNetworkRequestTypeFetch,         // Fetch API
    QCNetworkRequestTypeXHR,           // XMLHttpRequest
    QCNetworkRequestTypeScript,        // 脚本
    QCNetworkRequestTypeStylesheet,    // 样式
    QCNetworkRequestTypeImage,         // 图片
    QCNetworkRequestTypeFont,          // 字体
    QCNetworkRequestTypeMedia,         // 媒体
    QCNetworkRequestTypeOther          // 其他
};

/// 单个网络抓包记录
@interface QCNetworkPacket : NSObject

@property(nonatomic, strong) NSString *packetId;           // 唯一标识
@property(nonatomic, strong) NSString *url;                // 请求URL
@property(nonatomic, strong) NSString *method;             // HTTP方法
@property(nonatomic, assign) QCNetworkRequestType type;   // 请求类型
@property(nonatomic, strong) NSString *mimeType;           // MIME类型
@property(nonatomic, strong) NSString *operationId;        // 关联的操作ID

// 请求信息
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *requestHeaders;
@property(nonatomic, strong) NSString *requestBody;        // 请求体（可能为空）
@property(nonatomic, strong) NSNumber *requestBodySize;   // 请求体大小

// 响应信息
@property(nonatomic, assign) NSInteger statusCode;        // 状态码
@property(nonatomic, strong) NSString *statusText;         // 状态文本
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *responseHeaders;
@property(nonatomic, strong) NSString *responseBody;       // 响应体（可能截断）
@property(nonatomic, strong) NSNumber *responseBodySize;   // 响应体大小

// 时间信息
@property(nonatomic, strong) NSDate *startTime;           // 开始时间
@property(nonatomic, strong) NSDate *endTime;             // 结束时间
@property(nonatomic, strong) NSNumber *duration;           // 耗时（毫秒）

// 时间分解（毫秒）
@property(nonatomic, strong) NSNumber *dnsDuration;        // DNS查询
@property(nonatomic, strong) NSNumber *tcpDuration;        // TCP连接
@property(nonatomic, strong) NSNumber *sslDuration;        // SSL握手
@property(nonatomic, strong) NSNumber *ttfb;               // 首字节时间
@property(nonatomic, strong) NSNumber *downloadDuration;   // 下载时间

// 其他
@property(nonatomic, strong) NSString *redirectUrl;        // 重定向URL
@property(nonatomic, assign) BOOL fromCache;               // 是否来自缓存
@property(nonatomic, strong) NSString *errorMessage;       // 错误信息

@end

/// 用户操作类型
typedef NS_ENUM(NSInteger, QCNetworkOperationType) {
    QCNetworkOperationTypeUnknown = 0,
    QCNetworkOperationTypeClick,         // 点击
    QCNetworkOperationTypeInput,         // 输入
    QCNetworkOperationTypeSubmit,        // 表单提交
    QCNetworkOperationTypeScroll,        // 滚动
    QCNetworkOperationTypeSearch,        // 搜索
    QCNetworkOperationTypeNavigation,    // 导航跳转
    QCNetworkOperationTypePageLoad       // 页面加载
};

/// 用户操作记录
@interface QCNetworkOperation : NSObject

@property(nonatomic, strong) NSString *operationId;       // 操作唯一标识
@property(nonatomic, assign) QCNetworkOperationType type; // 操作类型
@property(nonatomic, strong) NSString *operationName;     // 操作名称/描述
@property(nonatomic, strong) NSString *elementInfo;       // 元素信息（标签、类名等）
@property(nonatomic, strong) NSString *url;               // 操作时页面URL
@property(nonatomic, strong) NSDate *startTime;           // 开始时间
@property(nonatomic, strong) NSMutableArray<NSString *> *packetIds;  // 关联的请求ID列表

- (instancetype)initWithType:(QCNetworkOperationType)type name:(NSString *)name url:(NSString *)url;
- (void)addPacketId:(NSString *)packetId;
- (NSInteger)requestCount;  // 关联的请求数
- (NSDictionary *)toDictionary;

@end

/// 网络会话（按主URL分组）
@interface QCNetworkSession : NSObject

@property(nonatomic, strong) NSString *sessionId;          // 会话ID
@property(nonatomic, strong) NSString *mainUrl;            // 主URL
@property(nonatomic, strong) NSString *pageTitle;          // 页面标题
@property(nonatomic, strong) NSDate *startTime;            // 开始时间
@property(nonatomic, strong) NSDate *endTime;              // 结束时间
@property(nonatomic, strong) NSMutableArray<QCNetworkPacket *> *packets;  // 抓包记录
@property(nonatomic, strong) NSMutableArray<QCNetworkOperation *> *operations;  // 操作记录

// 统计信息
@property(nonatomic, readonly) NSInteger totalRequests;    // 总请求数
@property(nonatomic, readonly) NSInteger successCount;     // 成功数
@property(nonatomic, readonly) NSInteger failureCount;     // 失败数
@property(nonatomic, readonly) NSInteger totalBytes;       // 总字节数
@property(nonatomic, readonly) NSNumber *totalDuration;    // 总耗时

- (instancetype)initWithMainUrl:(NSString *)mainUrl;
- (void)addPacket:(QCNetworkPacket *)packet;
- (NSDictionary *)toDictionary;  // 序列化

@end

/// 网络抓包管理器
@interface QCNetworkCaptureManager : NSObject

@property(nonatomic, strong, readonly) NSMutableArray<QCNetworkSession *> *sessions;
@property(nonatomic, assign) BOOL isCapturing;  // 是否开启抓包

+ (instancetype)sharedManager;

// 会话管理
- (QCNetworkSession *)createSessionWithUrl:(NSString *)url;
- (void)endCurrentSession;
- (QCNetworkSession *)currentSession;

// 抓包记录
- (QCNetworkPacket *)createPacketWithUrl:(NSString *)url method:(NSString *)method;
- (void)updatePacket:(NSString *)packetId withResponse:(NSDictionary *)responseInfo;
- (void)updatePacket:(NSString *)packetId withError:(NSError *)error;

// 数据管理
- (void)clearAll;
- (void)removeSession:(NSString *)sessionId;
- (NSArray<QCNetworkSession *> *)getSessions;

// 操作管理
- (QCNetworkOperation *)createOperationWithType:(QCNetworkOperationType)type
                                            name:(NSString *)name
                                             url:(NSString *)url;
- (void)associatePacket:(NSString *)packetId withOperation:(NSString *)operationId;
- (void)endCurrentOperation;
- (QCNetworkOperation *)currentOperation;  // 当前操作
- (void)associatePacketWithCurrentOperation:(NSString *)packetId;  // 自动关联到当前操作

// 持久化
- (void)saveToDisk;
- (void)loadFromDisk;

@end

NS_ASSUME_NONNULL_END
