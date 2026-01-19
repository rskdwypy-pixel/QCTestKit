//
//  QCDiagnosticHistoryViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCDiagnosticHistoryViewController.h"
#import "QCNetworkCapture.h"
#import "QCNetworkRequestDetailViewController.h"

@interface QCNetworkPacketDisplay : NSObject
@property(nonatomic, strong) QCNetworkPacket *packet;
@property(nonatomic, strong) NSString *domain;
@property(nonatomic, assign) QCNetworkRequestType type;
@end

@implementation QCNetworkPacketDisplay
@end

@interface QCDiagnosticHistoryViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, strong) QCNetworkSession *session;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UISegmentedControl *filterSegment;  // 过滤：全部/成功/失败
@property(nonatomic, strong) NSMutableArray<QCNetworkPacketDisplay *> *filteredPackets;

// 统计标签
@property(nonatomic, strong) UILabel *summaryLabel;

@end

@implementation QCDiagnosticHistoryViewController

- (instancetype)initWithSession:(QCNetworkSession *)session {
    self = [super init];
    if (self) {
        _session = session;
        _filteredPackets = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationWithTitle:@"页面详情"];
    [self setupFilterSegment];
    [self setupSummaryLabel];
    [self setupTableView];
    [self filterPackets];
}

- (void)setupFilterSegment {
    self.filterSegment = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"成功", @"失败", @"资源"]];
    self.filterSegment.selectedSegmentIndex = 0;
    [self.filterSegment addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged];
    self.filterSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.filterSegment];

    [NSLayoutConstraint activateConstraints:@[
        [self.filterSegment.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.filterSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.filterSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.filterSegment.heightAnchor constraintEqualToConstant:32]
    ]];
}

- (void)setupSummaryLabel {
    self.summaryLabel = [[UILabel alloc] init];
    self.summaryLabel.font = [UIFont systemFontOfSize:12];
    self.summaryLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    self.summaryLabel.textAlignment = NSTextAlignmentCenter;
    self.summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.summaryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.summaryLabel.topAnchor constraintEqualToAnchor:self.filterSegment.bottomAnchor constant:8],
        [self.summaryLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.summaryLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.summaryLabel.heightAnchor constraintEqualToConstant:20]
    ]];

    self.summaryLabel.text = [NSString stringWithFormat:@"URL: %@ | 总请求数: %ld",
                              self.session.mainUrl, (long)self.session.totalRequests];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.95 alpha:1.0];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.summaryLabel.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

- (void)filterChanged:(UISegmentedControl *)sender {
    [self filterPackets];
}

- (void)filterPackets {
    [self.filteredPackets removeAllObjects];

    NSInteger filterIndex = self.filterSegment.selectedSegmentIndex;

    for (QCNetworkPacket *packet in self.session.packets) {
        BOOL shouldInclude = NO;

        switch (filterIndex) {
            case 0:  // 全部
                shouldInclude = YES;
                break;
            case 1:  // 成功
                shouldInclude = (packet.statusCode >= 200 && packet.statusCode < 400);
                break;
            case 2:  // 失败
                shouldInclude = (packet.statusCode >= 400 || packet.errorMessage.length > 0);
                break;
            case 3:  // 资源（排除主文档）
                shouldInclude = (packet.type != QCNetworkRequestTypeMainDocument);
                break;
        }

        if (shouldInclude) {
            QCNetworkPacketDisplay *display = [[QCNetworkPacketDisplay alloc] init];
            display.packet = packet;
            display.type = packet.type;
            display.domain = [self extractDomain:packet.url];
            [self.filteredPackets addObject:display];
        }
    }

    // 按类型和域名排序
    [self.filteredPackets sortUsingComparator:^NSComparisonResult(QCNetworkPacketDisplay *obj1, QCNetworkPacketDisplay *obj2) {
        // 先按类型分组
        if (obj1.type != obj2.type) {
            return obj1.type > obj2.type ? NSOrderedDescending : NSOrderedAscending;
        }
        // 同类型按域名排序
        return [obj1.domain compare:obj2.domain];
    }];

    [self.tableView reloadData];
}

- (NSString *)extractDomain:(NSString *)url {
    if (!url) return @"";
    NSURL *urlObj = [NSURL URLWithString:url];
    return urlObj.host ?: @"";
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredPackets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"PacketCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    QCNetworkPacketDisplay *display = self.filteredPackets[indexPath.row];
    QCNetworkPacket *packet = display.packet;

    // URL处理：显示路径部分
    NSString *displayUrl = packet.url;
    NSURL *urlObj = [NSURL URLWithString:packet.url];
    if (urlObj.path && urlObj.path.length > 0) {
        if (urlObj.query) {
            displayUrl = [NSString stringWithFormat:@"%@?%@", urlObj.path, urlObj.query];
        } else {
            displayUrl = urlObj.path;
        }
    }
    if (displayUrl.length > 60) {
        displayUrl = [NSString stringWithFormat:@"...%@", [displayUrl substringFromIndex:displayUrl.length - 57]];
    }

    cell.textLabel.text = displayUrl;
    cell.textLabel.font = [UIFont systemFontOfSize:13];
    cell.textLabel.numberOfLines = 2;

    // 类型图标
    NSString *typeIcon = [self typeIcon:packet.type];
    NSString *methodBadge = [self methodBadge:packet.method];
    NSString *statusIcon = (packet.statusCode >= 200 && packet.statusCode < 300) ? @"✅" :
                           (packet.statusCode >= 400) ? @"❌" : @"⚠️";

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@ %ld (%.0fms) | %@",
                                  typeIcon, methodBadge, statusIcon,
                                  (long)packet.statusCode, [packet.duration doubleValue],
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

    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    QCNetworkPacketDisplay *display = self.filteredPackets[indexPath.row];
    QCNetworkRequestDetailViewController *detailVC = [[QCNetworkRequestDetailViewController alloc] initWithPacket:display.packet];
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"请求列表";
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

- (NSString *)typeIcon:(QCNetworkRequestType)type {
    switch (type) {
        case QCNetworkRequestTypeMainDocument: return @"📄";
        case QCNetworkRequestTypeFetch: return @"🔄";
        case QCNetworkRequestTypeXHR: return @"📡";
        case QCNetworkRequestTypeScript: return @"📜";
        case QCNetworkRequestTypeStylesheet: return @"🎨";
        case QCNetworkRequestTypeImage: return @"🖼️";
        case QCNetworkRequestTypeFont: return @"🔤";
        case QCNetworkRequestTypeMedia: return @"🎬";
        default: return @"📎";
    }
}

@end
