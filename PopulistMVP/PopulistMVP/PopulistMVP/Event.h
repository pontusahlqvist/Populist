//
//  Event.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/7/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Contribution;

@interface Event : NSManagedObject

@property (nonatomic, retain) NSString * eventId;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSDate * lastActive;
@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSString * city;
@property (nonatomic, retain) NSString * neighborhood;
@property (nonatomic, retain) NSSet *contributions;
@property (nonatomic, retain) NSSet *titleContributions;
@end

@interface Event (CoreDataGeneratedAccessors)

- (void)addContributionsObject:(Contribution *)value;
- (void)removeContributionsObject:(Contribution *)value;
- (void)addContributions:(NSSet *)values;
- (void)removeContributions:(NSSet *)values;

- (void)addTitleContributionsObject:(Contribution *)value;
- (void)removeTitleContributionsObject:(Contribution *)value;
- (void)addTitleContributions:(NSSet *)values;
- (void)removeTitleContributions:(NSSet *)values;

@end
