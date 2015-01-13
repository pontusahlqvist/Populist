//
//  PPLSTDataManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/5/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTDataManager.h"


@implementation PPLSTDataManager

-(id) init{
    self = [super init];
    if(self){
        id delegate = [[UIApplication sharedApplication] delegate];
        self.context = [delegate managedObjectContext];
    }
    return self;
}

-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date{
    /***************** GET DATA *****************/
    NSMutableArray *events = [[NSMutableArray alloc] init];
    //TODO: filler code. Replace with correct parse code
    for(int i = 0; i < 40; i++){
    
        NSString *eventId = [NSString stringWithFormat:@"eventId%i",i];
        Event *event = [self getEventFromCoreDataWithId:eventId];
        if(!event) event = [self createEventWithId:eventId];

        event.longitude = @(35.00+i);
        event.latitude = @(43.00+i);
        event.lastActive = [NSDate dateWithTimeInterval:-(rand()%1000) sinceDate:[NSDate date]];
        event.country = @"USA";
        event.state = @"California";
        event.city = @"Los Angeles";
        NSArray *possibleNeighborhoods = @[@"Little Osaka", @"Venice Beach", @"Santa Monica Pier", @"Culver City", @"Santa Monica", @"Brentwood", @"Westwood", @"Burbank", @"Beverly Hills", @"Bel Air"];
        event.neighborhood = possibleNeighborhoods[rand()%[possibleNeighborhoods count]];
        
        NSString *titleContributionId = [NSString stringWithFormat: @"titleContributionIdForEvent%i",i];
        Contribution *titleContribution = [self getContributionFromCoreDataWithId:titleContributionId];
        if(!titleContribution) titleContribution = [self createContributionWithId:titleContributionId];
        
        titleContribution.event = event;
        titleContribution.titleEvent = event;
        titleContribution.contributionType = @"photo";
        
        if(![[event titleContributions] containsObject:titleContribution]){
            //TODO: instead of adding the title contribution id, replace the old ones with new ones.. Think about perhaps deallocating memory for old contributions here...
            [event addTitleContributionsObject:titleContribution];
        }
        [events addObject:event];
    }
    
    /***************** SAVE DATA *****************/
    [self saveCoreData];
    
    return events;
}

-(NSArray*) downloadContributionIdsForEventId:(NSString*)eventId{
    /***************** GET DATA *****************/
    //TODO: filler code. Replace with correct parse code
    NSMutableArray *contributionIds = [[NSMutableArray alloc] init];
    for (int i = 0; i < 5; i++) {
        [contributionIds addObject:[NSString stringWithFormat:@"%@id%i",eventId,i]];
    }
    /***************** SAVE DATA *****************/

    Event *event = [self getEventFromCoreDataWithId:eventId];
    [event addContributions:[NSSet setWithArray:contributionIds]];
    
    [self saveCoreData];
    return contributionIds;
}


//by now, there should already exist a contribution object in core data. Here we just update the object.
-(Contribution*) downloadContributionWithId:(NSString*)contributionId{
    
    /************* GET FROM CORE DATA ******************/
    Contribution *contribution = [self getContributionFromCoreDataWithId:contributionId]; //should only have one contribution in the NSArray since ids are unique

    //TODO: check to see if this contribution already has its data set. In that case, don't query parse
    //TODO: filler code. Replace with correct parse code
    
    if ([contribution.contributionType isEqualToString:@"message"]) {
        contribution.message = [NSString stringWithFormat:@"message for %@",contributionId];
    } else if([contribution.contributionType isEqualToString:@"photo"]){
        //TODO: replace with parse code
        UIImage *image = [UIImage imageNamed:@"nyc.jpg"];
        contribution.imagePath = [self storeImage:image WithName:contributionId];
    }

    [self saveCoreData];
    
    return contribution;
}


#pragma mark - cell formatter

-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution{
    //TODO: make sure this asynch call is correct (i.e. uses the correct queues etc.)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        [self downloadContributionWithId:contribution.contributionId];
        NSLog(@"Inside async");
        dispatch_async(dispatch_get_main_queue(), ^{
            cell.titleImageView.image = [UIImage imageWithContentsOfFile:contribution.imagePath];
            [cell.parentTableView reloadData];
            NSLog(@"inside main thread again");
        });
    });
}

#pragma mark - Helper Methods

//retrieves an event object from core data
-(Event *) getEventFromCoreDataWithId:(NSString*) eventId{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Event"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"eventId == %@",eventId];
    NSError *error = nil;
    NSArray *returnedEvents = [self.context executeFetchRequest:fetchRequest error:&error];
    if([returnedEvents count] == 0){
        NSLog(@"Error: No event found in core data with eventId = %@",eventId);
        return nil;
    }
    return returnedEvents[0];
}

//retreives a contribution object from core data
-(Contribution *) getContributionFromCoreDataWithId:(NSString*)contributionId{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Contribution"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contributionId == %@",contributionId];
    NSError *error = nil;
    NSArray *returnedContributions = [self.context executeFetchRequest:fetchRequest error:&error];
    if([returnedContributions count] == 0){
        NSLog(@"Error: No contribution found in core data with contributionId = %@",contributionId);
        return nil;
    }
    return returnedContributions[0];
}

//just saves the current state to core data
-(void) saveCoreData{
    NSError *error = nil;
    if(![self.context save:&error]){
        NSLog(@"error: %@",error);
    }
}

//creates a new event with a given id
-(Event*) createEventWithId:(NSString*)eventId{
    Event *event = [NSEntityDescription insertNewObjectForEntityForName:@"Event" inManagedObjectContext:self.context];
    event.eventId = eventId;
    [self saveCoreData];
    return event;
}


//creates a new contribution with a given id
-(Contribution*) createContributionWithId:(NSString*)contributionId{
    Contribution *contribution = [NSEntityDescription insertNewObjectForEntityForName:@"Contribution" inManagedObjectContext:self.context];
    contribution.contributionId = contributionId;
    [self saveCoreData];
    return contribution;
}

//stores an image in the file system and returns the imagePath
-(NSString *) storeImage:(UIImage*)image WithName:(NSString*)imageName{
    NSData *imageData = UIImagePNGRepresentation(image);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *imagePath =[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",imageName]];
    NSLog((@"pre writing to file"));
    if (![imageData writeToFile:imagePath atomically:NO]){
        NSLog(@"Failed to cache image data to disk");
    }
    else{
        NSLog(@"the cachedImagedPath is %@",imagePath);
    }
    return imagePath;
}

@end
