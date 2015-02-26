//
//  PPLSTDataManager.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/5/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: include launch images for iphone 5/5s and iphone 6+. Just drag them into launchImage-1 in images.xcasset
//TODO: clean up core data for events that are no longer in the stream. Otherwise the data will just build and build...
//TODO: think carefully about memory management. We'll have to only load a certain number of contributions into memory. After that, we'll have to just read them from the file system. Basically create a FIFO max capacity queue data structure.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "Event.h"

@protocol PPLSTDataManagerDelegate <NSObject>
@required
-(void) didUpdateImportanceOfEvent:(Event*)event From:(float)oldValue To:(float) newValue;
-(void) didUpdateTitleContributionForEvent:(Event*)event;
-(void) didUpdateLastActiveForEvent:(Event*)event;
-(void) updateEventsTo:(NSArray*)newEventsArray;
@end

@protocol PPLSTDataManagerPushDelegate <NSObject>
-(void) didAddIncomingContribution:(Contribution*)newContribution ForEvent:(Event*)event;
@end

#import "Contribution.h"
#import "PPLSTEventTableViewCell.h"
#import "JSQMessages.h"
#import "PPLSTExploreTableViewController.h"
#import "PPLSTLocationManager.h"
#import "PPLSTAppDelegate.h"
#import <Parse/Parse.h>

@class PPLSTExploreTableViewController;

@interface PPLSTDataManager : NSObject
@property (strong, nonatomic) NSManagedObjectContext *context;

#pragma mark - Required Methods

-(id) init;


#pragma mark - Server Side Data Related API

//This method first retrieves the events. Then, if the user is not part of any of them, it creates a new invisible event
-(NSArray*) sendSignalAndDownloadEventMetaDataWithInputLatitude:(float) latitude andLongitude:(float) longitude andDate:(NSDate*)date;

//just downloads the event data without sending a signal. Appropriate for poor location situations when a local chat can't be established.
-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date;

//Returns (and saves as a relationship) an NSArray with contribution meta data (id, message etc but not media) for a certain event.
-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event inContext:(NSManagedObjectContext*)context;

-(Contribution*) downloadMediaForContribution:(Contribution*)contribution inContext:(NSManagedObjectContext*) context;

//Uploads (and saves to core data) and then returns a contribution to the cloud with the given data dictionary
-(Contribution*) uploadContributionWithData:(NSDictionary*)contributionDictionary andPhoto:(UIImage*)photo;

//returns (from the server side) a dictionary where the keys are the contributingUserIds and the values are their respective status in the event
-(NSMutableDictionary*) getStatusDictionaryForEvent:(Event*)event;

-(Event*) eventThatUserBelongsTo;

-(void) flagContribution:(Contribution*) contributionToBeFlagged;
#pragma mark - Local Data API

//returns the avatar that each status should have
-(JSQMessagesAvatarImage*) avatarForStatus:(NSNumber*)status;

//increases the importance of an event
-(void) increaseImportanceOfEvent:(Event*)event By:(float)amount;

//Resets the images stored in memory to avoid large amounts of wasted memory
-(void) resetImagesInMemory;

//Returns the image at a given filePath. It does so by storing them in memory once they have been loaded
-(UIImage*) getImageWithFileName:(NSString*)filePath;


#pragma mark - Cell Formatter API

//Requests download of media for a given cell and then reloads the appropriate tableview upon completion.
-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution;

//Requests download of media for a given JSQMessage and then reloads the appropriate tableview upon completion
-(void) formatJSQMessage:(JSQMessage*)message ForContribution:(Contribution*)contribution inCollectionView:(UICollectionView*)collectionView;

#pragma mark - Incoming Push Notification Handler

-(void) handleIncomingDataFromPush:(NSDictionary*)data;

#pragma mark - Variables

//@property (strong, nonatomic) NSMutableDictionary *imagesAtFilePath;
@property (strong, nonatomic) NSMutableDictionary *squareImagesForImageAtFilePath;
@property (strong, nonatomic) NSMutableDictionary *isLoading;
@property (strong, nonatomic) NSMutableDictionary *avatarForStatus;
@property (strong, nonatomic) NSString *contributingUserId;
@property (strong, nonatomic) Event *currentEvent;

@property (nonatomic) BOOL isUpdatingLocation;
@property (strong, nonatomic) PPLSTLocationManager *locationManager;

/*
The worry is that while a core data contribution (created by this user) is being saved, the push notification comes in thereby clashing with the one already being saved (because there won't be a core data object yet). So, instead of comparing the incoming object with core data, we will keep an NSSet with all the contributionIds already in the system. Then, before we save an incoming contribution to core data, we compare with this set. This will only ever be kept in memory so it deisappears on each new load.
*/
@property (strong, nonatomic) NSMutableSet *contributionIds;

@property (weak, nonatomic) id <PPLSTDataManagerDelegate> delegate;
@property (weak, nonatomic) id <PPLSTDataManagerPushDelegate> pushDelegate;

@end
