# DDDownloaderManager


## 描述
**是不是感觉SDWebImage太tm好用了，但是想下其他文件又不想要那么多解析图片之类的其他功能？**<br>

**DDDownloaderManager就是由此产生的，剥离了SDWebImage下载和硬盘缓存的功能，添加了部分下载api管理的功能，添加了批量多线程下载功能等等下载库该有的功能，在工程项目使用中可能进一步添加其他下载库好用的功能** <br>

推荐入口函数： <br>

**使用request类发起请求，能够进行简单的请求api管理**

```objective-c
- (nullable NSMutableArray <id <DDWebObjectCancelOperation>> *)downloadObjectWithRequests:(nullable NSMutableArray <DDDownloaderRequest *> *)requests 
  options:(DDDownloaderOptions)options 
    progress:(nullable DDWebObjectDownloaderProgressBlock)progressBlock
      singleCompleted:(nullable DDDownloadCompletionBlock)completedBlock
        allCompleted:(nullable DDDownloadAllCompletionBlock)allCompleteBlock;
```
举个简单粗暴塞入urls的🌰:

```objective-c
NSMutableArray *testArray = [NSMutableArray array];
    for (int i = 0; i < 15; i++) {
        [testArray addObject:@"https://www.baidu.com"];
    }
[[DDDownloaderManager sharedManager]downloadObjectWithURLS:testArray
                                                       options:DDDownloaderRetryFailed progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
                                                           NSLog(@"progress======%ld,expectedSize========%ld",receivedSize,expectedSize);
                                                       }
                                               singleCompleted:^(NSData * _Nullable data, NSError * _Nullable error, BOOL finished, NSURL * _Nullable objectURL, NSString * _Nullable filePath) {
                                                   NSLog(@"objectUrl=======%@,result=======%ld,fileUrl======%@",objectURL,finished,filePath);
                                                   
                                               }
                                                  allCompleted:^(BOOL finished) {
                                                      NSLog(@"result=======%ld",finished);
                                                  }];
```



**其他更多功能请参考.h文件内说明**

## Requirements

## Installation

DDDownloaderManager is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "DDDownloaderManager"
```

## Author

DDStrongman, lishengshu232@gmail.com

## License

DDDownloaderManager is available under the MIT license. See the LICENSE file for more info.
