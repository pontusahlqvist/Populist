//
//  PPLSTDataManager.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/5/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol PPLSTDataManagerDelegate <NSObject>
@required
-(void) locationUpdatedTo:(CLLocation*) newLocation;
-(void) didAcceptAuthorization;
-(void) didDeclineAuthorization;
@end

#import "Event.h"
#import "Contribution.h"
#import "PPLSTEventTableViewCell.h"
#import "JSQMessages.h"
#import "PPLSTExploreTableViewController.h"

@class PPLSTExploreTableViewController;

@interface PPLSTDataManager : NSObject <CLLocationManagerDelegate>
@property (strong, nonatomic) NSManagedObjectContext *context;

-(id) init;

//#pragma mark - Location Related API
//-(void) updateLocation;
//-(CLLocation*) getCurrentLocation;

#pragma mark - Server Side Data Related API
//Returns (and saves to core data) and NSArray where each entry corresponds to meta data for a given event
-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date;
//-(void) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date;

//Returns (and saves as a relationship) an NSArray with contribution meta data (id, message etc but not media) for a certain event.
-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event;

//Uploads (and saves to core data) and then returns a contribution to the cloud with the given data dictionary
-(Contribution*) uploadContributionWithData:(NSDictionary*)contributionDictionary andPhoto:(UIImage*)photo;

//returns (from the server side) a dictionary where the keys are the contributingUserIds and the values are their respective status in the event
-(NSMutableDictionary*) getStatusDictionaryForEvent:(Event*)event;

#pragma mark - Local Data API

//returns the avatar that each status should have
-(JSQMessagesAvatarImage*) avatarForStatus:(NSNumber*)status;

#pragma mark - Cell Formatter API

//Requests download of media for a given cell and then reloads the appropriate tableview upon completion.
-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution;

//Requests download of media for a given JSQMessage and then reloads the appropriate tableview upon completion
-(void) formatJSQMessage:(JSQMessage*)message ForContribution:(Contribution*)contribution inCollectionView:(UICollectionView*)collectionView;


#pragma mark - Variables

@property (weak, nonatomic) UIViewController *currentVC; //keeps track of the current VC so that call backs can be handled by the correct VC
@property (strong, nonatomic) NSMutableDictionary *imagesAtFilePath;
@property (strong, nonatomic) NSMutableDictionary *isLoading;
@property (strong, nonatomic) NSMutableDictionary *avatarForStatus;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *currentLocation;
@property (nonatomic) BOOL isUpdatingLocation;
/*
The worry is that while a core data contribution (created by this user) is being saved, the push notification comes in thereby clashing with the one already being saved (because there won't be a core data object yet). So, instead of comparing the incoming object with core data, we will keep an NSSet with all the contributionIds already in the system. Then, before we save an incoming contribution to core data, we compare with this set. This will only ever be kept in memory so it deisappears on each new load.
*/
@property (strong, nonatomic) NSMutableSet *contributionIds;
@property (weak, nonatomic) id <PPLSTDataManagerDelegate> delegate;

@end
