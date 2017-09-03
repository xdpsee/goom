//
//  ViewController.m
//  goom
//
//  Created by  cherry on 15-1-4.
//  Copyright (c) 2015年 JEECH. All rights reserved.
//

#import "GoomViewController.h"
#import "GoomView.h"
#import "Superpowered.h"



// class ViewController

@interface GoomViewController () {

    short _audioData[2][512];

    GoomView *_goomView;

    UIButton *_buttonBack;

    Superpowered *superpowered;
}

@property(nonatomic, strong) EAGLContext *context;

@end

@implementation GoomViewController

- (void)dealloc {

    [superpowered stop];
    superpowered = nil;

    _goomView = nil;
    _buttonBack = nil;

}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor magentaColor];
    // Do any additional setup after loading the view, typically from a nib.
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }

    _goomView = [[GoomView alloc] initWithFrame:CGRectMake(0, 20, 375, 282) context:self.context];
    _goomView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    _goomView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    _goomView.enableSetNeedsDisplay = NO;

    [self.view addSubview:_goomView];

    srand((unsigned) time(NULL));

    _buttonBack = [UIButton buttonWithType:UIButtonTypeCustom];
    [_buttonBack setTitle:@"Back" forState:UIControlStateNormal];
    [_buttonBack addTarget:self
                    action:@selector(buttonBackClicked:)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_buttonBack];
    [_buttonBack setFrame:CGRectMake(10, 360, 100, 30)];

    superpowered = [[Superpowered alloc] init];

    [superpowered toggle];
}

- (void)viewDidAppear:(BOOL)animated {

    [super viewDidDisappear:animated];

    [_goomView display];

}

- (void)viewDidDisappear:(BOOL)animated {

    [super viewDidDisappear:animated];
}


- (void)buttonBackClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
