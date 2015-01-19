//
//  PPLSTDataManager.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/5/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Event.h"
#import "Contribution.h"
#import "PPLSTEventTableViewCell.h"
#import "JSQMessages.h"


@interface PPLSTDataManager : NSObject
@property (strong, nonatomic) NSManagedObjectContext *context;

-(id) init;

//Returns (and saves to core data) and NSArray where each entry corresponds to meta data for a given event
-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date;

//Returns (and saves as a relationship) an NSArray with contribution meta data (id, message etc but not media) for a certain event.
-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event;

//Uploads (and saves to core data) and then returns a contribution to the cloud with the given data dictionary
-(Contribution*) uploadContributionWithData:(NSDictionary*)contributionDictionary andPhoto:(UIImage*)photo;



//Requests download of media for a given cell and then reloads the appropriate tableview upon completion.
-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution;

//Requests download of media for a given JSQMessage and then reloads the appropriate tableview upon completion
-(void) formatJSQMessage:(JSQMessage*)message ForContribution:(Contribution*)contribution inCollectionView:(UICollectionView*)collectionView;

@end
