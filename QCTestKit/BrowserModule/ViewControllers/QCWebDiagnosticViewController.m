//
//  QCWebDiagnosticViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCWebDiagnosticViewController.h"
#import "QCNetworkCapture.h"
#import "QCDiagnosticHistoryViewController.h"
#import "QCNetworkRequestDetailViewController.h"
#import "QCOperationDetailViewController.h"

@interface QCWebDiagnosticViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *displayItems;  // 会话列表
@property (nonatomic, strong) UILabel *statusLabel;

// 当前显示模式：0 = 按URL分组，1 = 时间线
@property (nonatomic, assign) NSInteger displayMode;

@end

@implementation QCWebDiagnosticViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.displayMode = 0;
    self.displayItems = [NSMutableArray array];

    [self setupNavigationWithTitle:@"网络分析"];
    [self setupNavigationItems];
    [self setupSegmentControl];
    [self setupTableView];

    [self loadData];
}

- (void)setupNavigationItems {
    // 导出按钮
    UIBarButtonItem *exportItem = [[UIBarButtonItem alloc] initWithTitle:@"导出"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(exportData)];

    // 清空按钮
    UIBarButtonItem *clearItem = [[UIBarButtonItem alloc] initWithTitle:@"清空"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(clearAll)];

    self.navigationItem.rightBarButtonItems = @[exportItem, clearItem];
}

- (void)setupSegmentControl {
    // 分段控件：按URL分组 / 时间线 / 按操作分组
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"按页面分组", @"全部请求", @"按操作分组"]];
    self.segmentControl.selectedSegmentIndex = 0;
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.segmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.segmentControl];

    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.segmentControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.segmentControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.segmentControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.segmentControl.heightAnchor constraintEqualToConstant:32],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.segmentControl.bottomAnchor constant:4],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.statusLabel.heightAnchor constraintEqualToConstant:20]
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.95 alpha:1.0];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

- (void)loadData {
    [self.displayItems removeAllObjects];

    NSArray<QCNetworkSession *> *sessions = [[QCNetworkCaptureManager sharedManager] getSessions];

    if (self.displayMode == 0) {
        // 按URL分组显示
        for (QCNetworkSession *session in sessions) {
            [self.displayItems addObject:@{
                @"type": @"session",
                @"session": session
            }];
        }
    } else if (self.displayMode == 1) {
        // 时间线模式 - 显示所有请求
        for (QCNetworkSession *session in sessions) {
            for (QCNetworkPacket *packet in session.packets) {
                [self.displayItems addObject:@{
                    @"type": @"packet",
                    @"packet": packet,
                    @"session": session
                }];
            }
        }
        // 按时间排序
        [self.displayItems sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            QCNetworkPacket *p1 = obj1[@"packet"];
            QCNetworkPacket *p2 = obj2[@"packet"];
            return [p2.startTime compare:p1.startTime];
        }];
    } else {
        // 按操作分组模式 - 显示所有操作
        for (QCNetworkSession *session in sessions) {
            for (QCNetworkOperation *operation in session.operations) {
                // 计算该操作关联的请求数
                NSInteger requestCount = 0;
                NSInteger successCount = 0;
                NSInteger failureCount = 0;
                for (NSString *packetId in operation.packetIds) {
                    for (QCNetworkPacket *packet in session.packets) {
                        if ([packet.packetId isEqualToString:packetId]) {
                            requestCount++;
                            if (packet.statusCode >= 200 && packet.statusCode < 400) {
                                successCount++;
                            } else if (packet.statusCode >= 400 || packet.errorMessage.length > 0) {
                                failureCount++;
                            }
                            break;
                        }
                    }
                }

                [self.displayItems addObject:@{
                    @"type": @"operation",
                    @"operation": operation,
                    @"session": session,
                    @"requestCount": @(requestCount),
                    @"successCount": @(successCount),
                    @"failureCount": @(failureCount)
                }];
            }
        }
        // 按时间排序
        [self.displayItems sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            QCNetworkOperation *o1 = obj1[@"operation"];
            QCNetworkOperation *o2 = obj2[@"operation"];
            return [o2.startTime compare:o1.startTime];
        }];
    }

    // 更新状态
    NSInteger totalRequests = 0;
    NSInteger totalBytes = 0;
    NSInteger totalOperations = 0;
    for (QCNetworkSession *session in sessions) {
        totalRequests += session.totalRequests;
        totalBytes += session.totalBytes;
        totalOperations += session.operations.count;
    }

    if (self.displayMode == 0) {
        self.statusLabel.text = [NSString stringWithFormat:@"%lu 个页面 | %ld 个请求 | %@",
                                 (unsigned long)sessions.count, (long)totalRequests, [self formatBytes:totalBytes]];
    } else if (self.displayMode == 1) {
        self.statusLabel.text = [NSString stringWithFormat:@"共 %ld 个请求 | %@",
                                 (long)totalRequests, [self formatBytes:totalBytes]];
    } else {
        self.statusLabel.text = [NSString stringWithFormat:@"%ld 个操作 | %ld 个请求 | %@",
                                 (long)totalOperations, (long)totalRequests, [self formatBytes:totalBytes]];
    }

    if (self.displayItems.count == 0) {
        [self showEmptyState];
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    [self.tableView reloadData];
}

- (void)showEmptyState {
    UILabel *emptyLabel = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    BOOL isCapturing = [QCNetworkCaptureManager sharedManager].isCapturing;
    emptyLabel.text = isCapturing ? @"📡\n\n暂无抓包记录\n\n访问网页后自动记录" : @"⚪\n\n抓包已暂停\n\n点击上方按钮开启";
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    emptyLabel.numberOfLines = 0;
    emptyLabel.font = [UIFont systemFontOfSize:16];
    emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundView = emptyLabel;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.statusLabel.text = @"暂无数据";
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.displayMode = sender.selectedSegmentIndex;
    [self loadData];
}

- (void)clearAll {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空记录"
                                                                   message:@"确定要删除所有抓包记录吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[QCNetworkCaptureManager sharedManager] clearAll];
        [self loadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportData {
    NSArray<QCNetworkSession *> *sessions = [[QCNetworkCaptureManager sharedManager] getSessions];
    if (sessions.count == 0) {
        [self showMessage:@"暂无数据可导出"];
        return;
    }

    NSMutableString *report = [NSMutableString string];
    [report appendString:@"# QCTestKit 网络抓包报告\n"];
    [report appendString:[NSString stringWithFormat:@"导出时间: %@\n\n", [self formatDate:[NSDate date]]]];
    [report appendString:[NSString stringWithFormat:@"会话数量: %lu\n\n", (unsigned long)sessions.count]];

    for (QCNetworkSession *session in sessions) {
        [report appendString:@"## 页面\n"];
        [report appendString:[NSString stringWithFormat:@"URL: %@\n", session.mainUrl]];
        [report appendString:[NSString stringWithFormat:@"标题: %@\n", session.pageTitle]];
        [report appendString:[NSString stringWithFormat:@"请求数: %ld\n", (long)session.totalRequests]];
        [report appendString:[NSString stringWithFormat:@"成功: %ld | 失败: %ld\n",
                             (long)session.successCount, (long)session.failureCount]];
        [report appendString:[NSString stringWithFormat:@"总流量: %@\n", [self formatBytes:session.totalBytes]]];
        [report appendString:@"\n### 请求列表\n"];

        for (QCNetworkPacket *packet in session.packets) {
            NSString *statusIcon = (packet.statusCode >= 200 && packet.statusCode < 300) ? @"✅" :
                                   (packet.statusCode >= 400) ? @"❌" : @"⚠️";
            [report appendString:[NSString stringWithFormat:@"- %@ %@ %@ - %ld (%.0fms)\n",
                                 statusIcon, packet.method, packet.url, (long)packet.statusCode,
                                 [packet.duration doubleValue]]];
        }
        [report appendString:@"\n"];
    }

    NSLog(@"╔══════════════════════════════════════════════════════════════════════════════");
    NSLog(@"[QCTestKit] 📊 ========== 抓包报告开始 ==========");
    NSLog(@"%@", report);
    NSLog(@"[QCTestKit] 📊 ========== 抓包报告结束 ==========");
    NSLog(@"╚══════════════════════════════════════════════════════════════════════════════");

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出完成"
                                                                   message:@"报告已输出到控制台日志"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"NetworkCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    NSDictionary *item = self.displayItems[indexPath.row];

    if ([item[@"type"] isEqualToString:@"session"]) {
        // 会话单元格
        QCNetworkSession *session = item[@"session"];
        cell.textLabel.text = session.mainUrl;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;

        NSString *statusIcon = session.failureCount > 0 ? @"❌" : @"✅";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %ld 个请求 | %@ | 失败 %ld",
                                      statusIcon,
                                      (long)session.totalRequests,
                                      [self formatBytes:session.totalBytes],
                                      (long)session.failureCount];
        cell.detailTextLabel.textColor = session.failureCount > 0 ?
            [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0] :
            [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    } else if ([item[@"type"] isEqualToString:@"operation"]) {
        // 操作单元格
        QCNetworkOperation *operation = item[@"operation"];
        NSInteger requestCount = [item[@"requestCount"] integerValue];
        NSInteger successCount = [item[@"successCount"] integerValue];
        NSInteger failureCount = [item[@"failureCount"] integerValue];

        cell.textLabel.text = operation.operationName;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;

        NSString *typeIcon = [self operationTypeIcon:operation.type];
        NSString *statusIcon = failureCount > 0 ? @"❌" : @"✅";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %ld 个请求 | 成功 %ld | 失败 %ld",
                                      typeIcon, statusIcon,
                                      (long)requestCount,
                                      (long)successCount,
                                      (long)failureCount];
        cell.detailTextLabel.textColor = failureCount > 0 ?
            [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0] :
            [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    } else {
        // 请求单元格
        QCNetworkPacket *packet = item[@"packet"];
        cell.textLabel.text = packet.url;
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.textLabel.numberOfLines = 2;

        NSString *methodBadge = [self methodBadge:packet.method];
        NSString *statusIcon = (packet.statusCode >= 200 && packet.statusCode < 300) ? @"✅" :
                               (packet.statusCode >= 400) ? @"❌" : @"⚠️";

        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %ld (%.0fms) | %@",
                                      methodBadge, statusIcon, (long)packet.statusCode,
                                      [packet.duration doubleValue],
                                      [self formatBytes:[packet.responseBodySize integerValue]]];

        // 根据状态设置颜色
        if (packet.statusCode >= 200 && packet.statusCode < 300) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.2 alpha:1.0];
        } else if (packet.statusCode >= 400) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
        } else {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.8 alpha:1.0];
        }

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.displayItems[indexPath.row];

    if ([item[@"type"] isEqualToString:@"session"]) {
        QCNetworkSession *session = item[@"session"];
        QCDiagnosticHistoryViewController *detailVC = [[QCDiagnosticHistoryViewController alloc] initWithSession:session];
        [self.navigationController pushViewController:detailVC animated:YES];
    } else if ([item[@"type"] isEqualToString:@"operation"]) {
        // 操作详情
        QCNetworkOperation *operation = item[@"operation"];
        QCNetworkSession *session = item[@"session"];
        QCOperationDetailViewController *detailVC = [[QCOperationDetailViewController alloc] initWithOperation:operation session:session];
        [self.navigationController pushViewController:detailVC animated:YES];
    } else {
        QCNetworkPacket *packet = item[@"packet"];
        QCNetworkRequestDetailViewController *detailVC = [[QCNetworkRequestDetailViewController alloc] initWithPacket:packet];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *item = self.displayItems[indexPath.row];

        if ([item[@"type"] isEqualToString:@"session"]) {
            QCNetworkSession *session = item[@"session"];
            [[QCNetworkCaptureManager sharedManager] removeSession:session.sessionId];
        }

        [self loadData];
    }
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

- (NSString *)formatDate:(NSDate *)date {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return [formatter stringFromDate:date];
}

- (NSString *)methodBadge:(NSString *)method {
    if ([method isEqualToString:@"GET"]) return @"🟢 GET";
    if ([method isEqualToString:@"POST"]) return @"🔵 POST";
    if ([method isEqualToString:@"PUT"]) return @"🟡 PUT";
    if ([method isEqualToString:@"DELETE"]) return @"🔴 DELETE";
    if ([method isEqualToString:@"PATCH"]) return @"🟣 PATCH";
    return [NSString stringWithFormat:@"⚪️ %@", method];
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

- (NSString *)operationTypeIcon:(QCNetworkOperationType)type {
    switch (type) {
        case QCNetworkOperationTypeClick: return @"👆";
        case QCNetworkOperationTypeInput: return @"⌨️";
        case QCNetworkOperationTypeSubmit: return @"📤";
        case QCNetworkOperationTypeScroll: return @"📜";
        case QCNetworkOperationTypeSearch: return @"🔍";
        case QCNetworkOperationTypeNavigation: return @"🔗";
        case QCNetworkOperationTypePageLoad: return @"📄";
        default: return @"❓";
    }
}

- (void)dealloc {
}

@end
