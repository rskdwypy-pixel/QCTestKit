//
//  QCBrowserViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCBrowserViewController.h"
#import "QCButtonStyler.h"
#import "QCDiagnosticHistoryViewController.h"
#import "QCWebDiagnosticViewController.h"
#import <WebKit/WebKit.h>

// UserDefaults keys
static NSString *const kQCBrowserClearCacheKey = @"QCBrowserClearCache";
static NSString *const kQCBrowserUseWKKey = @"QCBrowserUseWK";
static NSString *const kQCBrowserDiagnosticHistoryKey =
    @"QCBrowserDiagnosticHistory";
static NSString *const kQCBrowserMaxHistoryCount = @"50"; // 最多保存50条记录

@interface QCBrowserViewController () <WKNavigationDelegate, WKUIDelegate,
                                       UISearchBarDelegate,
                                       WKScriptMessageHandler>

@property(nonatomic, strong) UIView *webViewContainer;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong)
    UIWebView *legacyWebView; // UIWebView (已弃用但保留选项)
@property(nonatomic, strong) UISearchBar *searchBar;
@property(nonatomic, strong) UIButton *goButton;
@property(nonatomic, strong) UIToolbar *toolbar;
@property(nonatomic, strong) UIBarButtonItem *backButton;
@property(nonatomic, strong) UIBarButtonItem *forwardButton;
@property(nonatomic, strong) UIBarButtonItem *refreshButton;
@property(nonatomic, strong) UIBarButtonItem *clearCacheButton;
@property(nonatomic, strong) UIBarButtonItem *diagnosticButton;
@property(nonatomic, strong) UIProgressView *progressView;
@property(nonatomic, strong) UILabel *progressLabel;

// 导航栏设置按钮
@property(nonatomic, strong) UIBarButtonItem *clearCacheSettingButton;
@property(nonatomic, strong) UIBarButtonItem *webViewTypeButton;

@property(nonatomic, strong) NSMutableArray<NSDictionary *> *history;

// Settings
@property(nonatomic, assign) BOOL useWKWebView;
@property(nonatomic, assign) BOOL clearCacheOnStart;

// Network logging
@property(nonatomic, strong) NSMutableString *currentRequestLog;
@property(nonatomic, strong) NSDate *currentRequestStartTime;

// Diagnostics
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *>
        *resourceRequests;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *jsErrors;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *consoleLogs;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSNumber *> *timingMetrics;
@property(nonatomic, strong) NSDate *pageLoadStartTime;
@property(nonatomic, assign) long long totalBytesReceived;
@property(nonatomic, assign) NSInteger failedResourceCount;

// 加载状态跟踪
@property(nonatomic, assign) float lastProgress;
@property(nonatomic, assign) NSInteger progressJumpCount; // 进度突变次数
@property(nonatomic, assign) BOOL isLoadingFromCache;     // 是否从缓存加载
@property(nonatomic, assign) BOOL loadFailed;             // 加载是否失败
@property(nonatomic, strong) NSError *loadError;          // 加载错误信息
@property(nonatomic, strong)
    NSMutableArray<NSNumber *> *progressHistory; // 进度历史记录

@end

@implementation QCBrowserViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.history = [NSMutableArray array];

  // 初始化诊断数据
  self.resourceRequests = [NSMutableDictionary dictionary];
  self.jsErrors = [NSMutableArray array];
  self.consoleLogs = [NSMutableArray array];
  self.timingMetrics = [NSMutableDictionary dictionary];
  self.totalBytesReceived = 0;
  self.failedResourceCount = 0;

  // 初始化加载状态跟踪
  self.lastProgress = 0;
  self.progressJumpCount = 0;
  self.isLoadingFromCache = NO;
  self.loadFailed = NO;
  self.progressHistory = [NSMutableArray array];

  // 先读取设置
  [self loadSettings];

  // 设置导航栏（需要先加载设置）
  [self setupNavigationWithTitle:@"浏览器"];
  [self setupNavigationSwitches];

  [self setupSearchBar];
  [self setupWebView];
  [self setupToolbar];
  [self setupProgressView];

  // 启动时清除诊断历史
  [[NSUserDefaults standardUserDefaults]
      removeObjectForKey:kQCBrowserDiagnosticHistoryKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  NSLog(@"[QCTestKit] 🗑️ 启动时已清除诊断历史");

  // 根据设置决定是否清除缓存
  if (self.clearCacheOnStart) {
    [self clearCache];
  }

  // 默认加载百度
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [self loadURLString:@"https://www.baidu.com"];
      });
}

#pragma mark - Settings

- (void)loadSettings {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  // 默认使用 WKWebView
  if ([defaults objectForKey:kQCBrowserUseWKKey]) {
    self.useWKWebView = [defaults boolForKey:kQCBrowserUseWKKey];
  } else {
    self.useWKWebView = YES;
  }
  // 默认启动清除缓存
  if ([defaults objectForKey:kQCBrowserClearCacheKey]) {
    self.clearCacheOnStart = [defaults boolForKey:kQCBrowserClearCacheKey];
  } else {
    self.clearCacheOnStart = YES;
  }
}

- (void)saveSetting:(BOOL)value forKey:(NSString *)key {
  [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Setup UI

- (void)setupNavigationSwitches {
  // 清除缓存设置按钮 - 显示当前状态（右侧）
  NSString *clearCacheTitle = self.clearCacheOnStart ? @"✓ 清缓存" : @"清缓存";
  self.clearCacheSettingButton =
      [[UIBarButtonItem alloc] initWithTitle:clearCacheTitle
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(toggleClearCache)];

  // WebView类型按钮 - 显示当前类型（左侧）
  NSString *webViewTypeTitle = self.useWKWebView ? @"WK" : @"UI";
  self.webViewTypeButton =
      [[UIBarButtonItem alloc] initWithTitle:webViewTypeTitle
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(toggleWebViewType)];

  self.navigationItem.leftBarButtonItem = self.webViewTypeButton;
  self.navigationItem.rightBarButtonItem = self.clearCacheSettingButton;
}

- (void)toggleClearCache {
  self.clearCacheOnStart = !self.clearCacheOnStart;
  [self saveSetting:self.clearCacheOnStart forKey:kQCBrowserClearCacheKey];

  // 更新按钮标题
  NSString *title = self.clearCacheOnStart ? @"✓ 清缓存" : @"清缓存";
  self.clearCacheSettingButton.title = title;

  [self showMessage:self.clearCacheOnStart ? @"已开启启动清除缓存"
                                           : @"已关闭启动清除缓存"];
}

- (void)toggleWebViewType {
  self.useWKWebView = !self.useWKWebView;
  [self saveSetting:self.useWKWebView forKey:kQCBrowserUseWKKey];

  // 更新按钮标题
  self.webViewTypeButton.title = self.useWKWebView ? @"WK" : @"UI";

  // 重新创建WebView
  [self createCurrentWebView];
  self.searchBar.text = @"";
  [self updateNavigationButtons];

  [self showMessage:self.useWKWebView ? @"已切换到 WKWebView"
                                      : @"已切换到 UIWebView"];
}

- (void)setupSearchBar {
  // 搜索栏容器 - 现代化样式
  UIView *searchBarContainer = [[UIView alloc] init];
  searchBarContainer.backgroundColor = [UIColor colorWithRed:0.96
                                                       green:0.96
                                                        blue:0.94
                                                       alpha:1.0];
  searchBarContainer.layer.cornerRadius = 12;
  searchBarContainer.layer.borderWidth = 1;
  searchBarContainer.layer.borderColor =
      [UIColor colorWithRed:0.90 green:0.90 blue:0.88 alpha:1.0].CGColor;
  searchBarContainer.layer.shadowColor =
      [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.08].CGColor;
  searchBarContainer.layer.shadowOffset = CGSizeMake(0, 2);
  searchBarContainer.layer.shadowRadius = 4;
  searchBarContainer.layer.shadowOpacity = 1.0;
  searchBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:searchBarContainer];

  self.searchBar = [[UISearchBar alloc] init];
  self.searchBar.delegate = self;
  self.searchBar.placeholder = @""; // 默认为空
  self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
  self.searchBar.barTintColor = [UIColor clearColor];
  self.searchBar.backgroundColor = [UIColor clearColor];
  self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
  [searchBarContainer addSubview:self.searchBar];

  // 设置搜索栏外观
  UITextField *searchField = [self.searchBar valueForKey:@"searchField"];
  if (searchField) {
    searchField.backgroundColor = [UIColor clearColor];
    searchField.textColor = [UIColor colorWithRed:0.2
                                            green:0.2
                                             blue:0.2
                                            alpha:1.0];
    searchField.placeholder = @"输入网址或搜索";
    searchField.layer.cornerRadius = 8;
    searchField.layer.masksToBounds = YES;
  }

  // 前往按钮 - 应用现代化样式
  self.goButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.goButton setTitle:@"前往" forState:UIControlStateNormal];
  self.goButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self.goButton addTarget:self
                    action:@selector(goButtonTapped)
          forControlEvents:UIControlEventTouchUpInside];
  [searchBarContainer addSubview:self.goButton];
  [QCButtonStyler applyStyle:QCButtonStylePrimary
                        size:QCButtonSizeSmall
                    toButton:self.goButton];

  [NSLayoutConstraint activateConstraints:@[
    [searchBarContainer.topAnchor
        constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                       constant:8],
    [searchBarContainer.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor
                       constant:16],
    [searchBarContainer.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor
                       constant:-16],
    [searchBarContainer.heightAnchor constraintEqualToConstant:44],

    [self.searchBar.leadingAnchor
        constraintEqualToAnchor:searchBarContainer.leadingAnchor
                       constant:8],
    [self.searchBar.topAnchor
        constraintEqualToAnchor:searchBarContainer.topAnchor
                       constant:4],
    [self.searchBar.bottomAnchor
        constraintEqualToAnchor:searchBarContainer.bottomAnchor
                       constant:-4],

    [self.goButton.leadingAnchor
        constraintEqualToAnchor:self.searchBar.trailingAnchor
                       constant:8],
    [self.goButton.trailingAnchor
        constraintEqualToAnchor:searchBarContainer.trailingAnchor
                       constant:-8],
    [self.goButton.centerYAnchor
        constraintEqualToAnchor:searchBarContainer.centerYAnchor],
    [self.goButton.widthAnchor constraintEqualToConstant:60],
    [self.goButton.heightAnchor constraintEqualToConstant:28]
  ]];
}

- (void)setupWebView {
  self.webViewContainer = [[UIView alloc] init];
  self.webViewContainer.backgroundColor = [UIColor whiteColor];
  self.webViewContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.webViewContainer];

  [NSLayoutConstraint activateConstraints:@[
    [self.webViewContainer.topAnchor
        constraintEqualToAnchor:self.searchBar.bottomAnchor
                       constant:8],
    [self.webViewContainer.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.webViewContainer.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.webViewContainer.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor
                       constant:-44]
  ]];

  [self createCurrentWebView];
}

- (void)createCurrentWebView {
  // 移除旧的 web view
  if (self.webView) {
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.webView removeObserver:self forKeyPath:@"canGoBack"];
    [self.webView removeObserver:self forKeyPath:@"canGoForward"];
    [self.webView removeFromSuperview];
    self.webView = nil;
  }
  if (self.legacyWebView) {
    [self.legacyWebView removeFromSuperview];
    self.legacyWebView = nil;
  }

  if (self.useWKWebView) {
    [self setupWKWebView];
  } else {
    [self setupLegacyWebView];
  }
}

- (void)setupWKWebView {
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  config.dataDetectorTypes = WKDataDetectorTypeAll;

  if ([config.preferences respondsToSelector:@selector(setValue:forKey:)]) {
    [config.preferences setValue:@YES forKey:@"developerExtrasEnabled"];
  }

  // 注入网络拦截脚本
  NSString *interceptScript =
      @"(function() {"
      @"var originalFetch = window.fetch;"
      @"var originalXHR = window.XMLHttpRequest;"
      @"var requestId = 0;"
      @""
      @"function logRequest(type, url, headers, body) {"
      @"    var id = ++requestId;"
      @"    var msg = {"
      @"        id: id,"
      @"        type: type,"
      @"        url: url,"
      @"        headers: headers || {},"
      @"        body: body || '',"
      @"        timestamp: new Date().toISOString()"
      @"    };"
      @"    window.webkit.messageHandlers.networkLog.postMessage(msg);"
      @"    return id;"
      @"};"
      @""
      @"function logResponse(id, status, headers, body) {"
      @"    window.webkit.messageHandlers.networkLog.postMessage({"
      @"        responseId: id,"
      @"        status: status,"
      @"        headers: headers || {},"
      @"        body: body || ''"
      @"    });"
      @"};"
      @""
      @"window.fetch = function(url, options) {"
      @"    var id = logRequest('fetch', url, options ? options.headers : {}, "
      @"options ? options.body : '');"
      @"    return originalFetch.apply(this, "
      @"arguments).then(function(response) {"
      @"        response.clone().text().then(function(bodyText) {"
      @"            logResponse(id, response.status, {}, bodyText);"
      @"        });"
      @"        return response;"
      @"    });"
      @"};"
      @""
      @"var XHR_open = originalXHR.prototype.open;"
      @"var XHR_send = originalXHR.prototype.send;"
      @"var currentXHRId = null;"
      @""
      @"originalXHR.prototype.open = function(method, url) {"
      @"    this._method = method;"
      @"    this._url = url;"
      @"    return XHR_open.apply(this, arguments);"
      @"};"
      @""
      @"originalXHR.prototype.send = function(body) {"
      @"    var id = logRequest('xhr', this._url, {}, body);"
      @"    currentXHRId = id;"
      @""
      @"    this.addEventListener('load', function() {"
      @"        var headers = {};"
      @"        "
      @"this.getAllResponseHeaders().split('\\r\\n').forEach(function(line) {"
      @"            var parts = line.split(': ');"
      @"            if (parts.length === 2) headers[parts[0]] = parts[1];"
      @"        });"
      @"        logResponse(id, this.status, headers, this.responseText);"
      @"    });"
      @""
      @"    this.addEventListener('error', function() {"
      @"        window.webkit.messageHandlers.networkLog.postMessage({"
      @"            responseId: id,"
      @"            error: 'Network error'"
      @"        });"
      @"    });"
      @""
      @"    return XHR_send.apply(this, arguments);"
      @"};"
      @"})();";

  // 注入性能监控和错误捕获脚本
  NSString *performanceScript =
      @"(function() {"
      // 捕获 JavaScript 错误
      @"window.addEventListener('error', function(e) {"
      @"    window.webkit.messageHandlers.jsError.postMessage({"
      @"        message: e.message || 'Unknown error',"
      @"        file: e.filename || e.sourceURL || '',"
      @"        line: e.lineno || 0,"
      @"        column: e.colno || 0,"
      @"        stack: e.error ? e.error.stack : ''"
      @"    });"
      @"});"
      // 捕获未处理的 Promise 错误
      @"window.addEventListener('unhandledrejection', function(e) {"
      @"    window.webkit.messageHandlers.jsError.postMessage({"
      @"        message: 'Unhandled Promise Rejection: ' + (e.reason || "
      @"'Unknown'),"
      @"        file: '',"
      @"        line: 0,"
      @"        type: 'promise'"
      @"    });"
      @"});"
      // 拦截控制台日志
      @"(function() {"
      @"    var originalLog = console.log;"
      @"    var originalWarn = console.warn;"
      @"    var originalError = console.error;"
      @"    var originalInfo = console.info;"
      @""
      @"    function postConsole(level, args) {"
      @"        var message = Array.prototype.slice.call(args).map(function(a) "
      @"{"
      @"            try {"
      @"                return typeof a === 'object' ? JSON.stringify(a) : "
      @"String(a);"
      @"            } catch(e) {"
      @"                return String(a);"
      @"            }"
      @"        }).join(' ');"
      @"        window.webkit.messageHandlers.consoleLog.postMessage({"
      @"            level: level,"
      @"            message: message.substring(0, 500),"
      @"            timestamp: new Date().toISOString()"
      @"        });"
      @"    }"
      @""
      @"    console.log = function() {"
      @"        originalLog.apply(console, arguments);"
      @"        postConsole('log', arguments);"
      @"    };"
      @"    console.warn = function() {"
      @"        originalWarn.apply(console, arguments);"
      @"        postConsole('warn', arguments);"
      @"    };"
      @"    console.error = function() {"
      @"        originalError.apply(console, arguments);"
      @"        postConsole('error', arguments);"
      @"    };"
      @"    console.info = function() {"
      @"        originalInfo.apply(console, arguments);"
      @"        postConsole('info', arguments);"
      @"    };"
      @"})();"
      // 收集性能数据
      @"window.addEventListener('load', function() {"
      @"    setTimeout(function() {"
      @"        var perfData = {"
      @"            navigation: performance.timing,"
      @"            memory: performance.memory ? {"
      @"                usedJSHeapSize: performance.memory.usedJSHeapSize,"
      @"                totalJSHeapSize: performance.memory.totalJSHeapSize"
      @"            } : null"
      @"        };"
      @"        var timing = performance.timing;"
      @"        var metrics = {"
      @"            dns: timing.domainLookupEnd - timing.domainLookupStart,"
      @"            tcp: timing.connectEnd - timing.connectStart,"
      @"            ssl: timing.secureConnectionStart > 0 ? timing.connectEnd "
      @"- timing.secureConnectionStart : 0,"
      @"            ttfb: timing.responseStart - timing.requestStart,"
      @"            download: timing.responseEnd - timing.responseStart,"
      @"            domLoad: timing.domContentLoadedEventEnd - "
      @"timing.fetchStart,"
      @"            total: timing.loadEventEnd - timing.fetchStart"
      @"        };"
      @"        "
      @"window.webkit.messageHandlers.performanceData.postMessage(metrics);"
      @"    }, 100);"
      @"});"
      // 监控资源加载
      @"window.addEventListener('load', function() {"
      @"    var resources = performance.getEntriesByType('resource');"
      @"    resources.forEach(function(r) {"
      @"        window.webkit.messageHandlers.resourceTiming.postMessage({"
      @"            name: r.name.substring(0, 200),"
      @"            type: r.initiatorType || 'other',"
      @"            duration: Math.round(r.duration),"
      @"            size: r.transferSize || 0,"
      @"            decodedSize: r.decodedBodySize || 0"
      @"        });"
      @"    });"
      @"});"
      @"})();";

  WKUserScript *networkScript = [[WKUserScript alloc]
        initWithSource:interceptScript
         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:YES];
  [config.userContentController addUserScript:networkScript];
  [config.userContentController addScriptMessageHandler:self
                                                   name:@"networkLog"];

  WKUserScript *perfScript = [[WKUserScript alloc]
        initWithSource:performanceScript
         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:YES];
  [config.userContentController addUserScript:perfScript];
  [config.userContentController addScriptMessageHandler:self name:@"jsError"];
  [config.userContentController addScriptMessageHandler:self
                                                   name:@"consoleLog"];
  [config.userContentController addScriptMessageHandler:self
                                                   name:@"performanceData"];
  [config.userContentController addScriptMessageHandler:self
                                                   name:@"resourceTiming"];

  self.webView = [[WKWebView alloc] initWithFrame:self.webViewContainer.bounds
                                    configuration:config];
  self.webView.navigationDelegate = self;
  self.webView.UIDelegate = self;
  self.webView.backgroundColor = [UIColor whiteColor];
  self.webView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.webViewContainer addSubview:self.webView];

  [NSLayoutConstraint activateConstraints:@[
    [self.webView.topAnchor
        constraintEqualToAnchor:self.webViewContainer.topAnchor],
    [self.webView.leadingAnchor
        constraintEqualToAnchor:self.webViewContainer.leadingAnchor],
    [self.webView.trailingAnchor
        constraintEqualToAnchor:self.webViewContainer.trailingAnchor],
    [self.webView.bottomAnchor
        constraintEqualToAnchor:self.webViewContainer.bottomAnchor]
  ]];

  [self.webView addObserver:self
                 forKeyPath:@"estimatedProgress"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
  [self.webView addObserver:self
                 forKeyPath:@"canGoBack"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
  [self.webView addObserver:self
                 forKeyPath:@"canGoForward"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
}

- (void)setupLegacyWebView {
  // UIWebView 已在 iOS 12 弃用，但作为测试选项保留
  self.legacyWebView =
      [[UIWebView alloc] initWithFrame:self.webViewContainer.bounds];
  self.legacyWebView.delegate = (id<UIWebViewDelegate>)self;
  self.legacyWebView.backgroundColor = [UIColor whiteColor];
  self.legacyWebView.scalesPageToFit = YES;
  self.legacyWebView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.webViewContainer addSubview:self.legacyWebView];

  [NSLayoutConstraint activateConstraints:@[
    [self.legacyWebView.topAnchor
        constraintEqualToAnchor:self.webViewContainer.topAnchor],
    [self.legacyWebView.leadingAnchor
        constraintEqualToAnchor:self.webViewContainer.leadingAnchor],
    [self.legacyWebView.trailingAnchor
        constraintEqualToAnchor:self.webViewContainer.trailingAnchor],
    [self.legacyWebView.bottomAnchor
        constraintEqualToAnchor:self.webViewContainer.bottomAnchor]
  ]];
}

- (void)setupToolbar {
  self.toolbar = [[UIToolbar alloc] init];
  self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;

  // iOS 13+ 使用 UIToolbarAppearance 确保浅色主题
  UIColor *buttonTintColor = [UIColor colorWithRed:0.1
                                             green:0.1
                                              blue:0.1
                                             alpha:1.0];

  if (@available(iOS 13.0, *)) {
    UIToolbarAppearance *appearance = [[UIToolbarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor whiteColor];
    self.toolbar.standardAppearance = appearance;
    self.toolbar.compactAppearance = appearance;
  } else {
    self.toolbar.barTintColor = [UIColor whiteColor];
  }
  self.toolbar.tintColor = buttonTintColor;

  // 创建带配置的图标按钮
  UIImage *backImage = [UIImage systemImageNamed:@"chevron.left"];
  UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration
      configurationWithPointSize:20
                          weight:UIImageSymbolWeightMedium];
  backImage = [backImage imageByApplyingSymbolConfiguration:config];

  self.backButton =
      [[UIBarButtonItem alloc] initWithImage:backImage
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(goBack)];
  self.backButton.enabled = NO;
  self.backButton.tintColor = buttonTintColor;

  UIImage *forwardImage = [UIImage systemImageNamed:@"chevron.right"];
  forwardImage = [forwardImage imageByApplyingSymbolConfiguration:config];

  self.forwardButton =
      [[UIBarButtonItem alloc] initWithImage:forwardImage
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(goForward)];
  self.forwardButton.enabled = NO;
  self.forwardButton.tintColor = buttonTintColor;

  UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                           target:nil
                           action:nil];

  UIImage *refreshImage = [UIImage systemImageNamed:@"arrow.clockwise"];
  refreshImage = [refreshImage imageByApplyingSymbolConfiguration:config];

  self.refreshButton =
      [[UIBarButtonItem alloc] initWithImage:refreshImage
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(refresh)];
  self.refreshButton.tintColor = buttonTintColor;

  self.diagnosticButton =
      [[UIBarButtonItem alloc] initWithTitle:@"📊 诊断"
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(showDiagnostics)];
  self.diagnosticButton.tintColor = buttonTintColor;

  self.toolbar.items = @[
    self.backButton, flexibleSpace, self.forwardButton, flexibleSpace,
    self.refreshButton, flexibleSpace, self.diagnosticButton
  ];

  // 确保 tintColor 应用
  self.toolbar.tintColor = buttonTintColor;

  [self.view addSubview:self.toolbar];

  [NSLayoutConstraint activateConstraints:@[
    [self.toolbar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    [self.toolbar.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.toolbar.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.toolbar.heightAnchor constraintEqualToConstant:44]
  ]];
}

- (void)setupProgressView {
  // 进度条
  self.progressView = [[UIProgressView alloc]
      initWithProgressViewStyle:UIProgressViewStyleDefault];
  self.progressView.progressTintColor = [UIColor colorWithRed:0.0
                                                        green:0.5
                                                         blue:1.0
                                                        alpha:1.0];
  self.progressView.trackTintColor = [UIColor clearColor];
  self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
  self.progressView.hidden = YES;

  // 进度文字标签
  self.progressLabel = [[UILabel alloc] init];
  self.progressLabel.font = [UIFont systemFontOfSize:12];
  self.progressLabel.textColor = [UIColor colorWithRed:0.0
                                                 green:0.5
                                                  blue:1.0
                                                 alpha:1.0];
  self.progressLabel.text = @"";
  self.progressLabel.textAlignment = NSTextAlignmentCenter;
  self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.progressLabel.hidden = YES;

  [self.view addSubview:self.progressView];
  [self.view addSubview:self.progressLabel];

  [NSLayoutConstraint activateConstraints:@[
    // 进度条在搜索栏下方
    [self.progressView.topAnchor
        constraintEqualToAnchor:self.searchBar.bottomAnchor],
    [self.progressView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.progressView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.progressView.heightAnchor constraintEqualToConstant:2],

    // 进度标签在进度条下方
    [self.progressLabel.topAnchor
        constraintEqualToAnchor:self.progressView.bottomAnchor
                       constant:2],
    [self.progressLabel.centerXAnchor
        constraintEqualToAnchor:self.view.centerXAnchor],
    [self.progressLabel.heightAnchor constraintEqualToConstant:20]
  ]];
}

#pragma mark - Actions

- (void)goButtonTapped {
  [self loadURLString:self.searchBar.text];
  [self.searchBar resignFirstResponder];
}

- (void)goBack {
  if (self.useWKWebView) {
    if ([self.webView canGoBack]) {
      [self.webView goBack];
    }
  } else {
    if ([self.legacyWebView canGoBack]) {
      [self.legacyWebView goBack];
    }
  }
}

- (void)goForward {
  if (self.useWKWebView) {
    if ([self.webView canGoForward]) {
      [self.webView goForward];
    }
  } else {
    if ([self.legacyWebView canGoForward]) {
      [self.legacyWebView goForward];
    }
  }
}

- (void)refresh {
  if (self.useWKWebView) {
    [self.webView reload];
  } else {
    [self.legacyWebView reload];
  }
}

- (void)clearCacheNow {
  [self clearCache];
  [self showMessage:@"缓存已清除"];
}

#pragma mark - Cache

- (void)clearCache {
  if (self.useWKWebView) {
    // 清除 WKWebView 缓存
    NSSet *websiteDataTypes = [NSSet setWithArray:@[
      WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache,
      WKWebsiteDataTypeOfflineWebApplicationCache, WKWebsiteDataTypeCookies,
      WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeLocalStorage,
      WKWebsiteDataTypeWebSQLDatabases, WKWebsiteDataTypeIndexedDBDatabases,
      WKWebsiteDataTypeServiceWorkerRegistrations
    ]];

    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore]
        removeDataOfTypes:websiteDataTypes
            modifiedSince:dateFrom
        completionHandler:^{
          NSLog(@"[QCTestKit] WKWebView 缓存已清除");
        }];
  } else {
    // 清除 UIWebView 缓存
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSHTTPCookieStorage *cookieStorage =
        [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
      [cookieStorage deleteCookie:cookie];
    }
    NSLog(@"[QCTestKit] UIWebView 缓存已清除");
  }
}

#pragma mark - Diagnostics

- (void)resetDiagnosticData {
  self.resourceRequests = [NSMutableDictionary dictionary];
  self.jsErrors = [NSMutableArray array];
  self.consoleLogs = [NSMutableArray array];
  self.timingMetrics = [NSMutableDictionary dictionary];
  self.totalBytesReceived = 0;
  self.failedResourceCount = 0;
  self.pageLoadStartTime = [NSDate date];

  // 重置加载状态
  self.lastProgress = 0;
  self.progressJumpCount = 0;
  self.isLoadingFromCache = NO;
  self.loadFailed = NO;
  self.loadError = nil;
  [self.progressHistory removeAllObjects];
}

- (void)showDiagnostics {
  // 显示历史诊断列表
  QCDiagnosticHistoryViewController *historyVC =
      [[QCDiagnosticHistoryViewController alloc] init];
  [self.navigationController pushViewController:historyVC animated:YES];
}

- (void)saveDiagnosticData:(NSDictionary *)data {
  // 添加时间戳（转为字符串）
  NSMutableDictionary *mutableData = [data mutableCopy];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  mutableData[@"savedAt"] = [formatter stringFromDate:[NSDate date]];

  // 获取历史记录
  NSMutableArray *history = [[self loadDiagnosticHistory] mutableCopy];
  if (!history) {
    history = [NSMutableArray array];
  }

  // 添加新记录
  [history insertObject:mutableData atIndex:0];

  // 限制数量
  NSInteger maxCount = [kQCBrowserMaxHistoryCount integerValue];
  if (history.count > maxCount) {
    [history
        removeObjectsInRange:NSMakeRange(maxCount, history.count - maxCount)];
  }

  // 使用 JSON 序列化（更可靠）
  NSError *error = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:history
                                                     options:0
                                                       error:&error];
  if (error) {
    NSLog(@"[QCTestKit] ❌ JSON编码失败: %@", error);
    NSLog(@"[QCTestKit] 📋 数据内容: %@", history);
    return;
  }

  if (jsonData) {
    [[NSUserDefaults standardUserDefaults]
        setObject:jsonData
           forKey:kQCBrowserDiagnosticHistoryKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"[QCTestKit] ✅ 诊断数据已保存，历史记录数: %lu",
          (unsigned long)history.count);
  }
}

- (NSArray *)loadDiagnosticHistory {
  NSData *jsonData = [[NSUserDefaults standardUserDefaults]
      objectForKey:kQCBrowserDiagnosticHistoryKey];
  if (jsonData) {
    NSError *error = nil;
    NSArray *history = [NSJSONSerialization JSONObjectWithData:jsonData
                                                       options:0
                                                         error:&error];
    if (error) {
      NSLog(@"[QCTestKit] ❌ JSON解码失败: %@", error);
      return @[];
    }
    return history ?: @[];
  }
  return @[];
}

- (void)clearDiagnosticHistory {
  [[NSUserDefaults standardUserDefaults]
      removeObjectForKey:kQCBrowserDiagnosticHistoryKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  NSLog(@"[QCTestKit] 🗑️ 诊断历史已清除");
}

- (void)autoSaveDiagnosticData {
  if (!self.webView.URL) {
    NSLog(@"[QCTestKit] ⚠️ 跳过保存：无 URL");
    return;
  }

  NSLog(@"[QCTestKit] 💾 开始保存诊断数据...");

  // 收集诊断数据 - 使用不可变字典以便序列化
  NSMutableDictionary *diagnosticData = [NSMutableDictionary dictionary];

  // 基本信息
  diagnosticData[@"url"] = self.webView.URL.absoluteString;
  diagnosticData[@"title"] = self.webView.title ?: @"Unknown";

  // 加载状态信息
  diagnosticData[@"loadStatus"] = self.loadFailed ? @"failed" : @"success";
  diagnosticData[@"isLoadingFromCache"] = @(self.isLoadingFromCache);
  diagnosticData[@"progressJumpCount"] = @(self.progressJumpCount);

  // 如果加载失败，记录错误信息
  if (self.loadFailed && self.loadError) {
    diagnosticData[@"errorCode"] = @(self.loadError.code);
    diagnosticData[@"errorDomain"] = self.loadError.domain ?: @"";
    diagnosticData[@"errorMessage"] =
        self.loadError.localizedDescription ?: @"";
    diagnosticData[@"title"] = [NSString
        stringWithFormat:@"加载失败: %@", self.loadError.localizedDescription
                                              ?: @"Unknown Error"];
  }

  // 进度信息摘要
  if (self.progressHistory.count > 0) {
    float maxProgress =
        [[self.progressHistory valueForKeyPath:@"@max.floatValue"] floatValue];
    diagnosticData[@"maxProgress"] = @(maxProgress);
    diagnosticData[@"progressSteps"] = @(self.progressHistory.count);
  }

  // 时间指标 - 逐个添加，避免添加整个可变字典
  diagnosticData[@"dnsDuration"] = self.timingMetrics[@"dnsDuration"] ?: @0;
  diagnosticData[@"tcpDuration"] = self.timingMetrics[@"tcpDuration"] ?: @0;
  diagnosticData[@"sslDuration"] = self.timingMetrics[@"sslDuration"] ?: @0;
  diagnosticData[@"ttfb"] = self.timingMetrics[@"ttfb"] ?: @0;
  diagnosticData[@"downloadDuration"] =
      self.timingMetrics[@"downloadDuration"] ?: @0;
  diagnosticData[@"domLoadDuration"] =
      self.timingMetrics[@"domLoadDuration"] ?: @0;
  diagnosticData[@"totalLoadTime"] = self.timingMetrics[@"totalLoadTime"] ?: @0;

  // 资源统计
  diagnosticData[@"resourceCount"] = @(self.resourceRequests.count);
  diagnosticData[@"failedResourceCount"] = @(self.failedResourceCount);
  diagnosticData[@"jsErrorCount"] = @(self.jsErrors.count);
  diagnosticData[@"totalBytes"] = @(self.totalBytesReceived);

  NSLog(@"[QCTestKit] 📊 资源数: %lu, JS错误: %lu, 总流量: %lld, 状态: %@, "
        @"缓存: %@",
        (unsigned long)self.resourceRequests.count,
        (unsigned long)self.jsErrors.count, self.totalBytesReceived,
        self.loadFailed ? @"失败" : @"成功",
        self.isLoadingFromCache ? @"是" : @"否");

  // 资源请求列表
  NSMutableArray *requestList = [NSMutableArray array];
  for (NSString *url in self.resourceRequests) {
    NSArray *requests = self.resourceRequests[url];
    if (requests.count > 0) {
      NSDictionary *lastRequest = requests.lastObject;
      [requestList addObject:@{
        @"url" : url,
        @"method" : lastRequest[@"method"] ?: @"GET",
        @"status" : lastRequest[@"status"] ?: @"200",
        @"size" : lastRequest[@"size"] ?: @0,
        @"duration" : lastRequest[@"duration"] ?: @0
      }];
    }
  }
  // 按耗时排序
  [requestList sortUsingComparator:^NSComparisonResult(NSDictionary *obj1,
                                                       NSDictionary *obj2) {
    NSNumber *d1 = obj1[@"duration"] ?: @0;
    NSNumber *d2 = obj2[@"duration"] ?: @0;
    return [d2 compare:d1];
  }];
  diagnosticData[@"requests"] = [requestList copy]; // 不可变副本

  // JS 错误 - 转为不可变
  diagnosticData[@"jsErrors"] = [self.jsErrors copy];

  // 控制台日志 - 转为不可变
  NSArray *recentLogs =
      self.consoleLogs.count > 50
          ? [self.consoleLogs subarrayWithRange:NSMakeRange(0, 50)]
          : self.consoleLogs;
  diagnosticData[@"consoleLogs"] = [recentLogs copy];

  // 保存诊断数据 - 转为不可变
  [self saveDiagnosticData:[diagnosticData copy]];
}

// 保存失败诊断记录的便捷方法
- (void)saveFailedDiagnostic {
  if (!self.webView.URL && !self.loadError) {
    return;
  }

  // 立即保存失败记录
  [NSObject
      cancelPreviousPerformRequestsWithTarget:self
                                     selector:@selector(autoSaveDiagnosticData)
                                       object:nil];
  [self autoSaveDiagnosticData];
}

#pragma mark - Network Logging

- (void)logRequestStart:(NSURLRequest *)request {
  self.currentRequestStartTime = [NSDate date];
  self.currentRequestLog = [NSMutableString string];

  NSString *requestId = [NSString
      stringWithFormat:@"%.0f",
                       [self.currentRequestStartTime timeIntervalSince1970] *
                           1000];

  NSLog(@"╔════════════════════════════════════════════════════════════════════"
        @"══════════");
  NSLog(@"[QCTestKit] 📤 网络请求开始");
  NSLog(@"[QCTestKit] 📋 请求ID: %@", requestId);
  NSLog(@"[QCTestKit] 🔗 URL: %@", request.URL.absoluteString);
  NSLog(@"[QCTestKit] 📝 方法: %@", request.HTTPMethod);
  NSLog(@"[QCTestKit] 📦 请求头:");

  [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(
                                   NSString *key, NSString *value, BOOL *stop) {
    NSLog(@"[QCTestKit]    %@: %@", key, value);
  }];

  if (request.HTTPBody.length > 0) {
    NSString *bodyString = [[NSString alloc] initWithData:request.HTTPBody
                                                 encoding:NSUTF8StringEncoding];
    if (bodyString) {
      NSLog(@"[QCTestKit] 💾 请求体: %@", bodyString);
    } else {
      NSLog(@"[QCTestKit] 💾 请求体: (二进制数据，长度: %lu bytes)",
            (unsigned long)request.HTTPBody.length);
    }
  }

  NSLog(@"[QCTestKit] ⏱ 开始时间: %@",
        [self formatLogDate:self.currentRequestStartTime]);
}

- (void)logRequestResponse:(NSURLResponse *)response
                      body:(NSData *)bodyData
                     error:(NSError *)error {
  NSTimeInterval duration =
      [[NSDate date] timeIntervalSinceDate:self.currentRequestStartTime];
  NSString *requestId = [NSString
      stringWithFormat:@"%.0f",
                       [self.currentRequestStartTime timeIntervalSince1970] *
                           1000];

  if (error) {
    NSLog(@"[QCTestKit] ❌ 请求失败");
    NSLog(@"[QCTestKit] 📋 请求ID: %@", requestId);
    NSLog(@"[QCTestKit] ⚠️ 错误: %@ (Code: %ld)", error.localizedDescription,
          (long)error.code);
    NSLog(@"[QCTestKit] ⏱ 耗时: %.0fms", duration * 1000);
  } else {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    NSLog(@"[QCTestKit] 📥 网络响应完成");
    NSLog(@"[QCTestKit] 📋 请求ID: %@", requestId);
    NSLog(@"[QCTestKit] 🔗 URL: %@", response.URL.absoluteString);
    NSLog(@"[QCTestKit] 📊 状态码: %ld", (long)httpResponse.statusCode);
    NSLog(@"[QCTestKit] ⏱ 耗时: %.0fms", duration * 1000);

    NSLog(@"[QCTestKit] 📦 响应头:");
    [httpResponse.allHeaderFields
        enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value,
                                            BOOL *stop) {
          NSLog(@"[QCTestKit]    %@: %@", key, value);
        }];

    if (bodyData.length > 0) {
      NSString *bodyString =
          [[NSString alloc] initWithData:bodyData
                                encoding:NSUTF8StringEncoding];
      NSInteger maxLogLength = 500;
      if (bodyString.length > maxLogLength) {
        NSLog(@"[QCTestKit] 💾 响应体 (前%ld字节): %@", (long)maxLogLength,
              [bodyString substringToIndex:maxLogLength]);
        NSLog(@"[QCTestKit] ... (共 %lu 字节，已截断)",
              (unsigned long)bodyData.length);
      } else {
        NSLog(@"[QCTestKit] 💾 响应体: %@", bodyString);
      }
    } else {
      NSLog(@"[QCTestKit] 💾 响应体: (空)");
    }

    NSLog(@"[QCTestKit] 📏 Content-Length: %@",
          [httpResponse.allHeaderFields objectForKey:@"Content-Length"]
              ?: @"N/A");
    NSLog(@"[QCTestKit] 🍪 Cookie: %@",
          [httpResponse.allHeaderFields objectForKey:@"Set-Cookie"] ?: @"N/A");
  }

  NSLog(@"╚════════════════════════════════════════════════════════════════════"
        @"══════════");
}

- (NSString *)formatLogDate:(NSDate *)date {
  static NSDateFormatter *formatter = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
  });
  return [formatter stringFromDate:date];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  if ([message.name isEqualToString:@"networkLog"]) {
    [self handleNetworkLog:message.body];
  } else if ([message.name isEqualToString:@"jsError"]) {
    [self handleJSError:message.body];
  } else if ([message.name isEqualToString:@"consoleLog"]) {
    [self handleConsoleLog:message.body];
  } else if ([message.name isEqualToString:@"performanceData"]) {
    [self handlePerformanceData:message.body];
  } else if ([message.name isEqualToString:@"resourceTiming"]) {
    [self handleResourceTiming:message.body];
  }
}

- (void)handleNetworkLog:(NSDictionary *)body {
  if (body[@"type"]) {
    // fetch/xhr 请求
    NSLog(@"╔══════════════════════════════════════════════════════════════════"
          @"════════════");
    NSLog(@"[QCTestKit] 📤 [%@] 页面内网络请求", body[@"type"]);
    NSLog(@"[QCTestKit] 🔗 URL: %@", body[@"url"]);
    NSLog(@"[QCTestKit] 📋 请求ID: %@", body[@"id"]);

    if (body[@"headers"] && [body[@"headers"] count] > 0) {
      NSLog(@"[QCTestKit] 📦 请求头: %@", body[@"headers"]);
    }

    if (body[@"body"] && [body[@"body"] length] > 0) {
      NSString *bodyStr = body[@"body"];
      if (bodyStr.length > 200) {
        NSLog(@"[QCTestKit] 💾 请求体: %@... (共%lu字符)",
              [bodyStr substringToIndex:200], (unsigned long)bodyStr.length);
      } else {
        NSLog(@"[QCTestKit] 💾 请求体: %@", bodyStr);
      }
    }

    NSLog(@"[QCTestKit] ⏰ 时间: %@", body[@"timestamp"]);
    NSLog(@"╚══════════════════════════════════════════════════════════════════"
          @"════════════");

    // 保存到资源请求中
    NSString *url = body[@"url"];
    if (url && !self.resourceRequests[url]) {
      self.resourceRequests[url] = [NSMutableArray array];
    }
    [self.resourceRequests[url] addObject:@{
      @"type" : body[@"type"],
      @"method" : @"GET",
      @"url" : url,
      @"timestamp" : body[@"timestamp"]
    }];

  } else if (body[@"responseId"]) {
    // fetch/xhr 响应
    NSLog(@"╔══════════════════════════════════════════════════════════════════"
          @"════════════");
    NSLog(@"[QCTestKit] 📥 页面内网络响应");
    NSLog(@"[QCTestKit] 📋 响应ID: %@", body[@"responseId"]);

    if (body[@"error"]) {
      NSLog(@"[QCTestKit] ❌ 错误: %@", body[@"error"]);
      self.failedResourceCount++;
    } else {
      NSLog(@"[QCTestKit] 📊 状态码: %@", body[@"status"]);

      if (body[@"headers"] && [body[@"headers"] count] > 0) {
        NSLog(@"[QCTestKit] 📦 响应头: %@", body[@"headers"]);
      }

      if (body[@"body"]) {
        NSString *bodyStr = body[@"body"];
        if (bodyStr.length > 500) {
          NSLog(@"[QCTestKit] 💾 响应体: %@... (共%lu字符)",
                [bodyStr substringToIndex:500], (unsigned long)bodyStr.length);
        } else {
          NSLog(@"[QCTestKit] 💾 响应体: %@", bodyStr);
        }
      } else {
        NSLog(@"[QCTestKit] 💾 响应体: (空)");
      }
    }

    NSLog(@"╚══════════════════════════════════════════════════════════════════"
          @"════════════");
  }
}

- (void)handleJSError:(NSDictionary *)error {
  NSString *message = error[@"message"] ?: @"Unknown error";
  NSString *file = error[@"file"] ?: @"";
  NSNumber *line = error[@"line"] ?: @0;

  NSLog(@"╔════════════════════════════════════════════════════════════════════"
        @"══════════");
  NSLog(@"[QCTestKit] ❌ JavaScript 错误");
  NSLog(@"[QCTestKit] 📝 错误信息: %@", message);
  NSLog(@"[QCTestKit] 📁 文件: %@", file);
  NSLog(@"[QCTestKit] 📍 行号: %@", line);
  if (error[@"stack"]) {
    NSLog(@"[QCTestKit] 🔗 堆栈: %@", error[@"stack"]);
  }
  NSLog(@"╚════════════════════════════════════════════════════════════════════"
        @"══════════");

  // 保存到错误列表
  [self.jsErrors addObject:@{
    @"message" : message,
    @"file" : file,
    @"line" : line,
    @"stack" : error[@"stack"] ?: @""
  }];
}

- (void)handleConsoleLog:(NSDictionary *)log {
  NSString *level = log[@"level"] ?: @"log";
  NSString *message = log[@"message"] ?: @"";

  NSString *emoji = @"📝";
  if ([level isEqualToString:@"error"])
    emoji = @"❌";
  else if ([level isEqualToString:@"warn"])
    emoji = @"⚠️";
  else if ([level isEqualToString:@"info"])
    emoji = @"ℹ️";

  NSLog(@"[QCTestKit] %@ [Console.%@] %@", emoji, level, message);

  // 保存到控制台日志
  [self.consoleLogs addObject:@{
    @"level" : level,
    @"message" : message,
    @"timestamp" : log[@"timestamp"] ?: @""
  }];
}

- (void)handlePerformanceData:(NSDictionary *)metrics {
  NSLog(@"╔════════════════════════════════════════════════════════════════════"
        @"══════════");
  NSLog(@"[QCTestKit] ⏱️ 性能指标");
  NSLog(@"[QCTestKit] 🌐 DNS 查询: %.0f ms", [metrics[@"dns"] doubleValue]);
  NSLog(@"[QCTestKit] 🔌 TCP 连接: %.0f ms", [metrics[@"tcp"] doubleValue]);
  NSLog(@"[QCTestKit] 🔒 SSL 握手: %.0f ms", [metrics[@"ssl"] doubleValue]);
  NSLog(@"[QCTestKit] 📤 首字节时间 (TTFB): %.0f ms",
        [metrics[@"ttfb"] doubleValue]);
  NSLog(@"[QCTestKit] 📥 内容下载: %.0f ms",
        [metrics[@"download"] doubleValue]);
  NSLog(@"[QCTestKit] 🏗️ DOM 加载: %.0f ms", [metrics[@"domLoad"] doubleValue]);
  NSLog(@"[QCTestKit] ✅ 完全加载: %.0f ms", [metrics[@"total"] doubleValue]);
  NSLog(@"╚════════════════════════════════════════════════════════════════════"
        @"══════════");

  // 保存性能指标
  self.timingMetrics[@"dnsDuration"] = metrics[@"dns"];
  self.timingMetrics[@"tcpDuration"] = metrics[@"tcp"];
  self.timingMetrics[@"sslDuration"] = metrics[@"ssl"];
  self.timingMetrics[@"ttfb"] = metrics[@"ttfb"];
  self.timingMetrics[@"downloadDuration"] = metrics[@"download"];
  self.timingMetrics[@"domLoadDuration"] = metrics[@"domLoad"];
  self.timingMetrics[@"totalLoadTime"] = metrics[@"total"];
}

- (void)handleResourceTiming:(NSDictionary *)resource {
  NSString *name = resource[@"name"] ?: @"";
  NSString *type = resource[@"type"] ?: @"other";
  NSNumber *duration = resource[@"duration"] ?: @0;
  NSNumber *size = resource[@"size"] ?: @0;

  NSLog(@"[QCTestKit] 📦 资源 [%@] %@ | %.0fms | %lld bytes", type, name,
        [duration doubleValue], (long long)[size longLongValue]);

  // 保存到资源请求
  if (!self.resourceRequests[name]) {
    self.resourceRequests[name] = [NSMutableArray array];
  }
  [self.resourceRequests[name] addObject:@{
    @"type" : type,
    @"url" : name,
    @"duration" : duration,
    @"size" : size,
    @"status" : @200
  }];

  self.totalBytesReceived += [size longLongValue];
}

#pragma mark - URLProtocol Logging (for main request)

- (void)setupURLProtocolLogging {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
                    // 注册自定义 URLProtocol 用于拦截主请求
                    // 这里使用 NSURLSession 的方式来记录主请求
                });
}

#pragma mark - Load URL

- (void)loadURLString:(NSString *)urlString {
  NSString *trimmedURL = [urlString
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];

  if (trimmedURL.length == 0) {
    [self showMessage:@"请输入网址"];
    return;
  }

  NSURL *url = [NSURL URLWithString:trimmedURL];
  if (!url.scheme) {
    trimmedURL = [NSString stringWithFormat:@"https://%@", trimmedURL];
    url = [NSURL URLWithString:trimmedURL];
  }

  if (url) {
    if (self.useWKWebView) {
      NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
      [request setHTTPMethod:@"GET"];

      // 记录请求开始
      [self logRequestStart:request];

      // 使用 NSURLSession 发送请求以获取响应详情
      NSURLSessionConfiguration *config =
          [NSURLSessionConfiguration ephemeralSessionConfiguration];
      NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

      NSURLSessionDataTask *task =
          [session dataTaskWithRequest:request
                     completionHandler:^(NSData *data, NSURLResponse *response,
                                         NSError *error) {
                       [self logRequestResponse:response body:data error:error];
                     }];
      [task resume];

      [self.webView loadRequest:request];
    } else {
      NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

      // 记录请求开始
      [self logRequestStart:request];

      [self.legacyWebView loadRequest:request];
    }
  }
}

#pragma mark - UISearchBar Delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
  [self loadURLString:searchBar.text];
  [searchBar resignFirstResponder];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"estimatedProgress"]) {
    float progress = self.webView.estimatedProgress;
    BOOL isComplete = (progress == 1);

    // 记录进度历史
    [self.progressHistory addObject:@(progress)];

    // 检测进度突变（判断是否从缓存加载）
    float progressDelta = progress - self.lastProgress;
    if (self.lastProgress > 0 && progressDelta > 0.3) {
      // 进度跳跃超过30%，可能是从缓存加载
      self.progressJumpCount++;
      if (self.progressJumpCount >= 1) {
        self.isLoadingFromCache = YES;
      }
      NSLog(@"[QCTestKit] ⚡️ 检测到进度突变: %.2f -> %.2f (跳跃 "
            @"%.0f%%)，可能来自缓存",
            self.lastProgress * 100, progress * 100, progressDelta * 100);
    }

    self.lastProgress = progress;

    // 进度条
    self.progressView.hidden = isComplete;
    [self setAnimatedProgress:progress];

    // 进度文字
    self.progressLabel.hidden = isComplete;
    if (!isComplete) {
      NSInteger percent = (NSInteger)(progress * 100);
      NSString *statusText = @"加载中";
      if (self.isLoadingFromCache) {
        statusText = @"从缓存加载";
      }
      self.progressLabel.text =
          [NSString stringWithFormat:@"%@ %ld%%", statusText, (long)percent];
    } else {
      if (self.isLoadingFromCache) {
        self.progressLabel.text = @"缓存加载完成";
      } else {
        self.progressLabel.text = @"加载完成";
      }
    }
  } else if ([keyPath isEqualToString:@"canGoBack"]) {
    [self updateNavigationButtons];
  } else if ([keyPath isEqualToString:@"canGoForward"]) {
    [self updateNavigationButtons];
  }
}

- (void)setAnimatedProgress:(float)progress {
  [UIView animateWithDuration:0.1
                   animations:^{
                     [self.progressView setProgress:progress animated:NO];
                   }];
}

- (void)updateNavigationButtons {
  if (self.useWKWebView) {
    self.backButton.enabled = [self.webView canGoBack];
    self.forwardButton.enabled = [self.webView canGoForward];
  } else {
    self.backButton.enabled = [self.legacyWebView canGoBack];
    self.forwardButton.enabled = [self.legacyWebView canGoForward];
  }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:
                        (void (^)(WKNavigationActionPolicy))decisionHandler {
  // 允许所有导航
  decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView
    didStartProvisionalNavigation:(WKNavigation *)navigation {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  // 重置诊断数据
  [self resetDiagnosticData];
  NSLog(@"[QCTestKit] 🔄 开始加载页面: %@", webView.URL.absoluteString);
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  self.searchBar.text = webView.URL.absoluteString;

  if (webView.URL && webView.title) {
    [self.history addObject:@{
      @"title" : webView.title,
      @"url" : webView.URL.absoluteString,
      @"timestamp" : [NSDate date]
    }];
  }

  NSLog(@"[QCTestKit] 🌐 页面导航完成: %@ - %@", webView.URL.absoluteString,
        webView.title);

  // 延迟3秒后自动保存诊断数据（等待性能数据收集完成）
  [NSObject
      cancelPreviousPerformRequestsWithTarget:self
                                     selector:@selector(autoSaveDiagnosticData)
                                       object:nil];
  [self performSelector:@selector(autoSaveDiagnosticData)
             withObject:nil
             afterDelay:3.0];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

  // 忽略常见错误，不做任何提示
  if (error.code == NSURLErrorCancelled ||
      error.code == NSURLErrorUnsupportedURL) {
    return;
  }

  self.loadFailed = YES;
  self.loadError = error;

  NSLog(@"[QCTestKit] ❌ 导航失败: %@ - %@", error.localizedDescription,
        webView.URL.absoluteString);

  // 确保失败也被记录到诊断
  [self saveFailedDiagnostic];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

  // 忽略常见错误，不做任何提示
  if (error.code == NSURLErrorCancelled ||
      error.code == NSURLErrorUnsupportedURL) {
    return;
  }

  self.loadFailed = YES;
  self.loadError = error;

  NSLog(@"[QCTestKit] ❌ 临时导航失败: %@", error.localizedDescription);

  // 确保失败也被记录到诊断
  [self saveFailedDiagnostic];
}

- (void)webView:(WKWebView *)webView
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                    completionHandler:
                        (void (^)(
                            NSURLSessionAuthChallengeDisposition disposition,
                            NSURLCredential *credential))completionHandler {

  if (challenge.protectionSpace.authenticationMethod ==
      NSURLAuthenticationMethodServerTrust) {
    NSURLCredential *credential = [NSURLCredential
        credentialForTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
  } else {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
  }
}

#pragma mark - UIWebViewDelegate (Legacy)

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
  // 记录请求开始
  [self logRequestStart:request];
  return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  self.searchBar.text = webView.request.URL.absoluteString;

  [self.history addObject:@{
    @"title" :
        [webView stringByEvaluatingJavaScriptFromString:@"document.title"],
    @"url" : webView.request.URL.absoluteString,
    @"timestamp" : [NSDate date]
  }];

  NSLog(@"[QCTestKit] 🌐 UIWebView 页面加载完成: %@",
        webView.request.URL.absoluteString);
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  if (error.code != NSURLErrorCancelled) {
    [self showError:error.localizedDescription];
    NSLog(@"[QCTestKit] ❌ UIWebView 加载失败: %@", error.localizedDescription);
  }
}

#pragma mark - Dealloc

- (void)dealloc {
  if (self.webView) {
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.webView removeObserver:self forKeyPath:@"canGoBack"];
    [self.webView removeObserver:self forKeyPath:@"canGoForward"];
  }
}

@end
