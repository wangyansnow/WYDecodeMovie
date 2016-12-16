//
//  ViewController.m
//  decodeMovie
//
//  Created by 王俨 on 16/12/14.
//  Copyright © 2016年 wangyan. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "WLVideoDecoder.h"

// MARK: 设备相关
#define IS_IPHONE4 [[UIScreen mainScreen] bounds].size.height == 480.0
#define IS_IPHONE5 [[UIScreen mainScreen] bounds].size.height == 568.0
#define IS_IPHONE6 [[UIScreen mainScreen] bounds].size.height == 667.0
#define IS_IPHONE6PLUS [[UIScreen mainScreen] bounds].size.height == 736.0

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic, assign) NSTimeInterval timeInterval;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    
    if (IS_IPHONE4) {
        self.timeInterval = 0;
    } else if (IS_IPHONE5) {
        self.timeInterval = 0.01;
    } else if (IS_IPHONE6) {
        self.timeInterval = 0.03;
    } else if (IS_IPHONE6PLUS) {
        self.timeInterval = 0.03;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    NSLog(@"内存警告⚠️");
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    self.view.userInteractionEnabled = NO;
    NSString *fileUrlStr = [[NSBundle mainBundle] pathForResource:@"guide.mp4" ofType:nil];
    [WLVideoDecoder decodeVideoURL:[NSURL fileURLWithPath:fileUrlStr] imageRef:^(CGImageRef imageRef) {
        self.imageView.layer.contents = (__bridge id _Nullable)(imageRef);
        CFRelease(imageRef);
    } decodeEnded:^{
        self.view.userInteractionEnabled = YES;
    } error:^(NSError *error) {
        self.view.userInteractionEnabled = YES;
    }];
    
}

#pragma mark - private
- (void)movieDecoder {
    NSString *fileUrlStr = [[NSBundle mainBundle] pathForResource:@"guide.mp4" ofType:nil];
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:fileUrlStr]];
    NSError *error;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    NSLog(@"error = %@", error);
    
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks[0];
    
    // 视频播放时，m_pixelFormatType = kCVPixelFormatType_32BGRA
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
            if (imageRef) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.imageView.layer.contents = (__bridge id _Nullable)(imageRef);
                    CFRelease(imageRef);
                });
            }

            if (videoBuffer) {
                CFRelease(videoBuffer);
            }
            // 根据需要休眠一段时间；比如上层播放视频时每帧之间是有间隔的
            [NSThread sleepForTimeInterval:0.01];
        }
        
    }
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
