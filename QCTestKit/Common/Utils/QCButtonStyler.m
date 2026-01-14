//
//  QCButtonStyler.m
//  QCTestKit
//
//  Premium Button Styling Utilities
//

#import "QCButtonStyler.h"

static NSString *const kGradientLayerName = @"QCButtonGradientLayer";
static NSString *const kShadowLayerName = @"QCButtonShadowLayer";
static NSString *const kBorderLayerName = @"QCButtonBorderLayer";
static NSString *const kGlassLayerName = @"QCButtonGlassLayer";

@implementation QCButtonStyler

#pragma mark - Color Palettes

+ (NSArray<UIColor *> *)colorsForStyle:(QCButtonStyle)style {
  switch (style) {
  case QCButtonStylePrimary:
    return @[
      [UIColor colorWithRed:0.20 green:0.50 blue:1.00 alpha:1.0], // 亮蓝色
      [UIColor colorWithRed:0.10 green:0.35 blue:0.85 alpha:1.0]  // 深蓝色
    ];
  case QCButtonStyleSecondary:
    return @[
      [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0],
      [UIColor colorWithRed:0.88 green:0.88 blue:0.92 alpha:1.0]
    ];
  case QCButtonStyleDestructive:
    return @[
      [UIColor colorWithRed:1.00 green:0.35 blue:0.35 alpha:1.0], // 亮红色
      [UIColor colorWithRed:0.90 green:0.20 blue:0.25 alpha:1.0]  // 深红色
    ];
  case QCButtonStyleWarning:
    return @[
      [UIColor colorWithRed:1.00 green:0.60 blue:0.15 alpha:1.0], // 亮橙色
      [UIColor colorWithRed:0.95 green:0.45 blue:0.10 alpha:1.0]  // 深橙色
    ];
  case QCButtonStyleSuccess:
    return @[
      [UIColor colorWithRed:0.25 green:0.85 blue:0.45 alpha:1.0], // 亮绿色
      [UIColor colorWithRed:0.15 green:0.70 blue:0.35 alpha:1.0]  // 深绿色
    ];
  case QCButtonStyleGhost:
  case QCButtonStyleGlass:
    return @[ [UIColor clearColor], [UIColor clearColor] ];
  }
}

+ (UIColor *)textColorForStyle:(QCButtonStyle)style {
  switch (style) {
  case QCButtonStyleSecondary:
    return [UIColor colorWithRed:0.20 green:0.20 blue:0.25 alpha:1.0];
  case QCButtonStyleGhost:
    return [UIColor colorWithRed:0.20 green:0.50 blue:1.00 alpha:1.0];
  case QCButtonStyleGlass:
    return [UIColor whiteColor];
  default:
    return [UIColor whiteColor];
  }
}

+ (UIColor *)shadowColorForStyle:(QCButtonStyle)style {
  switch (style) {
  case QCButtonStylePrimary:
    return [UIColor colorWithRed:0.10 green:0.35 blue:0.85 alpha:0.4];
  case QCButtonStyleDestructive:
    return [UIColor colorWithRed:0.90 green:0.20 blue:0.25 alpha:0.4];
  case QCButtonStyleWarning:
    return [UIColor colorWithRed:0.95 green:0.45 blue:0.10 alpha:0.4];
  case QCButtonStyleSuccess:
    return [UIColor colorWithRed:0.15 green:0.70 blue:0.35 alpha:0.4];
  default:
    return [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1];
  }
}

#pragma mark - Size Configuration

+ (CGFloat)heightForSize:(QCButtonSize)size {
  switch (size) {
  case QCButtonSizeSmall:
    return 28.0;
  case QCButtonSizeMedium:
    return 36.0;
  case QCButtonSizeLarge:
    return 44.0;
  case QCButtonSizeXLarge:
    return 52.0;
  }
}

+ (CGFloat)cornerRadiusForSize:(QCButtonSize)size {
  switch (size) {
  case QCButtonSizeSmall:
    return 8.0;
  case QCButtonSizeMedium:
    return 10.0;
  case QCButtonSizeLarge:
    return 12.0;
  case QCButtonSizeXLarge:
    return 14.0;
  }
}

+ (UIFont *)fontForSize:(QCButtonSize)size {
  switch (size) {
  case QCButtonSizeSmall:
    return [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
  case QCButtonSizeMedium:
    return [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
  case QCButtonSizeLarge:
    return [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
  case QCButtonSizeXLarge:
    return [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
  }
}

+ (UIEdgeInsets)contentInsetsForSize:(QCButtonSize)size {
  switch (size) {
  case QCButtonSizeSmall:
    return UIEdgeInsetsMake(4, 12, 4, 12);
  case QCButtonSizeMedium:
    return UIEdgeInsetsMake(6, 16, 6, 16);
  case QCButtonSizeLarge:
    return UIEdgeInsetsMake(8, 20, 8, 20);
  case QCButtonSizeXLarge:
    return UIEdgeInsetsMake(10, 24, 10, 24);
  }
}

#pragma mark - Public Methods

+ (void)applyStyle:(QCButtonStyle)style toButton:(UIButton *)button {
  [self applyStyle:style size:QCButtonSizeMedium toButton:button];
}

+ (void)applyStyle:(QCButtonStyle)style
              size:(QCButtonSize)size
          toButton:(UIButton *)button {
  // 先移除旧样式
  [self removeStyleFromButton:button];

  // 基础配置
  button.clipsToBounds = NO;
  button.layer.masksToBounds = NO;
  button.titleLabel.font = [self fontForSize:size];
  [button setTitleColor:[self textColorForStyle:style]
               forState:UIControlStateNormal];
  [button
      setTitleColor:[[self textColorForStyle:style] colorWithAlphaComponent:0.7]
           forState:UIControlStateHighlighted];

  CGFloat cornerRadius = [self cornerRadiusForSize:size];

  // 设置内容边距
  UIEdgeInsets insets = [self contentInsetsForSize:size];
  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *config =
        [UIButtonConfiguration plainButtonConfiguration];
    config.contentInsets = NSDirectionalEdgeInsetsMake(
        insets.top, insets.left, insets.bottom, insets.right);
    button.configuration = config;
  } else {
    button.contentEdgeInsets = insets;
  }

  // 根据样式类型应用不同效果
  switch (style) {
  case QCButtonStyleGhost:
    [self applyGhostStyleToButton:button cornerRadius:cornerRadius];
    break;
  case QCButtonStyleGlass:
    [self applyGlassStyleToButton:button cornerRadius:cornerRadius];
    break;
  default:
    [self applyGradientStyleToButton:button
                               style:style
                        cornerRadius:cornerRadius];
    break;
  }

  // 添加触摸动画
  [self addTouchAnimationToButton:button];
}

+ (void)applyGradientToButton:(UIButton *)button
                   startColor:(UIColor *)startColor
                     endColor:(UIColor *)endColor {
  [self removeStyleFromButton:button];

  CAGradientLayer *gradientLayer = [CAGradientLayer layer];
  gradientLayer.name = kGradientLayerName;
  gradientLayer.colors = @[ (id)startColor.CGColor, (id)endColor.CGColor ];
  gradientLayer.startPoint = CGPointMake(0.0, 0.0);
  gradientLayer.endPoint = CGPointMake(1.0, 1.0);
  gradientLayer.frame = button.bounds;
  gradientLayer.cornerRadius =
      button.layer.cornerRadius > 0 ? button.layer.cornerRadius : 10;

  [button.layer insertSublayer:gradientLayer atIndex:0];
  [self addTouchAnimationToButton:button];
}

+ (UIButton *)buttonWithStyle:(QCButtonStyle)style
                         size:(QCButtonSize)size
                        title:(NSString *)title {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button setTitle:title forState:UIControlStateNormal];
  button.translatesAutoresizingMaskIntoConstraints = NO;

  [self applyStyle:style size:size toButton:button];

  return button;
}

+ (void)addTouchAnimationToButton:(UIButton *)button {
  // 移除已存在的动作
  [button removeTarget:self
                action:@selector(buttonTouchDown:)
      forControlEvents:UIControlEventTouchDown];
  [button removeTarget:self
                action:@selector(buttonTouchUp:)
      forControlEvents:UIControlEventTouchUpInside |
                       UIControlEventTouchUpOutside |
                       UIControlEventTouchCancel];

  // 添加触摸动画
  [button addTarget:self
                action:@selector(buttonTouchDown:)
      forControlEvents:UIControlEventTouchDown];
  [button addTarget:self
                action:@selector(buttonTouchUp:)
      forControlEvents:UIControlEventTouchUpInside |
                       UIControlEventTouchUpOutside |
                       UIControlEventTouchCancel];
}

+ (void)removeStyleFromButton:(UIButton *)button {
  // 移除渐变层
  NSArray *layers = [button.layer.sublayers copy];
  for (CALayer *layer in layers) {
    if ([layer.name isEqualToString:kGradientLayerName] ||
        [layer.name isEqualToString:kShadowLayerName] ||
        [layer.name isEqualToString:kBorderLayerName] ||
        [layer.name isEqualToString:kGlassLayerName]) {
      [layer removeFromSuperlayer];
    }
  }

  // 移除毛玻璃视图
  for (UIView *subview in button.subviews) {
    if ([subview isKindOfClass:[UIVisualEffectView class]]) {
      [subview removeFromSuperview];
    }
  }

  button.layer.shadowOpacity = 0;
  button.layer.borderWidth = 0;
}

+ (void)updateCornerRadiusForButton:(UIButton *)button size:(QCButtonSize)size {
  CGFloat cornerRadius = [self cornerRadiusForSize:size];
  button.layer.cornerRadius = cornerRadius;

  for (CALayer *layer in button.layer.sublayers) {
    if ([layer.name isEqualToString:kGradientLayerName]) {
      layer.frame = button.bounds;
      layer.cornerRadius = cornerRadius;
    }
  }
}

#pragma mark - Private Style Helpers

+ (void)applyGradientStyleToButton:(UIButton *)button
                             style:(QCButtonStyle)style
                      cornerRadius:(CGFloat)cornerRadius {
  NSArray<UIColor *> *colors = [self colorsForStyle:style];

  // 创建渐变层
  CAGradientLayer *gradientLayer = [CAGradientLayer layer];
  gradientLayer.name = kGradientLayerName;
  gradientLayer.colors = @[ (id)colors[0].CGColor, (id)colors[1].CGColor ];
  gradientLayer.startPoint = CGPointMake(0.0, 0.0);
  gradientLayer.endPoint = CGPointMake(1.0, 1.0);
  gradientLayer.cornerRadius = cornerRadius;

  // 使用 dispatch_async 确保在布局完成后设置 frame
  dispatch_async(dispatch_get_main_queue(), ^{
    gradientLayer.frame = button.bounds;
    if (gradientLayer.superlayer == nil && button.layer != nil) {
      [button.layer insertSublayer:gradientLayer atIndex:0];
    }
  });

  [button.layer insertSublayer:gradientLayer atIndex:0];

  // 添加阴影
  button.layer.shadowColor = [self shadowColorForStyle:style].CGColor;
  button.layer.shadowOffset = CGSizeMake(0, 4);
  button.layer.shadowRadius = 8;
  button.layer.shadowOpacity = 1.0;

  // 圆角
  button.layer.cornerRadius = cornerRadius;

  // 设置背景色为透明（让渐变可见）
  button.backgroundColor = [UIColor clearColor];
}

+ (void)applyGhostStyleToButton:(UIButton *)button
                   cornerRadius:(CGFloat)cornerRadius {
  button.backgroundColor = [UIColor clearColor];
  button.layer.cornerRadius = cornerRadius;
  button.layer.borderWidth = 2.0;
  button.layer.borderColor =
      [UIColor colorWithRed:0.20 green:0.50 blue:1.00 alpha:1.0].CGColor;

  // 轻微阴影
  button.layer.shadowColor =
      [UIColor colorWithRed:0.20 green:0.50 blue:1.00 alpha:0.2].CGColor;
  button.layer.shadowOffset = CGSizeMake(0, 2);
  button.layer.shadowRadius = 4;
  button.layer.shadowOpacity = 1.0;
}

+ (void)applyGlassStyleToButton:(UIButton *)button
                   cornerRadius:(CGFloat)cornerRadius {
  button.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
  button.layer.cornerRadius = cornerRadius;
  button.layer.borderWidth = 1.0;
  button.layer.borderColor =
      [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;

  // 毛玻璃效果
  UIBlurEffect *blurEffect =
      [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
  UIVisualEffectView *blurView =
      [[UIVisualEffectView alloc] initWithEffect:blurEffect];
  blurView.frame = button.bounds;
  blurView.layer.cornerRadius = cornerRadius;
  blurView.layer.masksToBounds = YES;
  blurView.userInteractionEnabled = NO;
  blurView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  [button insertSubview:blurView atIndex:0];
}

#pragma mark - Touch Animation Actions

+ (void)buttonTouchDown:(UIButton *)button {
  [UIView animateWithDuration:0.1
                        delay:0
                      options:UIViewAnimationOptionCurveEaseIn
                   animations:^{
                     button.transform = CGAffineTransformMakeScale(0.95, 0.95);
                     button.alpha = 0.9;

                     // 更新阴影
                     button.layer.shadowOffset = CGSizeMake(0, 2);
                     button.layer.shadowRadius = 4;
                   }
                   completion:nil];
}

+ (void)buttonTouchUp:(UIButton *)button {
  [UIView animateWithDuration:0.2
                        delay:0
       usingSpringWithDamping:0.5
        initialSpringVelocity:0.5
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     button.transform = CGAffineTransformIdentity;
                     button.alpha = 1.0;

                     // 恢复阴影
                     button.layer.shadowOffset = CGSizeMake(0, 4);
                     button.layer.shadowRadius = 8;
                   }
                   completion:nil];
}

@end
