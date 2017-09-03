//
//  EAGLContextWrapper.h
//  goom
//
//  Created by  cherry on 2017/9/2.
//  Copyright © 2017年 JEECH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

#import <AVFoundation/AVFoundation.h>
#include <OpenGLES/ES2/glext.h>

@interface EAGLContextWrapper : NSObject
@property(nonatomic, readonly) EAGLContext *context;
@property(nonatomic, readonly) GLuint program;
@property(nonatomic, readonly) GLuint quadVBO;
@property(nonatomic, readonly) GLuint quadVBOIndexes;
@property(nonatomic, readonly) GLuint textureVBO;

- (instancetype) initWithContext:(EAGLContext*) context;

- (void) setupGL;

- (BOOL) validateProgram;

- (void) tearDownGL;

@end
