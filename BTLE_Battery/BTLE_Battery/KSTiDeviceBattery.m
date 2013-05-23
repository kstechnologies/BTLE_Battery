//
//  KSTiDeviceBattery.m
//  BTLE_Battery
//
//  Created by bob on 3/26/13
//  Copyright (c) 2013 KS Technologies, LLC. All rights reserved.
//

/*
 
 _peripheral is the iDevice itself.  Upon connection, we set _peripheral to the connected peripheral.
 
 */

#import "KSTiDeviceBattery.h"

// Here, you should create multiple accelerometer characteristics and make them part of an Accelerometer Service.
// I'd also suggest NOT using the custom Battery Characteristic.  Just change this over to the Bluetooth 4.0 SIG's
// standard battery characteristic.  That will make you compatible with ANY app that reads BT4.0 Battery Characteristic.
#define TRANSFER_SERVICE_UUID                   @"E20A39F4-73F5-4BC4-A12F-17D1AD07A961"
#define BATTERY_CHARACTERISTIC_UUID             @"08590F7E-DB05-467E-8757-72F6FAEB13D4"
#define ACCELEROMETER_CHARACTERISTIC_UUID       @"38E3C7D5-8F09-4AFA-9EBF-2A1BBC2539F4"

@implementation KSTiDeviceBattery

-(id)init {
    
    [self startScan];
    return self;
    
}

-(void)startScan {
    
    NSLog(@"BTLE_Battery: Starting Scan");
    
    if( !centralManager ) {
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        shouldConnect = NO;
    }
    
    [self isLECapableHardware];
    
}

- (void)stopScan
{
    [centralManager stopScan];
}

-(void)connect {
    shouldConnect = YES;
}

-(void)disconnect {
    
    // Unsubscribe from all services; if you don't do this,
    // you'll get a nasty dirty disconnect.  Like with sockets, it's always best to disconnect
    // in reverse of how you connected.
    for (CBService *service in peripheral.services) {
        if (service.characteristics != nil) {
            for (CBCharacteristic *characteristic in service.characteristics) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BATTERY_CHARACTERISTIC_UUID]]) {
                    if (characteristic.isNotifying)
                    {
                        NSLog(@"Unsubscribe from BATTERY CHARACTERISTIC");
                        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                    }
                } else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:ACCELEROMETER_CHARACTERISTIC_UUID]])
                {
                    if (characteristic.isNotifying) {
                        NSLog(@"Unsubscribe from ACCELEROMETER CHARACTERISTIC");
                        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                    }
                }
            }
        }
    }
    
    shouldConnect = NO;
    
    if( peripheral.isConnected ) {
        NSLog(@"Requesting Disconnect");
        [centralManager cancelPeripheralConnection:peripheral];
    }
    
    [peripheral setDelegate:nil];
    peripheral = nil;
    
}

- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    
    bool isReady = FALSE;
    
    switch ([centralManager state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            isReady = NO;
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            isReady = NO;
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            isReady = NO;
            break;
        case CBCentralManagerStatePoweredOn:
            state = @"Bluetooth is on and ready to go!";
            isReady = YES;
            break;
        case CBCentralManagerStateUnknown:
            state = @"Bluetooth state is unknown.";
            isReady = NO;
            break;
        default:
            state = @"Bluetooth state is unknown.";
            isReady = NO;
            break;
    }
    
    NSLog(@"BTLE_Battery: Central Manager state - %@", state);
    
    if( isReady ) {
        NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], CBCentralManagerScanOptionAllowDuplicatesKey, nil];
        
        // Scan just for the service we care about; otherwise, you'll have to filter through every BLE device in your
        // office (personal experience).
        [centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:options];
    }
    
    return isReady;
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self isLECapableHardware];
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"BTLE_Battery: Scanned a peripheral - Signal Strength (%@), UUID (%@), Advert (%@)", RSSI, aPeripheral.UUID, advertisementData);
    
    if( shouldConnect ) {
        
        if( !aPeripheral.isConnected ) {
            
            if( !peripheral ) {
                peripheral = [[CBPeripheral alloc] init];
            }
            
            peripheral = aPeripheral;
            
            [centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
            
        } else {
            
            if( !peripheral ) {
                peripheral = [[CBPeripheral alloc] init];
            }
            
            peripheral = aPeripheral;
            [centralManager retrieveConnectedPeripherals];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"BTLE_Battery: Retrieved peripheral(s): %lu - %@", [peripherals count], peripherals);
    
    if([peripherals count] >= 1)
    {
        [centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
        
    }
    
    [self stopScan];
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
    NSLog(@"BTLE_Battery: Retrieved connected peripheral(s): %lu - %@", [peripherals count], peripherals);
    
    if([peripherals count] >= 1)
    {
        [centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
        
    }
    
    [self stopScan];
    
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    NSLog(@"BTLE_Battery: Connected to peripheral: %@", aPeripheral);
    
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    
    // I waffle on whether or not this should be here or after didDiscoverCharacteristics.  Technically, yes,
    // you're connected, but there's nothing fun you can do until you see the GATT Profile characteristics.
    // Your call.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kDeviceConnected" object:nil userInfo:nil];
    
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    NSLog(@"BTLE_Battery: Disconnected from peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    
    [peripheral setDelegate:nil];
    peripheral = nil;

    [[NSNotificationCenter defaultCenter] postNotificationName:@"kDeviceDisconnected" object:nil userInfo:nil];
    shouldConnect = NO;

    [self startScan];
    
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    NSLog(@"BTLE_Battery: Failed to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    
    [peripheral setDelegate:nil];
    peripheral = nil;
    
    // You probably want to help the user out here with some actions they can take.
    
}

#pragma mark - CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"BTLE_Battery: Discovered services for %@ with error (%@)", aPeripheral.name, [error localizedDescription]);
        return;
    }
    
    for (CBService *aService in aPeripheral.services) {
        
        NSLog(@"BTLE_Battery: Discovering all characteristics for Service %@", aService.UUID);
        [aPeripheral discoverCharacteristics:nil forService:aService];
        
    }
    
}

- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"BTLE_Battery: Discovered characteristics for %@ with error: (%@)", service.UUID, [error localizedDescription]);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        // If it is, subscribe to it
        NSLog(@"BTLE_Battery: Subscribed to Characteristic %@", characteristic.UUID);
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"BTLE_Battery: Error updating value for characteristic %@ error (%@)", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    // I suggest looking for a non-zero length; prevents exceptions.
    
    if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:BATTERY_CHARACTERISTIC_UUID]] && characteristic.value.length > 0 )
    {
        NSData *updatedValue = characteristic.value;
        NSString *batteryString = [[NSString alloc] initWithData:updatedValue encoding:NSUTF8StringEncoding];
        
        if( ![batteryString compare:@"EOM"] == NSOrderedSame ) {
            
            NSString *withoutPercentage = [batteryString substringToIndex:(batteryString.length-1)];
            [self setBatteryPercentage:[NSNumber numberWithInt:[withoutPercentage intValue]]];
            
        }
    } else if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:ACCELEROMETER_CHARACTERISTIC_UUID]] && characteristic.value.length > 0 )
    {
        NSData *updatedValue = characteristic.value;
        NSString *accelStringResponse = [[NSString alloc] initWithData:updatedValue encoding:NSUTF8StringEncoding];
        [self setAccelString:accelStringResponse];
        
        NSLog(@"BTLE_Battery: %@", accelStringResponse);
        
    } else {
        // Maybe some new GATT Characteristic?
    }
    
}

@end