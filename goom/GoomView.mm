//
// Created by  cherry on 2017/9/3.
// Copyright (c) 2017 JEECH. All rights reserved.
//

#import "GoomView.h"
#import "OGLESObjects.h"
#import "GoomObject.h"
#import "EAGLContextRenderer.h"

@interface GoomView () {
    GoomObject *_goomObject;
    EAGLContextRenderer *_eaglContextRenderer;
    OGLESMappedTexture *_mainTexture;
    OGLESMappedTexture *_backupTexture;

    BOOL trickyFirstDisplayDoesLoadNext;
    short _samples[2][512];
}

- (instancetype)init;

- (instancetype)initWithFrame:(CGRect)frame;

- (void)setup:(CGRect)frame context:(EAGLContext *)context;

@end

@implementation GoomView

- (void)dealloc {
    _mainTexture.isReady = FALSE;
    _backupTexture.isReady = FALSE;

    _mainTexture = nil;
    _mainTexture = nil;

    [_goomObject close];
    _goomObject = nil;

    [_eaglContextRenderer tearDownGL];
    _eaglContextRenderer = nil;
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

    // Init front and back mapped textures
    _mainTexture = [OGLESMappedTexture oGLESMappedTexture:context];
    _backupTexture = [OGLESMappedTexture oGLESMappedTexture:context];

    BOOL worked = [_mainTexture makeMappedTexture:size];
    NSAssert(worked, @"makeMappedTexture failed");
    worked = [_backupTexture makeMappedTexture:size];
    NSAssert(worked, @"makeMappedTexture failed");

    // The very first time the view controller is loaded, render the initial frame
    // of the texture as a blocking operation in the main thread. This is required
    // since the view needs to have an initial state that will be rendered the
    // first time the display method is invoked. Each frame that appears after
    // the first frame will be rendered in a GCD thread and the frame data will
    // not be changed until the background decode operation has completed.
    [_mainTexture lockTexture];
    [_mainTexture copyFlatPixelsIntoBuffer:nil];
    [_mainTexture unlockTexture];
    _mainTexture.isReady = TRUE;

    trickyFirstDisplayDoesLoadNext = TRUE;

}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {

    if (_mainTexture.isReady) {
        if (trickyFirstDisplayDoesLoadNext) {
            trickyFirstDisplayDoesLoadNext = NO;
            [self renderSamples];
        }

        [_eaglContextRenderer render:_mainTexture to:view inRect:rect];
    }

    if (_backupTexture.isReady) {
        [_eaglContextRenderer render:_backupTexture to:view inRect:rect];
    }

}

- (void) renderSamples {

    __block OGLESMappedTexture *mappedTextureRef = _mainTexture.isReady ? _backupTexture : _mainTexture;
    bool worked = [mappedTextureRef lockTexture];
    NSAssert(worked, @"lockTexture");

    __block GoomObject *goomObjectRef = _goomObject;
    dispatch_async(dispatch_get_global_queue(0, 0),
            ^{
                [goomObjectRef update:_samples];

                [mappedTextureRef copyFlatPixelsIntoBuffer:nil];

                dispatch_async(dispatch_get_main_queue(), ^{
                    bool worked = [mappedTextureRef unlockTexture];
                    NSAssert(worked, @"unlockTexture");

                    mappedTextureRef.isReady = TRUE;
                    // Mark the other texture as "not ready" since this one is ready now
                    if (mappedTextureRef == self->_mainTexture) {
                        self->_backupTexture.isReady = FALSE;
                    } else if (mappedTextureRef == self->_backupTexture) {
                        self->_mainTexture.isReady = FALSE;
                    }

                    // Start loading the next texture as soon as the previous one is
                    // done, since we are sure that the next render call will make use
                    // of the texture that just finished loading.

                    [self display];

                    [self renderSamples];
                });
            });

}


@end

