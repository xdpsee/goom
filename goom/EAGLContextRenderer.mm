//
//  EAGLContextRenderer.m
//  goom
//
//  Created by  cherry on 2017/9/2.
//  Copyright © 2017年 JEECH. All rights reserved.
//

#import "EAGLContextRenderer.h"

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
static GLint uniforms[NUM_UNIFORMS];

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

@interface EAGLContextRenderer() {
    GLuint _program;
    GLuint _quadVBO;
    GLuint _quadVBOIndexes;
    GLuint _textureVBO;
}

- (BOOL) loadShaders;

- (BOOL) compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;

- (BOOL) linkProgram:(GLuint)prog;

- (BOOL) validateProgram;

@end

@implementation EAGLContextRenderer

- (instancetype)initWithContext:(EAGLContext *)context {

    EAGLContextRenderer* wapper = [self init];
    if (wapper != nil) {
        _context = context;
    }

    return wapper;
}

- (void) setupGL {
    [EAGLContext setCurrentContext:self.context];

    [self loadShaders];

}

- (BOOL) validateProgram
{
    GLint logLength, status;

    glValidateProgram(_program);
    glGetProgramiv(_program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(_program, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }

    glGetProgramiv(_program, GL_VALIDATE_STATUS, &status);
    return status != 0;

}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];

    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }

    glDeleteBuffers(1, &_quadVBO);
    glDeleteBuffers(1, &_quadVBOIndexes);
    glDeleteBuffers(1, &_textureVBO);
}


- (BOOL)loadShaders
{
    GLuint vertexShader, fragShader;
    NSString *vertexShaderPathname, *fragShaderPathname;

    // Create shader program.
    _program = glCreateProgram();

    // Create and compile vertex shader.
    vertexShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER file:vertexShaderPathname]) {
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
    glAttachShader(_program, vertexShader);

    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);

    // Bind attribute offset to name.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_TEXCOORD, "textureCoordinate");

    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);

        if (vertexShader) {
            glDeleteShader(vertexShader);
            vertexShader = 0;
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
    if (vertexShader) {
        glDetachShader(_program, vertexShader);
        glDeleteShader(vertexShader);
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

    return status != 0;

}

- (void)render:(OGLESMappedTexture *)mappedTexture to:(GLKView *)glkView {

    glActiveTexture(GL_TEXTURE0);


    if (!mappedTexture.isReady) {
        NSLog(@"mappedTexture is not ready");
    }

    [mappedTexture bindTexture];

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

        uint32_t *flatCopy = (uint32_t*)malloc(mappedTexture.width * mappedTexture.height * sizeof(uint32_t));
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

    CGRect presentationRect = CGRectMake(0, 0, mappedTexture.width, mappedTexture.height);
    CGRect bounds = glkView.bounds;

    // Must call glUseProgram() before attaching uniform properties

    glUseProgram(_program);

    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);

#if defined(DEBUG)
    [self validateProgram];
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
            static_cast<GLfloat>(-1 * normalizedSamplingSize.width), static_cast<GLfloat>(-1 * normalizedSamplingSize.height),
            static_cast<GLfloat>(normalizedSamplingSize.width), static_cast<GLfloat>(-1 * normalizedSamplingSize.height),
            static_cast<GLfloat>(-1 * normalizedSamplingSize.width), static_cast<GLfloat>(normalizedSamplingSize.height),
            static_cast<GLfloat>(normalizedSamplingSize.width), static_cast<GLfloat>(normalizedSamplingSize.height),
    };

    static const GLushort quadVertexDataIndexes[] = { 0, 1, 2, 3 };

    if (_quadVBO == 0) {
        glGenBuffers(1, &_quadVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _quadVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertexData), &quadVertexData[0], GL_STATIC_DRAW);
        //glEnableClientState(GL_VERTEX_ARRAY);
    }

    if (_quadVBOIndexes == 0) {
        glGenBuffers(1, &_quadVBOIndexes);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _quadVBOIndexes);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(quadVertexDataIndexes), &quadVertexDataIndexes[0], GL_STATIC_DRAW);
    }

    // Bind vertex coordinates buffer, connect shader to already allocated vertex buffer

    glBindBuffer(GL_ARRAY_BUFFER, _quadVBO);
    //glEnableClientState(GL_VERTEX_ARRAY);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(ATTRIB_VERTEX);

    // Bind vertex coordinate indexes
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _quadVBOIndexes);

    // The texture vertices are set up such that we flip the texture vertically.
    // This is so that our top left origin buffers match OpenGL's bottom left texture coordinate system.

    CGRect textureSamplingRect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    GLfloat quadTextureData[] =  {
            static_cast<GLfloat>(CGRectGetMinX(textureSamplingRect)), static_cast<GLfloat>(CGRectGetMaxY(textureSamplingRect)),
            static_cast<GLfloat>(CGRectGetMaxX(textureSamplingRect)), static_cast<GLfloat>(CGRectGetMaxY(textureSamplingRect)),
            static_cast<GLfloat>(CGRectGetMinX(textureSamplingRect)), static_cast<GLfloat>(CGRectGetMinY(textureSamplingRect)),
            static_cast<GLfloat>(CGRectGetMaxX(textureSamplingRect)), static_cast<GLfloat>(CGRectGetMinY(textureSamplingRect))
    };

    if (_textureVBO == 0) {
        glGenBuffers(1, &_textureVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _textureVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(quadTextureData), &quadTextureData[0], GL_STATIC_DRAW);
        //glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    }

    // Connection from shader program to VBO buffer must be made on each render,
    // but the data itself does not need to be loaded into the buffer on each render.

    glBindBuffer(GL_ARRAY_BUFFER, _textureVBO);
    //glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);

    glDrawElements(GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_SHORT, BUFFER_OFFSET(0));
}


@end
