//
//  QCCrashTestItem.m
//  QCTestKit
//
//  Created by Claude
//

#import "QCCrashTestItem.h"

@implementation QCCrashTestItem

+ (instancetype)itemWithName:(NSString *)name
                      detail:(NSString *)detail
                        type:(QCCrashType)type
                isDestructive:(BOOL)isDestructive
                    category:(NSString *)category {
    QCCrashTestItem *item = [[self alloc] init];
    item.name = name;
    item.detail = detail;
    item.type = type;
    item.isDestructive = isDestructive;
    item.category = category;
    return item;
}

@end
