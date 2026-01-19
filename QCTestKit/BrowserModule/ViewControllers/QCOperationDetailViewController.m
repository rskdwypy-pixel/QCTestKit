//
//  QCOperationDetailViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCOperationDetailViewController.h"
#import "QCNetworkCapture.h"
#import "QCNetworkRequestDetailViewController.h"

@interface QCOperationDetailViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, strong) QCNetworkOperation *operation;
@property(nonatomic, strong) QCNetworkSession *session;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray<QCNetworkPacket *> *associatedPackets;
@property(nonatomic, strong) NSArray<NSDictionary *> *sections;

@end

@implementation QCOperationDetailViewController

- (instancetype)initWithOperation:(QCNetworkOperation *)operation session:(QCNetworkSession *)session {
    self = [super init];
    if (self) {
        _operation = operation;
        _session = session;
        [self setupSections];
        [self loadAssociatedPackets];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationWithTitle:@"操作详情"];
    [self setupTableView];
    [self exportLog];
}

- (void)setupSections {
    NSMutableArray<NSDictionary *> *secs = [NSMutableArray array];
    NSString *typeName = [self typeName:self.operation.type];
    [secs addObject:@{
        @"title": @"基本信息",
        @"items": @[
            @{@"label": @"操作", @"value": self.operation.operationName},
            @{@"label": @"类型", @"value": typeName},
            @{@"label": @"时间", @"value": [self formatDate:self.operation.startTime]},
            @{@"label": @"关联请求数", @"value": [NSString stringWithFormat:@"%ld", (long)self.operation.packetIds.count]},
        ]
    }];
    if (self.operation.elementInfo.length > 0) {
        [secs addObject:@{
            @"title": @"元素信息",
            @"items": @[
                @{@"label": @"元素", @"value": self.operation.elementInfo},
            ]
        }];
    }
    if (self.operation.url.length > 0) {
        [secs addObject:@{
            @"title": @"页面信息",
            @"items": @[
                @{@"label": @"页面URL", @"value": self.operation.url},
            ]
        }];
    }
    self.sections = secs;
}

- (void)loadAssociatedPackets {
    NSMutableArray<QCNetworkPacket *> *packets = [NSMutableArray array];
    for (NSString *packetId in self.operation.packetIds) {
        for (QCNetworkPacket *packet in self.session.packets) {
            if ([packet.packetId isEqualToString:packetId]) {
                [packets addObject:packet];
                break;
            }
        }
    }
    [packets sortUsingComparator:^NSComparisonResult(QCNetworkPacket *obj1, QCNetworkPacket *obj2) {
        return [obj1.startTime compare:obj2.startTime];
    }];
    self.associatedPackets = packets;
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
    NSLog(@"[QCTestKit] ========== 操作详情 ==========");
    NSLog(@"[QCTestKit] 操作: %@", self.operation.operationName);
    NSLog(@"[QCTestKit] 类型: %@", [self typeName:self.operation.type]);
    NSLog(@"[QCTestKit] 时间: %@", [self formatDate:self.operation.startTime]);
    NSLog(@"[QCTestKit] 关联请求数: %ld", (long)self.operation.packetIds.count);
    NSLog(@"[QCTestKit] 元素: %@", self.operation.elementInfo);

    if (self.associatedPackets.count > 0) {
        NSLog(@"[QCTestKit] ========== 关联的请求 ==========");
        for (QCNetworkPacket *packet in self.associatedPackets) {
            NSLog(@"[QCTestKit]   - %@ %@ %ld (%.0fms)",
                  packet.method, packet.url, (long)packet.statusCode, [packet.duration doubleValue]);
        }
    }
    NSLog(@"[QCTestKit] ========== 详情结束 ==========");
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count + (self.associatedPackets.count > 0 ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < self.sections.count) {
        NSArray *items = self.sections[section][@"items"];
        return items.count;
    } else {
        return self.associatedPackets.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < self.sections.count) {
        return self.sections[section][@"title"];
    } else {
        return [NSString stringWithFormat:@"关联的请求 (%lu)", (unsigned long)self.associatedPackets.count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"DetailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }

    if (indexPath.section < self.sections.count) {
        NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
        cell.textLabel.text = item[@"label"];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
        cell.detailTextLabel.text = item[@"value"];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        QCNetworkPacket *packet = self.associatedPackets[indexPath.row];
        NSString *displayUrl = packet.url;
        if (displayUrl.length > 50) {
            displayUrl = [NSString stringWithFormat:@"...%@", [displayUrl substringFromIndex:displayUrl.length - 47]];
        }
        cell.textLabel.text = displayUrl;
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.textLabel.numberOfLines = 2;

        NSString *methodBadge = [self methodBadge:packet.method];
        NSString *statusIcon = (packet.statusCode >= 200 && packet.statusCode < 300) ? @"OK" :
                               (packet.statusCode >= 400) ? @"ERR" : @"WARN";

        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %ld (%.0fms)",
                                      methodBadge, statusIcon, (long)packet.statusCode,
                                      [packet.duration doubleValue]];

        if (packet.statusCode >= 200 && packet.statusCode < 300) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.2 alpha:1.0];
        } else if (packet.statusCode >= 400) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
        } else {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.8 alpha:1.0];
        }

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section >= self.sections.count) {
        QCNetworkPacket *packet = self.associatedPackets[indexPath.row];
        QCNetworkRequestDetailViewController *detailVC = [[QCNetworkRequestDetailViewController alloc] initWithPacket:packet];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (NSString *)formatDate:(NSDate *)date {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });
    return [formatter stringFromDate:date];
}

- (NSString *)methodBadge:(NSString *)method {
    if ([method isEqualToString:@"GET"]) return @"GET";
    if ([method isEqualToString:@"POST"]) return @"POST";
    if ([method isEqualToString:@"PUT"]) return @"PUT";
    if ([method isEqualToString:@"DELETE"]) return @"DELETE";
    if ([method isEqualToString:@"PATCH"]) return @"PATCH";
    return method;
}

- (NSString *)typeName:(QCNetworkOperationType)type {
    switch (type) {
        case QCNetworkOperationTypeClick: return @"点击";
        case QCNetworkOperationTypeInput: return @"输入";
        case QCNetworkOperationTypeSubmit: return @"提交";
        case QCNetworkOperationTypeScroll: return @"滚动";
        case QCNetworkOperationTypeSearch: return @"搜索";
        case QCNetworkOperationTypeNavigation: return @"导航";
        case QCNetworkOperationTypePageLoad: return @"页面加载";
        default: return @"未知";
    }
}

@end
