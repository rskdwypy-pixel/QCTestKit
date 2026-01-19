//
//  QCDiagnosticHistoryViewController.h
//  QCTestKit
//
//  Created by Claude
//

#import "QCBaseViewController.h"

@class QCNetworkSession;

NS_ASSUME_NONNULL_BEGIN

/// 网络会话详情页 - 显示单个页面会话的所有抓包记录
@interface QCDiagnosticHistoryViewController : QCBaseViewController

- (instancetype)initWithSession:(QCNetworkSession *)session;

@end

NS_ASSUME_NONNULL_END
