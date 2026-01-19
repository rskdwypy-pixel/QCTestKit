//
//  QCNetworkRequestDetailViewController.h
//  QCTestKit
//
//  Created by Claude
//

#import "QCBaseViewController.h"

@class QCNetworkPacket;

NS_ASSUME_NONNULL_BEGIN

/// 网络请求详情页 - 展示单个请求的完整信息
@interface QCNetworkRequestDetailViewController : QCBaseViewController

- (instancetype)initWithPacket:(QCNetworkPacket *)packet;

@end

NS_ASSUME_NONNULL_END
