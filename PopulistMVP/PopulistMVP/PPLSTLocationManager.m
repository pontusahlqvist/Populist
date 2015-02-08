//
//  PPLSTLocationManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/22/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: make sure location is sufficiently accurate before stopping the location loading. Maybe wait for +/-10m.

#import "PPLSTLocationManager.h"

@implementation PPLSTLocationManager

#pragma mark - Parameters
float veryNearCutoff = 30.0; //in meters
float cutoffDistance = 50.0; //in meters - TODO: update to 100.0 meters or something reasonable
float cutoffTime = 60.0*30; //in seconds - TODO: update to a reasonable time
int locationUpdateTimeInterval = 60; //in seconds - TODO: update to e.g. every 1 min or so
int locationUpdateCount = 0; //keeps track of how many times the location has been updated so that we don't wait forever for accurate results

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

#pragma mark - NSTimer related methods

-(void) onLocationTick:(NSTimer*)locationTimer{
    NSLog(@"locationTimer tick - updating location");
    [self updateLocation];
}

#pragma mark - CLLocationManager Delegate methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    if(!self.isUpdatingLocation) return; //makes sure that we only update the location once per update cycle.
    
    CLLocation *newLocation = [locations lastObject];
    NSLog(@"count = %i, locationManager didUpdateLocation lastObject = %@, accuracy = %f", locationUpdateCount, newLocation, [newLocation horizontalAccuracy]);
    [newLocation horizontalAccuracy];
    if(-[newLocation.timestamp timeIntervalSinceNow] < 5){ //if the new location is newer than 5s old, we're done.
        locationUpdateCount++;
        //if either location is rather precise, or we've already looked at a certain number of updates, we set the location. Otherwise we keep waiting.
        NSLog(@"startedUpdatingLocationAt:%@",self.startedUpdatingLocationAt);
        NSLog(@"now: %@", [NSDate date]);
        NSLog(@"timeinterval = %f", [self.startedUpdatingLocationAt timeIntervalSinceNow]);
        //TODO: keep checking for awesome accuracy (10) for 10s, then settle for ok accuracy (30)
        if([newLocation horizontalAccuracy] <= 15.0 || -[self.startedUpdatingLocationAt timeIntervalSinceNow] >= 20){
            //TODO: if accuracy ended up very poor, tell the user.
            [self.locationManager stopUpdatingLocation];
            locationUpdateCount = 0;
            
            CLLocation *oldLocation = self.currentLocation;
            self.currentLocation = newLocation;
            [self setCurrentLocationStrings];
            
            self.isUpdatingLocation = NO;
            [self.delegate locationUpdatedTo:newLocation From:oldLocation];
        } else{
            //TODO: keep track of the best location so far
//            //This forces a quick update of the location so that the user doesn't have to wait too long
//            [self.locationManager stopUpdatingLocation];
//            [self.locationManager startUpdatingLocation];
        }
    }
    
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Failed To Get Location" message:@"Hmm, it seems like we're having a tough time gathering your location. Please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [errorAlert show];
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
    self.startedUpdatingLocationAt = [NSDate date];
    NSLog(@"just set it to %@", self.startedUpdatingLocationAt);
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
