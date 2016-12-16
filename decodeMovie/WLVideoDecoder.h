//
//  WLVideoDecoder.h
//  WangliBank
//
//  Created by 王俨 on 16/12/14.
//  Copyright © 2016年 iSoftstone infomation Technology (Group) Co.,Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WLVideoDecoder : NSObject

+ (void)decodeVideoURL:(NSURL *)url imageRef:(void(^)(CGImageRef imageRef))imageRefBlock
           decodeEnded:(void(^)())endBlock
                 error:(void(^)(NSError *error))errorBlock;

@end
