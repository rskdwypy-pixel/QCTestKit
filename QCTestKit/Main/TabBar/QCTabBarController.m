//
//  QCTabBarController.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCTabBarController.h"
#import "QCBrowserViewController.h"
#import "QCNetworkTestViewController.h"
#import "QCCrashTestViewController.h"
#import "QCSettingsViewController.h"
#import "QCConstants.h"

@implementation QCTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 配置 TabBar 外观（需要在创建视图控制器之前设置）
    [self configureTabBarAppearance];

    // 创建各个模块的视图控制器
    QCBrowserViewController *browserVC = [[QCBrowserViewController alloc] init];
    UINavigationController *browserNav = [self createNavigationWithRoot:browserVC
                                                                  title:@"浏览器"
                                                           iconName:@"safari"];

    QCNetworkTestViewController *networkVC = [[QCNetworkTestViewController alloc] init];
    UINavigationController *networkNav = [self createNavigationWithRoot:networkVC
                                                                  title:@"网络测试"
                                                           iconName:@"antenna.radiowaves.left.and.right"];

    QCCrashTestViewController *crashVC = [[QCCrashTestViewController alloc] init];
    UINavigationController *crashNav = [self createNavigationWithRoot:crashVC
                                                                title:@"崩溃测试"
                                                             iconName:@"bolt.fill"];

    QCSettingsViewController *settingsVC = [[QCSettingsViewController alloc] init];
    UINavigationController *settingsNav = [self createNavigationWithRoot:settingsVC
                                                                  title:@"设置"
                                                             iconName:@"gearshape.fill"];

    self.viewControllers = @[browserNav, networkNav, crashNav, settingsNav];

    // 检查崩溃恢复
    [self checkCrashRecovery];
}

#pragma mark - Private Methods

- (UINavigationController *)createNavigationWithRoot:(UIViewController *)rootVC
                                                title:(NSString *)title
                                             iconName:(NSString *)iconName {
    rootVC.title = title;

    // 创建图标，使用默认大小
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:iconName];
        UITabBarItem *tabItem = [[UITabBarItem alloc] initWithTitle:title image:image tag:0];
        rootVC.tabBarItem = tabItem;
    } else {
        // iOS 13 以下不支持 SF Symbols，使用文字替代
        UITabBarItem *tabItem = [[UITabBarItem alloc] initWithTitle:title image:nil tag:0];
        rootVC.tabBarItem = tabItem;
    }

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:rootVC];

    // 配置导航栏外观 - 浅色主题
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor whiteColor];
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18]
        };
        appearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]
        };

        navController.navigationBar.standardAppearance = appearance;
        navController.navigationBar.scrollEdgeAppearance = appearance;
        navController.navigationBar.compactAppearance = appearance;
    } else {
        navController.navigationBar.barTintColor = [UIColor whiteColor];
        navController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18]
        };
        navController.navigationBar.translucent = NO;
    }

    navController.navigationBar.tintColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];

    return navController;
}

- (void)configureTabBarAppearance {
    // 选中颜色：蓝色
    UIColor *selectedColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    // 未选中颜色：深灰色（更深的颜色确保可见）
    UIColor *normalColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1.0];

    // 设置 TabBar 的 tintColor（这个会影响所有子项）
    self.tabBar.tintColor = selectedColor;
    self.tabBar.unselectedItemTintColor = normalColor;

    if (@available(iOS 15.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        appearance.backgroundColor = [UIColor whiteColor];

        [appearance configureWithOpaqueBackground];

        // 选中的颜色
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = @{
            NSForegroundColorAttributeName: selectedColor
        };
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor;

        // 未选中的颜色
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = @{
            NSForegroundColorAttributeName: normalColor
        };
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor;

        self.tabBar.standardAppearance = appearance;
        self.tabBar.scrollEdgeAppearance = appearance;
    } else if (@available(iOS 13.0, *)) {
        self.tabBar.barTintColor = [UIColor whiteColor];
    } else {
        self.tabBar.barTintColor = [UIColor whiteColor];
    }
}

- (void)checkCrashRecovery {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:QCCrashRecoveryKey]) {
        [defaults setBool:NO forKey:QCCrashRecoveryKey];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"应用已恢复"
                message:@"检测到应用上次异常退出，可能是由于崩溃测试导致。"
                preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];

            [self presentViewController:alert animated:YES completion:nil];
        });
    }
}

@end
