//
//  EAGLContextRenderer.h
//  goom
//
//  Created by  cherry on 2017/9/2.
//  Copyright © 2017年 JEECH. All rights reserved.
//

#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/ES2/glext.h>

#import "OGLESObjects.h"

@interface EAGLContextRenderer : NSObject
@property(nonatomic, readonly) EAGLContext *context;
@property(nonatomic, readonly) GLuint program;

- (instancetype) initWithContext:(EAGLContext*) context;

- (void) setupGL;

- (void) tearDownGL;

- (void) render:(OGLESMappedTexture *) texture to:(GLKView *) glkView inRect:(CGRect) rect;

@end
