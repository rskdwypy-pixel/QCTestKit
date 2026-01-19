//
//  QCOperationDetailViewController.h
//  QCTestKit
//
//  Created by Claude
//

#import "QCBaseViewController.h"

@class QCNetworkOperation;
@class QCNetworkSession;

NS_ASSUME_NONNULL_BEGIN

/// 操作详情页 - 展示单个操作及其关联的请求
@interface QCOperationDetailViewController : QCBaseViewController

- (instancetype)initWithOperation:(QCNetworkOperation *)operation session:(QCNetworkSession *)session;

@end

NS_ASSUME_NONNULL_END
