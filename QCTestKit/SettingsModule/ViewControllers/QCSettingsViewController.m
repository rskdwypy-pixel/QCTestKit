//
//  QCSettingsViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCSettingsViewController.h"
#import "QCLogger.h"

@interface QCSettingsCell : UITableViewCell

@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *detailLabel;
@property(nonatomic, strong) UISwitch *toggleSwitch;
@property(nonatomic, strong) UIImageView *arrowImageView;

- (void)configureWithTitle:(NSString *)title
                    detail:(NSString *)detail
                showSwitch:(BOOL)showSwitch
                 showArrow:(BOOL)showArrow;

@end

@implementation QCSettingsCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // 容器视图 - 应用现代化卡片样式
    UIView *containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor colorWithRed:0.12
                                                    green:0.12
                                                     blue:0.18
                                                    alpha:1.0];
    containerView.layer.cornerRadius = 14;
    containerView.layer.shadowColor =
        [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.25].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 3);
    containerView.layer.shadowRadius = 6;
    containerView.layer.shadowOpacity = 1.0;
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:containerView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.titleLabel];

    self.detailLabel = [[UILabel alloc] init];
    self.detailLabel.font = [UIFont systemFontOfSize:13];
    self.detailLabel.textColor =
        [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.detailLabel];

    self.toggleSwitch = [[UISwitch alloc] init];
    self.toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.toggleSwitch.hidden = YES;
    [containerView addSubview:self.toggleSwitch];

    self.arrowImageView = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    self.arrowImageView.tintColor =
        [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    self.arrowImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.arrowImageView.hidden = YES;
    [containerView addSubview:self.arrowImageView];

    [NSLayoutConstraint activateConstraints:@[
      [containerView.topAnchor
          constraintEqualToAnchor:self.contentView.topAnchor
                         constant:4],
      [containerView.leadingAnchor
          constraintEqualToAnchor:self.contentView.leadingAnchor
                         constant:16],
      [containerView.trailingAnchor
          constraintEqualToAnchor:self.contentView.trailingAnchor
                         constant:-16],
      [containerView.bottomAnchor
          constraintEqualToAnchor:self.contentView.bottomAnchor
                         constant:-4],

      [self.titleLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor
                                                constant:12],
      [self.titleLabel.leadingAnchor
          constraintEqualToAnchor:containerView.leadingAnchor
                         constant:16],
      [self.titleLabel.trailingAnchor
          constraintEqualToAnchor:self.toggleSwitch.leadingAnchor
                         constant:-12],

      [self.detailLabel.topAnchor
          constraintEqualToAnchor:self.titleLabel.bottomAnchor
                         constant:4],
      [self.detailLabel.leadingAnchor
          constraintEqualToAnchor:self.titleLabel.leadingAnchor],
      [self.detailLabel.trailingAnchor
          constraintEqualToAnchor:self.titleLabel.trailingAnchor],
      [self.detailLabel.bottomAnchor
          constraintEqualToAnchor:containerView.bottomAnchor
                         constant:-12],

      [self.toggleSwitch.centerYAnchor
          constraintEqualToAnchor:containerView.centerYAnchor],
      [self.toggleSwitch.trailingAnchor
          constraintEqualToAnchor:containerView.trailingAnchor
                         constant:-16],

      [self.arrowImageView.centerYAnchor
          constraintEqualToAnchor:containerView.centerYAnchor],
      [self.arrowImageView.trailingAnchor
          constraintEqualToAnchor:containerView.trailingAnchor
                         constant:-16]
    ]];
  }
  return self;
}

- (void)configureWithTitle:(NSString *)title
                    detail:(NSString *)detail
                showSwitch:(BOOL)showSwitch
                 showArrow:(BOOL)showArrow {
  self.titleLabel.text = title;
  self.detailLabel.text = detail;
  self.detailLabel.hidden = !detail;

  self.toggleSwitch.hidden = !showSwitch;
  self.arrowImageView.hidden = !showArrow;

  if (!showSwitch && !showArrow) {
    // 移除右侧约束，让标题占满宽度
    for (NSLayoutConstraint *c in self.titleLabel.constraints) {
      if (c.secondItem == self.toggleSwitch) {
        [self.titleLabel removeConstraint:c];
      }
    }
    [self.titleLabel.trailingAnchor
        constraintEqualToAnchor:self.detailLabel.trailingAnchor]
        .active = YES;
  }
}

@end

#pragma mark - Main ViewController

@interface QCSettingsViewController () <UITableViewDelegate,
                                        UITableViewDataSource>

@property(nonatomic, strong) UITableView *tableView;

@property(nonatomic, strong) NSArray<NSDictionary *> *settingsItems;

@end

@implementation QCSettingsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupNavigationWithTitle:@"设置"];

  [self setupSettingsItems];
  [self setupTableView];
}

- (void)setupSettingsItems {
  self.settingsItems = @[
    @{
      @"title" : @"应用信息",
      @"items" : @[
        @{@"title" : @"版本", @"detail" : @"1.0.0", @"type" : @"info"},
        @{@"title" : @"构建", @"detail" : @"1", @"type" : @"info"}
      ]
    },
    @{
      @"title" : @"日志",
      @"items" : @[
        @{
          @"title" : @"查看日志",
          @"detail" : @"查看应用运行日志",
          @"type" : @"action",
          @"action" : @"viewLogs"
        },
        @{
          @"title" : @"清除日志",
          @"detail" : @"清空所有日志记录",
          @"type" : @"action",
          @"action" : @"clearLogs"
        },
        @{
          @"title" : @"导出日志",
          @"detail" : @"导出日志到剪贴板",
          @"type" : @"action",
          @"action" : @"exportLogs"
        }
      ]
    },
    @{
      @"title" : @"关于",
      @"items" : @[ @{
        @"title" : @"关于 QCTestKit",
        @"detail" : @"自动化测试工具",
        @"type" : @"action",
        @"action" : @"about"
      } ]
    }
  ];
}

- (void)setupTableView {
  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                style:UITableViewStyleGrouped];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.backgroundColor = [UIColor clearColor];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:self.tableView];

  [NSLayoutConstraint activateConstraints:@[
    [self.tableView.topAnchor
        constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [self.tableView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tableView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
  ]];

  [self.tableView registerClass:[QCSettingsCell class]
         forCellReuseIdentifier:@"SettingsCell"];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return self.settingsItems.count;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return [self.settingsItems[section][@"items"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  QCSettingsCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"SettingsCell"
                                      forIndexPath:indexPath];

  NSDictionary *item =
      self.settingsItems[indexPath.section][@"items"][indexPath.row];
  NSString *type = item[@"type"];

  BOOL showSwitch = [type isEqualToString:@"switch"];
  BOOL showArrow =
      [type isEqualToString:@"action"] || [type isEqualToString:@"disclosure"];

  [cell configureWithTitle:item[@"title"]
                    detail:item[@"detail"]
                showSwitch:showSwitch
                 showArrow:showArrow];

  if (showSwitch) {
    cell.toggleSwitch.on = [item[@"boolValue"] boolValue];
    [cell.toggleSwitch removeTarget:nil
                             action:nil
                   forControlEvents:UIControlEventValueChanged];
    [cell.toggleSwitch addTarget:self
                          action:@selector(switchToggled:)
                forControlEvents:UIControlEventValueChanged];
  }

  return cell;
}

- (NSDictionary *)sectionItems:(NSInteger)section {
  return self.settingsItems[section];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  NSDictionary *item =
      self.settingsItems[indexPath.section][@"items"][indexPath.row];
  NSString *action = item[@"action"];

  if ([action isEqualToString:@"viewLogs"]) {
    [self viewLogs];
  } else if ([action isEqualToString:@"clearLogs"]) {
    [self clearLogs];
  } else if ([action isEqualToString:@"exportLogs"]) {
    [self exportLogs];
  } else if ([action isEqualToString:@"about"]) {
    [self showAbout];
  }
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  return self.settingsItems[section][@"title"];
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForHeaderInSection:(NSInteger)section {
  return 40;
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForFooterInSection:(NSInteger)section {
  return 10;
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
  CGPoint center = sender.center;
  CGPoint point = [sender convertPoint:center toView:self.tableView];
  NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];

  if (indexPath) {
    NSLog(@"Switch at section:%ld row:%ld toggled to %d",
          (long)indexPath.section, (long)indexPath.row, sender.on);
  }
}

- (void)viewLogs {
  NSArray *logs = [[QCLogger sharedLogger] getAllLogs];
  NSString *logText =
      logs.count > 0 ? [logs componentsJoinedByString:@"\n"] : @"暂无日志";

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"应用日志"
                                          message:logText
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:@"关闭"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearLogs {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"清除日志"
                                          message:@"确定要清空所有日志记录吗？"
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"清除"
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
                                            [[QCLogger sharedLogger] clearLogs];
                                            [self showMessage:@"日志已清空"];
                                          }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportLogs {
  NSString *logText = [[QCLogger sharedLogger] exportLogs];

  if (logText.length > 0) {
    UIPasteboard.generalPasteboard.string = logText;
    [self showMessage:@"日志已复制到剪贴板"];
  } else {
    [self showMessage:@"暂无日志可导出"];
  }
}

- (void)showAbout {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"关于 QCTestKit"
                       message:
                           @"QCTestKit 是一个专业的 iOS 自动化测试工具。\n\n"
                           @"功能：\n"
                           @"• 内置浏览器\n"
                           @"• 网络状态测试\n"
                           @"• 崩溃和性能测试\n\n"
                           @"Version 1.0.0\n"
                           @"Created with Claude"
                preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

@end
