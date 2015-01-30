//
//  Event.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/27/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Contribution;

@interface Event : NSManagedObject

@property (nonatomic, retain) NSString * city;
@property (nonatomic, retain) NSNumber * containsUser;
@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSString * eventId;
@property (nonatomic, retain) NSDate * lastActive;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSString * neighborhood;
@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) NSNumber * importance;
@property (nonatomic, retain) NSSet *contributions;
@property (nonatomic, retain) Contribution *titleContribution;
@end

@interface Event (CoreDataGeneratedAccessors)

- (void)addContributionsObject:(Contribution *)value;
- (void)removeContributionsObject:(Contribution *)value;
- (void)addContributions:(NSSet *)values;
- (void)removeContributions:(NSSet *)values;

@end
