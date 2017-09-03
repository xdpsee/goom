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
    uint32_t* _videoBuffer;
}

- (id) init;

@end

@implementation GoomObject
@synthesize videoBuffer = _videoBuffer;

- (void) dealloc {
    [self close];
}

- (id) init {
    self = [super init];
    if (self) {
        _pluginInfo = goom_init(320, 240);
        _videoBuffer = malloc(320 * 240 * 4);
        goom_set_screenbuffer(_pluginInfo, _videoBuffer);
    }
    
    return self;
}

- (id) initWithWidth:(uint) width height:(uint)height {
    self = [super init];
    if (self) {
        _pluginInfo = goom_init(width, height);
        _videoBuffer = malloc(width * height * 4);
        goom_set_screenbuffer(_pluginInfo, _videoBuffer);
    }
    
    return self;
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
