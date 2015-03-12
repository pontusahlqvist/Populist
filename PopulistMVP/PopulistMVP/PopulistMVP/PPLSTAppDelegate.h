//
//  PPLSTAppDelegate.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/3/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PPLSTDataManager.h"
#import <Parse/Parse.h>
#import "Reachability.h"

//TODO: make sure that only things that are actually public appear in the .h files

@class PPLSTDataManager;

@interface PPLSTAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@property (strong, nonatomic) PPLSTDataManager *dataManager;
@end
