//
//  GameViewController.m
//  game
//
//  Created by 李锐剑 on 2017/12/4.
//  Copyright © 2017年 李锐剑. All rights reserved.
//

#import "GameViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreMotion/CoreMotion.h>
//c++ code start
#import "opencv2/highgui/ios.h"
#include <opencv2/opencv.hpp>
#include "opencv2/nonfree/nonfree.hpp"
#include "opencv2/legacy/legacy.hpp"
#include <vector>
using namespace std;

//c++ code end

double horiTheta = 0;
double selfTheta = 0;
int timeCount = 0;

cv::Mat SURF(cv::Mat image);

//change Mat to UIImage, must be rewrite or that we will lose orientation
UIImage *UIImageFromCVMat(cv::Mat cvMat);


@implementation GameViewController{
    AVCaptureSession *_captureSession;
    UIImageView *_outputImageView;
    AVCaptureVideoPreviewLayer *_captureLayer;
    CMMotionManager *motionManager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //run function findTheta
    [self initMotionManager];
    
    
    //self.view.backgroundColor = [UIColor whiteColor];
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] error:nil];
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc]init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    //AVCaptureVideoDataOutput->AVCaptureDevice   minFrameDuration->videoMinFrameDuration
    //captureOutput.minFrameDuration = CMTimeMake(1, 15);
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    //add id<AVCaptureVideoDataOutputSampleBufferDelegate> _Nullable to solve the type convertion
    [captureOutput setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate> _Nullable)self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession addInput:captureInput];
    [_captureSession addOutput:captureOutput];
    //start
    [_captureSession startRunning];
    
    
    //show output
    _outputImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0,0,WIDTH,HEIGHT)];
    
    //_outputImageView.image has type UIImage
    [self.view addSubview:_outputImageView];
}



#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    //lock start address for pragma
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    //get information about image
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //create rgb image, store in newImage
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress,width, height, 8, bytesPerRow, colorSpace,kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    //release useless data
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image= [UIImage imageWithCGImage:newImage];
    timeCount += 1;
    
    CGImageRelease(newImage);
    cv::Mat cv_img;
    //change to mat, deal by opencv
    UIImageToMat(image, cv_img);
    cv::cvtColor(cv_img,cv_img,CV_RGBA2RGB,3);
    
    [self findTheta];
    cv_img = SURF(cv_img);
        
    image = UIImageFromCVMat(cv_img);
    
    [_outputImageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
    //unlock
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}



- (void)initMotionManager
{
    //initialize motion object
    motionManager = [[CMMotionManager alloc] init];
    if(motionManager.accelerometerAvailable) {
        //update interval
        motionManager.accelerometerUpdateInterval=0.1f;
        [motionManager startAccelerometerUpdates];
    }
}
- (void)findTheta
{
    CMAcceleration accel = motionManager.accelerometerData.acceleration;
    //0-90 is used
    horiTheta = -(atan2(accel.z,sqrtf(accel.x*accel.x+accel.y*accel.y))/M_PI*(-90.0)*2-90);
    selfTheta = atan2(accel.x,accel.y)/M_PI*180.0;
    //left(0 - 180) right(0 - -180)
    selfTheta = selfTheta>0?(selfTheta-180.0):(selfTheta+180.0);
    NSLog(@"手机与水平面夹角是%.2f,手机绕自身旋转角是%.2f",horiTheta,selfTheta);
}



- (void) handleTap:(UIGestureRecognizer*)gestureRecognize
{
    // retrieve the SCNView
    SCNView *scnView = (SCNView *)self.view;
    
    // check what nodes are tapped
    CGPoint p = [gestureRecognize locationInView:scnView];
    NSArray *hitResults = [scnView hitTest:p options:nil];
    
    // check that we clicked on at least one object
    if([hitResults count] > 0){
        // retrieved the first clicked object
        SCNHitTestResult *result = [hitResults objectAtIndex:0];
        
        // get its material
        SCNMaterial *material = result.node.geometry.firstMaterial;
        
        // highlight it
        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:0.5];
        
        // on completion - unhighlight
        [SCNTransaction setCompletionBlock:^{
            [SCNTransaction begin];
            [SCNTransaction setAnimationDuration:0.5];
            
            material.emission.contents = [UIColor blackColor];
            
            [SCNTransaction commit];
        }];
        
        material.emission.contents = [UIColor redColor];
        
        [SCNTransaction commit];
    }
}
//show status bar
- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


@end

double angle( cv::Point pt1, cv::Point pt2, cv::Point pt0 ) {
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}

cv::Mat SURF(cv::Mat image) {
    //resize frame
    cv::resize(image, image, cvSize(0,0), 0.5, 0.5, cv::INTER_LINEAR);
    // source card image
    UIImage* resImage=[UIImage imageNamed:@"art.scnassets/temp.JPG"];
    cv::Mat cardImage;
    UIImageToMat(resImage, cardImage);
    std::vector<cv::KeyPoint>keypoints1;
    std::vector<cv::KeyPoint>keypoints2;
    cv::SurfFeatureDetector surf(2500);
    surf.detect(cardImage,keypoints1);
    surf.detect(image,keypoints2);
    if (keypoints2.size() ==0){
        return image;
    }
    //get descriptor
    cv::SurfDescriptorExtractor SurfDescriptor;
    cv::Mat imageDesc1,imageDesc2;
    SurfDescriptor.compute(cardImage,keypoints1,imageDesc1);
    SurfDescriptor.compute(image,keypoints2,imageDesc2);
    //match descriptor
    cv::FlannBasedMatcher matcher;
    std::vector<cv::DMatch> matchePoints;
    matcher.match(imageDesc1,imageDesc2,matchePoints,cv::Mat());
    //find good descriptor
    double minMatch=1;
    double maxMatch=0;
    for(int i=0;i<matchePoints.size();i++)
    {
        minMatch=minMatch>matchePoints[i].distance?matchePoints[i].distance:minMatch;
        maxMatch=maxMatch<matchePoints[i].distance?matchePoints[i].distance:maxMatch;
    }
    std::vector<cv::DMatch> goodMatchePoints;
    for(int i=0;i<matchePoints.size();i++)
    {
        if(matchePoints[i].distance<minMatch+(maxMatch-minMatch-0.2)/2)
        {
            goodMatchePoints.push_back(matchePoints[i]);
        }
    }
    
    std::vector<cv::KeyPoint> test2;
    for (size_t i = 0; i < goodMatchePoints.size(); i++) {
        test2.push_back(keypoints2[goodMatchePoints[i].trainIdx]);
    }
    cv::Mat imageOutput;
    cv::drawKeypoints(image,test2,imageOutput,cv::Scalar(255,0,0),
                      cv::DrawMatchesFlags::DRAW_RICH_KEYPOINTS);
    //resize back
    cv::resize(imageOutput, imageOutput, cvSize(0,0), 2, 2, cv::INTER_LINEAR);
    return imageOutput;
}

UIImage *UIImageFromCVMat(cv::Mat cvMat)
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    /*if (cvMat.elemSize() == 1) {
     colorSpace = CGColorSpaceCreateDeviceGray();
     }*/
    colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,cvMat.rows,8,8 * cvMat.elemSize(),cvMat.step[0],colorSpace,kCGImageAlphaNone|kCGBitmapByteOrderDefault,provider,NULL,false,kCGRenderingIntentDefault);
    
    // Getting UIImage from CGImage   must change orientation here!!!!!!
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:1 orientation:UIImageOrientationRight];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return result;
}

