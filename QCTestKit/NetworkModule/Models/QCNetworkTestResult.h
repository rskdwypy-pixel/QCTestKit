//
//  QCNetworkTestResult.h
//  QCTestKit
//
//  Created by Claude
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCNetworkTestResult : NSObject

@property (nonatomic, copy) NSString *testName;
@property (nonatomic, copy, nullable) NSString *URL;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, assign) BOOL success;
@property (nonatomic, assign) NSTimeInterval responseTime;
@property (nonatomic, copy, nullable) NSError *error;
@property (nonatomic, copy, nullable) NSString *responseBody;
@property (nonatomic, copy, nullable) NSDictionary *responseHeaders;

- (NSDictionary *)dictionaryValue;

@end

NS_ASSUME_NONNULL_END
