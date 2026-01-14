//
//  QCNetworkTestResult.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCNetworkTestResult.h"

@implementation QCNetworkTestResult

- (NSDictionary *)dictionaryValue {
    return @{
        @"testName": self.testName ?: @"",
        @"URL": self.URL ?: @"",
        @"statusCode": @(self.statusCode),
        @"success": @(self.success),
        @"responseTime": @(self.responseTime),
        @"error": self.error.localizedDescription ?: @"",
        @"responseBody": self.responseBody ?: @"",
        @"responseHeaders": self.responseHeaders ?: @{}
    };
}

- (NSString *)description {
    if (self.success) {
        return [NSString stringWithFormat:@"✅ %@\n状态码: %ld\n耗时: %.0fms\n响应: %@",
                self.testName,
                (long)self.statusCode,
                self.responseTime * 1000,
                self.responseBody ?: @"(空)"];
    } else {
        return [NSString stringWithFormat:@"❌ %@\n错误: %@",
                self.testName,
                self.error.localizedDescription];
    }
}

@end
