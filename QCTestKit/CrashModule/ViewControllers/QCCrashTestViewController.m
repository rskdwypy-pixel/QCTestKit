//
//  QCCrashTestViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCCrashTestViewController.h"
#import "QCButtonStyler.h"
#import "QCCrashSimulator.h"
#import "QCCrashTestItem.h"
#import "QCLogger.h"

@interface QCCrashTestCell : UITableViewCell

@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UILabel *detailLabel;
@property(nonatomic, strong) UIButton *triggerButton;
@property(nonatomic, strong) UIView *dangerIndicator;

- (void)configureWithItem:(QCCrashTestItem *)item;

@end

@implementation QCCrashTestCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  // 容器视图 - 应用现代化卡片样式
  UIView *containerView = [[UIView alloc] init];
  containerView.backgroundColor = [UIColor colorWithRed:0.12
                                                  green:0.12
                                                   blue:0.18
                                                  alpha:1.0];
  containerView.layer.cornerRadius = 16;
  containerView.layer.shadowColor =
      [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.3].CGColor;
  containerView.layer.shadowOffset = CGSizeMake(0, 4);
  containerView.layer.shadowRadius = 8;
  containerView.layer.shadowOpacity = 1.0;
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:containerView];

  // 危险指示器 - 添加发光效果
  self.dangerIndicator = [[UIView alloc] init];
  self.dangerIndicator.backgroundColor = [UIColor colorWithRed:1.0
                                                         green:0.3
                                                          blue:0.3
                                                         alpha:1.0];
  self.dangerIndicator.layer.cornerRadius = 4;
  self.dangerIndicator.layer.shadowColor =
      [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.8].CGColor;
  self.dangerIndicator.layer.shadowOffset = CGSizeZero;
  self.dangerIndicator.layer.shadowRadius = 4;
  self.dangerIndicator.layer.shadowOpacity = 1.0;
  self.dangerIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  self.dangerIndicator.hidden = YES;
  [containerView addSubview:self.dangerIndicator];

  // 名称标签
  self.nameLabel = [[UILabel alloc] init];
  self.nameLabel.font = [UIFont boldSystemFontOfSize:16];
  self.nameLabel.textColor = [UIColor whiteColor];
  self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [containerView addSubview:self.nameLabel];

  // 详情标签
  self.detailLabel = [[UILabel alloc] init];
  self.detailLabel.font = [UIFont systemFontOfSize:13];
  self.detailLabel.textColor =
      [[UIColor whiteColor] colorWithAlphaComponent:0.6];
  self.detailLabel.numberOfLines = 0;
  self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [containerView addSubview:self.detailLabel];

  // 触发按钮
  self.triggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.triggerButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
  self.triggerButton.layer.cornerRadius = 8;
  self.triggerButton.translatesAutoresizingMaskIntoConstraints = NO;
  [containerView addSubview:self.triggerButton];

  [NSLayoutConstraint activateConstraints:@[
    [containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor
                                            constant:8],
    [containerView.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor
                       constant:16],
    [containerView.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor
                       constant:-16],
    [containerView.bottomAnchor
        constraintEqualToAnchor:self.contentView.bottomAnchor
                       constant:-8],

    [self.dangerIndicator.leadingAnchor
        constraintEqualToAnchor:containerView.leadingAnchor
                       constant:12],
    [self.dangerIndicator.topAnchor
        constraintEqualToAnchor:containerView.topAnchor
                       constant:12],
    [self.dangerIndicator.widthAnchor constraintEqualToConstant:6],
    [self.dangerIndicator.heightAnchor constraintEqualToConstant:6],

    [self.nameLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor
                                             constant:12],
    [self.nameLabel.leadingAnchor
        constraintEqualToAnchor:self.dangerIndicator.trailingAnchor
                       constant:8],
    [self.nameLabel.trailingAnchor
        constraintEqualToAnchor:self.triggerButton.leadingAnchor
                       constant:-12],

    [self.detailLabel.topAnchor
        constraintEqualToAnchor:self.nameLabel.bottomAnchor
                       constant:4],
    [self.detailLabel.leadingAnchor
        constraintEqualToAnchor:self.nameLabel.leadingAnchor],
    [self.detailLabel.trailingAnchor
        constraintEqualToAnchor:self.nameLabel.trailingAnchor],
    [self.detailLabel.bottomAnchor
        constraintEqualToAnchor:containerView.bottomAnchor
                       constant:-12],

    [self.triggerButton.centerYAnchor
        constraintEqualToAnchor:containerView.centerYAnchor],
    [self.triggerButton.trailingAnchor
        constraintEqualToAnchor:containerView.trailingAnchor
                       constant:-16],
    [self.triggerButton.widthAnchor constraintEqualToConstant:70],
    [self.triggerButton.heightAnchor constraintEqualToConstant:36]
  ]];
}

- (void)configureWithItem:(QCCrashTestItem *)item {
  self.nameLabel.text = item.name;
  self.detailLabel.text = item.detail;
  self.dangerIndicator.hidden = !item.isDestructive;

  if (item.isDestructive) {
    [self.triggerButton setTitle:@"触发" forState:UIControlStateNormal];
    [QCButtonStyler applyStyle:QCButtonStyleDestructive
                          size:QCButtonSizeMedium
                      toButton:self.triggerButton];
  } else {
    [self.triggerButton setTitle:@"执行" forState:UIControlStateNormal];
    [QCButtonStyler applyStyle:QCButtonStyleWarning
                          size:QCButtonSizeMedium
                      toButton:self.triggerButton];
  }
}

@end

#pragma mark - Performance Monitor View

@interface QCPerformanceMonitorView : UIView

@property(nonatomic, strong) UILabel *cpuLabel;
@property(nonatomic, strong) UILabel *memoryLabel;
@property(nonatomic, strong) UIProgressView *cpuProgress;
@property(nonatomic, strong) UIProgressView *memoryProgress;

- (void)updateWithCPU:(CGFloat)cpu memory:(CGFloat)memory;

@end

@implementation QCPerformanceMonitorView

- (instancetype)init {
  self = [super init];
  if (self) {
    self.backgroundColor = [UIColor colorWithRed:0.1
                                           green:0.1
                                            blue:0.15
                                           alpha:1.0];
    self.layer.cornerRadius = 12;

    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  // CPU 标签
  self.cpuLabel = [[UILabel alloc] init];
  self.cpuLabel.font = [UIFont systemFontOfSize:13];
  self.cpuLabel.textColor = [UIColor whiteColor];
  self.cpuLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.cpuLabel];

  self.cpuProgress = [[UIProgressView alloc]
      initWithProgressViewStyle:UIProgressViewStyleDefault];
  self.cpuProgress.progressTintColor = [UIColor systemGreenColor];
  self.cpuProgress.trackTintColor =
      [[UIColor whiteColor] colorWithAlphaComponent:0.2];
  self.cpuProgress.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.cpuProgress];

  // 内存标签
  self.memoryLabel = [[UILabel alloc] init];
  self.memoryLabel.font = [UIFont systemFontOfSize:13];
  self.memoryLabel.textColor = [UIColor whiteColor];
  self.memoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.memoryLabel];

  self.memoryProgress = [[UIProgressView alloc]
      initWithProgressViewStyle:UIProgressViewStyleDefault];
  self.memoryProgress.progressTintColor = [UIColor systemBlueColor];
  self.memoryProgress.trackTintColor =
      [[UIColor whiteColor] colorWithAlphaComponent:0.2];
  self.memoryProgress.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.memoryProgress];

  [NSLayoutConstraint activateConstraints:@[
    [self.cpuLabel.topAnchor constraintEqualToAnchor:self.topAnchor
                                            constant:12],
    [self.cpuLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                                constant:16],
    [self.cpuLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                 constant:-16],

    [self.cpuProgress.topAnchor
        constraintEqualToAnchor:self.cpuLabel.bottomAnchor
                       constant:6],
    [self.cpuProgress.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                                   constant:16],
    [self.cpuProgress.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                    constant:-16],
    [self.cpuProgress.heightAnchor constraintEqualToConstant:8],

    [self.memoryLabel.topAnchor
        constraintEqualToAnchor:self.cpuProgress.bottomAnchor
                       constant:12],
    [self.memoryLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                                   constant:16],
    [self.memoryLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                    constant:-16],

    [self.memoryProgress.topAnchor
        constraintEqualToAnchor:self.memoryLabel.bottomAnchor
                       constant:6],
    [self.memoryProgress.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:16],
    [self.memoryProgress.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor
                       constant:-16],
    [self.memoryProgress.heightAnchor constraintEqualToConstant:8]
  ]];

  [self updateWithCPU:0 memory:0];
}

- (void)updateWithCPU:(CGFloat)cpu memory:(CGFloat)memory {
  self.cpuLabel.text = [NSString stringWithFormat:@"CPU: %.1f%%", cpu];
  self.memoryLabel.text = [NSString stringWithFormat:@"内存: %.1f MB", memory];

  self.cpuProgress.progress = MIN(cpu / 100.0, 1.0);
  self.memoryProgress.progress = MIN(memory / 500.0, 1.0);

  // 根据使用率改变颜色
  if (cpu > 80) {
    self.cpuProgress.progressTintColor = [UIColor systemRedColor];
  } else if (cpu > 50) {
    self.cpuProgress.progressTintColor = [UIColor systemOrangeColor];
  } else {
    self.cpuProgress.progressTintColor = [UIColor systemGreenColor];
  }

  if (memory > 400) {
    self.memoryProgress.progressTintColor = [UIColor systemRedColor];
  } else if (memory > 250) {
    self.memoryProgress.progressTintColor = [UIColor systemOrangeColor];
  } else {
    self.memoryProgress.progressTintColor = [UIColor systemBlueColor];
  }
}

@end

#pragma mark - Main ViewController

@interface QCCrashTestViewController () <UITableViewDelegate,
                                         UITableViewDataSource>

@property(nonatomic, strong) UISegmentedControl *segmentedControl;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) QCPerformanceMonitorView *monitorView;

@property(nonatomic, strong) NSArray<QCCrashTestItem *> *basicCrashes;
@property(nonatomic, strong) NSArray<QCCrashTestItem *> *performanceIssues;
@property(nonatomic, strong) NSArray<QCCrashTestItem *> *advancedTests;
@property(nonatomic, strong) NSArray<QCCrashTestItem *> *currentTests;

@property(nonatomic, strong) NSTimer *performanceTimer;

@end

@implementation QCCrashTestViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupNavigationWithTitle:@"崩溃测试"];

  [self setupTestData];
  [self setupSegmentedControl];
  [self setupMonitorView];
  [self setupTableView];

  // 启动性能监控
  [self startPerformanceMonitoring];
}

- (void)dealloc {
  [self.performanceTimer invalidate];
}

- (void)setupTestData {
  // 基础崩溃
  self.basicCrashes = @[
    [QCCrashTestItem itemWithName:@"应用闪退 (abort)"
                           detail:@"立即终止应用，模拟崩溃"
                             type:QCCrashTypeAbort
                    isDestructive:YES
                         category:@"基础崩溃"],
    [QCCrashTestItem itemWithName:@"应用退出 (exit)"
                           detail:@"正常退出应用"
                             type:QCCrashTypeExit
                    isDestructive:YES
                         category:@"基础崩溃"],
    [QCCrashTestItem itemWithName:@"NSException"
                           detail:@"抛出未捕获的Objective-C异常"
                             type:QCCrashTypeNSException
                    isDestructive:YES
                         category:@"基础崩溃"],
    [QCCrashTestItem itemWithName:@"未识别方法"
                           detail:@"调用不存在的方法"
                             type:QCCrashTypeUnrecognizedSelector
                    isDestructive:YES
                         category:@"基础崩溃"],
    [QCCrashTestItem itemWithName:@"空指针访问"
                           detail:@"访问nil对象的元素"
                             type:QCCrashTypeNilPointer
                    isDestructive:YES
                         category:@"基础崩溃"]
  ];

  // 性能问题
  self.performanceIssues = @[
    [QCCrashTestItem itemWithName:@"主线程阻塞"
                           detail:@"阻塞主线程5秒，观察UI卡顿"
                             type:QCCrashTypeMainThreadBlocking
                    isDestructive:NO
                         category:@"性能问题"],
    [QCCrashTestItem itemWithName:@"UI卡顿"
                           detail:@"连续多次耗时操作"
                             type:QCCrashTypeUICatton
                    isDestructive:NO
                         category:@"性能问题"],
    [QCCrashTestItem itemWithName:@"内存泄漏"
                           detail:@"分配10MB内存并保持引用"
                             type:QCCrashTypeMemoryLeak
                    isDestructive:NO
                         category:@"性能问题"],
    [QCCrashTestItem itemWithName:@"高CPU占用"
                           detail:@"后台密集计算5秒"
                             type:QCCrashTypeHighCPU
                    isDestructive:NO
                         category:@"性能问题"]
  ];

  // 专项测试
  self.advancedTests = @[
    [QCCrashTestItem itemWithName:@"野指针"
                           detail:@"访问已释放的内存对象"
                             type:QCCrashTypeWildPointer
                    isDestructive:YES
                         category:@"专项测试"],
    [QCCrashTestItem itemWithName:@"数组越界"
                           detail:@"访问超出数组范围的索引"
                             type:QCCrashTypeArrayOutOfBounds
                    isDestructive:YES
                         category:@"专项测试"],
    [QCCrashTestItem itemWithName:@"内存溢出"
                           detail:@"连续分配大量内存（警告）"
                             type:QCCrashTypeMemoryOverflow
                    isDestructive:NO
                         category:@"专项测试"],
    [QCCrashTestItem itemWithName:@"死锁"
                           detail:@"模拟线程死锁场景"
                             type:QCCrashTypeDeadlock
                    isDestructive:NO
                         category:@"专项测试"]
  ];

  self.currentTests = self.basicCrashes;
}

- (void)setupSegmentedControl {
  self.segmentedControl = [[UISegmentedControl alloc]
      initWithItems:@[ @"基础崩溃", @"性能问题", @"专项测试" ]];
  self.segmentedControl.selectedSegmentIndex = 0;
  [self.segmentedControl addTarget:self
                            action:@selector(segmentChanged:)
                  forControlEvents:UIControlEventValueChanged];
  self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:self.segmentedControl];

  [NSLayoutConstraint activateConstraints:@[
    [self.segmentedControl.topAnchor
        constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                       constant:12],
    [self.segmentedControl.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor
                       constant:16],
    [self.segmentedControl.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor
                       constant:-16],
    [self.segmentedControl.heightAnchor constraintEqualToConstant:32]
  ]];
}

- (void)setupMonitorView {
  self.monitorView = [[QCPerformanceMonitorView alloc] init];
  self.monitorView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.monitorView];

  [NSLayoutConstraint activateConstraints:@[
    [self.monitorView.topAnchor
        constraintEqualToAnchor:self.segmentedControl.bottomAnchor
                       constant:12],
    [self.monitorView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor
                       constant:16],
    [self.monitorView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor
                       constant:-16],
    [self.monitorView.heightAnchor constraintEqualToConstant:100]
  ]];
}

- (void)setupTableView {
  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                style:UITableViewStylePlain];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.backgroundColor = [UIColor clearColor];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:self.tableView];

  [NSLayoutConstraint activateConstraints:@[
    [self.tableView.topAnchor
        constraintEqualToAnchor:self.monitorView.bottomAnchor
                       constant:12],
    [self.tableView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tableView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
  ]];

  [self.tableView registerClass:[QCCrashTestCell class]
         forCellReuseIdentifier:@"CrashTestCell"];
}

- (void)startPerformanceMonitoring {
  QCCrashSimulator *simulator = [QCCrashSimulator sharedSimulator];

  self.performanceTimer =
      [NSTimer scheduledTimerWithTimeInterval:1.0
                                       target:self
                                     selector:@selector(updatePerformance)
                                     userInfo:nil
                                      repeats:YES];

  [self updatePerformance];
}

- (void)updatePerformance {
  QCCrashSimulator *simulator = [QCCrashSimulator sharedSimulator];
  CGFloat memory = [simulator currentMemoryUsage];
  CGFloat cpu = [simulator currentCPUUsage];

  [self.monitorView updateWithCPU:cpu memory:memory];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
  switch (sender.selectedSegmentIndex) {
  case 0:
    self.currentTests = self.basicCrashes;
    break;
  case 1:
    self.currentTests = self.performanceIssues;
    break;
  case 2:
    self.currentTests = self.advancedTests;
    break;
  default:
    self.currentTests = self.basicCrashes;
    break;
  }

  [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return self.currentTests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  QCCrashTestCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"CrashTestCell"
                                      forIndexPath:indexPath];

  QCCrashTestItem *item = self.currentTests[indexPath.row];
  [cell configureWithItem:item];

  cell.triggerButton.tag = indexPath.row;
  [cell.triggerButton removeTarget:nil
                            action:nil
                  forControlEvents:UIControlEventTouchUpInside];
  [cell.triggerButton addTarget:self
                         action:@selector(triggerButtonTapped:)
               forControlEvents:UIControlEventTouchUpInside];

  return cell;
}

#pragma mark - Actions

- (void)triggerButtonTapped:(UIButton *)sender {
  NSInteger index = sender.tag;
  if (index >= 0 && index < self.currentTests.count) {
    QCCrashTestItem *item = self.currentTests[index];

    if (item.isDestructive) {
      [self showConfirmAlertForItem:item];
    } else {
      [self executeTest:item];
    }
  }
}

- (void)showConfirmAlertForItem:(QCCrashTestItem *)item {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"确认触发崩溃?"
                       message:@"此操作将导致应用崩溃或异常退出，请确保已保存重"
                               @"要数据。"
                preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"确认触发"
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
                                            [self executeTest:item];
                                          }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)executeTest:(QCCrashTestItem *)item {
  [[QCLogger sharedLogger] info:@"执行崩溃测试: %@", item.name];

  if (item.isDestructive) {
    // 破坏性测试 - 显示提示
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"即将崩溃"
                         message:[NSString
                                     stringWithFormat:
                                         @"\n测试: %@\n\n应用将在1秒后崩溃...",
                                         item.name]
                  preferredStyle:UIAlertControllerStyleAlert];

    [self presentViewController:alert
                       animated:YES
                     completion:^{
                       dispatch_after(
                           dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                             [[QCCrashSimulator sharedSimulator]
                                 triggerCrash:item.type];
                           });
                     }];
  } else {
    // 非破坏性测试 - 执行并显示结果
    [[QCCrashSimulator sharedSimulator] triggerCrash:item.type];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          [self showMessage:[NSString
                                stringWithFormat:@"已执行: %@\n请观察应用表现",
                                                 item.name]];
        });
  }
}

@end
