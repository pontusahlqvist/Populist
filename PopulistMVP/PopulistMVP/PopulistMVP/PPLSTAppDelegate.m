//
//  PPLSTAppDelegate.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/3/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTAppDelegate.h"
#import <Parse/Parse.h>

@implementation PPLSTAppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    if (networkStatus == NotReachable) {
        NSLog(@"There IS NO internet connection");
        UIAlertView *internetIssueAlert = [[UIAlertView alloc] initWithTitle:@"Failed to connect to the internet" message:@"It seems like your internet connection is a bit spotty right now. Please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [internetIssueAlert show];
    } else{
        // Initialize Parse.
        /*TODO: make sure to use the applicationkey HqSQkohCVzDHOILzZ6tVcV7uPc2Sycv5SHTY5rye and clientKey yFhhnIp67MMBejd9xsb9Snph9tfYnad7vPXw56Ja
        The other ones are just meant for testing!
        */
        //These are for Populist
        [Parse setApplicationId:@"HqSQkohCVzDHOILzZ6tVcV7uPc2Sycv5SHTY5rye"
                      clientKey:@"yFhhnIp67MMBejd9xsb9Snph9tfYnad7vPXw56Ja"];
        //These are for PopulistDev
    //    [Parse setApplicationId:@"9QBXXnp5slVEcnO4yofC8V6mh2UhbCIUEuWb6pIf"
    //                  clientKey:@"MG7WGsU9FAkrT9ciEiH59ns0emRLcWJj5vOQaoOa"];
        
        //These are the old credentials below
    //    [Parse setApplicationId:@"DxLocYGgTcUhCkpYsicPsKYVdBv9IxPClq8vS3pf"
    //                  clientKey:@"Nk8ICVkbYUsENWel8iO8ww6WUwDSOgvmcHNUyYJM"];
     
        // [Optional] Track statistics around application opens.
        [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];

        UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert |
                                                      UIUserNotificationTypeBadge |
                                                      UIUserNotificationTypeSound);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
                                                                               categories:nil];
        [application registerUserNotificationSettings:settings];
        [application registerForRemoteNotifications]; 
    }
    return YES;
}


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  // Store the deviceToken in the current installation and save it to Parse.
    NSLog(@"didRegisterForRemoteNotificationWithDeviceToken:%@", deviceToken);
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    currentInstallation.channels = @[ @"global" ];
    [currentInstallation saveInBackground];
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error{
    NSLog(@"didFailToRegisterForRemoteNotificationsWithError");
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    if([[userInfo allKeys] containsObject:@"t"]){ //t for type. If push doesn't contain t as a key, we deal with it separately
        [self.dataManager handleIncomingDataFromPush:userInfo];
    } else if([[userInfo allKeys] containsObject:@"o"]){ //o for old. If push contains this key, it's a merge notification
        [self.dataManager handleIncomingMergePush:userInfo];
    } else if([[userInfo allKeys] containsObject:@"d"]){ //d for description
        //If the app is open, do nothing. This is meant to engage the user once the app is closed.
//        UIAlertView *crowdForming = [[UIAlertView alloc] initWithTitle:@"A crowd is forming near you!" message:userInfo[@"d"] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
//        [crowdForming show];
    } else{
        [PFPush handlePush:userInfo];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
//        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"PopulistMVP" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"PopulistMVP.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
