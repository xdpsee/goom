//
//  ViewController.h
//  goom
//
//  Created by  cherry on 15-1-4.
//  Copyright (c) 2015年 JEECH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIButton* buttonGoom;

@property (strong, nonatomic) IBOutlet UIButton* buttonProjectM;

- (IBAction) buttonGoomClicked :(id)sender;

- (IBAction) buttonProjectMClicked:(id)sender;

@end

