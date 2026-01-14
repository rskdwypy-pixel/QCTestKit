//
//  QCDiagnosticHistoryViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCDiagnosticHistoryViewController.h"
#import "QCWebDiagnosticViewController.h"
#import <WebKit/WebKit.h>

static NSString * const kQCBrowserDiagnosticHistoryKey = @"QCBrowserDiagnosticHistory";

@interface QCDiagnosticHistoryViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *historyItems;

@end

@implementation QCDiagnosticHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationWithTitle:@"📊 诊断历史"];
    [self setupTableView];
    [self setupToolbar];

    // 加载历史记录
    [self loadHistory];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
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
    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithTitle:@"🗑️ 清空"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(clearHistory)];
    UIBarButtonItem *exportButton = [[UIBarButtonItem alloc] initWithTitle:@"📤 导出全部"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(exportAll)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil];

    self.toolbarItems = @[clearButton, space, exportButton];
    self.navigationController.toolbarHidden = NO;
}

- (void)loadHistory {
    NSData *jsonData = [[NSUserDefaults standardUserDefaults] objectForKey:kQCBrowserDiagnosticHistoryKey];
    NSLog(@"[QCTestKit] 📖 读取诊断历史，jsonData: %@", jsonData ? @"存在" : @"不存在");

    if (jsonData) {
        NSError *error = nil;
        self.historyItems = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (error) {
            NSLog(@"[QCTestKit] ❌ JSON解码失败: %@", error);
            // 解码失败，清除损坏的数据
            NSLog(@"[QCTestKit] 🗑️ 清除损坏的历史数据");
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kQCBrowserDiagnosticHistoryKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            self.historyItems = @[];
        } else {
            NSLog(@"[QCTestKit] 📊 解码后记录数: %lu", (unsigned long)self.historyItems.count);
        }
    } else {
        self.historyItems = @[];
    }

    // 确保 historyItems 不为 nil
    if (!self.historyItems) {
        self.historyItems = @[];
    }

    if (self.historyItems.count == 0) {
        // 显示空状态
        [self showEmptyState];
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        [self.tableView reloadData];
    }
}

- (void)showEmptyState {
    UILabel *emptyLabel = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    emptyLabel.text = @"📭\n\n暂无诊断记录\n\n访问网页后会自动保存诊断数据";
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    emptyLabel.numberOfLines = 0;
    emptyLabel.font = [UIFont systemFontOfSize:16];
    emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundView = emptyLabel;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)clearHistory {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空历史"
                                                                   message:@"确定要删除所有诊断记录吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kQCBrowserDiagnosticHistoryKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"[QCTestKit] 🗑️ 诊断历史已清空");
        self.historyItems = @[];
        [self.tableView reloadData];
        [self showEmptyState];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportAll {
    if (self.historyItems.count == 0) {
        [self showMessage:@"没有可导出的记录"];
        return;
    }

    NSMutableString *report = [NSMutableString string];
    [report appendString:@"# QCTestKit 诊断历史报告\n"];
    [report appendString:[NSString stringWithFormat:@"导出时间: %@\n", [self formatDate:[NSDate date]]]];
    [report appendString:[NSString stringWithFormat:@"记录数量: %lu\n\n", (unsigned long)self.historyItems.count]];

    NSInteger index = 0;
    for (NSDictionary *item in self.historyItems) {
        index++;
        [report appendString:[NSString stringWithFormat:@"## 记录 #%ld\n", (long)index]];
        [report appendString:[NSString stringWithFormat:@"页面: %@\n", item[@"title"] ?: @"Unknown"]];
        [report appendString:[NSString stringWithFormat:@"URL: %@\n", item[@"url"] ?: @""]];
        [report appendString:[NSString stringWithFormat:@"访问时间: %@\n", [self formatDate:item[@"savedAt"]]]];

        NSDictionary *metrics = item;
        if (metrics[@"totalLoadTime"]) {
            [report appendString:[NSString stringWithFormat:@"加载时间: %.0f ms\n", [metrics[@"totalLoadTime"] doubleValue]]];
        }
        if (metrics[@"resourceCount"]) {
            [report appendString:[NSString stringWithFormat:@"资源数: %@\n", metrics[@"resourceCount"]]];
        }
        if (metrics[@"jsErrorCount"]) {
            [report appendString:[NSString stringWithFormat:@"JS错误: %@\n", metrics[@"jsErrorCount"]]];
        }
        [report appendString:@"\n"];
    }

    // 输出到日志
    NSLog(@"╔══════════════════════════════════════════════════════════════════════════════");
    NSLog(@"[QCTestKit] 📊 ========== 历史报告开始 ==========");
    NSLog(@"%@", report);
    NSLog(@"[QCTestKit] 📊 ========== 历史报告结束 ==========");
    NSLog(@"╚══════════════════════════════════════════════════════════════════════════════");

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出完成"
                                                                   message:[NSString stringWithFormat:@"已导出 %lu 条记录到日志", (unsigned long)self.historyItems.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)formatDate:(id)date {
    if (!date) return @"";

    // 如果是字符串，直接返回
    if ([date isKindOfClass:[NSString class]]) {
        return date;
    }

    // 如果是 NSDate，格式化
    if ([date isKindOfClass:[NSDate class]]) {
        static NSDateFormatter *formatter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        });
        return [formatter stringFromDate:date];
    }

    return @"";
}

- (NSString *)formatDuration:(NSNumber *)milliseconds {
    if (!milliseconds) return @"--";
    double ms = [milliseconds doubleValue];
    if (ms < 1000) {
        return [NSString stringWithFormat:@"%.0f ms", ms];
    } else {
        return [NSString stringWithFormat:@"%.2f s", ms / 1000.0];
    }
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.historyItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"HistoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    NSDictionary *item = self.historyItems[indexPath.row];
    NSString *url = item[@"url"] ?: @"";
    NSString *title = item[@"title"] ?: @"Unknown";
    NSDate *savedAt = item[@"savedAt"];
    NSNumber *loadTime = item[@"totalLoadTime"];
    NSNumber *errorCount = item[@"jsErrorCount"];

    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.textColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.2 alpha:1.0];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
    cell.textLabel.numberOfLines = 2;

    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];

    // 标题和URL
    cell.textLabel.text = title;

    // 副标题：时间、加载时长、错误数
    NSMutableString *subtitle = [NSMutableString string];
    [subtitle appendString:[self formatDate:savedAt]];

    if (loadTime) {
        [subtitle appendFormat:@" | ⏱ %@", [self formatDuration:loadTime]];
    }

    if (errorCount && [errorCount integerValue] > 0) {
        [subtitle appendFormat:@" | ❌ %@", errorCount];
    }

    cell.detailTextLabel.text = subtitle;

    // 根据错误数量设置状态颜色
    if (errorCount && [errorCount integerValue] > 0) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.historyItems[indexPath.row];
    QCWebDiagnosticViewController *detailVC = [[QCWebDiagnosticViewController alloc] initWithDiagnosticData:item];
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

// 支持删除
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSMutableArray *mutableHistory = [self.historyItems mutableCopy];
        [mutableHistory removeObjectAtIndex:indexPath.row];

        // 使用 JSON 保存更新后的历史
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:mutableHistory options:0 error:&error];
        if (!error) {
            [[NSUserDefaults standardUserDefaults] setObject:jsonData forKey:kQCBrowserDiagnosticHistoryKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        self.historyItems = mutableHistory;
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        NSLog(@"[QCTestKit] 🗑️ 已删除一条诊断记录");

        if (self.historyItems.count == 0) {
            [self showEmptyState];
        }
    }
}

@end
