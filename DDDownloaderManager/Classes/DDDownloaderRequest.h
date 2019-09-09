//
//  DDDownloaderRequest.h
//
//  Created by DDLi on 2019/9/4.
//  Copyright © 2019 LittleLights. All rights reserved.
//  

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDDownloaderRequest : NSObject

@property (nonatomic, copy) NSString *url;///< request url
@property (nonatomic, copy) NSString *urlVersion;///< request url version,default to app version

@property (nonatomic, readonly) NSString *urlUUID;///< the uuid belong to url,read only

/**
 when use request, you must use the class to control download url request version.this method will help you compare the version between two version

 @param minVersion min version
 @param requestVersion requestVersion
 @return satify or not
 */
- (BOOL)compareVersionString:(NSString *)minVersion
              requestVersion:(NSString *)requestVersion;

@end

NS_ASSUME_NONNULL_END
