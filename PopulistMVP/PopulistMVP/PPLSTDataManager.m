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
        
        //setup the basic info for this contribution
        titleContribution.contributingUserId = @"otherPerson";
        titleContribution.createdAt = [event.lastActive copy]; //be careful not to point to the same date object
        titleContribution.contributionType = @"photo";
        
        titleContribution.titleEvent = event;
        titleContribution.contributionType = @"photo";
        
        //add as regular contribution too
        titleContribution.event = event;
        [event addContributionsObject:titleContribution];
        
        //TODO: since it's an NSSet, do we really have to check this? Aren't they unique by default?
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

-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event{
    /***************** GET DATA *****************/
    //TODO: filler code. Replace with correct parse code
    
//    NSMutableArray *contributions = [[NSMutableArray alloc] init];
//    for (int i = 0; i < 5; i++) {
//        Contribution *newContribution = [self createContributionWithId:[NSString stringWithFormat:@"%@id%i",eventId,i]];
//        newContribution.contributionType = @"message";
//        newContribution.message = [NSString stringWithFormat:@"message for contribution with id = %@",newContribution.contributionId];
//        newContribution.createdAt = [NSDate date];
//        newContribution.contributingUserId = @"otherPerson";
//        if(rand()%2 == 0) newContribution.contributingUserId = @"tmpSenderId";
//        [contributions addObject:newContribution];
//    }
//    /***************** SAVE DATA *****************/
//
//    Event *event = [self getEventFromCoreDataWithId:eventId];
//    [event addContributions:[NSSet setWithArray:contributions]];
//
//    [self saveCoreData];
//    return contributions;

    //TODO: return sorted contributions by time
    NSArray *contributions = [event.contributions allObjects];
    NSLog(@"Downloaded %i objects", [contributions count]);
    
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedArray;
    sortedArray = [contributions sortedArrayUsingDescriptors:sortDescriptors];
    return sortedArray;
}


//by now, there should already exist a contribution object in core data. Here we just update the object.
-(Contribution*) downloadMediaForContribution:(Contribution*)contribution{
    
    /************* GET FROM CORE DATA ******************/

    //TODO: check to see if this contribution already has its data set. In that case, don't query parse
    //TODO: filler code. Replace with correct parse code
    
    if ([contribution.contributionType isEqualToString:@"message"]) {
        NSLog(@"downloading message for contribution %@",contribution.contributionId);
        contribution.message = [NSString stringWithFormat:@"message for %@",contribution.contributionId];
    } else if([contribution.contributionType isEqualToString:@"photo"]){
        //TODO: replace with parse code
        NSLog(@"downloading image for contribution %@",contribution.contributionId);
        UIImage *image = [UIImage imageNamed:@"nyc.jpg"];
        contribution.imagePath = [self storeImage:image];
    }
    contribution.contributingUserId = @"otherPerson";
    contribution.createdAt = [NSDate date];
    

    [self saveCoreData];
    
    return contribution;
}


-(Contribution *) uploadContributionWithData:(NSDictionary*)contributionDictionary andPhoto:(UIImage*)photo{
    Contribution *newContribution = [self createContributionWithId:[NSString stringWithFormat:@"tmpId%i",rand()]];
    if([[contributionDictionary allKeys] containsObject:@"eventId"]){
        Event *event = [self getEventFromCoreDataWithId:contributionDictionary[@"eventId"]];
        newContribution.event = event;
        [event addContributionsObject:newContribution];
    }
    if([[contributionDictionary allKeys] containsObject:@"senderId"]){
        newContribution.contributingUserId = contributionDictionary[@"senderId"];
    }
    if([[contributionDictionary allKeys] containsObject:@"contributionType"]){
        newContribution.contributionType = contributionDictionary[@"contributionType"];
    }
    //TODO: also support images here
    if([[contributionDictionary allKeys] containsObject:@"message"]){
        newContribution.message = contributionDictionary[@"message"];
    }
    if([[contributionDictionary allKeys] containsObject:@"createdAt"]){
        newContribution.createdAt = contributionDictionary[@"createdAt"];
    } else{
        newContribution.createdAt = [NSDate date];
    }
    
    if(photo){
        newContribution.imagePath = [self storeImage:photo];
    }
    
    
    [self uploadAndSaveContributionInBackground:newContribution];
    
    return newContribution;
}


//private method
-(void) uploadAndSaveContributionInBackground:(Contribution*) contribution{
    //TODO: replace with parse code
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //TODO: re-assign the contributionId when the upload has completed
        [self saveCoreData];
    });
}


#pragma mark - cell formatter

-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution{
    //first check to see if the media is already set (or its an image) for this cell. If not, go ahead and download it
    NSLog(@"contributionPath for eventId %@ is %@",contribution.contributionId, contribution.imagePath);
    if(([contribution.contributionType isEqualToString:@"photo"] && contribution.imagePath && ![contribution.imagePath isEqualToString:@""]) || ([contribution.contributionType isEqualToString:@"message"] && contribution.message && ![contribution.message isEqualToString:@""])) return;

    //TODO: make sure this asynch call is correct (i.e. uses the correct queues etc.)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        [self downloadMediaForContribution:contribution];
        //after download is complete, move back to main queue for UI updates
//        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            cell.titleImageView.image = [UIImage imageWithContentsOfFile:contribution.imagePath];
            [cell.parentTableView reloadData];
        });
    });
}

-(void) formatJSQMessage:(JSQMessage*)message ForContribution:(Contribution*)contribution inCollectionView:(UITableView *)collectionView{
    //TODO: make asynch
    if([contribution.contributionType isEqualToString:@"photo"]){
        if(contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
                JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                mediaItem.image = [UIImage imageWithContentsOfFile:contribution.imagePath];
        } else{
            //TODO: put parse code here
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                mediaItem.image = [UIImage imageWithContentsOfFile:contribution.imagePath];
                [collectionView reloadData];
            });
        }
    }
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
    NSLog(@"Getting contribution from database with id = %@", contributionId);
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
    NSLog(@"Creating contribution with id = %@",contributionId);
    Contribution *contribution = [NSEntityDescription insertNewObjectForEntityForName:@"Contribution" inManagedObjectContext:self.context];
    contribution.contributionId = contributionId;
    [self saveCoreData];
    return contribution;
}

//stores an image in the file system and returns the imagePath
-(NSString *) storeImage:(UIImage*)image{
    NSData *imageData = UIImagePNGRepresentation(image);
    NSString *imagePath = [self getEmptyFilePath];
    NSLog((@"pre writing to file"));
    if (![imageData writeToFile:imagePath atomically:NO]){
        NSLog(@"Failed to cache image data to disk");
    }
    else{
        NSLog(@"the cachedImagedPath is %@",imagePath);
    }
    return imagePath;
}

//returns NSString representing a filePath which is guaranteed to be empty
-(NSString*) getEmptyFilePath{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString *imageName = [self randomStringWithLength:10];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",imageName]];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    while([fileManager fileExistsAtPath:filePath]){
        imageName = [self randomStringWithLength:10];
        filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",imageName]];
    }
    NSLog(@"Just generated the following free file path: %@", filePath);
    return filePath;
}

//returns a random alphanumeric string of a given length
-(NSString*) randomStringWithLength:(int)length{
    NSString *allowedCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randString = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [randString appendString:[NSString stringWithFormat:@"%C",[allowedCharacters characterAtIndex:rand()%[allowedCharacters length]]]];
    }
    return randString;
}


@end
