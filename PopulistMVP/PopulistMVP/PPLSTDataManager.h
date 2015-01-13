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


@interface PPLSTDataManager : NSObject
@property (strong, nonatomic) NSManagedObjectContext *context;

-(id) init;

//Returns (and saves to core data) and NSArray where each entry corresponds to meta data for a given event
-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date;

//Returns (and saves as a relationship) an NSArray with contributionIds for a certain event.
-(NSArray*) downloadContributionIdsForEventId:(NSString*)eventId;

//Returns (and saves to core data) entire contribution for a certain contributionId
-(Contribution*) downloadContributionWithId:(NSString*)contributionId;

-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution;

@end
