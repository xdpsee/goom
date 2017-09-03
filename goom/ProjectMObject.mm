#import "ProjectMObject.h"
#import "projectM.hpp"

@interface ProjectMObject() {
    projectM* _projectM;
}

@end

@implementation ProjectMObject

- (void) dealloc {
    if (_projectM != NULL) {
        delete _projectM;
        _projectM = NULL;
    }
}

- (id) initWithConfigPath:(NSString *)configPath andPresetsUrl:(NSString *) presetsPath {
    self = [super init];
    if (self) {
        _projectM = new projectM([configPath UTF8String], [presetsPath UTF8String]);
    }
    
    return self;
}

- (void) setResolution:(uint)width height:(uint)height {
    _projectM->projectM_resetGL(width, height);
}

- (void) update:(short [2][512])data {
    _projectM->pcm()->addPCM16(data);
}

- (void) render {
    _projectM->renderFrame();
}

- (void) close {
    
}
@end