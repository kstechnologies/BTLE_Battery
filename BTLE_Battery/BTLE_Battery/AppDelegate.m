//
//  AppDelegate.m
//  BTLE_Battery
//
//  Created by bob on 3/26/13
//  Copyright (c) 2013 KS Technologies, LLC. All rights reserved.
//

/*
 KVO is used to watch for changes to the battery percentage (key: batteryPercentage) as well as the accelerometer events (key: accelString).
 
 There are many, many changes I would make to this if it were a real app.  
 
 For instance, getting a string from the iDevice and dumping it into an NSTextField is pretty weak.  It would be better to modify the GATT Profile on the iDevice so that there is a single characteristic per axis.  Also, there's no reason that the iDevice battery percentage uses a custom characteristic.  It'd be better to use the real Battery Characteristic from the Bluetooth SIG.
 
 There is legacy code in here from a sample Apple project - you'll notice in KSTiDeviceBattery that I'm looking for an "EOM" (End of Message) Marker.  Remember that BLE is limited to 20-bytes per transaction.  So, if you want larger transactions than this, one easy way to do it is to use bookends like this ... perhaps SOM (Start of Message), then gobs of NSData, then EOM.
 
 There seems be an issue with disconnects and OSX.  I would strongly suggest that the iDevice initiate the disconnect by killing its CBPeripheralManager.  I do this in BTLE_Transfer when I pop from the Peripheral View to the List View.  If you try to disconnect from OSX (which is logical!), then I find you have to reboot the iDevice as of iOS6.1.3.
 
 As of this writing, there is no info.plist Key to require the OSX device you're using to have a BLE radio.  I think that's an Apple oversight, and I've submitted a feature request.  You should, too.
 
 And, finally, you should never dump key methods in your AppDelegate.  That's just bad coding practice.  Sorry.  :-(
 
 */

#import "AppDelegate.h"
#import "KSTiDeviceBattery.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    _battery = [[KSTiDeviceBattery alloc] init];
    
    [_battery addObserver:self forKeyPath:@"batteryPercentage" options:0 context:NULL];
    [_battery addObserver:self forKeyPath:@"accelString" options:0 context:NULL];
    
    [self setUItoDisconnect];
    
    // Look for Connect / Disconnect Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidDisconnect:) name:@"kDeviceDisconnected" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidConnect:) name:@"kDeviceConnected" object:nil];
    
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    
    [_battery removeObserver:self forKeyPath:@"batteryPercentage"];
    [_battery removeObserver:self forKeyPath:@"accelString"];
    
    [_battery disconnect];
    
}

-(IBAction)changeConnectionStatus:(id)sender
{
    NSLog(@"Connect to Peripheral");
    [_battery connect];
}

-(void)setUItoDisconnect
{
    [_batteryTextField setStringValue:@"-- %"];
    [_accelTextField setStringValue:@"x y z"];
    [_batteryImage setFrame:NSMakeRect(_batteryImage.frame.origin.x, _batteryImage.frame.origin.y, _batteryImage.frame.size.width, 0)];
}

-(void)deviceDidConnect:(NSNotification *)aNotification
{
    [_connectButton setEnabled:NO];
}

-(void)deviceDidDisconnect:(NSNotification *)aNotification
{
    [_connectButton setEnabled:YES];
    [self setUItoDisconnect];
}

// I'm using KVO here, but there are many ways to do this - delegates, notifications, etc.
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    
    if ([keyPath isEqualToString:@"batteryPercentage"])
    {
        _batteryTextField.stringValue = [NSString stringWithFormat:@"%@%%", _battery.batteryPercentage];
        
        // Also, really dirt simple.  I just set the height equal to the battery, and the image is max'ed out at 100px.
        [_batteryImage setFrame:NSMakeRect(_batteryImage.frame.origin.x, _batteryImage.frame.origin.y, _batteryImage.frame.size.width, [_battery.batteryPercentage intValue])];
        
    }
    else if ([keyPath isEqualToString:@"accelString"])
    {
        // Here's where I'd suggest you break acceleration up into three different BLE characteristics.
        _accelTextField.stringValue = [NSString stringWithFormat:@"%@", _battery.accelString];
        
        NSArray *accelElements = [_accelTextField.stringValue componentsSeparatedByString:@" "];
        float xValue = [[accelElements objectAtIndex:0] floatValue];
        float yValue = [[accelElements objectAtIndex:1] floatValue];
        float zValue = [[accelElements objectAtIndex:2] floatValue];
        
        // This is just for fun, to show what you can do now that you have an expensive wireless accelerometer.
        // Here, we look for a magnitude of greater than 1.5 on the accelerometer and then fire off a local
        // notification on OSX.  Remember, you only see this if your app does not have the focus.
        if( abs(xValue) > 1.5 ||
           abs(yValue) > 1.5 ||
           abs(zValue) > 1.5
           ) {
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            [notification setTitle:@"BTLE_Battery"];
            [notification setInformativeText:@"Ouch!  Stop that."];
            [notification setDeliveryDate:[NSDate dateWithTimeInterval:0.1 sinceDate:[NSDate date]]];
            [notification setSoundName:NSUserNotificationDefaultSoundName];
            NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
            [center scheduleNotification:notification];
            
        }
    }
}

@end
