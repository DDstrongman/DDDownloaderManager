//
//  DDDownloaderRequest.m
//
//  Created by DDLi on 2019/9/4.
//  Copyright © 2019 LittleLights. All rights reserved.
//

#import "DDDownloaderRequest.h"

@interface DDDownloaderRequest ()

@property (nonatomic, strong) NSString *urlUUID;///< modify inside

@end

@implementation DDDownloaderRequest

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.urlUUID = [[NSUUID UUID] UUIDString];
    self.urlVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];;
    return self;
}

#pragma mark - Support Methods
- (BOOL)compareVersionString:(NSString *)minVersion
              requestVersion:(NSString *)requestVersion {
    if (!minVersion) {
        return YES;
    }
    NSArray *minArray = [@"" componentsSeparatedByString:@"."];
    NSArray *currentArray = [requestVersion componentsSeparatedByString:@"."];
    for (int i = 0; i < minArray.count && i < currentArray.count; i++) {
        if ([currentArray[i] integerValue] > [minArray[i] integerValue]) {
            return YES;
        } else if ([currentArray[i] integerValue] < [minArray[i] integerValue]) {
            return NO;
        } else if (i == currentArray.count - 1 && i == minArray.count - 1) {
            return YES;
        }
    }
    return NO;
}

@end
