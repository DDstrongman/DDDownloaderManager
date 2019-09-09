//
//  DDDownloaderItemConfig.h
//  Gkid_Chinese
//
//  Created by DDLi on 2019/9/5.
//  Copyright © 2019 LittleLights. All rights reserved.
//  修改自SDWebimage

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDDownloaderItemConfig : NSObject

/**
 *  disable iCloud backup [defaults to YES]
 */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

/**
 * The maximum length of time to keep an object in the disk, in seconds
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * The maximum count of objects to keep in the disk
 */
@property (assign, nonatomic) NSInteger maxCount;

/**
 * The maximum size of the disk, in bytes.
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

@end

NS_ASSUME_NONNULL_END
