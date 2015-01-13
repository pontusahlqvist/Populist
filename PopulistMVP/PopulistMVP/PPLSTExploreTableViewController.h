//
//  PPLSTExploreTableViewController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/8/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PPLSTDataManager.h"

@interface PPLSTExploreTableViewController : UITableViewController
@property (strong, nonatomic) NSMutableArray *events;

@property (strong, nonatomic) PPLSTDataManager *dataManager;

@property (strong, nonatomic) NSString *country;
@property (strong, nonatomic) NSString *state;
@property (strong, nonatomic) NSString *city;
@property (strong, nonatomic) NSString *neighborhood;
@end
