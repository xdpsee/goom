//
//  ViewController.m
//  goom
//
//  Created by  cherry on 15-1-4.
//  Copyright (c) 2015年 JEECH. All rights reserved.
//

#import "GoomViewController.h"
#import "GoomObject.h"

#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/ES2/glext.h>

#import "OGLESObjects.h"
#import "EAGLContextRenderer.h"
#import "Superpowered.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

//#define LOGGING

// Attribute index.
enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

// Uniform index.
enum {
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// class ViewController

@interface GoomViewController () {

    CGSize _textureSize;
    OGLESMappedTexture *_mappedTexture1;
    OGLESMappedTexture *_mappedTexture2;

    BOOL _increasing;

    BOOL trickyFirstDisplayDoesLoadNext;

    GoomObject *_goomObject;
    GLKView *_glkView;
    void *_screenBuffer;
    short _audioData[2][512];

    UILabel *_fpsLabel;

    UIButton *_buttonBack;

    BOOL _stop;

    EAGLContextRenderer *_eaglContextRenderer;


    Superpowered *superpowered;
}

@property(nonatomic, strong) EAGLContext *context;

@property(nonatomic, retain) OGLESMappedTexture *mappedTexture1;
@property(nonatomic, retain) OGLESMappedTexture *mappedTexture2;

@property(nonatomic, retain) NSMutableArray *approxFPSValues;

@property(nonatomic, retain) NSMutableArray *lastSecondRenderReportTimes;

@property(nonatomic, retain) NSDate *renderStartDate;

@property(nonatomic, retain) NSDate *lastSecondStartDate;

@property(nonatomic, assign) float approxFPS;


@end

@implementation GoomViewController

- (void)dealloc {

    _glkView = nil;

    [_goomObject close];

    if (_screenBuffer != NULL) {
        free(_screenBuffer);
        _screenBuffer = nil;
    }

    _fpsLabel = nil;
    _buttonBack = nil;

    [_eaglContextRenderer tearDownGL];
    _eaglContextRenderer = nil;

    superpowered = nil;

}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor brownColor];
    // Do any additional setup after loading the view, typically from a nib.
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }

    _eaglContextRenderer = [[EAGLContextRenderer alloc] initWithContext:self.context];
    [_eaglContextRenderer setupGL];

    _textureSize = CGSizeZero;
    _screenBuffer = malloc(375 * 282 * 4);
    memset(_screenBuffer, 0, 375 * 282 * 4);

    [_eaglContextRenderer setupGL];

    [self initTextures];

    _glkView = [[GLKView alloc] initWithFrame:CGRectMake(0, 20, 375, 282) context:self.context];
    _glkView.delegate = self;
    _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    _glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    _glkView.enableSetNeedsDisplay = NO;

    [self.view addSubview:_glkView];

    _goomObject = [[GoomObject alloc] initWithWidth:375 height:282];
    [_goomObject setScreenBuffer:_screenBuffer];


    srand((unsigned) time(NULL));

    _fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 320, 100, 30)];
    [self.view addSubview:_fpsLabel];
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
    [_glkView display];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];


}


- (void)initTextures {
    int maxTextureSize = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);

    CGSize size = CGSizeMake(375, 282);
    //_textureSize = size;

    NSLog(@"loading texture with dimensions %d x %d", (int) size.width, (int) size.height);

    if (size.width > maxTextureSize || size.height > maxTextureSize) {
        NSAssert(FALSE, @"maxTextureSize of %d exceeded, cannot load texture with dimensions %d x %d", maxTextureSize, (int) size.width, (int) size.height);
    }

    // Init front and back mapped textures
    OGLESMappedTexture *mappedTexture1 = [OGLESMappedTexture oGLESMappedTexture:self.context];
    NSAssert(mappedTexture1, @"mappedTexture1");
    self.mappedTexture1 = mappedTexture1;

    OGLESMappedTexture *mappedTexture2 = [OGLESMappedTexture oGLESMappedTexture:self.context];
    NSAssert(mappedTexture2, @"mappedTexture2");
    self.mappedTexture2 = mappedTexture2;

    BOOL worked;

    worked = [mappedTexture1 makeMappedTexture:size];
    NSAssert(worked, @"makeMappedTexture failed");
    worked = [mappedTexture2 makeMappedTexture:size];
    NSAssert(worked, @"makeMappedTexture failed");

    // The very first time the view controller is loaded, render the initial frame
    // of the texture as a blocking operation in the main thread. This is required
    // since the view needs to have an initial state that will be rendered the
    // first time the display method is invoked. Each frame that appears after
    // the first frame will be rendered in a GCD thread and the frame data will
    // not be changed until the background decode operation has completed.

    [mappedTexture1 lockTexture];

    [mappedTexture1 copyFlatPixelsIntoBuffer:(uint32_t *) _screenBuffer];

    [mappedTexture1 unlockTexture];

    mappedTexture1.isReady = TRUE;


    trickyFirstDisplayDoesLoadNext = TRUE;

    self.approxFPSValues = [NSMutableArray array];

    self.lastSecondRenderReportTimes = [NSMutableArray array];

    self.renderStartDate = [NSDate date];
    self.lastSecondStartDate = self.renderStartDate;

    NSLog(@"done with texture prep");

    return;
}


- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    OGLESMappedTexture *mappedTexture;

    if (self.mappedTexture1.isReady) {
        mappedTexture = self.mappedTexture1;
        if (trickyFirstDisplayDoesLoadNext) {
            trickyFirstDisplayDoesLoadNext = FALSE;
            [self loadNextBuffer];
        }
    } else if (self.mappedTexture2.isReady) {
        // Texture 2 is ready to render, it has been fully written at this point
        mappedTexture = self.mappedTexture2;
    } else {
        NSLog(@"neither texture ready to bind and render");
    }

    if (mappedTexture != nil) {
        [_eaglContextRenderer render:mappedTexture to:_glkView];
    }
}

- (void)loadNextBuffer {
    BOOL worked;
    BOOL loadTexture1;

    OGLESMappedTexture *mappedTexture;

    if (self.mappedTexture1.isReady) {
        loadTexture1 = FALSE;
    } else {
        // Texture 2 is loaded, so begin loading texture 1
        loadTexture1 = TRUE;
    }

    if (loadTexture1) {
        mappedTexture = self.mappedTexture1;
    } else {
        mappedTexture = self.mappedTexture2;
    }

    // Lock the CoreVideo memory in the main thread, the result is a pointer
    // to pixels that can be written from the secondary thread without worry
    // about thread safety issues in specific Apple APIs.

    worked = [mappedTexture lockTexture];
    NSAssert(worked, @"lockTexture");
    // Kick off a GCD threaded block op to actually do the PNG decompression
    // into the texture memory.

    __block void *screenBufferRef = _screenBuffer;
    __block OGLESMappedTexture *mappedTextureRef = mappedTexture;

    dispatch_async(dispatch_get_global_queue(0, 0),
            ^{
                if (_stop) {
                    return;
                }

                [_goomObject update:_audioData];

                [mappedTextureRef copyFlatPixelsIntoBuffer:(uint32_t *) screenBufferRef];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self loadNextBufferFinished:mappedTextureRef];
                });
            });

}

// This callback is invoked on the main thread after all PNG image data has been decompressed in the secondary
// thread and written into the texture mapped memory. This callback must unlock the CoreVideo buffer and
// finish processing the texture in this thread so that it will be displayed in the next redraw callback.

- (void)loadNextBufferFinished:(OGLESMappedTexture *)mappedTexture {
    BOOL worked;

    worked = [mappedTexture unlockTexture];
    NSAssert(worked, @"unlockTexture");

    mappedTexture.isReady = TRUE;

    // Mark the other texture as "not ready" since this one is ready now

    if (mappedTexture == self.mappedTexture1) {
        self.mappedTexture2.isReady = FALSE;
    } else if (mappedTexture == self.mappedTexture2) {
        self.mappedTexture1.isReady = FALSE;
    }

    // Start loading the next texture as soon as the previous one is
    // done, since we are sure that the next render call will make use
    // of the texture that just finished loading.

    [_glkView display];

    [self loadNextBuffer];

    return;
}

- (void)buttonBackClicked:(id)sender {
    _stop = YES;


    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
