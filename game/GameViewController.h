//
//  GameViewController.h
//  game
//
//  Created by 李锐剑 on 2017/12/4.
//  Copyright © 2017年 李锐剑. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <AVFoundation/AVFoundation.h>
#define WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define START_POSITION ([[[UIDevice currentDevice] systemVersion] floatValue] >=7.0 ? 20 : 0)


@interface GameViewController : UIViewController

@end


