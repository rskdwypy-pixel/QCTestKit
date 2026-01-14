//
//  QCBaseViewController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCBaseViewController.h"

@interface QCBaseViewController ()

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) NSTimer *toastTimer;

@end

@implementation QCBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.95 alpha:1.0]; // 乳白色背景
    self.edgesForExtendedLayout = UIRectEdgeNone;
}

#pragma mark - Properties

- (UIColor *)primaryColor {
    return [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
}

- (UIColor *)backgroundColor {
    return [UIColor colorWithRed:0.95 green:0.95 blue:0.93 alpha:1.0];
}

- (UIColor *)textColor {
    return [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]; // 深色文字
}

#pragma mark - Setup Methods

- (void)setupNavigationWithTitle:(NSString *)title {
    self.title = title;

    // iOS 13+ 使用 UINavigationBarAppearance
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor whiteColor];
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: self.textColor,
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18]
        };
        appearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: self.textColor,
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18]
        };

        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    } else {
        self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
        self.navigationController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: self.textColor,
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18]
        };
    }

    self.navigationController.navigationBar.tintColor = self.primaryColor;
    self.navigationController.navigationBar.translucent = NO;
}

- (void)setupBackButton {
    // iOS 默认返回按钮已足够，这里可以自定义
}

#pragma mark - Loading

- (void)showLoading {
    if (!self.loadingOverlay) {
        self.loadingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
        self.loadingOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        self.loadingOverlay.userInteractionEnabled = YES;

        self.loadingIndicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        self.loadingIndicator.color = [UIColor whiteColor];
        self.loadingIndicator.center = self.loadingOverlay.center;
        [self.loadingOverlay addSubview:self.loadingIndicator];
    }

    [self.view addSubview:self.loadingOverlay];
    [self.loadingIndicator startAnimating];
}

- (void)hideLoading {
    [self.loadingIndicator stopAnimating];
    [self.loadingOverlay removeFromSuperview];
}

#pragma mark - Toast Messages

- (void)showToast:(NSString *)message {
    [self hideToast];

    // 创建 Toast 容器
    UIView *toastContainer = [[UIView alloc] init];
    toastContainer.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.95];
    toastContainer.layer.cornerRadius = 12;
    toastContainer.layer.masksToBounds = YES;
    toastContainer.translatesAutoresizingMaskIntoConstraints = NO;

    // 创建 Toast 标签
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.text = message;
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.font = [UIFont systemFontOfSize:15];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.numberOfLines = 0;
    toastLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastLabel = toastLabel;

    [toastContainer addSubview:toastLabel];
    [self.view addSubview:toastContainer];

    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [toastContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toastContainer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-100],
        [toastContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40],
        [toastContainer.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40],
        [toastContainer.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        [toastLabel.topAnchor constraintEqualToAnchor:toastContainer.topAnchor constant:12],
        [toastLabel.leadingAnchor constraintEqualToAnchor:toastContainer.leadingAnchor constant:16],
        [toastLabel.trailingAnchor constraintEqualToAnchor:toastContainer.trailingAnchor constant:-16],
        [toastLabel.bottomAnchor constraintEqualToAnchor:toastContainer.bottomAnchor constant:-12]
    ]];

    // 动画显示
    toastContainer.alpha = 0;
    toastContainer.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.3 animations:^{
        toastContainer.alpha = 1;
        toastContainer.transform = CGAffineTransformIdentity;
    }];

    // 2秒后自动隐藏
    self.toastTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(hideToast) userInfo:nil repeats:NO];
}

- (void)hideToast {
    if (self.toastTimer && self.toastTimer.isValid) {
        [self.toastTimer invalidate];
        self.toastTimer = nil;
    }

    // 查找 Toast 容器（带特定特征的 view）
    for (UIView *subview in self.view.subviews) {
        if (subview.layer.cornerRadius == 12 && subview.subviews.count > 0) {
            UILabel *label = (UILabel *)subview.subviews.firstObject;
            if ([label isKindOfClass:[UILabel class]] && label == self.toastLabel) {
                [UIView animateWithDuration:0.3 animations:^{
                    subview.alpha = 0;
                    subview.transform = CGAffineTransformMakeScale(0.9, 0.9);
                } completion:^(BOOL finished) {
                    [subview removeFromSuperview];
                }];
                self.toastLabel = nil;
                break;
            }
        }
    }
}

#pragma mark - Messages

- (void)showMessage:(NSString *)message {
    [self showToast:message];
}

- (void)showError:(NSString *)error {
    [self showToast:error];
}

- (void)showAlert:(NSString *)message title:(NSString *)title {
    // 使用 Toast 替代 Alert
    [self showToast:message];
}

@end
