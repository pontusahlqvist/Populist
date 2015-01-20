//
//  Contribution.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/19/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Event;

@interface Contribution : NSManagedObject

@property (nonatomic, retain) NSString * contributingUserId;
@property (nonatomic, retain) NSString * contributionId;
@property (nonatomic, retain) NSString * contributionType;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSString * iconId;
@property (nonatomic, retain) NSString * imagePath;
@property (nonatomic, retain) NSString * message;
@property (nonatomic, retain) Event *event;
@property (nonatomic, retain) Event *titleEvent;

@end
