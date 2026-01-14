//
//  QCNetworkTestViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCNetworkTestViewController.h"
#import "QCButtonStyler.h"
#import "QCLocalHTTPServer.h"
#import "QCLogger.h"
#import "QCNetworkTestResult.h"

@interface QCNetworkTestCell : UITableViewCell

@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UILabel *detailLabel;
@property(nonatomic, strong) UIButton *testButton;

- (void)configureWithName:(NSString *)name detail:(NSString *)detail;

@end

@implementation QCNetworkTestCell

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

  // 测试按钮 - 应用现代化样式
  self.testButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.testButton setTitle:@"测试" forState:UIControlStateNormal];
  self.testButton.translatesAutoresizingMaskIntoConstraints = NO;
  [containerView addSubview:self.testButton];
  [QCButtonStyler applyStyle:QCButtonStylePrimary
                        size:QCButtonSizeMedium
                    toButton:self.testButton];

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

    [self.nameLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor
                                             constant:12],
    [self.nameLabel.leadingAnchor
        constraintEqualToAnchor:containerView.leadingAnchor
                       constant:16],
    [self.nameLabel.trailingAnchor
        constraintEqualToAnchor:self.testButton.leadingAnchor
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

    [self.testButton.centerYAnchor
        constraintEqualToAnchor:containerView.centerYAnchor],
    [self.testButton.trailingAnchor
        constraintEqualToAnchor:containerView.trailingAnchor
                       constant:-16],
    [self.testButton.widthAnchor constraintEqualToConstant:70],
    [self.testButton.heightAnchor constraintEqualToConstant:36]
  ]];
}

- (void)configureWithName:(NSString *)name detail:(NSString *)detail {
  self.nameLabel.text = name;
  self.detailLabel.text = detail;
}

@end

#pragma mark - Test Scenario Model

@interface QCNetworkScenario : NSObject

@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic, copy) NSString *endpoint;
@property(nonatomic, strong) NSArray<NSNumber *> *statusCodes;

@end

@implementation QCNetworkScenario
@end

#pragma mark - Main ViewController

@interface QCNetworkTestViewController () <UITableViewDelegate,
                                           UITableViewDataSource>

@property(nonatomic, strong) UISegmentedControl *segmentedControl;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIActivityIndicatorView *serverIndicator;
@property(nonatomic, strong) UILabel *serverStatusLabel;

@property(nonatomic, strong) NSArray<QCNetworkScenario *> *presetScenarios;
@property(nonatomic, strong) NSArray<QCNetworkScenario *> *redirectScenarios;
@property(nonatomic, strong) NSArray<QCNetworkScenario *> *clientErrorScenarios;
@property(nonatomic, strong) NSArray<QCNetworkScenario *> *serverErrorScenarios;
@property(nonatomic, strong) NSArray<QCNetworkScenario *> *specialScenarios;

@property(nonatomic, strong) NSArray<QCNetworkScenario *> *currentScenarios;

@end

@implementation QCNetworkTestViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupNavigationWithTitle:@"网络测试"];

  [self setupScenarios];
  [self setupSegmentedControl];
  [self setupTableView];
  [self setupServerStatus];

  // 延迟启动服务器，避免在 viewDidLoad 中阻塞
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [self startLocalServer];
      });
}

- (void)setupScenarios {
  // 2xx 成功场景
  self.presetScenarios = @[
    [self scenarioWithName:@"200 OK"
                    detail:@"成功响应"
                  endpoint:@"/test/200"
               statusCodes:@[ @200 ]],
    [self scenarioWithName:@"201 Created"
                    detail:@"资源已创建"
                  endpoint:@"/test/201"
               statusCodes:@[ @201 ]],
    [self scenarioWithName:@"204 No Content"
                    detail:@"无内容返回"
                  endpoint:@"/test/204"
               statusCodes:@[ @204 ]]
  ];

  // 3xx 重定向场景
  self.redirectScenarios = @[
    [self scenarioWithName:@"301 Moved Permanently"
                    detail:@"永久重定向"
                  endpoint:@"/test/301"
               statusCodes:@[ @301 ]],
    [self scenarioWithName:@"302 Found"
                    detail:@"临时重定向"
                  endpoint:@"/test/302"
               statusCodes:@[ @302 ]],
    [self scenarioWithName:@"304 Not Modified"
                    detail:@"资源未修改"
                  endpoint:@"/test/304"
               statusCodes:@[ @304 ]],
    [self scenarioWithName:@"307 Temporary Redirect"
                    detail:@"临时重定向(保持方法)"
                  endpoint:@"/test/307"
               statusCodes:@[ @307 ]]
  ];

  // 4xx 客户端错误
  self.clientErrorScenarios = @[
    [self scenarioWithName:@"400 Bad Request"
                    detail:@"错误请求"
                  endpoint:@"/test/400"
               statusCodes:@[ @400 ]],
    [self scenarioWithName:@"401 Unauthorized"
                    detail:@"未授权"
                  endpoint:@"/test/401"
               statusCodes:@[ @401 ]],
    [self scenarioWithName:@"403 Forbidden"
                    detail:@"禁止访问"
                  endpoint:@"/test/403"
               statusCodes:@[ @403 ]],
    [self scenarioWithName:@"404 Not Found"
                    detail:@"资源未找到"
                  endpoint:@"/test/404"
               statusCodes:@[ @404 ]],
    [self scenarioWithName:@"429 Too Many Requests"
                    detail:@"请求过多"
                  endpoint:@"/test/429"
               statusCodes:@[ @429 ]]
  ];

  // 5xx 服务器错误
  self.serverErrorScenarios = @[
    [self scenarioWithName:@"500 Internal Server Error"
                    detail:@"服务器内部错误"
                  endpoint:@"/test/500"
               statusCodes:@[ @500 ]],
    [self scenarioWithName:@"502 Bad Gateway"
                    detail:@"网关错误"
                  endpoint:@"/test/502"
               statusCodes:@[ @502 ]],
    [self scenarioWithName:@"503 Service Unavailable"
                    detail:@"服务不可用"
                  endpoint:@"/test/503"
               statusCodes:@[ @503 ]],
    [self scenarioWithName:@"504 Gateway Timeout"
                    detail:@"网关超时"
                  endpoint:@"/test/504"
               statusCodes:@[ @504 ]]
  ];

  // 特殊场景
  self.specialScenarios = @[
    [self scenarioWithName:@"延迟响应"
                    detail:@"2秒延迟后返回成功"
                  endpoint:@"/test/delay"
               statusCodes:@[ @200 ]],
    [self
        scenarioWithName:@"DNS 失败"
                  detail:@"访问不存在的域名"
                endpoint:@"http://"
                         @"this-domain-definitely-does-not-exist-12345.com/test"
             statusCodes:@[ @0 ]],
    [self scenarioWithName:@"超时"
                    detail:@"请求超时(连接不存在的服务器)"
                  endpoint:@"http://192.0.2.1:12345/test"
               statusCodes:@[ @0 ]]
  ];

  // 默认显示2xx场景
  self.currentScenarios = self.presetScenarios;
}

- (QCNetworkScenario *)scenarioWithName:(NSString *)name
                                 detail:(NSString *)detail
                               endpoint:(NSString *)endpoint
                            statusCodes:(NSArray<NSNumber *> *)statusCodes {
  QCNetworkScenario *scenario = [[QCNetworkScenario alloc] init];
  scenario.name = name;
  scenario.detail = detail;
  scenario.endpoint = endpoint;
  scenario.statusCodes = statusCodes;
  return scenario;
}

- (void)setupSegmentedControl {
  self.segmentedControl = [[UISegmentedControl alloc]
      initWithItems:@[ @"2xx", @"3xx", @"4xx", @"5xx", @"特殊" ]];
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

- (void)setupTableView {
  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                style:UITableViewStylePlain];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.backgroundColor = [UIColor clearColor];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:self.tableView];

  // 先添加服务器状态视图，再设置 tableView 约束
  [self setupServerStatus];

  [NSLayoutConstraint activateConstraints:@[
    [self.tableView.topAnchor
        constraintEqualToAnchor:self.segmentedControl.bottomAnchor
                       constant:12],
    [self.tableView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tableView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor
                                                constant:-60] // 留出状态栏空间
  ]];

  [self.tableView registerClass:[QCNetworkTestCell class]
         forCellReuseIdentifier:@"NetworkTestCell"];
}

- (void)setupServerStatus {
  UIView *statusContainer = [[UIView alloc] init];
  statusContainer.backgroundColor = [UIColor colorWithRed:0.1
                                                    green:0.1
                                                     blue:0.15
                                                    alpha:1.0];
  statusContainer.layer.cornerRadius = 8;
  statusContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:statusContainer];

  self.serverIndicator = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  self.serverIndicator.color = [UIColor orangeColor];
  self.serverIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  [statusContainer addSubview:self.serverIndicator];
  [self.serverIndicator startAnimating];

  self.serverStatusLabel = [[UILabel alloc] init];
  self.serverStatusLabel.text = @"正在启动本地服务器...";
  self.serverStatusLabel.font = [UIFont systemFontOfSize:13];
  self.serverStatusLabel.textColor = [UIColor whiteColor];
  self.serverStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [statusContainer addSubview:self.serverStatusLabel];

  [NSLayoutConstraint activateConstraints:@[
    [statusContainer.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor
                       constant:16],
    [statusContainer.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor
                       constant:-16],
    [statusContainer.bottomAnchor
        constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                       constant:-8],
    [statusContainer.heightAnchor constraintEqualToConstant:36],

    [self.serverIndicator.leadingAnchor
        constraintEqualToAnchor:statusContainer.leadingAnchor
                       constant:12],
    [self.serverIndicator.centerYAnchor
        constraintEqualToAnchor:statusContainer.centerYAnchor],

    [self.serverStatusLabel.leadingAnchor
        constraintEqualToAnchor:self.serverIndicator.trailingAnchor
                       constant:8],
    [self.serverStatusLabel.trailingAnchor
        constraintEqualToAnchor:statusContainer.trailingAnchor
                       constant:-12],
    [self.serverStatusLabel.centerYAnchor
        constraintEqualToAnchor:statusContainer.centerYAnchor]
  ]];
}

- (void)startLocalServer {
  QCLocalHTTPServer *server = [QCLocalHTTPServer sharedServer];
  [server
      startServerWithPort:8080
               completion:^(BOOL success, NSError *error) {
                 [self.serverIndicator stopAnimating];

                 if (success) {
                   self.serverIndicator.color = [UIColor systemGreenColor];
                   [self.serverIndicator startAnimating];
                   self.serverStatusLabel.text = [NSString
                       stringWithFormat:@"本地服务器运行中 - 端口: %ld",
                                        (long)server.port];
                   [[QCLogger sharedLogger] info:@"本地HTTP服务器启动成功"];
                 } else {
                   self.serverIndicator.color = [UIColor systemRedColor];
                   [self.serverIndicator startAnimating];
                   self.serverStatusLabel.text =
                       [NSString stringWithFormat:@"服务器启动失败: %@",
                                                  error.localizedDescription];
                   [[QCLogger sharedLogger] error:@"本地HTTP服务器启动失败: %@",
                                                  error.localizedDescription];
                 }
               }];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
  switch (sender.selectedSegmentIndex) {
  case 0:
    self.currentScenarios = self.presetScenarios;
    break;
  case 1:
    self.currentScenarios = self.redirectScenarios;
    break;
  case 2:
    self.currentScenarios = self.clientErrorScenarios;
    break;
  case 3:
    self.currentScenarios = self.serverErrorScenarios;
    break;
  case 4:
    self.currentScenarios = self.specialScenarios;
    break;
  default:
    self.currentScenarios = self.presetScenarios;
    break;
  }

  [self.tableView reloadData];
}

#pragma mark - Network Testing

- (void)runTestForScenario:(QCNetworkScenario *)scenario {
  [self showLoading];

  NSString *urlString = scenario.endpoint;
  if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
    urlString = [NSString
        stringWithFormat:@"http://localhost:8080%@", scenario.endpoint];
  }

  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    [self hideLoading];
    [self showError:@"无效的URL"];
    return;
  }

  NSDate *startTime = [NSDate date];

  NSURLSessionConfiguration *config =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  config.timeoutIntervalForRequest = 10;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

  NSURLSessionDataTask *task = [session
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *response,
                          NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self hideLoading];

          NSTimeInterval responseTime =
              [[NSDate date] timeIntervalSinceDate:startTime];

          QCNetworkTestResult *result = [[QCNetworkTestResult alloc] init];
          result.testName = scenario.name;
          result.URL = urlString;
          result.responseTime = responseTime;

          if (error) {
            result.success = NO;
            result.error = error;
            result.statusCode = error.code;
            [[QCLogger sharedLogger] error:@"网络测试失败: %@ - %@",
                                           scenario.name,
                                           error.localizedDescription];
          } else {
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
              result.statusCode = httpResponse.statusCode;
              result.responseHeaders = httpResponse.allHeaderFields;
            }

            result.success = YES;

            if (data) {
              result.responseBody =
                  [[NSString alloc] initWithData:data
                                        encoding:NSUTF8StringEncoding];
            }

            [[QCLogger sharedLogger] info:@"网络测试成功: %@ - 状态码: %ld",
                                          scenario.name,
                                          (long)result.statusCode];
          }

          [self showTestResult:result];
        });
      }];

  [task resume];
}

- (void)showTestResult:(QCNetworkTestResult *)result {
  NSString *message;
  if (result.success) {
    message = [NSString stringWithFormat:@"状态码: %ld\n耗时: %.0fms\n响应: %@",
                                         (long)result.statusCode,
                                         result.responseTime * 1000,
                                         result.responseBody ?: @"(空)"];
  } else {
    message = [NSString
        stringWithFormat:@"错误: %@", result.error.localizedDescription];
  }

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:result.testName
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];

  [alert
      addAction:[UIAlertAction actionWithTitle:@"复制"
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action) {
                                         UIPasteboard.generalPasteboard.string =
                                             message;
                                         [self showMessage:@"已复制到剪贴板"];
                                       }]];

  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return self.currentScenarios.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  QCNetworkTestCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"NetworkTestCell"
                                      forIndexPath:indexPath];

  QCNetworkScenario *scenario = self.currentScenarios[indexPath.row];
  [cell configureWithName:scenario.name detail:scenario.detail];

  cell.testButton.tag = indexPath.row;
  [cell.testButton removeTarget:nil
                         action:nil
               forControlEvents:UIControlEventTouchUpInside];
  [cell.testButton addTarget:self
                      action:@selector(testButtonTapped:)
            forControlEvents:UIControlEventTouchUpInside];

  return cell;
}

#pragma mark - Actions

- (void)testButtonTapped:(UIButton *)sender {
  NSInteger index = sender.tag;
  if (index >= 0 && index < self.currentScenarios.count) {
    QCNetworkScenario *scenario = self.currentScenarios[index];
    [self runTestForScenario:scenario];
  }
}

@end
