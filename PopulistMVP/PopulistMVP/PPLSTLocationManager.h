//
//  PPLSTLocationManager.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/22/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#pragma mark - PPLSTLocationManagerDelegate

@protocol PPLSTLocationManagerDelegate <NSObject>
@required
-(void) locationUpdatedTo:(CLLocation*) newLocation;
-(void) didAcceptAuthorization;
-(void) didDeclineAuthorization;
@end

@interface PPLSTLocationManager : NSObject <CLLocationManagerDelegate>

#pragma mark - Public API

-(void) updateLocation;
-(CLLocation*) getCurrentLocation;

#pragma mark - Variables
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *currentLocation;
@property (nonatomic) BOOL isUpdatingLocation;
@property (weak, nonatomic) id<PPLSTLocationManagerDelegate> delegate;

@end
