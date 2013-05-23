//
//  AppDelegate.h
//  BTLE_Battery
//
//  Created by bob on 2/25/13.
//  Copyright (c) 2013 bob. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSTiDeviceBattery.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (retain) KSTiDeviceBattery *battery;

// UI - a real app should not put all of this in the app delegate
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *connectButton;
@property (assign) IBOutlet NSTextField *batteryTextField;
@property (assign) IBOutlet NSTextField *accelTextField;
@property (assign) IBOutlet NSImageView *batteryImage;

@end
