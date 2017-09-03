//
//  Goom.h
//  goom
//
//  Created by  cherry on 15-1-4.
//  Copyright (c) 2015年 JEECH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GoomObject : NSObject

@property(nonatomic, readonly) uint32_t* videoBuffer;

- (id) initWithWidth:(uint) width height:(uint)height;

- (void) update:(short[2][512]) data;

- (void) close;

@end
