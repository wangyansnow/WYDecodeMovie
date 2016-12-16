//
//  WLVideoDecoder.m
//  WangliBank
//
//  Created by 王俨 on 16/12/14.
//  Copyright © 2016年 iSoftstone infomation Technology (Group) Co.,Ltd. All rights reserved.
//

#import "WLVideoDecoder.h"
#import <AVFoundation/AVFoundation.h>

/// block安全使用之宏定义
#define BLOCK_EXEC(block, ...) if (block) { block(__VA_ARGS__); };

@interface WLVideoDecoder ()

@property (nonatomic, copy) void(^imageRefBlock)(CGImageRef imageRef);
@property (nonatomic, copy) void(^endBlock)();
@property (nonatomic, copy) void(^errorBlock)(NSError *error);

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) NSTimeInterval timeInterval;

@end

@implementation WLVideoDecoder

+ (void)decodeVideoURL:(NSURL *)url imageRef:(void(^)(CGImageRef imageRef))imageRefBlock
           decodeEnded:(void(^)())endBlock
                 error:(void(^)(NSError *error))errorBlock {
    
    WLVideoDecoder *videoDecoder = [WLVideoDecoder new];
    
    videoDecoder.imageRefBlock = imageRefBlock;
    videoDecoder.endBlock = endBlock;
    videoDecoder.errorBlock = errorBlock;
    videoDecoder.url = url;
    [videoDecoder configureTimeInterval];
    
    dispatch_async(dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL), ^{
        [videoDecoder movieDecoder];
    });
}


#pragma mark - private

- (void)configureTimeInterval {
    self.timeInterval = 0.03;
}

- (void)movieDecoder {
    
    AVAsset *asset = [AVAsset assetWithURL:self.url];
    NSError *error;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BLOCK_EXEC(self.errorBlock, error);
        });
        return;
    }
    
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks[0];
    
    NSDictionary* options = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:
                                                                (int)kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    AVAssetReaderTrackOutput* videoReaderOutput = [[AVAssetReaderTrackOutput alloc]
                                                   initWithTrack:videoTrack outputSettings:options];
    
    
    [assetReader addOutput:videoReaderOutput];
    [assetReader startReading];
    
    // 要确保nominalFrameRate>0，之前出现过android拍的0帧视频
    while ([assetReader status] == AVAssetReaderStatusReading && videoTrack.nominalFrameRate > 0) {
        @autoreleasepool {
            // 读取video sample
            CMSampleBufferRef videoBuffer = [videoReaderOutput copyNextSampleBuffer];
            
            CGImageRef imageRef = [self imageFromSampleBuffer:videoBuffer];
            if (videoBuffer) CFRelease(videoBuffer);
            
            if (imageRef) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BLOCK_EXEC(self.imageRefBlock, imageRef);
                });
            }
            // 根据需要休眠一段时间；比如上层播放视频时每帧之间是有间隔的
            [NSThread sleepForTimeInterval:self.timeInterval];
        }
        
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 视频解码结束
        BLOCK_EXEC(self.endBlock);
    });
    
}

- (CGImageRef) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return quartzImage;
}


@end
