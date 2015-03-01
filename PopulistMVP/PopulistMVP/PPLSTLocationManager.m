//
//  PPLSTLocationManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/22/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTLocationManager.h"

@interface PPLSTLocationManager()
@property (strong, nonatomic) CLLocation *bestLocationDuringUpdate; //keeps track of the best location found during the update
@property (strong, nonatomic) PPLSTUpdatingLocationView *updatingLocationView;
@property (strong, nonatomic) NSDate *timeOfLastLocationCheck; //Note: different from timeOfLastUpdate since that has to do with actual clustering.
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
    if(!self.isUpdatingLocation) return; //makes sure that we only update the location once per update cycle.
    
    CLLocation *newLocation = [locations lastObject];
    NSLog(@"locationManager didUpdateLocation lastObject = %@, accuracy = %f", newLocation, [newLocation horizontalAccuracy]);
    [newLocation horizontalAccuracy];
    if(-[newLocation.timestamp timeIntervalSinceNow] < 5){ //if the new location is newer than 5s old, we're done.
        float timeSinceStartedUpdating = -[self.startedUpdatingLocationAt timeIntervalSinceNow];
        if(!self.bestLocationDuringUpdate || [self.bestLocationDuringUpdate horizontalAccuracy] > [newLocation horizontalAccuracy]){
            self.bestLocationDuringUpdate = newLocation;
        }
        if([self.bestLocationDuringUpdate horizontalAccuracy] <= desiredHorizontalAccuracy || ([self.bestLocationDuringUpdate horizontalAccuracy] <= acceptableHorizontalAccuracy && timeSinceStartedUpdating > maxWaitTimeForDesiredAccuracy) || timeSinceStartedUpdating >= maxWaitTimeForLocationUpdate){

            [self.locationManager stopUpdatingLocation];
            [self.updatingLocationView removeFromSuperview];
            
            CLLocation *oldLocation = self.currentLocation;
            self.currentLocation = self.bestLocationDuringUpdate;
            self.bestLocationDuringUpdate = nil;
            [self setCurrentLocationStrings];
            
            self.isUpdatingLocation = NO;
            
            if([self.currentLocation horizontalAccuracy] <= worstHorizontalAccuracyToEnableChat){
                [self.delegate locationUpdatedTo:self.bestLocationDuringUpdate From:oldLocation withPoorAccuracy:NO];
            } else{
                //accuracy was so bad that we can't enable the local chat. We will still allow the user to view nearby conversations though.
                [self.delegate locationUpdatedTo:self.bestLocationDuringUpdate From:oldLocation withPoorAccuracy:YES];
            }
        }
    }
    
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
    if(!self.timeOfLastLocationCheck || -[self.timeOfLastLocationCheck timeIntervalSinceNow] > cutoffTime){
        [[[UIApplication sharedApplication] keyWindow] addSubview:self.updatingLocationView]; //TODO: is it really necessary to even show this?
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

    //TODO: make sure this works properly
    self.country = @"";
    self.state = @"";
    self.city = @"";
    self.neighborhood = @"";

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
