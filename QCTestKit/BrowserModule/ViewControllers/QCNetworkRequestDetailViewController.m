//
//  QCNetworkRequestDetailViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCNetworkRequestDetailViewController.h"
#import "QCNetworkCapture.h"

@interface QCNetworkRequestDetailViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, strong) QCNetworkPacket *packet;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray<NSDictionary *> *sections;

@end

@implementation QCNetworkRequestDetailViewController

- (instancetype)initWithPacket:(QCNetworkPacket *)packet {
    self = [super init];
    if (self) {
        _packet = packet;
        [self setupSections];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationWithTitle:@"请求详情"];
    [self setupTableView];

    // 输出日志
    [self exportLog];
}

- (void)setupSections {
    NSMutableArray<NSDictionary *> *secs = [NSMutableArray array];

    // 基本信息
    [secs addObject:@{
        @"title": @"基本信息",
        @"items": @[
            @{@"label": @"URL", @"value": self.packet.url ?: @""},
            @{@"label": @"方法", @"value": self.packet.method ?: @""},
            @{@"label": @"状态码", @"value": [NSString stringWithFormat:@"%ld %@", (long)self.packet.statusCode, self.packet.statusText ?: @""]},
            @{@"label": @"类型", @"value": [self typeName:self.packet.type]},
            @{@"label": @"耗时", @"value": [NSString stringWithFormat:@"%.0f ms", [self.packet.duration doubleValue]]},
            @{@"label": @"大小", @"value": [self formatBytes:[self.packet.responseBodySize integerValue]]},
        ]
    }];

    // 时间分解
    NSMutableArray<NSDictionary *> *timingItems = [NSMutableArray array];
    if (self.packet.dnsDuration && [self.packet.dnsDuration doubleValue] > 0) {
        [timingItems addObject:@{@"label": @"DNS", @"value": [NSString stringWithFormat:@"%.0f ms", [self.packet.dnsDuration doubleValue]]}];
    }
    if (self.packet.tcpDuration && [self.packet.tcpDuration doubleValue] > 0) {
        [timingItems addObject:@{@"label": @"TCP", @"value": [NSString stringWithFormat:@"%.0f ms", [self.packet.tcpDuration doubleValue]]}];
    }
    if (self.packet.sslDuration && [self.packet.sslDuration doubleValue] > 0) {
        [timingItems addObject:@{@"label": @"SSL", @"value": [NSString stringWithFormat:@"%.0f ms", [self.packet.sslDuration doubleValue]]}];
    }
    if (self.packet.ttfb && [self.packet.ttfb doubleValue] > 0) {
        [timingItems addObject:@{@"label": @"TTFB", @"value": [NSString stringWithFormat:@"%.0f ms", [self.packet.ttfb doubleValue]]}];
    }
    if (timingItems.count > 0) {
        [secs addObject:@{
            @"title": @"时间分解",
            @"items": timingItems
        }];
    }

    // MIME类型
    if (self.packet.mimeType.length > 0) {
        [secs addObject:@{
            @"title": @"内容类型",
            @"items": @[
                @{@"label": @"MIME", @"value": self.packet.mimeType},
                @{@"label": @"来源", @"value": self.packet.fromCache ? @"⚡️ 缓存" : @"网络"},
            ]
        }];
    }

    // 请求头
    if (self.packet.requestHeaders.count > 0) {
        NSMutableArray<NSDictionary *> *headerItems = [NSMutableArray array];
        for (NSString *key in self.packet.requestHeaders) {
            [headerItems addObject:@{@"label": key, @"value": self.packet.requestHeaders[key]}];
        }
        [secs addObject:@{
            @"title": [NSString stringWithFormat:@"请求头 (%lu)", (unsigned long)headerItems.count],
            @"items": headerItems
        }];
    }

    // 响应头
    if (self.packet.responseHeaders.count > 0) {
        NSMutableArray<NSDictionary *> *headerItems = [NSMutableArray array];
        for (NSString *key in self.packet.responseHeaders) {
            [headerItems addObject:@{@"label": key, @"value": self.packet.responseHeaders[key]}];
        }
        [secs addObject:@{
            @"title": [NSString stringWithFormat:@"响应头 (%lu)", (unsigned long)headerItems.count],
            @"items": headerItems
        }];
    }

    // 响应体
    if (self.packet.responseBody && self.packet.responseBody.length > 0) {
        [secs addObject:@{
            @"title": @"响应体",
            @"items": @[
                @{@"label": @"内容", @"value": self.packet.responseBody, @"isLongText": @YES}
            ]
        }];
    }

    // 错误信息
    if (self.packet.errorMessage.length > 0) {
        [secs addObject:@{
            @"title": @"错误信息",
            @"items": @[
                @{@"label": @"错误", @"value": self.packet.errorMessage, @"isError": @YES}
            ]
        }];
    }

    self.sections = secs;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

- (void)exportLog {
    NSString *logPrefix = @"[QCPacket]";

    NSLog(@"╔══════════════════════════════════════════════════════════════════════════════");
    NSLog(@"%@ ========== 网络请求详情 ==========", logPrefix);
    NSLog(@"%@ URL: %@", logPrefix, self.packet.url);
    NSLog(@"%@ 方法: %@", logPrefix, self.packet.method);
    NSLog(@"%@ 状态码: %ld", logPrefix, (long)self.packet.statusCode);
    NSLog(@"%@ 类型: %@", logPrefix, [self typeName:self.packet.type]);
    NSLog(@"%@ 耗时: %.0f ms", logPrefix, [self.packet.duration doubleValue]);
    NSLog(@"%@ 大小: %@", logPrefix, [self formatBytes:[self.packet.responseBodySize integerValue]]);

    if (self.packet.mimeType.length > 0) {
        NSLog(@"%@ MIME类型: %@", logPrefix, self.packet.mimeType);
    }

    if (self.packet.fromCache) {
        NSLog(@"%@ 来源: ⚡️ 缓存", logPrefix);
    }

    if (self.packet.dnsDuration && [self.packet.dnsDuration doubleValue] > 0) {
        NSLog(@"%@ DNS: %.0f ms", logPrefix, [self.packet.dnsDuration doubleValue]);
    }
    if (self.packet.tcpDuration && [self.packet.tcpDuration doubleValue] > 0) {
        NSLog(@"%@ TCP: %.0f ms", logPrefix, [self.packet.tcpDuration doubleValue]);
    }
    if (self.packet.sslDuration && [self.packet.sslDuration doubleValue] > 0) {
        NSLog(@"%@ SSL: %.0f ms", logPrefix, [self.packet.sslDuration doubleValue]);
    }
    if (self.packet.ttfb && [self.packet.ttfb doubleValue] > 0) {
        NSLog(@"%@ TTFB: %.0f ms", logPrefix, [self.packet.ttfb doubleValue]);
    }

    if (self.packet.requestHeaders.count > 0) {
        NSLog(@"%@ ========== 请求头 ==========", logPrefix);
        for (NSString *key in self.packet.requestHeaders) {
            NSLog(@"%@   %@: %@", logPrefix, key, self.packet.requestHeaders[key]);
        }
    }

    if (self.packet.responseHeaders.count > 0) {
        NSLog(@"%@ ========== 响应头 ==========", logPrefix);
        for (NSString *key in self.packet.responseHeaders) {
            NSLog(@"%@   %@: %@", logPrefix, key, self.packet.responseHeaders[key]);
        }
    }

    if (self.packet.responseBody && self.packet.responseBody.length > 0) {
        NSString *bodyPreview = self.packet.responseBody;
        if (bodyPreview.length > 500) {
            bodyPreview = [bodyPreview substringToIndex:500];
        }
        NSLog(@"%@ ========== 响应体预览 ==========", logPrefix);
        NSLog(@"%@ %@", logPrefix, bodyPreview);
    }

    if (self.packet.errorMessage.length > 0) {
        NSLog(@"%@ ========== 错误信息 ==========", logPrefix);
        NSLog(@"%@ %@", logPrefix, self.packet.errorMessage);
    }

    NSLog(@"%@ ========== 详情结束 ==========", logPrefix);
    NSLog(@"╚══════════════════════════════════════════════════════════════════════════════");
}

#pragma mark - UITableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *items = self.sections[section][@"items"];
    return items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"DetailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }

    NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
    NSString *label = item[@"label"];
    NSString *value = item[@"value"];
    BOOL isLongText = [item[@"isLongText"] boolValue];
    BOOL isError = [item[@"isError"] boolValue];

    cell.textLabel.text = label;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:13];

    if (isLongText) {
        // 长文本显示预览
        NSString *preview = value;
        if (preview.length > 50) {
            preview = [NSString stringWithFormat:@"%@", [preview substringToIndex:50]];
        }
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@... (点击查看完整)", preview];
        cell.detailTextLabel.numberOfLines = 2;
    } else {
        cell.detailTextLabel.text = value;
        cell.detailTextLabel.numberOfLines = 0;
    }

    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];

    // 根据状态设置颜色
    if (isError) {
        cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
    } else if ([label isEqualToString:@"状态码"]) {
        if (self.packet.statusCode >= 200 && self.packet.statusCode < 300) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.2 alpha:1.0];
        } else if (self.packet.statusCode >= 400) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
        } else {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.8 alpha:1.0];
        }
    } else {
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
    NSString *value = item[@"value"];

    // 复制到剪贴板
    UIPasteboard.generalPasteboard.string = value;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制"
                                                                   message:@"内容已复制到剪贴板"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

#pragma mark - Helper Methods

- (NSString *)formatBytes:(NSInteger)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%ld B", (long)bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    } else {
        return [NSString stringWithFormat:@"%.2f MB", bytes / (1024.0 * 1024.0)];
    }
}

- (NSString *)typeName:(QCNetworkRequestType)type {
    switch (type) {
        case QCNetworkRequestTypeMainDocument: return @"主文档";
        case QCNetworkRequestTypeFetch: return @"Fetch";
        case QCNetworkRequestTypeXHR: return @"XHR";
        case QCNetworkRequestTypeScript: return @"脚本";
        case QCNetworkRequestTypeStylesheet: return @"样式";
        case QCNetworkRequestTypeImage: return @"图片";
        case QCNetworkRequestTypeFont: return @"字体";
        case QCNetworkRequestTypeMedia: return @"媒体";
        default: return @"其他";
    }
}

@end
