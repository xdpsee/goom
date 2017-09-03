//
//  Goom.m
//  goom
//
//  Created by  cherry on 15-1-4.
//  Copyright (c) 2015年 JEECH. All rights reserved.
//

#import "GoomObject.h"
#import "goom.h"

@interface GoomObject() {
    PluginInfo* _pluginInfo;
    void* _screenBuffer;
}

- (id) init;

@end

@implementation GoomObject

- (void) dealloc {
    [self close];
}

- (id) init {
    self = [super init];
    if (self) {
        _pluginInfo = goom_init(320, 240);
    }
    
    return self;
}

- (id) initWithWidth:(uint) width height:(uint)height {
    self = [super init];
    if (self) {
        _pluginInfo = goom_init(width, height);
    }
    
    return self;
}

- (void) setResolution:(uint)width height:(uint)height {
    if (_pluginInfo != NULL) {
        goom_set_resolution(_pluginInfo, width, height);
    }
}

- (void) setScreenBuffer:(void *)buffer {
    if (_pluginInfo != NULL) {
        goom_set_screenbuffer(_pluginInfo, buffer);
    }
}

- (void) update:(short [2][512]) data {
    if (_pluginInfo != NULL) {
        goom_update(_pluginInfo, data, 0, 0, "", "");
    }
}

- (void) close {
    if (_pluginInfo != NULL) {
        goom_close(_pluginInfo);
        _pluginInfo = NULL;
    }
}



@end
