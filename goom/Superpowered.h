// This object handles Superpowered.
// Compare the source to CoreAudio.mm and see how much easier it is to understand.

#import <UIKit/UIKit.h>

#define NUMFXUNITS 8
#define TIMEPITCHINDEX 0
#define PITCHSHIFTINDEX 1
#define ROLLINDEX 2
#define FILTERINDEX 3
#define EQINDEX 4
#define FLANGERINDEX 5
#define DELAYINDEX 6
#define REVERBINDEX 7

@interface Superpowered: NSObject {
@public
    bool playing;
    uint64_t avgUnitsPerSecond, maxUnitsPerSecond;
}

// Updates the user interface according to the file player's state.
- (void)updatePlayerLabel:(UILabel *)label slider:(UISlider *)slider button:(UIButton *)button;

- (void)togglePlayback; // Play/pause.
- (void)seekTo:(float)percent; // Jump to a specific position.

- (void)toggle; // Start/stop Superpowered.
- (bool)toggleFx:(int)index; // Enable/disable fx.

- (void) stop;

@end
