//
//  TestController.m
//  goom
//
//  Created by  cherry on 2017/9/3.
//  Copyright © 2017 JEECH. All rights reserved.
//

#import "TestController.h"
#import "GoomView.h"
#import "SuperpoweredAdvancedAudioPlayer.h"
#import "SuperpoweredIOSAudioIO.h"
#import "SuperpoweredRoll.h"
#import "SuperpoweredFilter.h"
#import "SuperpoweredFlanger.h"
#import "SuperpoweredSimple.h"

#define HEADROOM_DECIBEL 3.0f
static const float headroom = powf(10.0f, -HEADROOM_DECIBEL * 0.025);
static short samples[2][512];

@interface TestController ()<SuperpoweredIOSAudioIODelegate> {
    GoomView* _testView;
    UIButton * _buttonBack;
    EAGLContext *_context;

    SuperpoweredAdvancedAudioPlayer *playerA;
    SuperpoweredIOSAudioIO *output;
    SuperpoweredRoll *roll;
    SuperpoweredFilter *filter;
    SuperpoweredFlanger *flanger;
    unsigned char activeFx;
    float *stereoBuffer, volA;
    unsigned int lastSamplerate;

}

@end

@implementation TestController

- (void) dealloc {

    [self->output stop];
    delete playerA;
    self->output = nil;
    
    free(stereoBuffer);
#if !__has_feature(objc_arc)
    [output release];
    [super dealloc];
#endif

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

    _testView = [[GoomView alloc] initWithFrame:CGRectMake(0, 20, 375, 282) context:_context];

    [self.view addSubview:_testView];

    lastSamplerate = activeFx = 0;
    volA = 1.0f * headroom;
    if (posix_memalign((void **)&stereoBuffer, 16, 4096 + 128) != 0) abort(); // Allocating memory, aligned to 16.

    playerA = new SuperpoweredAdvancedAudioPlayer((__bridge void *)self, playerEventCallbackA, 44100, 0);
    playerA->open([[[NSBundle mainBundle] pathForResource:@"Dangerous" ofType:@"mp3"] fileSystemRepresentation]);
    playerA->syncMode = SuperpoweredAdvancedAudioPlayerSyncMode_TempoAndBeat;

    roll = new SuperpoweredRoll(44100);
    filter = new SuperpoweredFilter(SuperpoweredFilter_Resonant_Lowpass, 44100);
    flanger = new SuperpoweredFlanger(44100);

    output = [[SuperpoweredIOSAudioIO alloc] initWithDelegate:(id<SuperpoweredIOSAudioIODelegate>)self preferredBufferSize:12 preferredMinimumSamplerate:44100 audioSessionCategory:AVAudioSessionCategoryPlayback channels:2 audioProcessingCallback:audioProcessing clientdata:(__bridge void *)self];
    [output start];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

void playerEventCallbackA(void *clientData, SuperpoweredAdvancedAudioPlayerEvent event, void *value) {
    if (event == SuperpoweredAdvancedAudioPlayerEvent_LoadSuccess) {
        TestController *self = (__bridge TestController *)clientData;
        self->playerA->setBpm(126.0f);
        self->playerA->setFirstBeatMs(353);
        self->playerA->setPosition(self->playerA->firstBeatMs, false, false);

        self->playerA->play(false);
    };
}


- (void)interruptionStarted {}
- (void)recordPermissionRefused {}
- (void)mapChannels:(multiOutputChannelMap *)outputMap inputMap:(multiInputChannelMap *)inputMap externalAudioDeviceName:(NSString *)externalAudioDeviceName outputsAndInputs:(NSString *)outputsAndInputs {}

- (void)interruptionEnded { // If a player plays Apple Lossless audio files, then we need this. Otherwise unnecessary.
    playerA->onMediaserverInterrupt();
}


// This is where the Superpowered magic happens.
static bool audioProcessing(void *clientdata, float **buffers, unsigned int inputChannels, unsigned int outputChannels, unsigned int numberOfSamples, unsigned int samplerate, uint64_t hostTime) {
    __unsafe_unretained TestController *self = (__bridge TestController *)clientdata;
    if (samplerate != self->lastSamplerate) { // Has samplerate changed?
        self->lastSamplerate = samplerate;
        self->playerA->setSamplerate(samplerate);
        self->roll->setSamplerate(samplerate);
        self->filter->setSamplerate(samplerate);
        self->flanger->setSamplerate(samplerate);
    };

    
    memcpy(&samples[0], buffers[0], 512);
    memcpy(&samples[1], buffers[1], 512);
    
    [self->_testView updateAudioSamples:samples];

    
    bool silence = !self->playerA->process(self->stereoBuffer, false, numberOfSamples);
    self->roll->bpm = self->flanger->bpm = self->playerA->bpm; // Syncing fx is one line.

    if (self->roll->process(silence ? NULL : self->stereoBuffer, self->stereoBuffer, numberOfSamples) && silence) {
        silence = false;
    }

    if (!silence) {
        self->filter->process(self->stereoBuffer, self->stereoBuffer, numberOfSamples);
        self->flanger->process(self->stereoBuffer, self->stereoBuffer, numberOfSamples);
    };

    if (!silence) {
        // The stereoBuffer is ready now, let's put the finished audio into the requested buffers.
        SuperpoweredDeInterleave(self->stereoBuffer, buffers[0], buffers[1], numberOfSamples);

        
    }

    return !silence;
}

- (void)buttonBackClicked:(id)sender {


    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
