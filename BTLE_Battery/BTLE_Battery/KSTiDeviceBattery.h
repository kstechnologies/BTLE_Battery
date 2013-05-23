//
//  KSTiDeviceBattery.h
//  BTLE_Battery
//
//  Created by bob on 3/26/13
//  Copyright (c) 2013 KS Technologies, LLC. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>

@interface KSTiDeviceBattery : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> {
    
    CBCentralManager *centralManager;
    CBPeripheral *peripheral;
    
    bool shouldConnect;
    
}

@property(retain) NSNumber *batteryPercentage;
@property(retain) NSString *accelString;

-(void)startScan;
-(void)stopScan;

-(void)connect;
-(void)disconnect;

@end
