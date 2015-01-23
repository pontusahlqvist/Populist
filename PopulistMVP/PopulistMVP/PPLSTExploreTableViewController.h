//
//  PPLSTExploreTableViewController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/8/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PPLSTDataManager.h"
#import "PPLSTLocationManager.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@class PPLSTDataManager;

@interface PPLSTExploreTableViewController : UITableViewController <PPLSTLocationManagerDelegate>
@property (strong, nonatomic) PPLSTDataManager *dataManager;
@property (strong, nonatomic) PPLSTLocationManager *locationManager;
@property (strong, nonatomic) NSMutableArray *events;

@property (nonatomic) BOOL isUpdatingEvents;


//TODO: Location Data for User - consider moving into a separate location class
@property (strong, nonatomic) NSString *country;
@property (strong, nonatomic) NSString *state;
@property (strong, nonatomic) NSString *city;
@property (strong, nonatomic) NSString *neighborhood;

-(void) updateEvents;
@end
