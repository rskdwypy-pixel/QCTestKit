//
//  QCButtonStyler.h
//  QCTestKit
//
//  Premium Button Styling Utilities
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QCButtonStyle) {
    QCButtonStylePrimary,        // 主要操作 - 渐变蓝色
    QCButtonStyleSecondary,      // 次要操作 - 浅色背景
    QCButtonStyleDestructive,    // 危险操作 - 渐变红色
    QCButtonStyleWarning,        // 警告操作 - 渐变橙色
    QCButtonStyleSuccess,        // 成功操作 - 渐变绿色
    QCButtonStyleGhost,          // 幽灵按钮 - 透明背景描边
    QCButtonStyleGlass           // 玻璃态按钮 - 毛玻璃效果
};

typedef NS_ENUM(NSInteger, QCButtonSize) {
    QCButtonSizeSmall,           // 小尺寸 28pt高度
    QCButtonSizeMedium,          // 中尺寸 36pt高度
    QCButtonSizeLarge,           // 大尺寸 44pt高度
    QCButtonSizeXLarge           // 超大尺寸 52pt高度
};

@interface QCButtonStyler : NSObject

/// 应用预设样式到按钮
+ (void)applyStyle:(QCButtonStyle)style
          toButton:(UIButton *)button;

/// 应用带尺寸的预设样式
+ (void)applyStyle:(QCButtonStyle)style
              size:(QCButtonSize)size
          toButton:(UIButton *)button;

/// 应用自定义渐变样式
+ (void)applyGradientToButton:(UIButton *)button
                   startColor:(UIColor *)startColor
                     endColor:(UIColor *)endColor;

/// 创建一个带样式的按钮
+ (UIButton *)buttonWithStyle:(QCButtonStyle)style
                         size:(QCButtonSize)size
                        title:(NSString *)title;

/// 添加按压动画效果
+ (void)addTouchAnimationToButton:(UIButton *)button;

/// 移除按钮样式层
+ (void)removeStyleFromButton:(UIButton *)button;

/// 更新按钮边角半径（用于布局后更新）
+ (void)updateCornerRadiusForButton:(UIButton *)button size:(QCButtonSize)size;

@end

NS_ASSUME_NONNULL_END
