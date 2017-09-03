//
//  ProjectMObject.h
//  goom
//
//  Created by  cherry on 15-1-9.
//  Copyright (c) 2015年 JEECH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ProjectMObject : NSObject

- (id) initWithConfigPath:(NSString *)configPath andPresetsUrl:(NSString *) presetsPath;

- (void) setResolution:(uint) width height:(uint) height;

- (void) update:(short[2][512]) data;

- (void) render;

- (void) close;



@end
