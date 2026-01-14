//
//  QCLocalHTTPServer.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCLocalHTTPServer.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@implementation QCHTTPMockResponse

- (instancetype)initWithStatusCode:(NSInteger)statusCode
                              body:(NSData * _Nullable)body {
    self = [super init];
    if (self) {
        _statusCode = statusCode;
        _body = body;
        _headers = @{@"Content-Type": @"application/json"};
        _delay = 0;
    }
    return self;
}

+ (instancetype)responseWithStatusCode:(NSInteger)statusCode body:(NSData * _Nullable)body {
    return [[self alloc] initWithStatusCode:statusCode body:body];
}

+ (instancetype)responseWithStatusCode:(NSInteger)statusCode
                             jsonString:(NSString *)jsonString {
    NSData *body = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    return [[self alloc] initWithStatusCode:statusCode body:body];
}

@end

@interface QCLocalHTTPServer () <NSNetServiceDelegate>

@property (nonatomic, assign) NSInteger serverPort;
@property (nonatomic, strong) NSFileHandle *listeningHandle;
@property (nonatomic, strong) NSNetService *netService;
@property (nonatomic, strong) NSMutableDictionary<NSString *, QCHTTPMockResponse *> *endpoints;

@property (nonatomic, strong) dispatch_queue_t serverQueue;
@property (nonatomic, strong) NSMutableArray<NSFileHandle *> *activeConnections;

@end

@implementation QCLocalHTTPServer

+ (instancetype)sharedServer {
    static QCLocalHTTPServer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _serverPort = 8080;
        _endpoints = [NSMutableDictionary dictionary];
        _activeConnections = [NSMutableArray array];
        _serverQueue = dispatch_queue_create("com.qctestkit.httpserver", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSInteger)port {
    return _serverPort;
}

- (BOOL)isRunning {
    return self.listeningHandle != nil;
}

#pragma mark - Start/Stop Server

- (void)startServerWithPort:(NSInteger)port completion:(void(^)(BOOL success, NSError *error))completion {
    if (self.isRunning) {
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"QCLocalHTTPServer"
                                              code:1
                                          userInfo:@{NSLocalizedDescriptionKey: @"服务器已在运行中"}]);
        }
        return;
    }

    _serverPort = port;

    dispatch_async(self.serverQueue, ^{
        NSError *error = nil;
        BOOL success = [self startListeningOnPort:port error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self registerPresetScenarios];
                NSLog(@"[QCTestKit] 本地HTTP服务器已启动，端口: %ld", (long)port);
            }
            if (completion) {
                completion(success, error);
            }
        });
    });
}

- (void)stopServer {
    if (!self.isRunning) {
        return;
    }

    dispatch_async(self.serverQueue, ^{
        // 关闭所有活动连接
        for (NSFileHandle *handle in self.activeConnections) {
            [handle closeFile];
        }
        [self.activeConnections removeAllObjects];

        // 关闭监听socket
        [self.listeningHandle closeFile];
        self.listeningHandle = nil;

        // 停止NetService
        [self.netService stop];
        self.netService = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"[QCTestKit] 本地HTTP服务器已停止");
        });
    });
}

#pragma mark - Socket Setup

- (BOOL)startListeningOnPort:(NSInteger)port error:(NSError **)error {
    // 创建socket
    int listenSocket = socket(AF_INET, SOCK_STREAM, 0);
    if (listenSocket == -1) {
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        return NO;
    }

    // 设置socket选项
    int yes = 1;
    setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));

    // 绑定端口
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(listenSocket, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
        close(listenSocket);
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        return NO;
    }

    // 开始监听
    if (listen(listenSocket, 5) == -1) {
        close(listenSocket);
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        return NO;
    }

    // 创建文件handle
    self.listeningHandle = [[NSFileHandle alloc] initWithFileDescriptor:listenSocket closeOnDealloc:YES];

    // 接受连接通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewConnection:)
                                                 name:NSFileHandleConnectionAcceptedNotification
                                               object:nil];

    [self.listeningHandle acceptConnectionInBackgroundAndNotify];

    return YES;
}

- (void)handleNewConnection:(NSNotification *)notification {
    NSFileHandle *newConnection = notification.userInfo[NSFileHandleNotificationFileHandleItem];

    if (newConnection) {
        @synchronized(self.activeConnections) {
            [self.activeConnections addObject:newConnection];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleConnectionData:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:newConnection];

        [newConnection waitForDataInBackgroundAndNotify];
    }

    // 继续接受新连接
    [self.listeningHandle acceptConnectionInBackgroundAndNotify];
}

- (void)handleConnectionData:(NSNotification *)notification {
    NSFileHandle *connection = notification.object;

    NSData *data = [connection availableData];
    if (data.length == 0) {
        [self closeConnection:connection];
        return;
    }

    // 解析HTTP请求
    NSString *requestString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [requestString componentsSeparatedByString:@"\r\n"];

    if (lines.count > 0) {
        NSString *requestLine = lines[0];
        NSArray *components = [requestLine componentsSeparatedByString:@" "];

        if (components.count >= 2) {
            NSString *method = components[0];
            NSString *path = components[1];

            // 处理请求
            [self handleRequest:method path:path connection:connection];
            return;
        }
    }

    // 返回400错误
    [self sendResponse:connection
            statusCode:400
                  body:[@"Bad Request" dataUsingEncoding:NSUTF8StringEncoding]];

    [self closeConnection:connection];
}

- (void)handleRequest:(NSString *)method path:(NSString *)path connection:(NSFileHandle *)connection {
    // 查找对应的endpoint
    QCHTTPMockResponse *response = self.endpoints[path];

    if (!response) {
        // 尝试匹配路径模式
        for (NSString *endpoint in self.endpoints.allKeys) {
            if ([path hasPrefix:endpoint]) {
                response = self.endpoints[endpoint];
                break;
            }
        }
    }

    if (response) {
        // 如果有延迟，先等待
        if (response.delay > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(response.delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self sendMockResponse:response toConnection:connection];
            });
        } else {
            [self sendMockResponse:response toConnection:connection];
        }
    } else {
        // 返回404
        NSString *notFoundBody = [NSString stringWithFormat:@"{\"error\": \"Not Found\", \"path\": \"%@\"}", path];
        [self sendResponse:connection
                statusCode:404
                      body:[notFoundBody dataUsingEncoding:NSUTF8StringEncoding]];
    }

    [self closeConnection:connection];
}

- (void)sendMockResponse:(QCHTTPMockResponse *)response toConnection:(NSFileHandle *)connection {
    [self sendResponse:connection
            statusCode:response.statusCode
                  body:response.body
                headers:response.headers];
}

- (void)sendResponse:(NSFileHandle *)connection
          statusCode:(NSInteger)statusCode
                body:(NSData *)body {
    [self sendResponse:connection statusCode:statusCode body:body headers:nil];
}

- (void)sendResponse:(NSFileHandle *)connection
          statusCode:(NSInteger)statusCode
                body:(NSData *)body
              headers:(NSDictionary *)headers {
    NSMutableString *headerString = [NSMutableString string];

    // 状态行
    NSString *statusText = @"OK";
    switch (statusCode) {
        case 200: statusText = @"OK"; break;
        case 201: statusText = @"Created"; break;
        case 204: statusText = @"No Content"; break;
        case 301: statusText = @"Moved Permanently"; break;
        case 302: statusText = @"Found"; break;
        case 304: statusText = @"Not Modified"; break;
        case 307: statusText = @"Temporary Redirect"; break;
        case 308: statusText = @"Permanent Redirect"; break;
        case 400: statusText = @"Bad Request"; break;
        case 401: statusText = @"Unauthorized"; break;
        case 403: statusText = @"Forbidden"; break;
        case 404: statusText = @"Not Found"; break;
        case 429: statusText = @"Too Many Requests"; break;
        case 500: statusText = @"Internal Server Error"; break;
        case 502: statusText = @"Bad Gateway"; break;
        case 503: statusText = @"Service Unavailable"; break;
        case 504: statusText = @"Gateway Timeout"; break;
        default: statusText = [NSString stringWithFormat:@"Status %ld", (long)statusCode]; break;
    }

    [headerString appendFormat:@"HTTP/1.1 %ld %@\r\n", (long)statusCode, statusText];

    // 默认headers
    NSMutableDictionary *allHeaders = [NSMutableDictionary dictionaryWithDictionary:@{
        @"Server": @"QCTestKit/1.0",
        @"Connection": @"close",
        @"Content-Length": body ? [NSString stringWithFormat:@"%lu", (unsigned long)body.length] : @"0"
    }];

    if (headers) {
        [allHeaders addEntriesFromDictionary:headers];
    }

    for (NSString *key in allHeaders) {
        [headerString appendFormat:@"%@: %@\r\n", key, allHeaders[key]];
    }

    [headerString appendString:@"\r\n"];

    NSMutableData *responseData = [NSMutableData data];
    [responseData appendData:[headerString dataUsingEncoding:NSUTF8StringEncoding]];
    if (body) {
        [responseData appendData:body];
    }

    [connection writeData:responseData];
}

- (void)closeConnection:(NSFileHandle *)connection {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:connection];
    [connection closeFile];

    @synchronized(self.activeConnections) {
        [self.activeConnections removeObject:connection];
    }
}

#pragma mark - Endpoint Management

- (void)registerEndpoint:(NSString *)endpoint response:(QCHTTPMockResponse *)response {
    if (!endpoint || !response) {
        return;
    }

    // 确保endpoint以/开头
    if (![endpoint hasPrefix:@"/"]) {
        endpoint = [NSString stringWithFormat:@"/%@", endpoint];
    }

    self.endpoints[endpoint] = response;
    NSLog(@"[QCTestKit] 注册端点: %@ -> 状态码: %ld", endpoint, (long)response.statusCode);
}

- (void)unregisterEndpoint:(NSString *)endpoint {
    if ([endpoint hasPrefix:@"/"]) {
        [self.endpoints removeObjectForKey:endpoint];
    } else {
        [self.endpoints removeObjectForKey:[NSString stringWithFormat:@"/%@", endpoint]];
    }
}

- (NSURL *)testURLForEndpoint:(NSString *)endpoint {
    if (![endpoint hasPrefix:@"/"]) {
        endpoint = [NSString stringWithFormat:@"/%@", endpoint];
    }
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%ld%@", (long)self.port, endpoint]];
}

#pragma mark - Preset Scenarios

- (void)registerPresetScenarios {
    // 2xx 成功响应
    [self registerEndpoint:@"/test/200"
                 response:[QCHTTPMockResponse responseWithStatusCode:200
                                                          jsonString:@"{\"status\": \"success\", \"code\": 200, \"message\": \"OK\"}"]];

    [self registerEndpoint:@"/test/201"
                 response:[QCHTTPMockResponse responseWithStatusCode:201
                                                          jsonString:@"{\"status\": \"created\", \"code\": 201, \"message\": \"Resource Created\"}"]];

    [self registerEndpoint:@"/test/204"
                 response:[QCHTTPMockResponse responseWithStatusCode:204 body:nil]];

    // 3xx 重定向
    {
        QCHTTPMockResponse *response = [QCHTTPMockResponse responseWithStatusCode:301
                                                                     jsonString:@"{\"redirect\": \"/target\", \"code\": 301}"];
        NSMutableDictionary *mutableHeaders = [response.headers mutableCopy];
        mutableHeaders[@"Location"] = @"/target";
        response.headers = mutableHeaders;
        [self registerEndpoint:@"/test/301" response:response];
    }

    {
        QCHTTPMockResponse *response = [QCHTTPMockResponse responseWithStatusCode:302
                                                                     jsonString:@"{\"redirect\": \"/target\", \"code\": 302}"];
        NSMutableDictionary *mutableHeaders = [response.headers mutableCopy];
        mutableHeaders[@"Location"] = @"/target";
        response.headers = mutableHeaders;
        [self registerEndpoint:@"/test/302" response:response];
    }

    [self registerEndpoint:@"/test/304"
                 response:[QCHTTPMockResponse responseWithStatusCode:304 body:nil]];

    {
        QCHTTPMockResponse *response = [QCHTTPMockResponse responseWithStatusCode:307
                                                                     jsonString:@"{\"redirect\": \"/target\", \"code\": 307}"];
        NSMutableDictionary *mutableHeaders = [response.headers mutableCopy];
        mutableHeaders[@"Location"] = @"/target";
        response.headers = mutableHeaders;
        [self registerEndpoint:@"/test/307" response:response];
    }

    // 4xx 客户端错误
    [self registerEndpoint:@"/test/400"
                 response:[QCHTTPMockResponse responseWithStatusCode:400
                                                          jsonString:@"{\"error\": \"Bad Request\", \"code\": 400}"]];

    [self registerEndpoint:@"/test/401"
                 response:[QCHTTPMockResponse responseWithStatusCode:401
                                                          jsonString:@"{\"error\": \"Unauthorized\", \"code\": 401}"]];

    [self registerEndpoint:@"/test/403"
                 response:[QCHTTPMockResponse responseWithStatusCode:403
                                                          jsonString:@"{\"error\": \"Forbidden\", \"code\": 403}"]];

    [self registerEndpoint:@"/test/404"
                 response:[QCHTTPMockResponse responseWithStatusCode:404
                                                          jsonString:@"{\"error\": \"Not Found\", \"code\": 404}"]];

    [self registerEndpoint:@"/test/429"
                 response:[QCHTTPMockResponse responseWithStatusCode:429
                                                          jsonString:@"{\"error\": \"Too Many Requests\", \"code\": 429}"]];

    // 5xx 服务器错误
    [self registerEndpoint:@"/test/500"
                 response:[QCHTTPMockResponse responseWithStatusCode:500
                                                          jsonString:@"{\"error\": \"Internal Server Error\", \"code\": 500}"]];

    [self registerEndpoint:@"/test/502"
                 response:[QCHTTPMockResponse responseWithStatusCode:502
                                                          jsonString:@"{\"error\": \"Bad Gateway\", \"code\": 502}"]];

    [self registerEndpoint:@"/test/503"
                 response:[QCHTTPMockResponse responseWithStatusCode:503
                                                          jsonString:@"{\"error\": \"Service Unavailable\", \"code\": 503}"]];

    [self registerEndpoint:@"/test/504"
                 response:[QCHTTPMockResponse responseWithStatusCode:504
                                                          jsonString:@"{\"error\": \"Gateway Timeout\", \"code\": 504}"]];

    // 延迟测试端点
    QCHTTPMockResponse *delayedResponse = [QCHTTPMockResponse responseWithStatusCode:200
                                                                            jsonString:@"{\"status\": \"ok\", \"delayed\": true}"];
    delayedResponse.delay = 2.0;
    [self registerEndpoint:@"/test/delay" response:delayedResponse];

    // 目标端点（用于重定向测试）
    [self registerEndpoint:@"/target"
                 response:[QCHTTPMockResponse responseWithStatusCode:200
                                                          jsonString:@"{\"status\": \"target reached\"}"]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
