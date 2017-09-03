//
// Created by  cherry on 2017/9/3.
// Copyright (c) 2017 JEECH. All rights reserved.
//

#import "TestView.h"
#import "GoomObject.h"
#import "EAGLContextRenderer.h"

@interface TestView () {
    GoomObject *_goomObject;
    EAGLContextRenderer *_eaglContextRenderer;
    OGLESMappedTexture *_mainTexture;

    uint32_t * _videoBuffer;
    short _samples[2][512];

    NSTimer* _timer;
    BOOL _rendering;
}

- (instancetype)init;

- (instancetype)initWithFrame:(CGRect)frame;

- (void)setup:(CGRect)frame context:(EAGLContext *)context;

@end

@implementation TestView


- (void)dealloc {

    [_timer invalidate];
    _timer = nil;

    _mainTexture.isReady = FALSE;
    _mainTexture = nil;
    _mainTexture = nil;

    [_goomObject close];
    _goomObject = nil;

    [_eaglContextRenderer tearDownGL];
    _eaglContextRenderer = nil;

    if (_videoBuffer != nil) {
        free(_videoBuffer);
        _videoBuffer = nil;
    }
}

// private
- (instancetype)init {
    return nil;
}

- (instancetype)initWithFrame:(CGRect)frame {

    self = [super initWithFrame:frame];
    if (self != nil) {
        self.delegate = self;
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame context:(EAGLContext *)context {

    self = [super initWithFrame:frame context:context];
    if (self != nil) {
        [self setup:frame context:context];
        self.delegate = self;
    }

    return self;

}

- (void)setup:(CGRect)frame context:(EAGLContext *)context {

    _eaglContextRenderer = [[EAGLContextRenderer alloc] initWithContext:context];
    [_eaglContextRenderer setupGL];

    int maxTextureSize = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);

    const CGSize size = frame.size;
    NSLog(@"loading texture with dimensions %d x %d", (int) size.width, (int) size.height);

    if (size.width > maxTextureSize || size.height > maxTextureSize) {
        NSAssert(FALSE, @"maxTextureSize of %d exceeded, cannot load texture with dimensions %d x %d", maxTextureSize, (int) size.width, (int) size.height);
    }

    // alloc video buffer
    _goomObject = [[GoomObject alloc] initWithWidth:(uint32_t) size.width height:(uint32_t) size.height];
    _videoBuffer = (uint32_t*)malloc(size.width * size.height * 4);
    [_goomObject setScreenBuffer:_videoBuffer];

    // Init front and back mapped textures
    _mainTexture = [OGLESMappedTexture oGLESMappedTexture:context];

    BOOL worked = [_mainTexture makeMappedTexture:size];
    NSAssert(worked, @"makeMappedTexture failed");

    // The very first time the view controller is loaded, render the initial frame
    // of the texture as a blocking operation in the main thread. This is required
    // since the view needs to have an initial state that will be rendered the
    // first time the display method is invoked. Each frame that appears after
    // the first frame will be rendered in a GCD thread and the frame data will
    // not be changed until the background decode operation has completed.
    [_mainTexture lockTexture];
    [_mainTexture copyFlatPixelsIntoBuffer:_videoBuffer];
    [_mainTexture unlockTexture];
    _mainTexture.isReady = TRUE;

    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerCallback:) userInfo:nil repeats:YES];
    [_timer fire];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {

    if (_mainTexture.isReady) {
        [_eaglContextRenderer render:_mainTexture to:view inRect:rect];
        _mainTexture.isReady = FALSE;
    }

}

- (void) timerCallback:(NSTimer*)timer {

    if (!_mainTexture.isReady && !_rendering) {
        [self renderSamples];
    }

}

- (void) renderSamples {

    _rendering = TRUE;
    __block OGLESMappedTexture *mappedTextureRef = _mainTexture;
    bool worked = [mappedTextureRef lockTexture];
    NSAssert(worked, @"lockTexture");


    __block GoomObject *goomObjectRef = _goomObject;
    dispatch_async(dispatch_get_global_queue(0, 0),
            ^{
                [goomObjectRef update:_samples];

                [mappedTextureRef copyFlatPixelsIntoBuffer:_videoBuffer];

                dispatch_async(dispatch_get_main_queue(), ^{
                    bool worked = [mappedTextureRef unlockTexture];
                    NSAssert(worked, @"unlockTexture");

                    _rendering = FALSE;
                    mappedTextureRef.isReady = TRUE;
                    // Start loading the next texture as soon as the previous one is
                    // done, since we are sure that the next render call will make use
                    // of the texture that just finished loading.

                    [self display];

                    [self renderSamples];
                });
            });

}


@end