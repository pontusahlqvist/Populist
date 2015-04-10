//
//  PPLSTLocationManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/22/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTLocationManager.h"
#import <Parse/Parse.h>

@interface PPLSTLocationManager()
@property (strong, nonatomic) CLLocation *bestLocationDuringUpdate; //keeps track of the best location found during the update
@property (strong, nonatomic) PPLSTUpdatingLocationView *updatingLocationView;
@property (strong, nonatomic) NSDate *timeOfLastLocationCheck; //Note: different from timeOfLastUpdate since that has to do with actual clustering.
//The following two keep track of the location sent to parse for tracking purposes
@property (strong, nonatomic) CLLocation *lastLocationSentToParse;
@property (strong, nonatomic) NSDate *timeOfLastLocationSentToParse;
@end

@implementation PPLSTLocationManager

#pragma mark - Parameters
//TODO: make sure parameters are reasonable
float veryNearCutoff = 30.0; //in meters
float cutoffDistance = 100.0; //in meters
float cutoffTime = 60.0*30; //in seconds. The time after which we re-fetch the event that the user belongs to
int locationUpdateTimeInterval = 60; //in seconds

float desiredHorizontalAccuracy = 10.0; //meters
float acceptableHorizontalAccuracy = 15.0; //meters
float worstHorizontalAccuracyToEnableChat = 100.0; //meters - if accuracy falls below this, the local chat feature is disabled.
float maxWaitTimeForLocationUpdate = 20.0; //seconds - max wait time before we give up
float maxWaitTimeForDesiredAccuracy = 5.0; //seconds - max wait time for desired accuracy

//these parameters are for the location updates sent to parse to keep track of the user's location in case we want to send location targeted pushes
float timeAfterParseLocationUpdateShouldOccur = 15;//30*60;
float distanceMovedAfterParseLocationUpdateShouldOccur = 100.0;

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
    [self.locationManager requestAlwaysAuthorization];
    [self.locationManager startMonitoringSignificantLocationChanges];
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation; //kCLLocationAccuracyBest;
    self.locationManager.delegate = self;
    [self startUpdatingLocationWithInterval:locationUpdateTimeInterval];
}

-(void) startUpdatingLocationWithInterval:(int)interval{
    self.locationUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(onLocationTick:) userInfo:nil repeats:YES];
}

-(PPLSTUpdatingLocationView *)updatingLocationView{
    if(!_updatingLocationView) _updatingLocationView = [[PPLSTUpdatingLocationView alloc] initWithFrame:[[UIApplication sharedApplication] keyWindow].frame];
    return _updatingLocationView;
}

#pragma mark - NSTimer related methods

-(void) onLocationTick:(NSTimer*)locationTimer{
    NSLog(@"PPLSTLocationManager - onLocationTick:%@", locationTimer);
    [self updateLocation];
}

#pragma mark - CLLocationManager Delegate methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    NSLog(@"PPLSTLocationManager - locationManager:%@ didUpdateLocations:%@",manager, locations);
    CLLocation *newLocation = [locations lastObject];
    NSLog(@"locationManager didUpdateLocation lastObject = %@, accuracy = %f", newLocation, [newLocation horizontalAccuracy]);
    if(-[newLocation.timestamp timeIntervalSinceNow] < 5){ //if the new location is newer than 5s old, we're done.
        if(!self.isUpdatingLocation){ //this means that this update must be a significant location change from the background. Use it at most to update parse
            if([self shouldSendLocationToParse]){
                [self sendLocationToParse:newLocation]; //TODO: should we place an accuracy resistriction here?
            }
            return;
        }
        float timeSinceStartedUpdating = -[self.startedUpdatingLocationAt timeIntervalSinceNow];
        if(!self.bestLocationDuringUpdate || [self.bestLocationDuringUpdate horizontalAccuracy] > [newLocation horizontalAccuracy]){
            self.bestLocationDuringUpdate = newLocation;
        }
        if([self.bestLocationDuringUpdate horizontalAccuracy] <= desiredHorizontalAccuracy || ([self.bestLocationDuringUpdate horizontalAccuracy] <= acceptableHorizontalAccuracy && timeSinceStartedUpdating > maxWaitTimeForDesiredAccuracy) || timeSinceStartedUpdating >= maxWaitTimeForLocationUpdate){
            [self.locationManager stopUpdatingLocation];
            [self.updatingLocationView removeFromSuperview]; //TODO: what if it wasn't added?
            CLLocation *oldLocation = self.currentLocation;
            self.currentLocation = self.bestLocationDuringUpdate;
            self.bestLocationDuringUpdate = nil;
            self.isUpdatingLocation = NO;
            if([self shouldSendLocationToParse]){
                [self sendLocationToParse:self.currentLocation];
            }
            if([self.currentLocation horizontalAccuracy] <= worstHorizontalAccuracyToEnableChat){
                [self.delegate locationUpdatedTo:self.bestLocationDuringUpdate From:oldLocation withPoorAccuracy:NO];
            } else{
                //accuracy was so bad that we can't enable the local chat. We will still allow the user to view nearby conversations though.
                [self.delegate locationUpdatedTo:self.bestLocationDuringUpdate From:oldLocation withPoorAccuracy:YES];
            }
        }
    }
}

-(BOOL) shouldSendLocationToParse{
    if(!self.timeOfLastLocationSentToParse || !self.lastLocationSentToParse){
        return YES;
    }
    if([self timeBetween:self.timeOfLastLocationSentToParse and:[NSDate date]] > timeAfterParseLocationUpdateShouldOccur){
        return YES;
    }
    if([self.currentLocation distanceFromLocation:self.lastLocationSentToParse] > distanceMovedAfterParseLocationUpdateShouldOccur){
        return YES;
    }
    return NO;
}

-(void) sendLocationToParse:(CLLocation*)newLocation{
    NSLog(@"PPLSTLocationManager - sendLocationToParse");
    if(!newLocation){
        NSLog(@"newLocation = nil");
        return;
    }
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setObject:[PFGeoPoint geoPointWithLatitude:newLocation.coordinate.latitude longitude:newLocation.coordinate.longitude] forKey:@"lastKnownLocation"];
    [currentInstallation setObject:[NSDate date] forKey:@"lastKnownLocationDate"];
    [currentInstallation saveInBackground];
    self.lastLocationSentToParse = [newLocation copy];
    self.timeOfLastLocationSentToParse = [NSDate date];
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    NSLog(@"PPLSTLocationManager - locationManager:%@ didFailWithError: %@", manager, error);
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Failed To Get Location" message:@"Hmm, it seems like we're having a tough time gathering your location. Please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [errorAlert show];
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    NSLog(@"PPLSTLocationManager - locationManager:%@ didChangeAuthorizationStatus to status = %i",manager, status);
    if(status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse){
        [self.delegate didAcceptAuthorization];
    } else if(status != 0){
        [self.delegate didDeclineAuthorization];
    }
}

#pragma mark - Public API

-(void)updateLocation{
    [self.locationManager startUpdatingLocation];
    self.startedUpdatingLocationAt = [NSDate date];
    self.isUpdatingLocation = YES;
    if(!self.timeOfLastLocationCheck){ //signifies a fresh app open
        [[[UIApplication sharedApplication] keyWindow] addSubview:self.updatingLocationView];
    }
    self.timeOfLastLocationCheck = [NSDate date];
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

-(BOOL) waitedTooLongSinceTimeOfLastUpdate{
    return [self waitedTooLongFrom:self.timeOfLastUpdate To:[NSDate date]];
}
@end
