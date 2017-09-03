//
//  TestController.m
//  goom
//
//  Created by  cherry on 2017/9/3.
//  Copyright © 2017 JEECH. All rights reserved.
//

#import "TestController.h"
#import "GoomView.h"

@interface TestController () {
    GoomView* _testView;
    UIButton * _buttonBack;
    EAGLContext *_context;
}

@end

@implementation TestController

- (void) dealloc {

    _buttonBack = nil;
    _testView = nil;

    _context = nil;

}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor magentaColor];

    _buttonBack = [UIButton buttonWithType:UIButtonTypeCustom];
    [_buttonBack setTitle:@"Back" forState:UIControlStateNormal];
    [_buttonBack addTarget:self
                    action:@selector(buttonBackClicked:)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_buttonBack];
    [_buttonBack setFrame:CGRectMake(40, 400, 100, 30)];

    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }

    _testView = [[GoomView alloc] initWithFrame:CGRectMake(21, 41, 320, 240) context:_context];

    [self.view addSubview:_testView];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)buttonBackClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
