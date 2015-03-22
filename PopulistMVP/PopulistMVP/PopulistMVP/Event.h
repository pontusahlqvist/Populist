//
//  Event.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 3/21/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Contribution;

@interface Event : NSManagedObject

@property (nonatomic, retain) NSNumber * containsUser;
@property (nonatomic, retain) NSString * eventId;
@property (nonatomic, retain) NSNumber * importance;
@property (nonatomic, retain) NSDate * lastActive;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSSet *contributions;
@property (nonatomic, retain) Contribution *titleContribution;
@end

@interface Event (CoreDataGeneratedAccessors)

- (void)addContributionsObject:(Contribution *)value;
- (void)removeContributionsObject:(Contribution *)value;
- (void)addContributions:(NSSet *)values;
- (void)removeContributions:(NSSet *)values;

@end
