//
//  PPLSTLocationManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/22/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTLocationManager.h"

@implementation PPLSTLocationManager

#pragma mark - Parameters
float veryNearCutoff = 30.0; //in meters
float cutoffDistance = 100.0; //in meters - TODO: update to 100.0 meters
float cutoffTime = 60.0*30; //in seconds - TODO: update to a reasonable time
int locationUpdateTimeInterval = 60; //in seconds - TODO: update to e.g. every 1 min or so

#pragma mark - Initialization

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
    [self startUpdatingLocationWithInterval:locationUpdateTimeInterval];
}

-(void) startUpdatingLocationWithInterval:(int)interval{
    self.locationUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(onLocationTick:) userInfo:nil repeats:YES];
}

#pragma mark - NSTimer related methods

-(void) onLocationTick:(NSTimer*)locationTimer{
    NSLog(@"locationTimer tick - updating location");
    [self updateLocation];
}

#pragma mark - CLLocationManager Delegate methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    if(!self.isUpdatingLocation) return; //makes sure that we only update the location once per update cycle.
    
    CLLocation *newLocation = [locations lastObject];
    NSLog(@"locationManager didUpdateLocation lastObject = %@", newLocation);
    if([[NSDate date] timeIntervalSinceDate:newLocation.timestamp] < 10){ //if the new location is newer than 10s old, we're done.
        [self.locationManager stopUpdatingLocation];

        CLLocation *oldLocation = self.currentLocation;
        self.currentLocation = newLocation;
        [self setCurrentLocationStrings];
        
        self.isUpdatingLocation = NO;
        [self.delegate locationUpdatedTo:newLocation From:oldLocation];
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

-(BOOL) veryNearEvent:(Event*)event{
    CLLocation *eventLocation = [[CLLocation alloc] initWithLatitude:[event.latitude floatValue] longitude:[event.longitude floatValue]];
    if([self distanceMovedFrom:self.currentLocation To:eventLocation] <= veryNearCutoff){
        return YES;
    } else{
        return NO;
    }
}

#pragma mark - Distance Listeners

-(void) updateLocationOfLastUpdate:(CLLocation*)newLocationOfLastUpdate{
    NSLog(@"PPLSTLocationManager - updateLocationOfLastUpdate:%@",newLocationOfLastUpdate);
    self.locationOfLastUpdate = [newLocationOfLastUpdate copy];
}

-(float) distanceMovedFrom:(CLLocation*) locationA To:(CLLocation*) locationB{
    return [locationB distanceFromLocation:locationA];
}

-(BOOL)movedTooFarFrom:(CLLocation *)locationA To:(CLLocation *)locationB{
    NSLog(@"locationA = %@, locationB = %@", locationA, locationB);
    float distanceMoved = [self distanceMovedFrom:locationA To:locationB];
    NSLog(@"Distance Moved = %f", distanceMoved);
    if(distanceMoved > cutoffDistance){
        return YES;
    } else{
        return NO;
    }
}

-(BOOL)movedTooFarFromLocationOfLastUpdate{
    return [self movedTooFarFrom:self.locationOfLastUpdate To:self.currentLocation];
}

#pragma mark - Time Interval Listeners

-(void) updateTimeOfLastUpdate:(NSDate*)newTimeOfLastUpdate{
    NSLog(@"PPLSTLocationManager - updateTimeOfLastUpdate:%@", newTimeOfLastUpdate);
    self.timeOfLastUpdate = [newTimeOfLastUpdate copy];
}

-(float) timeBetween:(NSDate*)dateA and:(NSDate*)dateB{
    return fabsf([dateA timeIntervalSinceDate:dateB]);
}

-(BOOL) waitedTooLongFrom:(NSDate*)dateA To:(NSDate*)dateB{
    float timeWaited = [self timeBetween:dateA and:dateB];
    if(timeWaited > cutoffTime){
        return YES;
    } else{
        return NO;
    }
}

-(BOOL) waitedToLongSinceTimeOfLastUpdate{
    return [self waitedTooLongFrom:self.timeOfLastUpdate To:[NSDate date]];
}



#pragma mark - Helper methods

//sets user's current location strings
-(void) setCurrentLocationStrings{
    NSString *googleUrl = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=false&result_type=neighborhood%%7Clocality%%7Ccountry&key=AIzaSyClR6wH3_BfA1bXFjr3LEI-Cp_SiOrPJog", self.currentLocation.coordinate.latitude, self.currentLocation.coordinate.longitude];
    NSURL *url = [[NSURL alloc] initWithString:googleUrl];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    NSError *error = nil;
    NSURLResponse *response = nil;
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:returnData options:0 error:nil];

    NSString *formattedAddress = dictionary[@"results"][0][@"formatted_address"];
    NSArray *locationArray = [formattedAddress componentsSeparatedByString:@","];

    self.country = nil;
    self.state = nil;
    self.city = nil;
    self.neighborhood = nil;

    if([locationArray count] > 0){
        self.country = [locationArray[[locationArray count] - 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    if([locationArray count] > 1){
        self.state = [locationArray[[locationArray count] - 2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    if([locationArray count] > 2){
        self.city = [locationArray[[locationArray count] - 3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    if([locationArray count] > 3){
        self.neighborhood = [locationArray[[locationArray count] - 4] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
}

@end
