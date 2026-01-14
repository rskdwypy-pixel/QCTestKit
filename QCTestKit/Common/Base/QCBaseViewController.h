//
//  QCBaseViewController.h
//  QCTestKit
//
//  Created by Claude
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCBaseViewController : UIViewController

// 主题色
@property (nonatomic, strong, readonly) UIColor *primaryColor;
@property (nonatomic, strong, readonly) UIColor *backgroundColor;
@property (nonatomic, strong, readonly) UIColor *textColor;

// 设置导航栏标题
- (void)setupNavigationWithTitle:(NSString *)title;

// 返回按钮
- (void)setupBackButton;

// 显示加载指示器
- (void)showLoading;
- (void)hideLoading;

// 显示提示消息
- (void)showMessage:(NSString *)message;
- (void)showError:(NSString *)error;

@end

NS_ASSUME_NONNULL_END
