//
// Created by  cherry on 2017/9/3.
// Copyright (c) 2017 JEECH. All rights reserved.
//

#import <GLKit/GLKit.h>


@interface GoomView : GLKView<GLKViewDelegate>

- (instancetype) initWithFrame:(CGRect)frame context:(EAGLContext *)context;

- (void) updateAudioSamples:(short[2][512]) samples;

@end


