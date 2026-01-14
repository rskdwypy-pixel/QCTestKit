//
//  QCWebDiagnosticViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCWebDiagnosticViewController.h"

@interface QCWebDiagnosticViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSDictionary *diagnosticData;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *displayItems;

@end

@implementation QCWebDiagnosticViewController

- (instancetype)initWithDiagnosticData:(NSDictionary *)data {
    self = [super init];
    if (self) {
        _diagnosticData = data;
        [self parseDiagnosticData];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationWithTitle:@"📊 页面诊断"];
    [self setupTableView];
    [self setupToolbar];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.95 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

- (void)setupToolbar {
    // 导出按钮
    UIBarButtonItem *exportButton = [[UIBarButtonItem alloc] initWithTitle:@"📤 导出"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(exportDiagnostic)];
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithTitle:@"📤 分享"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(shareDiagnostic)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil];

    self.toolbarItems = @[exportButton, space, shareButton];
    self.navigationController.toolbarHidden = NO;
}

- (void)parseDiagnosticData {
    self.displayItems = [NSMutableArray array];

    // 页面基本信息
    if (self.diagnosticData[@"url"]) {
        [self.displayItems addObject:@{
            @"section": @"📋 页面信息",
            @"title": @"URL",
            @"value": self.diagnosticData[@"url"],
            @"type": @"text"
        }];
    }

    if (self.diagnosticData[@"title"]) {
        [self.displayItems addObject:@{
            @"section": @"📋 页面信息",
            @"title": @"标题",
            @"value": self.diagnosticData[@"title"],
            @"type": @"text"
        }];
    }

    // 加载状态信息
    NSString *loadStatus = self.diagnosticData[@"loadStatus"];
    if (loadStatus) {
        NSString *statusText = [loadStatus isEqualToString:@"success"] ? @"成功" : @"失败";
        NSString *statusIcon = [loadStatus isEqualToString:@"success"] ? @"✅" : @"❌";
        [self.displayItems addObject:@{
            @"section": @"📋 页面信息",
            @"title": @"加载状态",
            @"value": [NSString stringWithFormat:@"%@ %@", statusIcon, statusText],
            @"type": [loadStatus isEqualToString:@"success"] ? @"status_ok" : @"status_error"
        }];
    }

    // 缓存状态
    NSNumber *isFromCache = self.diagnosticData[@"isLoadingFromCache"];
    if (isFromCache) {
        NSString *cacheText = [isFromCache boolValue] ? @"⚡️ 是（从缓存加载）" : @"否（网络加载）";
        [self.displayItems addObject:@{
            @"section": @"📋 页面信息",
            @"title": @"来自缓存",
            @"value": cacheText,
            @"type": @"text"
        }];
    }

    // 进度跳跃次数
    NSNumber *jumpCount = self.diagnosticData[@"progressJumpCount"];
    if (jumpCount && [jumpCount integerValue] > 0) {
        [self.displayItems addObject:@{
            @"section": @"📋 页面信息",
            @"title": @"进度跳跃",
            @"value": [NSString stringWithFormat:@"%@ 次（可能来自缓存）", jumpCount],
            @"type": @"text"
        }];
    }

    // 最大进度
    NSNumber *maxProgress = self.diagnosticData[@"maxProgress"];
    if (maxProgress) {
        [self.displayItems addObject:@{
            @"section": @"📋 页面信息",
            @"title": @"最大进度",
            @"value": [NSString stringWithFormat:@"%.0f%%", [maxProgress doubleValue] * 100],
            @"type": @"text"
        }];
    }

    // 错误信息（如果加载失败）
    if (self.diagnosticData[@"errorCode"]) {
        [self.displayItems addObject:@{
            @"section": @"❌ 错误信息",
            @"title": @"错误码",
            @"value": [NSString stringWithFormat:@"%@", self.diagnosticData[@"errorCode"]],
            @"type": @"error"
        }];
    }

    if (self.diagnosticData[@"errorMessage"]) {
        [self.displayItems addObject:@{
            @"section": @"❌ 错误信息",
            @"title": @"错误描述",
            @"value": self.diagnosticData[@"errorMessage"],
            @"type": @"error"
        }];
    }

    // 加载时间指标
    [self.displayItems addObject:@{
        @"section": @"⏱️ 加载时间",
        @"title": @"DNS 查询",
        @"value": [self formatTiming:self.diagnosticData[@"dnsDuration"]],
        @"type": @"timing"
    }];

    [self.displayItems addObject:@{
        @"section": @"⏱️ 加载时间",
        @"title": @"TCP 连接",
        @"value": [self formatTiming:self.diagnosticData[@"tcpDuration"]],
        @"type": @"timing"
    }];

    [self.displayItems addObject:@{
        @"section": @"⏱️ 加载时间",
        @"title": @"SSL 握手",
        @"value": [self formatTiming:self.diagnosticData[@"sslDuration"]],
        @"type": @"timing"
    }];

    [self.displayItems addObject:@{
        @"section": @"⏱️ 加载时间",
        @"title": @"首字节时间 (TTFB)",
        @"value": [self formatTiming:self.diagnosticData[@"ttfb"]],
        @"type": @"timing"
    }];

    [self.displayItems addObject:@{
        @"section": @"⏱️ 加载时间",
        @"title": @"内容下载",
        @"value": [self formatTiming:self.diagnosticData[@"downloadDuration"]],
        @"type": @"timing"
    }];

    [self.displayItems addObject:@{
        @"section": @"⏱️ 加载时间",
        @"title": @"DOM 加载",
        @"value": [self formatTiming:self.diagnosticData[@"domLoadDuration"]],
        @"type": @"timing"
    }];

    [self.displayItems addObject:@{
        @"section": @"⏱️ 加载时间",
        @"title": @"完全加载",
        @"value": [self formatTiming:self.diagnosticData[@"totalLoadTime"]],
        @"type": @"timing"
    }];

    // 资源统计
    [self.displayItems addObject:@{
        @"section": @"📦 资源统计",
        @"title": @"总资源数",
        @"value": [NSString stringWithFormat:@"%@", self.diagnosticData[@"resourceCount"] ?: @"0"],
        @"type": @"stat"
    }];

    [self.displayItems addObject:@{
        @"section": @"📦 资源统计",
        @"title": @"失败资源",
        @"value": [NSString stringWithFormat:@"%@", self.diagnosticData[@"failedResourceCount"] ?: @"0"],
        @"type": @"stat"
    }];

    [self.displayItems addObject:@{
        @"section": @"📦 资源统计",
        @"title": @"JS 错误",
        @"value": [NSString stringWithFormat:@"%@", self.diagnosticData[@"jsErrorCount"] ?: @"0"],
        @"type": @"stat"
    }];

    [self.displayItems addObject:@{
        @"section": @"📦 资源统计",
        @"title": @"总数据大小",
        @"value": [self formatBytes:[self.diagnosticData[@"totalBytes"] longLongValue]],
        @"type": @"stat"
    }];

    // 网络请求
    NSArray *requests = self.diagnosticData[@"requests"];
    if (requests.count > 0) {
        for (NSDictionary *request in requests) {
            [self.displayItems addObject:@{
                @"section": @"🌐 网络请求",
                @"title": request[@"url"] ?: @"Unknown",
                @"value": [NSString stringWithFormat:@"%@ - %@ | %@",
                           request[@"method"] ?: @"GET",
                           request[@"status"] ?: @"?",
                           [self formatBytes:[request[@"size"] longLongValue]]],
                @"type": @"request",
                @"status": request[@"status"] ?: @"0",
                @"duration": request[@"duration"] ?: @"0"
            }];
        }
    }

    // JS 错误
    NSArray *jsErrors = self.diagnosticData[@"jsErrors"];
    if (jsErrors.count > 0) {
        for (NSDictionary *error in jsErrors) {
            [self.displayItems addObject:@{
                @"section": @"❌ JavaScript 错误",
                @"title": error[@"message"] ?: @"Unknown Error",
                @"value": [NSString stringWithFormat:@"%@:%@",
                           error[@"file"] ?: @"?",
                           error[@"line"] ?: @"?"],
                @"type": @"error"
            }];
        }
    }

    // 控制台日志
    NSArray *consoleLogs = self.diagnosticData[@"consoleLogs"];
    if (consoleLogs.count > 0) {
        for (NSDictionary *log in consoleLogs) {
            NSString *level = log[@"level"] ?: @"log";
            NSString *icon = @"📝";
            if ([level isEqualToString:@"error"]) icon = @"❌";
            else if ([level isEqualToString:@"warn"]) icon = @"⚠️";

            [self.displayItems addObject:@{
                @"section": [NSString stringWithFormat:@"%@ 控制台", icon],
                @"title": log[@"message"] ?: @"",
                @"value": [NSString stringWithFormat:@"%@", log[@"timestamp"] ?: @""],
                @"type": @"log",
                @"level": level
            }];
        }
    }

    // 性能指标
    if (self.diagnosticData[@"performanceMetrics"]) {
        NSDictionary *perf = self.diagnosticData[@"performanceMetrics"];

        if (perf[@"domContentLoaded"]) {
            [self.displayItems addObject:@{
                @"section": @"🚀 性能指标",
                @"title": @"DOM Content Loaded",
                @"value": [NSString stringWithFormat:@"%@ ms", perf[@"domContentLoaded"]],
                @"type": @"perf"
            }];
        }

        if (perf[@"loadComplete"]) {
            [self.displayItems addObject:@{
                @"section": @"🚀 性能指标",
                @"title": @"Load Complete",
                @"value": [NSString stringWithFormat:@"%@ ms", perf[@"loadComplete"]],
                @"type": @"perf"
            }];
        }

        if (perf[@"firstPaint"]) {
            [self.displayItems addObject:@{
                @"section": @"🚀 性能指标",
                @"title": @"First Paint",
                @"value": [NSString stringWithFormat:@"%@ ms", perf[@"firstPaint"]],
                @"type": @"perf"
            }];
        }
    }
}

- (NSString *)formatTiming:(NSNumber *)milliseconds {
    if (!milliseconds || [milliseconds isKindOfClass:[NSNull class]]) {
        return @"--";
    }
    double ms = [milliseconds doubleValue];
    if (ms < 0) return @"--";

    if (ms < 1000) {
        return [NSString stringWithFormat:@"%.0f ms", ms];
    } else {
        return [NSString stringWithFormat:@"%.2f s", ms / 1000.0];
    }
}

- (NSString *)formatBytes:(long long)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%lld B", bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    } else {
        return [NSString stringWithFormat:@"%.2f MB", bytes / (1024.0 * 1024.0)];
    }
}

#pragma mark - UITableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSMutableSet<NSString *> *sections = [NSMutableSet set];
    for (NSDictionary *item in self.displayItems) {
        [sections addObject:item[@"section"]];
    }
    return sections.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    // 获取所有section名称并排序
    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    NSMutableSet<NSString *> *seenSections = [NSMutableSet set];

    for (NSDictionary *item in self.displayItems) {
        NSString *sectionName = item[@"section"];
        if (![seenSections containsObject:sectionName]) {
            [sections addObject:sectionName];
            [seenSections addObject:sectionName];
        }
    }

    if (section < sections.count) {
        return sections[section];
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:section];
    NSInteger count = 0;
    for (NSDictionary *item in self.displayItems) {
        if ([item[@"section"] isEqualToString:sectionTitle]) {
            count++;
        }
    }
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"DiagnosticCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }

    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:indexPath.section];
    NSMutableArray<NSDictionary *> *sectionItems = [NSMutableArray array];

    for (NSDictionary *item in self.displayItems) {
        if ([item[@"section"] isEqualToString:sectionTitle]) {
            [sectionItems addObject:item];
        }
    }

    if (indexPath.row < sectionItems.count) {
        NSDictionary *item = sectionItems[indexPath.row];
        NSString *type = item[@"type"];

        cell.backgroundColor = [UIColor whiteColor];
        cell.textLabel.textColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.2 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        if ([type isEqualToString:@"request"]) {
            cell.textLabel.font = [UIFont systemFontOfSize:12];
            cell.textLabel.numberOfLines = 2;
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = item[@"value"];

            // 根据状态码设置颜色
            NSInteger status = [item[@"status"] integerValue];
            if (status >= 200 && status < 300) {
                cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.2 alpha:1.0];
            } else if (status >= 300 && status < 400) {
                cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.8 alpha:1.0];
            } else if (status >= 400) {
                cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
            }
        } else if ([type isEqualToString:@"error"]) {
            cell.textLabel.font = [UIFont systemFontOfSize:13];
            cell.textLabel.numberOfLines = 3;
            cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = item[@"value"];
        } else if ([type isEqualToString:@"status_ok"]) {
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = item[@"value"];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.2 alpha:1.0];
        } else if ([type isEqualToString:@"status_error"]) {
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = item[@"value"];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
        } else if ([type isEqualToString:@"log"]) {
            NSString *level = item[@"level"];
            cell.textLabel.font = [UIFont systemFontOfSize:11];
            cell.textLabel.numberOfLines = 2;

            if ([level isEqualToString:@"error"]) {
                cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
            } else if ([level isEqualToString:@"warn"]) {
                cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.5 blue:0.0 alpha:1.0];
            } else {
                cell.textLabel.textColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.2 alpha:1.0];
            }
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = item[@"value"];
        } else if ([type isEqualToString:@"timing"]) {
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = item[@"value"];

            // 根据时间设置颜色警告
            NSString *value = item[@"value"];
            if ([value containsString:@"ms"]) {
                double ms = [[value stringByReplacingOccurrencesOfString:@" ms" withString:@""] doubleValue];
                if (ms > 1000) {
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.2 alpha:1.0];
                } else if (ms > 500) {
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.8 green:0.6 blue:0.1 alpha:1.0];
                } else {
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:0.2 alpha:1.0];
                }
            }
        } else {
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = item[@"value"];
        }
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:indexPath.section];
    for (NSDictionary *item in self.displayItems) {
        if ([item[@"section"] isEqualToString:sectionTitle]) {
            NSString *type = item[@"type"];
            if ([type isEqualToString:@"request"] || [type isEqualToString:@"error"] || [type isEqualToString:@"log"]) {
                return UITableViewAutomaticDimension;
            }
        }
    }
    return 44;
}

#pragma mark - Actions

- (void)exportDiagnostic {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"# QCTestKit 网页诊断报告\n"];
    [report appendString:[NSString stringWithFormat:@"生成时间: %@\n\n", [self formatReportDate:[NSDate date]]]];

    NSString *currentSection = @"";
    for (NSDictionary *item in self.displayItems) {
        NSString *section = item[@"section"];
        if (![section isEqualToString:currentSection]) {
            [report appendString:[NSString stringWithFormat:@"\n## %@\n", section]];
            currentSection = section;
        }
        [report appendString:[NSString stringWithFormat:@"- **%@**: %@\n", item[@"title"], item[@"value"]]];
    }

    NSLog(@"[QCTestKit] 📄 诊断报告:\n%@", report);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"诊断报告"
                                                                   message:@"报告已输出到控制台日志，可用第三方工具捕获"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shareDiagnostic {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"QCTestKit 网页诊断报告\n"];
    [report appendString:[NSString stringWithFormat:@"生成时间: %@\n\n", [self formatReportDate:[NSDate date]]]];

    NSString *currentSection = @"";
    for (NSDictionary *item in self.displayItems) {
        NSString *section = item[@"section"];
        if (![section isEqualToString:currentSection]) {
            [report appendString:[NSString stringWithFormat:@"\n[%@]\n", section]];
            currentSection = section;
        }
        [report appendString:[NSString stringWithFormat:@"%@: %@\n", item[@"title"], item[@"value"]]];
    }

    // 输出完整日志供第三方工具捕获
    NSLog(@"╔══════════════════════════════════════════════════════════════════════════════");
    NSLog(@"[QCTestKit] 📊 ========== 诊断报告开始 ==========");
    NSLog(@"%@", report);
    NSLog(@"[QCTestKit] 📊 ========== 诊断报告结束 ==========");
    NSLog(@"╚══════════════════════════════════════════════════════════════════════════════");

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"报告已分享"
                                                                   message:@"完整诊断报告已输出到日志"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)formatReportDate:(NSDate *)date {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return [formatter stringFromDate:date];
}

@end
