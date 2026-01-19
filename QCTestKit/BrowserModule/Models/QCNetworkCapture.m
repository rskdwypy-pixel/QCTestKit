//
//  QCNetworkCapture.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCNetworkCapture.h"

// UserDefaults keys
static NSString *const kQCNetworkSessionsKey = @"QCNetworkSessions";
static NSString *const kQCNetworkIsCapturingKey = @"QCNetworkIsCapturing";

@implementation QCNetworkPacket

- (instancetype)init {
    self = [super init];
    if (self) {
        _packetId = [[NSUUID UUID] UUIDString];
        _method = @"GET";
        _type = QCNetworkRequestTypeUnknown;
        _statusCode = 0;
        _requestHeaders = @{};
        _responseHeaders = @{};
        _startTime = [NSDate date];
        _fromCache = NO;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = self.packetId;
    dict[@"url"] = self.url ?: @"";
    dict[@"method"] = self.method;
    dict[@"type"] = @(self.type);
    dict[@"mimeType"] = self.mimeType ?: @"";

    dict[@"requestHeaders"] = self.requestHeaders ?: @{};
    dict[@"requestBody"] = self.requestBody ?: @"";
    dict[@"requestBodySize"] = self.requestBodySize ?: @0;

    dict[@"statusCode"] = @(self.statusCode);
    dict[@"statusText"] = self.statusText ?: @"";
    dict[@"responseHeaders"] = self.responseHeaders ?: @{};
    dict[@"responseBody"] = self.responseBody ?: @"";
    dict[@"responseBodySize"] = self.responseBodySize ?: @0;

    if (self.startTime) {
        static NSDateFormatter *formatter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        });
        dict[@"startTime"] = [formatter stringFromDate:self.startTime];
    }
    dict[@"duration"] = self.duration ?: @0;
    dict[@"dnsDuration"] = self.dnsDuration ?: @0;
    dict[@"tcpDuration"] = self.tcpDuration ?: @0;
    dict[@"sslDuration"] = self.sslDuration ?: @0;
    dict[@"ttfb"] = self.ttfb ?: @0;
    dict[@"downloadDuration"] = self.downloadDuration ?: @0;

    dict[@"redirectUrl"] = self.redirectUrl ?: @"";
    dict[@"fromCache"] = @(self.fromCache);
    dict[@"errorMessage"] = self.errorMessage ?: @"";

    return [dict copy];
}

@end

#pragma mark - QCNetworkOperation

@implementation QCNetworkOperation

- (instancetype)initWithType:(QCNetworkOperationType)type name:(NSString *)name url:(NSString *)url {
    self = [super init];
    if (self) {
        _operationId = [[NSUUID UUID] UUIDString];
        _type = type;
        _operationName = name ?: @"";
        _url = url ?: @"";
        _startTime = [NSDate date];
        _packetIds = [NSMutableArray array];
        _elementInfo = @"";
    }
    return self;
}

- (void)addPacketId:(NSString *)packetId {
    if (packetId && ![self.packetIds containsObject:packetId]) {
        [self.packetIds addObject:packetId];
    }
}

- (NSInteger)requestCount {
    return self.packetIds.count;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"operationId"] = self.operationId;
    dict[@"type"] = @(self.type);
    dict[@"operationName"] = self.operationName;
    dict[@"elementInfo"] = self.elementInfo ?: @"";
    dict[@"url"] = self.url;
    dict[@"startTime"] = [self formatDate:self.startTime];
    dict[@"packetIds"] = self.packetIds;
    return [dict copy];
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) return @"";
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });
    return [formatter stringFromDate:date];
}

@end

@implementation QCNetworkSession

- (instancetype)initWithMainUrl:(NSString *)mainUrl {
    self = [super init];
    if (self) {
        _sessionId = [[NSUUID UUID] UUIDString];
        _mainUrl = mainUrl;
        _pageTitle = @"";
        _startTime = [NSDate date];
        _packets = [NSMutableArray array];
        _operations = [NSMutableArray array];
    }
    return self;
}

- (void)addPacket:(QCNetworkPacket *)packet {
    if (packet) {
        [self.packets addObject:packet];
    }
}

- (NSInteger)totalRequests {
    return self.packets.count;
}

- (NSInteger)successCount {
    NSInteger count = 0;
    for (QCNetworkPacket *packet in self.packets) {
        if (packet.statusCode >= 200 && packet.statusCode < 400) {
            count++;
        }
    }
    return count;
}

- (NSInteger)failureCount {
    NSInteger count = 0;
    for (QCNetworkPacket *packet in self.packets) {
        if (packet.statusCode >= 400 || packet.errorMessage.length > 0) {
            count++;
        }
    }
    return count;
}

- (NSInteger)totalBytes {
    NSInteger bytes = 0;
    for (QCNetworkPacket *packet in self.packets) {
        bytes += [packet.responseBodySize integerValue];
    }
    return bytes;
}

- (NSNumber *)totalDuration {
    if (self.packets.count == 0) {
        return @0;
    }
    // 使用第一个请求的开始时间和最后一个请求的结束时间
    NSDate *firstStart = nil;
    NSDate *lastEnd = nil;
    for (QCNetworkPacket *packet in self.packets) {
        if (!firstStart || [packet.startTime compare:firstStart] == NSOrderedAscending) {
            firstStart = packet.startTime;
        }
        if (!lastEnd || [packet.endTime compare:lastEnd] == NSOrderedDescending) {
            lastEnd = packet.endTime;
        }
    }
    if (firstStart && lastEnd) {
        return @([lastEnd timeIntervalSinceDate:firstStart] * 1000);
    }
    return @0;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"sessionId"] = self.sessionId;
    dict[@"mainUrl"] = self.mainUrl;
    dict[@"pageTitle"] = self.pageTitle;
    dict[@"startTime"] = [self formatDate:self.startTime];
    dict[@"endTime"] = [self formatDate:self.endTime];
    dict[@"totalRequests"] = @(self.totalRequests);
    dict[@"successCount"] = @(self.successCount);
    dict[@"failureCount"] = @(self.failureCount);
    dict[@"totalBytes"] = @(self.totalBytes);
    dict[@"totalDuration"] = self.totalDuration ?: @0;

    NSMutableArray *packetsArray = [NSMutableArray array];
    for (QCNetworkPacket *packet in self.packets) {
        [packetsArray addObject:[packet toDictionary]];
    }
    dict[@"packets"] = packetsArray;

    // 序列化操作
    NSMutableArray *operationsArray = [NSMutableArray array];
    for (QCNetworkOperation *operation in self.operations) {
        [operationsArray addObject:[operation toDictionary]];
    }
    dict[@"operations"] = operationsArray;

    return [dict copy];
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) return @"";
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return [formatter stringFromDate:date];
}

@end

@interface QCNetworkCaptureManager ()
@property(nonatomic, strong, readwrite) NSMutableArray<QCNetworkSession *> *sessions;
@property(nonatomic, strong) QCNetworkSession *currentSession;
@property(nonatomic, strong) QCNetworkOperation *currentOperation;
@property(nonatomic, strong) NSMutableDictionary<NSString *, QCNetworkPacket *> *pendingPackets;
@end

@implementation QCNetworkCaptureManager

+ (instancetype)sharedManager {
    static QCNetworkCaptureManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[QCNetworkCaptureManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessions = [NSMutableArray array];
        _pendingPackets = [NSMutableDictionary dictionary];
        _isCapturing = YES;  // 默认开启抓包
        [self loadFromDisk];
    }
    return self;
}

- (QCNetworkSession *)createSessionWithUrl:(NSString *)url {
    if (!self.isCapturing) {
        return nil;
    }

    // 结束当前会话
    [self endCurrentSession];

    QCNetworkSession *session = [[QCNetworkSession alloc] initWithMainUrl:url];
    self.currentSession = session;
    [self.sessions insertObject:session atIndex:0];

    // 自动创建一个"页面加载"操作，用于捕获页面初始加载时的所有请求
    QCNetworkOperation *pageLoadOp = [[QCNetworkOperation alloc] initWithType:QCNetworkOperationTypePageLoad
                                                                             name:[NSString stringWithFormat:@"页面加载: %@", url]
                                                                              url:url];
    self.currentOperation = pageLoadOp;
    [session.operations addObject:pageLoadOp];

    NSLog(@"[QCTestKit] 🌐 创建抓包会话: %@", url);
    NSLog(@"[QCTestKit] 🎯 创建初始操作: %@", pageLoadOp.operationName);
    return session;
}

- (void)endCurrentSession {
    if (self.currentSession) {
        self.currentSession.endTime = [NSDate date];
        NSLog(@"[QCTestKit] ✅ 结束抓包会话: %@, 请求数: %ld",
              self.currentSession.mainUrl, (long)self.currentSession.totalRequests);
        [self saveToDisk];
        self.currentSession = nil;
    }
}

- (QCNetworkSession *)currentSession {
    return _currentSession;
}

- (QCNetworkPacket *)createPacketWithUrl:(NSString *)url method:(NSString *)method {
    if (!self.isCapturing || !self.currentSession) {
        NSLog(@"[QCTestKit] ⚠️ 不能创建抓包: capturing=%d, session=%@", self.isCapturing, self.currentSession != nil ? @"存在" : @"不存在");
        return nil;
    }

    QCNetworkPacket *packet = [[QCNetworkPacket alloc] init];
    packet.url = url;
    packet.method = method ?: @"GET";
    packet.startTime = [NSDate date];

    // 判断请求类型
    packet.type = [self classifyRequestType:url];

    self.pendingPackets[packet.packetId] = packet;
    [self.currentSession addPacket:packet];

    NSLog(@"[QCTestKit] 📤 创建抓包: %@ %@, ID: %@", packet.method, packet.url, packet.packetId);
    NSLog(@"[QCTestKit] 📊 当前操作: %@", self.currentOperation ? self.currentOperation.operationName : @"无");

    return packet;
}

- (void)updatePacket:(NSString *)packetId withResponse:(NSDictionary *)responseInfo {
    QCNetworkPacket *packet = self.pendingPackets[packetId];
    if (!packet) {
        return;
    }

    packet.endTime = [NSDate date];
    packet.duration = @([packet.endTime timeIntervalSinceDate:packet.startTime] * 1000);

    if (responseInfo[@"statusCode"]) {
        packet.statusCode = [responseInfo[@"statusCode"] integerValue];
    }
    if (responseInfo[@"statusText"]) {
        packet.statusText = responseInfo[@"statusText"];
    }
    if (responseInfo[@"headers"]) {
        packet.responseHeaders = responseInfo[@"headers"];
    }
    if (responseInfo[@"body"]) {
        NSString *body = responseInfo[@"body"];
        // 限制响应体大小
        if (body.length > 10000) {
            body = [body substringToIndex:10000];
        }
        packet.responseBody = body;
    }
    if (responseInfo[@"bodySize"]) {
        packet.responseBodySize = responseInfo[@"bodySize"];
    }
    if (responseInfo[@"mimeType"]) {
        packet.mimeType = responseInfo[@"mimeType"];
    }

    // 时间分解
    if (responseInfo[@"dns"]) packet.dnsDuration = responseInfo[@"dns"];
    if (responseInfo[@"tcp"]) packet.tcpDuration = responseInfo[@"tcp"];
    if (responseInfo[@"ssl"]) packet.sslDuration = responseInfo[@"ssl"];
    if (responseInfo[@"ttfb"]) packet.ttfb = responseInfo[@"ttfb"];
    if (responseInfo[@"download"]) packet.downloadDuration = responseInfo[@"download"];

    if (responseInfo[@"fromCache"]) {
        packet.fromCache = [responseInfo[@"fromCache"] boolValue];
    }

    NSLog(@"[QCTestKit] 📥 抓包响应: %@ %@ - %ld (%.0fms)",
          packet.method, packet.url, (long)packet.statusCode, [packet.duration doubleValue]);
}

- (void)updatePacket:(NSString *)packetId withError:(NSError *)error {
    QCNetworkPacket *packet = self.pendingPackets[packetId];
    if (!packet) {
        return;
    }

    packet.endTime = [NSDate date];
    packet.duration = @([packet.endTime timeIntervalSinceDate:packet.startTime] * 1000);
    packet.errorMessage = error.localizedDescription ?: @"Unknown error";

    NSLog(@"[QCTestKit] ❌ 抓包错误: %@ %@ - %@", packet.method, packet.url, packet.errorMessage);
}

- (QCNetworkRequestType)classifyRequestType:(NSString *)url {
    NSString *lowerUrl = [url lowercaseString];

    if ([lowerUrl containsString:@".js"] || [lowerUrl containsString:@"javascript"]) {
        return QCNetworkRequestTypeScript;
    }
    if ([lowerUrl containsString:@".css"]) {
        return QCNetworkRequestTypeStylesheet;
    }
    if ([lowerUrl containsString:@".png"] || [lowerUrl containsString:@".jpg"] ||
        [lowerUrl containsString:@".jpeg"] || [lowerUrl containsString:@".gif"] ||
        [lowerUrl containsString:@".webp"] || [lowerUrl containsString:@".svg"] ||
        [lowerUrl containsString:@".ico"]) {
        return QCNetworkRequestTypeImage;
    }
    if ([lowerUrl containsString:@".woff"] || [lowerUrl containsString:@".woff2"] ||
        [lowerUrl containsString:@".ttf"] || [lowerUrl containsString:@".eot"] ||
        [lowerUrl containsString:@".otf"]) {
        return QCNetworkRequestTypeFont;
    }
    if ([lowerUrl containsString:@".mp4"] || [lowerUrl containsString:@".webm"] ||
        [lowerUrl containsString:@".ogg"] || [lowerUrl containsString:@".mp3"]) {
        return QCNetworkRequestTypeMedia;
    }

    return QCNetworkRequestTypeOther;
}

- (void)clearAll {
    [self.sessions removeAllObjects];
    self.currentSession = nil;
    self.currentOperation = nil;
    [self.pendingPackets removeAllObjects];
    [self saveToDisk];
    NSLog(@"[QCTestKit] 🗑️ 清空所有抓包记录");
}

- (void)removeSession:(NSString *)sessionId {
    NSInteger index = -1;
    for (NSInteger i = 0; i < self.sessions.count; i++) {
        if ([self.sessions[i].sessionId isEqualToString:sessionId]) {
            index = i;
            break;
        }
    }
    if (index >= 0) {
        [self.sessions removeObjectAtIndex:index];
        [self saveToDisk];
    }
}

- (NSArray<QCNetworkSession *> *)getSessions {
    return [self.sessions copy];
}

#pragma mark - 操作管理

- (QCNetworkOperation *)createOperationWithType:(QCNetworkOperationType)type
                                            name:(NSString *)name
                                             url:(NSString *)url {
    if (!self.isCapturing || !self.currentSession) {
        return nil;
    }

    // 结束当前操作
    [self endCurrentOperation];

    QCNetworkOperation *operation = [[QCNetworkOperation alloc] initWithType:type name:name url:url];
    self.currentOperation = operation;
    [self.currentSession.operations addObject:operation];

    NSLog(@"[QCTestKit] 🎯 创建操作: %@", name);

    return operation;
}

- (void)associatePacket:(NSString *)packetId withOperation:(NSString *)operationId {
    if (!self.currentSession) return;

    for (QCNetworkOperation *operation in self.currentSession.operations) {
        if ([operation.operationId isEqualToString:operationId]) {
            [operation addPacketId:packetId];

            // 同时更新 packet 的 operationId
            for (QCNetworkPacket *packet in self.currentSession.packets) {
                if ([packet.packetId isEqualToString:packetId]) {
                    packet.operationId = operationId;
                    break;
                }
            }
            break;
        }
    }
}

- (void)endCurrentOperation {
    if (self.currentOperation) {
        NSLog(@"[QCTestKit] ✅ 结束操作: %@, 请求数: %ld",
              self.currentOperation.operationName, (long)self.currentOperation.requestCount);
        self.currentOperation = nil;
    }
}

// 获取当前操作
- (QCNetworkOperation *)currentOperation {
    return _currentOperation;
}

// 自动关联最近的请求到当前操作
- (void)associatePacketWithCurrentOperation:(NSString *)packetId {
    if (self.currentOperation) {
        [self associatePacket:packetId withOperation:self.currentOperation.operationId];
        NSLog(@"[QCTestKit] 🔗 关联请求 %@ 到操作: %@", packetId, self.currentOperation.operationName);
    } else {
        NSLog(@"[QCTestKit] ⚠️ 无当前操作，无法关联请求: %@", packetId);
    }
}

- (void)saveToDisk {
    if (!self.isCapturing) {
        return;
    }

    NSMutableArray *sessionsArray = [NSMutableArray array];
    for (QCNetworkSession *session in self.sessions) {
        [sessionsArray addObject:[session toDictionary]];
    }

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sessionsArray
                                                       options:0
                                                         error:&error];
    if (!error) {
        [[NSUserDefaults standardUserDefaults] setObject:jsonData forKey:kQCNetworkSessionsKey];
        [[NSUserDefaults standardUserDefaults] setBool:self.isCapturing forKey:kQCNetworkIsCapturingKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)loadFromDisk {
    NSData *jsonData = [[NSUserDefaults standardUserDefaults] objectForKey:kQCNetworkSessionsKey];
    if (jsonData) {
        NSError *error = nil;
        NSArray *sessionsArray = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                options:0
                                                                  error:&error];
        if (!error && sessionsArray.count > 0) {
            for (NSDictionary *sessionDict in sessionsArray) {
                QCNetworkSession *session = [self sessionFromDictionary:sessionDict];
                if (session) {
                    [self.sessions addObject:session];
                }
            }
            NSLog(@"[QCTestKit] 📖 加载抓包记录: %lu 个会话", (unsigned long)self.sessions.count);
        }
    }

    // 加载抓包开关状态
    self.isCapturing = [[NSUserDefaults standardUserDefaults] boolForKey:kQCNetworkIsCapturingKey];
}

- (QCNetworkSession *)sessionFromDictionary:(NSDictionary *)dict {
    if (!dict[@"sessionId"] || !dict[@"mainUrl"]) {
        return nil;
    }

    QCNetworkSession *session = [[QCNetworkSession alloc] initWithMainUrl:dict[@"mainUrl"]];
    session.sessionId = dict[@"sessionId"];
    session.pageTitle = dict[@"pageTitle"] ?: @"";

    // 恢复数据包
    NSArray *packetsArray = dict[@"packets"];
    for (NSDictionary *packetDict in packetsArray) {
        QCNetworkPacket *packet = [[QCNetworkPacket alloc] init];
        packet.packetId = packetDict[@"id"] ?: @"";
        packet.url = packetDict[@"url"] ?: @"";
        packet.method = packetDict[@"method"] ?: @"GET";
        packet.type = [packetDict[@"type"] integerValue];
        packet.mimeType = packetDict[@"mimeType"] ?: @"";
        packet.requestHeaders = packetDict[@"requestHeaders"] ?: @{};
        packet.requestBody = packetDict[@"requestBody"] ?: @"";
        packet.requestBodySize = packetDict[@"requestBodySize"] ?: @0;
        packet.statusCode = [packetDict[@"statusCode"] integerValue];
        packet.statusText = packetDict[@"statusText"] ?: @"";
        packet.responseHeaders = packetDict[@"responseHeaders"] ?: @{};
        packet.responseBody = packetDict[@"responseBody"] ?: @"";
        packet.responseBodySize = packetDict[@"responseBodySize"] ?: @0;
        packet.duration = packetDict[@"duration"] ?: @0;
        packet.dnsDuration = packetDict[@"dnsDuration"] ?: @0;
        packet.tcpDuration = packetDict[@"tcpDuration"] ?: @0;
        packet.sslDuration = packetDict[@"sslDuration"] ?: @0;
        packet.ttfb = packetDict[@"ttfb"] ?: @0;
        packet.downloadDuration = packetDict[@"downloadDuration"] ?: @0;
        packet.redirectUrl = packetDict[@"redirectUrl"] ?: @"";
        packet.fromCache = [packetDict[@"fromCache"] boolValue];
        packet.errorMessage = packetDict[@"errorMessage"] ?: @"";
        packet.operationId = packetDict[@"operationId"] ?: @"";

        [session addPacket:packet];
    }

    // 恢复操作
    NSArray *operationsArray = dict[@"operations"];
    if (operationsArray) {
        for (NSDictionary *opDict in operationsArray) {
            QCNetworkOperationType type = [opDict[@"type"] integerValue];
            QCNetworkOperation *operation = [[QCNetworkOperation alloc] initWithType:type
                                                                               name:opDict[@"operationName"]
                                                                                url:opDict[@"url"]];
            operation.operationId = opDict[@"operationId"];
            operation.elementInfo = opDict[@"elementInfo"] ?: @"";

            // 恢复关联的请求ID
            NSArray *packetIds = opDict[@"packetIds"];
            if (packetIds) {
                [operation.packetIds addObjectsFromArray:packetIds];
            }

            [session.operations addObject:operation];
        }
    }

    return session;
}

@end
