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

@interface PPLSTExploreTableViewController : UITableViewController <PPLSTLocationManagerDelegate, PPLSTDataManagerDelegate>

//External data/location manager classes
@property (strong, nonatomic) PPLSTDataManager *dataManager;
@property (strong, nonatomic) PPLSTLocationManager *locationManager;

//content related
@property (strong, nonatomic) NSMutableArray *events;
@property (strong, nonatomic) Event *currentEvent;
@property (nonatomic) BOOL isUpdatingEvents;

@end
