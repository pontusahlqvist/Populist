//
//  PPLSTLocationManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/22/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTLocationManager.h"

@implementation PPLSTLocationManager

-(id) init{
    self = [super init];
    if (self){
        [self setupLocationMananger];   
    }
    return self;
}

-(void) setupLocationMananger{
    self.isUpdatingLocation = NO;
    self.locationManager = [[CLLocationManager alloc] init];
    [self.locationManager requestWhenInUseAuthorization];
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.delegate = self;
}

#pragma mark - CLLocationManager Delegate methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    if(!self.isUpdatingLocation) return; //makes sure that we only update the location once per update cycle.
    
    CLLocation *newLocation = [locations lastObject];
    NSLog(@"locationManager didUpdateLocation lastObject = %@", newLocation);
    if([[NSDate date] timeIntervalSinceDate:newLocation.timestamp] < 10){ //if the new location is newer than 10s old, we're done.
        [self.locationManager stopUpdatingLocation];
        self.isUpdatingLocation = NO;
        self.currentLocation = newLocation;
        [self.delegate locationUpdatedTo:newLocation];
    }
    
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    NSLog(@"locationManager didFailWithError: %@", error);
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    //TODO: make sure that this works properly, i.e. that we're checking for all correct acceptance codes
    NSLog(@"locationManager didChangeAuthorizationStatus to status = %i", status);
    if(status == 4){
        [self.delegate didAcceptAuthorization];
    } else if(status != 0){
        [self.delegate didDeclineAuthorization];
    }
}

#pragma mark - Public API

-(void)updateLocation{
    NSLog(@"updateLocation called in PPLSTLocationManager");
    [self.locationManager startUpdatingLocation];
    self.isUpdatingLocation = YES;
}

-(CLLocation *)getCurrentLocation{
    return self.currentLocation;
}

@end
