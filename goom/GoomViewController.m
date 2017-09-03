//
//  ViewController.m
//  goom
//
//  Created by  cherry on 15-1-4.
//  Copyright (c) 2015年 JEECH. All rights reserved.
//

#import "GoomViewController.h"
#import "GoomObject.h"
#import <GLKit/GLKit.h>

#import "AEAudioController.h"
#import "AEAudioFilePlayer.h"
#import "AEBlockFilter.h"

#import <AVFoundation/AVFoundation.h>
#include <OpenGLES/ES2/glext.h>

#import "OGLESObjects.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

//#define LOGGING

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

// Uniform index.
enum
{
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// class ViewController

@interface GoomViewController() {
    GLuint _program;
    CGSize _textureSize;
    GLuint quadVBO;
    GLuint quadVBOIndexes;
    GLuint textureVBO;
    OGLESMappedTexture *_mappedTexture1;
    OGLESMappedTexture *_mappedTexture2;
    
    BOOL _increasing;
    
    BOOL trickyFirstDisplayDoesLoadNext;
    
    GoomObject* _goomObject;
    GLKView* _glkView;
    CADisplayLink* _displayLink;
    void* _screenBuffer;
    short _audioData[2][512];
    
    UILabel* _fpsLabel;
    
    UIButton* _buttonBack;
    
    BOOL _stop;
    
    AEAudioController* _audioController;
}

@property (nonatomic, strong) EAGLContext *context;

@property (nonatomic, copy) NSArray *cyclePNGDataArr;

@property (nonatomic, retain) OGLESMappedTexture *mappedTexture1;
@property (nonatomic, retain) OGLESMappedTexture *mappedTexture2;

@property (nonatomic, retain) NSMutableArray *approxFPSValues;

@property (nonatomic, retain) NSMutableArray *lastSecondRenderReportTimes;

@property (nonatomic, retain) NSDate *renderStartDate;

@property (nonatomic, retain) NSDate *lastSecondStartDate;

@property (nonatomic, assign) float approxFPS;


- (void) setupGL;

@end

@implementation GoomViewController

- (void) dealloc {
    
    [_displayLink invalidate];
    _displayLink = nil;
    
    _glkView = nil;
    
    [_goomObject close];
    
    if (_screenBuffer != NULL) {
        free(_screenBuffer);
        _screenBuffer = nil;
    }
    
    _fpsLabel = nil;
    _buttonBack = nil;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor brownColor];
    // Do any additional setup after loading the view, typically from a nib.
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    quadVBO = 0;
    quadVBOIndexes = 0;
    textureVBO = 0;
    
    _textureSize = CGSizeZero;
    _screenBuffer = malloc(320 * 240 * 4);
    memset(_screenBuffer, 0, 320 * 240 * 4);
    
    [self setupGL];
    
    _glkView = [[GLKView alloc] initWithFrame:CGRectMake(0, 20, 320, 240) context:self.context];
    _glkView.delegate = self;
    _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    _glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    _glkView.enableSetNeedsDisplay = NO;
    
    [self.view addSubview:_glkView];
    
    _goomObject = [[GoomObject alloc] initWithWidth:320 height:240];

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
    _displayLink.frameInterval = 2;
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    srand((unsigned)time(NULL));
    
    _fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 280, 100, 30)];
    [self.view addSubview:_fpsLabel];
    _buttonBack = [UIButton buttonWithType:UIButtonTypeCustom];
    [_buttonBack setTitle:@"Back" forState:UIControlStateNormal];
    [_buttonBack addTarget:self
                   action:@selector(buttonBackClicked:)
         forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_buttonBack];
    [_buttonBack setFrame:CGRectMake(10, 320, 100, 30)];
    
    _audioController = [[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleaved16BitStereoAudioDescription] inputEnabled:FALSE];
    _audioController.preferredBufferDuration = 0.005;
    
    [_audioController setAudioSessionCategory:AVAudioSessionCategoryPlayback];
    
    NSError* error = nil;
    [_audioController start:&error];
    
    error = nil;
    NSMutableArray* urls = [NSMutableArray array];
    [urls addObject:[[NSBundle mainBundle] URLForResource:@"Thriller" withExtension:@"mp3"]];
    [urls addObject:[[NSBundle mainBundle] URLForResource:@"Bad" withExtension:@"mp3"]];
    [urls addObject:[[NSBundle mainBundle] URLForResource:@"Billie Jean" withExtension:@"mp3"]];
    [urls addObject:[[NSBundle mainBundle] URLForResource:@"Dangerous" withExtension:@"mp3"]];
    
    srand((unsigned int)time(NULL));
    
    int select = rand() % 4;
    
    NSURL* url = urls[3];
    
    AEAudioFilePlayer* filePlayer = [AEAudioFilePlayer audioFilePlayerWithURL:url audioController:_audioController error:&error];
    filePlayer.removeUponFinish = NO;
    [_audioController addChannels:@[filePlayer]];
    
    AEBlockFilter* blockFilter = [AEBlockFilter filterWithBlock:^(AEAudioControllerFilterProducer producer, void *producerToken, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
        // Pull audio
        OSStatus status = producer(producerToken, audio, &frames);
        if ( status != noErr ) return;
        
        if (audio->mNumberBuffers == 1) {
            AudioBuffer buffer = audio->mBuffers[0];
            memcpy(_audioData[0], buffer.mData, MIN(512, buffer.mDataByteSize));
            memcpy(_audioData[1], buffer.mData, MIN(512, buffer.mDataByteSize));
        } else if (audio->mNumberBuffers >= 2){
            AudioBuffer buffer = audio->mBuffers[0];
            memcpy(_audioData[0], buffer.mData, MIN(512, buffer.mDataByteSize));
            buffer = audio->mBuffers[1];
            memcpy(_audioData[1], buffer.mData, MIN(512, buffer.mDataByteSize));
        }
    }];
    
    [_audioController addFilter:blockFilter];
    
}

- (void) viewDidAppear:(BOOL)animated {
    [_glkView display];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    
}

- (void) setupGL {
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    [self initTextures];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    glDeleteBuffers(1, &quadVBO);
    glDeleteBuffers(1, &quadVBOIndexes);
    glDeleteBuffers(1, &textureVBO);
}

- (void) initTextures
{
    int maxTextureSize = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    
    CGSize size = CGSizeMake(320, 240);
    _textureSize = size;
    
    NSLog(@"loading texture with dimensions %d x %d", (int)size.width, (int)size.height);
    
    if (size.width > maxTextureSize || size.height > maxTextureSize) {
        NSAssert(FALSE, @"maxTextureSize of %d exceeded, cannot load texture with dimensions %d x %d", maxTextureSize, (int)size.width, (int)size.height);
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
    
    [mappedTexture1 copyFlatPixelsIntoBuffer:_screenBuffer];
    
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


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    if (self.isViewLoaded && nil == self.view.window) {
        [self tearDownGL];
    }
}


- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    //NSLog(@"draw");
    
    // Bind the texture that is ready to display
    
    glActiveTexture(GL_TEXTURE0);
    
    OGLESMappedTexture *mappedTexture;
    
    if (self.mappedTexture1.isReady) {
#if defined(LOGGING)
        NSLog(@"texture1 ready to bind and render");
#endif
        
        // Texture 1 is ready to render, it has been fully written at this point
        mappedTexture = self.mappedTexture1;
        [mappedTexture bindTexture];
        
        if (trickyFirstDisplayDoesLoadNext) {
            trickyFirstDisplayDoesLoadNext = FALSE;
            [self loadNextBuffer];
        }
    } else if (self.mappedTexture2.isReady) {
#if defined(LOGGING)
        NSLog(@"texture2 ready to bind and render");
#endif
        
        // Texture 2 is ready to render, it has been fully written at this point
        mappedTexture = self.mappedTexture2;
        [mappedTexture bindTexture];
        
        //[self loadNextBuffer];
        //self.mappedTexture2.isReady = FALSE;
    } else {
        NSLog(@"neither texture ready to bind and render");
    }
    
#if TARGET_IPHONE_SIMULATOR
    // OpenGL does not know that texture data was changed when running in the simulator. Explictly
    // "upload" the visual data to the texture when running in the simulator. This should
    // not be needed, but it is needed. Because GL_UNPACK_ROW_LENGTH is not supported on iOS,
    // this logic bends over backwards to allocate a new flat copy of the framebuffer and then
    // upload this flat framebuffer copy to the textture, this is way too much extra work
    // but performance on the simulator does not matter as long as something is visible.
    
    if (mappedTexture) {
        BOOL worked;
        
        worked = [mappedTexture lockTexture];
        NSAssert(worked, @"lockTexture failed");
        
        uint32_t *flatCopy = malloc(mappedTexture.width * mappedTexture.height * sizeof(uint32_t));
        [mappedTexture copyIntoFlatPixelsBuffer:flatCopy];
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, mappedTexture.width, mappedTexture.height, GL_BGRA_EXT, GL_UNSIGNED_BYTE, flatCopy);
        free(flatCopy);
        
        worked = [mappedTexture unlockTexture];
        NSAssert(worked, @"unlockTexture failed");
    }
#endif // TARGET_IPHONE_SIMULATOR
    
    // Set texture parameters for "indexes" texture
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // Done setting texture
    
    uint32_t width  = _textureSize.width;
    uint32_t height = _textureSize.height;
    CGRect presentationRect = CGRectMake(0, 0, width, height);
    
    // done with texture setup
    
    CGRect bounds = _glkView.bounds;
    
    // Must call glUseProgram() before attaching uniform properties
    
    glUseProgram(_program);
    
    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
    
#if defined(DEBUG)
    [self validateProgram:_program];
#endif
    
    // http://duriansoftware.com/joe/An-intro-to-modern-OpenGL.-Chapter-2.1:-Buffers-and-Textures.html
    
    // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
    CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(presentationRect.size, bounds);
    
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(0.0, 0.0);
    CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/bounds.size.width, vertexSamplingRect.size.height/bounds.size.height);
    
    // Normalize the quad vertices.
    if (cropScaleAmount.width > cropScaleAmount.height) {
        normalizedSamplingSize.width = 1.0;
        normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
    }
    else {
        normalizedSamplingSize.width = 1.0;
        normalizedSamplingSize.height = cropScaleAmount.width/cropScaleAmount.height;
    }
    
    // The quad vertex data defines the region of 2D plane onto which we draw our pixel buffers.
    // Vertex data formed using (-1,-1) and (1,1) as the bottom left and top right coordinates respectively.
    // covers the entire screen.
    
    GLfloat quadVertexData[] = {
        -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
        normalizedSamplingSize.width, normalizedSamplingSize.height,
    };
    
    static const GLushort quadVertexDataIndexes[] = { 0, 1, 2, 3 };
    
    if (quadVBO == 0) {
        glGenBuffers(1, &quadVBO);
        glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertexData), &quadVertexData[0], GL_STATIC_DRAW);
        //glEnableClientState(GL_VERTEX_ARRAY);
    }
    
    if (quadVBOIndexes == 0) {
        glGenBuffers(1, &quadVBOIndexes);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quadVBOIndexes);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(quadVertexDataIndexes), &quadVertexDataIndexes[0], GL_STATIC_DRAW);
    }
    
    // Bind vertex coordinates buffer, connect shader to already allocated vertex buffer
    
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
    //glEnableClientState(GL_VERTEX_ARRAY);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    
    // Bind vertex coordinate indexes
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quadVBOIndexes);
    
    // The texture vertices are set up such that we flip the texture vertically.
    // This is so that our top left origin buffers match OpenGL's bottom left texture coordinate system.
    
    CGRect textureSamplingRect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    GLfloat quadTextureData[] =  {
        CGRectGetMinX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
        CGRectGetMaxX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
        CGRectGetMinX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
        CGRectGetMaxX(textureSamplingRect), CGRectGetMinY(textureSamplingRect)
    };
    
    if (textureVBO == 0) {
        glGenBuffers(1, &textureVBO);
        glBindBuffer(GL_ARRAY_BUFFER, textureVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(quadTextureData), &quadTextureData[0], GL_STATIC_DRAW);
        //glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    }
    
    // Connection from shader program to VBO buffer must be made on each render,
    // but the data itself does not need to be loaded into the buffer on each render.
    
    glBindBuffer(GL_ARRAY_BUFFER, textureVBO);
    //glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    
    glDrawElements(GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_SHORT, BUFFER_OFFSET(0));
    return;
}

- (void) loadNextBuffer
{
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
    
    __block void *pngDataThreaded = _goomObject.videoBuffer;
    __block OGLESMappedTexture *mappedTextureThreaded = mappedTexture;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                   ^{
                       
                       if (_stop) {
                           return;
                       }
                       
                       [_goomObject update:_audioData];
                       
                       [mappedTextureThreaded copyFlatPixelsIntoBuffer:pngDataThreaded];
                       
                       //NSAssert(worked, @"renderImageIntoBuffer");
                       
                       // send a function invocation back to the main thread
                       // so that the mapped texture can be swapped.
                       
                       dispatch_async(dispatch_get_main_queue(), ^{
                           [self loadNextBufferFinished:mappedTextureThreaded];
                       });
                   });
    
}

// This callback is invoked on the main thread after all PNG image data has been decompressed in the secondary
// thread and written into the texture mapped memory. This callback must unlock the CoreVideo buffer and
// finish processing the texture in this thread so that it will be displayed in the next redraw callback.

- (void) loadNextBufferFinished:(OGLESMappedTexture*)mappedTexture
{
    BOOL worked;
    
    worked = [mappedTexture unlockTexture];
    NSAssert(worked, @"unlockTexture");
    
    mappedTexture.isReady = TRUE;
    
    // Mark the other texture as "not ready" since this one is ready now
    
    if (mappedTexture == self.mappedTexture1) {
        self.mappedTexture2.isReady = FALSE;
    } else if (mappedTexture == self.mappedTexture2) {
        self.mappedTexture1.isReady = FALSE;
    } else {
        NSAssert(FALSE, @"neither texture matched");
    }
    
    // Record info about the "report time", basically when the render was
    // reported as finished in the main thread. This is used to calculate
    // the FPS speed of the PNG decompression.
    
    NSDate *dateNow = [NSDate date];
    
    NSTimeInterval startOffset = [self.renderStartDate timeIntervalSinceDate:dateNow] * -1.0;
    startOffset = startOffset; // silence warning
#if defined(LOGGING)
    NSLog(@"reporting render time %.4f", startOffset);
#endif
    
    NSDate *lastReportedTime = self.renderStartDate;
    if (self.lastSecondRenderReportTimes.count > 0) {
        lastReportedTime = [self.lastSecondRenderReportTimes lastObject];
    }
    
    if (self.lastSecondRenderReportTimes.count >= 60) {
        [self.lastSecondRenderReportTimes removeObjectAtIndex:0];
    }
    [self.lastSecondRenderReportTimes addObject:dateNow];
    
    // Generate a delta since the last time interval
    
    NSTimeInterval offsetSinceLastReport = [lastReportedTime timeIntervalSinceDate:dateNow] * -1.0;
    
#if defined(LOGGING)
    NSLog(@"reporting offset since last render time %.4f (approx FPS %.2f)", offsetSinceLastReport, (1.0 / offsetSinceLastReport));
#endif
    
    float approxFPS = (1.0 / offsetSinceLastReport);
    NSNumber *floatNum = [NSNumber numberWithFloat:approxFPS];
    
    [self.approxFPSValues addObject:floatNum];
    
    // If the current time is more than 1 whole second after the previous report time, then
    // create an average of all the FPS values for the previous second. This value will be
    // displayed as the FPS for the double buffered render logic.
    
    NSTimeInterval currentSecondOffset = [self.lastSecondStartDate timeIntervalSinceDate:dateNow] * -1.0;
#if defined(LOGGING)
    NSLog(@"reporting current second offset %.4f", currentSecondOffset);
#endif
    
    if (currentSecondOffset >= 1.0f && [self.approxFPSValues count] > 0) {
        float sum = 0.0f;
        int count = [self.approxFPSValues count];
        
        for (NSNumber *num in self.approxFPSValues) {
#if defined(LOGGING)
            NSLog(@"sum FPS num %.4f", [num floatValue]);
#endif
            
            sum += [num floatValue];
        }
        
        float approxFPS = sum / count;
        
        self.approxFPS = approxFPS;
        
#if defined(LOGGING)
        NSLog(@"approx FPS for %d decode time samples %.4f", count, approxFPS);
#endif
        
        [_fpsLabel setText:[NSString stringWithFormat:@"FPS: %.1f", approxFPS]];
        
        [self.approxFPSValues removeAllObjects];
        
        self.lastSecondStartDate = dateNow;
    }
    
    // Start loading the next texture as soon as the previous one is
    // done, since we are sure that the next render call will make use
    // of the texture that just finished loading.
    
    [_glkView display];
    
    [self loadNextBuffer];
    
    return;
}


- (void) render {
    //[_goomObject update:_audioData];
    
    //NSLog(@"%f", [NSDate timeIntervalSinceReferenceDate]);
    
    //[_glkView display];
    
}

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute offset to name.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_TEXCOORD, "textureCoordinate");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Link textures to named textures variables in the shader program
    uniforms[UNIFORM_TEXTURE] = glGetUniformLocation(_program, "videoframe");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}


// Given an image, query the BGRA format pixels (native endian).
// Note that for a large image, the returned buffer will be massive
// (it is 64 megs at 4096 x 4096) so it is critial that the app
// deallocate this huge memory allocation when finished with it.

+ (uint32_t*) imageToBGRAData:(UIImage*)img
                      sizePtr:(CGSize*)sizePtr
{
    // Create the bitmap context
    
    size_t w = CGImageGetWidth(img.CGImage);
    size_t h = CGImageGetHeight(img.CGImage);
    
    CGSize size = CGSizeMake(w, h);
    
    CGContextRef context = [self createBGRABitmapContextWithSize:size data:NULL bitmapBytesPerRow:0];
    if (context == NULL) {
        return nil;
    }
    
    CGRect rect = {{0,0},{w,h}};
    *sizePtr = CGSizeMake(w, h);
    
    // Draw the image to the bitmap context. Once we draw, the memory
    // allocated for the context for rendering will then contain the
    // raw image data in the specified color space.
    CGContextDrawImage(context, rect, img.CGImage);
    
    // Now we can get a pointer to the image data associated with the bitmap
    // context.
    
    uint32_t *pixels = NULL;
    void *data = CGBitmapContextGetData(context);
    if (data != NULL)
    {
        pixels = malloc(w*h*sizeof(uint32_t));
        assert(pixels);
        memcpy(pixels, data, w*h*sizeof(uint32_t));
    }
    
    CGContextRelease(context);
    
    return pixels;
}

+ (CGContextRef) createBGRABitmapContextWithSize:(CGSize)inSize
                                            data:(uint32_t*)data
                               bitmapBytesPerRow:(int)bitmapBytesPerRow
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    
    size_t pixelsWide = inSize.width;
    size_t pixelsHigh = inSize.height;
    
    // Declare the number of bytes per row. Each pixel in the bitmap in this
    // example is represented by 4 bytes; 8 bits each of red, green, blue, and
    // alpha.
    
    if (bitmapBytesPerRow == 0) {
        bitmapBytesPerRow   = (pixelsWide * sizeof(uint32_t));
    }
    
    bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);
    
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
    {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
    
    size_t bitsPerComponent = 8;
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst;
    
    context = CGBitmapContextCreate (data,
                                     pixelsWide,
                                     pixelsHigh,
                                     bitsPerComponent,
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     bitmapInfo);
    if (context == NULL)
    {
        fprintf (stderr, "Context not created!");
    }
    
    // Make sure and release colorspace before returning
    CGColorSpaceRelease(colorSpace);
    
    return context;
}

// Given an image, render the BGRA pixels into a CVImageBufferRef.
// The rendering logic should be able to render directly into
// an existing memory region, so it should provide better performance
// as compared to logic that allocates a region just to render a copy.

+ (BOOL) renderImageIntoCoreVideoBuffer:(UIImage*)img
                       cVImageBufferRef:(CVImageBufferRef)cVImageBufferRef
{
    // Create a bitmap context over the existing memory, then use CoreGraphics
    // to render into the existing memory region.
    
    size_t w = CGImageGetWidth(img.CGImage);
    size_t h = CGImageGetHeight(img.CGImage);
    
    size_t cvWidth = CVPixelBufferGetWidth(cVImageBufferRef);
    size_t cvHeight = CVPixelBufferGetHeight(cVImageBufferRef);
    size_t cvBytesPerRow = CVPixelBufferGetBytesPerRow(cVImageBufferRef);
    
    NSAssert(w == cvWidth, @"width");
    NSAssert(h == cvHeight, @"height");
    
    CGSize size = CGSizeMake(w, h);
    
    // Lock the buffer to get the pointer to render into
    CVPixelBufferLockBaseAddress(cVImageBufferRef, 0);
    uint32_t *baseAddress = CVPixelBufferGetBaseAddress(cVImageBufferRef);
    
    CGContextRef context = [self createBGRABitmapContextWithSize:size data:baseAddress bitmapBytesPerRow:cvBytesPerRow];
    
    if (context == NULL) {
        CVPixelBufferUnlockBaseAddress(cVImageBufferRef, 0);
        return FALSE;
    }
    
    CGRect rect = {{0,0},{w,h}};
    //*sizePtr = CGSizeMake(w, h);
    
    // Draw the image to the bitmap context. Once we draw, the memory
    // allocated for the context for rendering will then contain the
    // raw image data in the specified color space.
    CGContextDrawImage(context, rect, img.CGImage);
    
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(cVImageBufferRef, 0);
    
    return TRUE;
}

// Given an image, render the image using CoreGraphis into a memory
// range given the row width. This implementation does not depend
// on CoreVideo APIs and should be safe the execute in a secondary
// thread since only CoreGraphics APIs are actually invoked.

+ (BOOL) renderImageIntoBuffer:(UIImage*)img
                framebufferPtr:(uint32_t*)framebufferPtr
                   bytesPerRow:(uint32_t)bytesPerRow
{
    // Create a bitmap context over the existing memory, then use CoreGraphics
    // to render into the existing memory region.
    
    size_t w = CGImageGetWidth(img.CGImage);
    size_t h = CGImageGetHeight(img.CGImage);
    
    CGSize size = CGSizeMake(w, h);
    
    CGContextRef context = [self createBGRABitmapContextWithSize:size data:framebufferPtr bitmapBytesPerRow:bytesPerRow];
    
    if (context == NULL) {
        return FALSE;
    }
    
    CGRect rect = {{0,0},{w,h}};
    
    // Draw the image into the bitmap context, this directly writes decoded pixels
    // into the framebuffer memory.
    
    CGContextDrawImage(context, rect, img.CGImage);
    
    CGContextRelease(context);
    
    return TRUE;
}

- (void) buttonBackClicked:(id)sender {
    _stop = YES;
    [_audioController stop];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
