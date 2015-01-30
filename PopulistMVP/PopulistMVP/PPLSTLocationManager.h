//
//  PPLSTLocationManager.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/22/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "Event.h"

#pragma mark - PPLSTLocationManagerDelegate

@protocol PPLSTLocationManagerDelegate <NSObject>
@required
-(void) locationUpdatedTo:(CLLocation*) newLocation From:(CLLocation*) oldLocation;
-(void) didAcceptAuthorization;
-(void) didDeclineAuthorization;
@end

@interface PPLSTLocationManager : NSObject <CLLocationManagerDelegate>

#pragma mark - Variables
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (nonatomic) BOOL isUpdatingLocation;
@property (weak, nonatomic) id<PPLSTLocationManagerDelegate> delegate;
@property (strong, nonatomic) NSTimer *locationUpdateTimer;

#pragma mark - location based parameters

//location data
@property (strong, nonatomic) CLLocation *locationOfLastUpdate; //the location at which the last clustering was done
@property (strong, nonatomic) NSDate *timeOfLastUpdate; //the time at which the last clustering was done
@property (strong, nonatomic) CLLocation *currentLocation;
@property (strong, nonatomic) NSString *country;
@property (strong, nonatomic) NSString *state;
@property (strong, nonatomic) NSString *city;
@property (strong, nonatomic) NSString *neighborhood;

#pragma mark - Public API

-(void) updateLocation;
-(CLLocation*) getCurrentLocation;
-(BOOL) veryNearEvent:(Event*)event;

-(void) updateLocationOfLastUpdate:(CLLocation*)newLocationOfLastUpdate;
-(BOOL) movedTooFarFromLocationOfLastUpdate;

-(void) updateTimeOfLastUpdate:(NSDate*)newTimeOfLastUpdate;
-(BOOL) waitedToLongSinceTimeOfLastUpdate;

@end
