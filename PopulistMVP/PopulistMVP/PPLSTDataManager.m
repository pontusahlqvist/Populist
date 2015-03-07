//
//  PPLSTDataManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/5/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: when two events are merged, the contributingUsers were not previously merged on parse. I have added code to fix this, but we still need to make sure that it works properly.
//TODO: when deleting events/contributions/files during cleanup, there seems to be left over garbage. Not sure why, but even with a clean slate, there's still several MB of stored stuff...

#import "PPLSTDataManager.h"
#import <Parse/Parse.h>
#import "PPLSTUUID.h"

@interface PPLSTDataManager()
//@property (strong, nonatomic) NSMutableDictionary *imagesAtFilePath;
@property (strong, nonatomic) PPLSTMutableDictionary *imagesAtFilePath;
@property (strong, nonatomic) NSMutableDictionary *avatarImageSourceForStatus;
@end

@implementation PPLSTDataManager

//NOTE: prior to iOS8 the max payload for an apple push notification was 256 bytes. Starting with iOS8, this has been increased to 2kb.
int maxMessageLengthForPush = 1000;

#pragma mark - Required Methods

-(id) init{
    self = [super init];
    if(self){
        id delegate = [[UIApplication sharedApplication] delegate];
        self.context = [delegate managedObjectContext];
        //setup a listener to see if other contexts on other threads have been saved
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextHasChanged:) name:NSManagedObjectContextDidSaveNotification object:nil];
        self.contributingUserId = [PPLSTUUID UUID];
        
        PPLSTAppDelegate *appDelegate = (PPLSTAppDelegate*)[UIApplication sharedApplication].delegate;
        appDelegate.dataManager = self;
        [self createAvatarForStatusDictionary];
    }
    return self;
}

#pragma mark - NSManagedObjectContext Save Notification

-(void) contextHasChanged:(NSNotification*)notification{
    if ([notification object] == [self context]) return;

    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(contextHasChanged:) withObject:notification waitUntilDone:YES];
        return;
    }
    [[self context] mergeChangesFromContextDidSaveNotification:notification];
}

#pragma mark - Setup / Instantiation Methods

-(PPLSTMutableDictionary *)imagesAtFilePath{
    if(!_imagesAtFilePath) _imagesAtFilePath = [[PPLSTMutableDictionary alloc] init];
    return _imagesAtFilePath;
}

-(PPLSTMutableDictionary *)imagesInMemoryForContributionId{
    if(!_imagesInMemoryForContributionId) _imagesInMemoryForContributionId = [[PPLSTMutableDictionary alloc] init];
    return _imagesInMemoryForContributionId;
}

-(NSMutableDictionary *)isLoading {
    if(!_isLoading) _isLoading = [[NSMutableDictionary alloc] init];
    return _isLoading;
}

-(NSMutableDictionary *)avatarForStatus{
    if(!_avatarForStatus) _avatarForStatus = [[NSMutableDictionary alloc] init];
    return _avatarForStatus;
}

-(NSMutableDictionary *)avatarImageSourceForStatus{
    if(!_avatarImageSourceForStatus) _avatarImageSourceForStatus = [[NSMutableDictionary alloc] init];
    return _avatarImageSourceForStatus;
}

-(UIImage*) drawText:(NSString*)text atCenterOfImage:(UIImage*)image{
    UIFont *font = [UIFont boldSystemFontOfSize:110];
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setAlignment:NSTextAlignmentCenter];
    NSDictionary *attributesForText = @{NSFontAttributeName:font,NSForegroundColorAttributeName:[UIColor whiteColor], NSParagraphStyleAttributeName:style};
    CGSize size = [text sizeWithAttributes:attributesForText];
    CGRect rect = CGRectMake(image.size.width/2.0-size.width/2.0, image.size.height/2.0-size.height/2.0, size.width, size.height);
    
    UIGraphicsBeginImageContext(image.size);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    [[UIColor whiteColor] set];
    [text drawInRect:rect withAttributes:attributesForText];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

//TODO: this re-generates the avatars each time. Do something better than this. Maybe just store them as image assets or something
-(void) createAvatarForStatusDictionary{
    NSLog(@"PPLSTDataManager - createAvatarForStatusDictionary");

    self.avatarImageSourceForStatus[@0] = @"gold.jpg";
    self.avatarImageSourceForStatus[@1] = @"salmon.jpg";
    self.avatarImageSourceForStatus[@2] = @"lightBlue.jpg";
    self.avatarImageSourceForStatus[@3] = @"darkGreen.jpg";
    self.avatarImageSourceForStatus[@4] = @"lightGreen.jpg";
    self.avatarImageSourceForStatus[@5] = @"purple.png";
    self.avatarImageSourceForStatus[@6] = @"red.jpg";
    self.avatarImageSourceForStatus[@7] = @"black.png";
    self.avatarImageSourceForStatus[@8] = @"orange.jpg";
    self.avatarImageSourceForStatus[@9] = @"grey.jpg";

    NSArray *firstLetter = [NSArray arrayWithObjects: @"", @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
    NSArray *secondLetter = [NSArray arrayWithObjects: @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
    
    NSInteger count = [self.avatarImageSourceForStatus count];
    for(int i = 0; i < [firstLetter count]; i++){
        for(int j = 0; j < [secondLetter count]; j++){
            self.avatarImageSourceForStatus[[NSNumber numberWithInteger:count]] = [NSString stringWithFormat:@"%@%@",firstLetter[i],secondLetter[j]];
            count++;
        }
    }
}

-(NSMutableSet *)contributionIds{
    if(!_contributionIds) _contributionIds = [[NSMutableSet alloc] init];
    return _contributionIds;
}

#pragma mark - Server Side Data Related API

-(PFObject*) sendSignalWithLatitude:(float)latitude andLongitude:(float)longitude andDate:(NSDate*)date{
    NSLog(@"PPLSTDataManager - sendSignalWithLatitude:%f andLongitude:%f andDate:%@", latitude, longitude, date);
    //TODO: make sure that these are the same as on the cloud side. In fact, perhaps outsource all of this to the cloud to avoid duplication
    NSNumber *alpha0 = [NSNumber numberWithDouble:1.4489501];
    NSNumber *beta0 = [NSNumber numberWithDouble:0.000073628];
    NSNumber *alpha = [NSNumber numberWithDouble:2.77777];
    NSNumber *beta = [NSNumber numberWithDouble:11111.1];
    PFObject *newEvent = [PFObject objectWithClassName:@"FlatCluster"];
    [newEvent setObject:@1 forKey:@"k"];
    [newEvent setObject:@2 forKey:@"N"];
    [newEvent setObject:@0.9 forKey:@"importance"]; //just a signal so keep smaller than 1, however close to 1 to make sure nearby people get clustered properly.
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"dd-MM-yyyy";
    [newEvent setObject:[dateFormatter dateFromString:@"1-1-2101"] forKey:@"validUntil"];
    [newEvent setObject:@[] forKey:@"contributions"];
    [newEvent setObject:@[] forKey:@"contributingUsers"];
    [newEvent setObject:@[] forKey:@"titlePhotoIdArray"];
    [newEvent setObject:@[] forKey:@"titleMessageIdArray"];
    [newEvent setObject:[PFGeoPoint geoPointWithLatitude:latitude longitude:longitude] forKey:@"location"];
    [newEvent setObject:alpha0 forKey:@"alphan"];
    [newEvent setObject:beta0 forKey:@"betan"];
    [newEvent setObject:date forKey:@"t1"];
    [newEvent setObject:date forKey:@"tk"];
    [newEvent setObject:date forKey:@"tbar"];
    [newEvent setObject:alpha forKey:@"alpha"];
    [newEvent setObject:beta forKey:@"beta"];
    [newEvent setObject:self.locationManager.country forKey:@"country"];
    [newEvent setObject:self.locationManager.state forKey:@"state"];
    [newEvent setObject:self.locationManager.city forKey:@"city"];
    [newEvent setObject:self.locationManager.neighborhood forKey:@"neighborhood"];

    //Note: must save synchronously so that the event newEvent has a correct eventId by the time we create the core data event below.
    [newEvent save];
    return newEvent;
}

-(NSArray*) sendSignalAndDownloadEventMetaDataWithInputLatitude:(float) latitude andLongitude:(float) longitude andDate:(NSDate*)date{
    NSLog(@"PPLSTDataManager - sendSignalAndDownloadEventMetaDataWithInputLatitude:%f andLongitude:%f andDate:%@",latitude,longitude,date);
    //first setup a new event with the given location and time. Then, fetch and return the events
    NSMutableArray *eventsFromCloud = [[self downloadEventMetaDataWithInputLatitude:latitude andLongitude:longitude andDate:date] mutableCopy];
    Event *firstEvent = [eventsFromCloud firstObject];
    if([firstEvent.containsUser isEqualToNumber:@1]){
        self.currentEvent = firstEvent;
        return eventsFromCloud;
    } else{
        PFObject *newEvent = [self sendSignalWithLatitude:latitude andLongitude:longitude andDate:date];
        NSString *eventId = newEvent.objectId;
        Event *currentEvent = [self createEventWithId:eventId inContext:self.context];
        currentEvent.city = [newEvent objectForKey:@"city"];
        currentEvent.country = [newEvent objectForKey:@"country"];
        currentEvent.containsUser = @1;
        currentEvent.importance = [newEvent objectForKey:@"importance"];
        currentEvent.lastActive = [newEvent objectForKey:@"updatedAt"];
        currentEvent.latitude = [NSNumber numberWithFloat:latitude];
        currentEvent.longitude = [NSNumber numberWithFloat:longitude];
        currentEvent.neighborhood = [newEvent objectForKey:@"neighborhood"];
        currentEvent.state = [newEvent objectForKey:@"state"];
        
        Contribution *titleContribution = [self newDummyTitleContribution];
        //Set relationship
        //Note: don't set event because we don't want it to appear in the actual feed
        titleContribution.parentEvent = currentEvent;

        self.currentEvent = currentEvent;

        [self saveCoreDataInContext:self.context];
        
        [eventsFromCloud insertObject:currentEvent atIndex:0];
        return eventsFromCloud;
    }
}

-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date{
    NSLog(@"PPLSTDataManager - downloadEventMetaDataWithInputLatitude:%f andLongitude:%f andDate:%@", latitude, longitude, date);
    NSDictionary *result = [PFCloud  callFunction:@"getClusters" withParameters:@{@"latitude": [NSNumber numberWithFloat:latitude], @"longitude": [NSNumber numberWithFloat:longitude]}];
    NSArray *eventDataArray = result[@"customClusterObjects"];


    NSMutableArray *events = [[NSMutableArray alloc] init];
    for(NSDictionary *eventDictionary in eventDataArray){
        NSLog(@"eventDictionary = %@", eventDictionary);
        NSString *eventId = eventDictionary[@"objectId"];

        Event *event = [self getEventFromCoreDataWithId:eventId inContext:self.context];
        if(!event) event = [self createEventWithId:eventId inContext:self.context];
        
        event.city = eventDictionary[@"city"];
        event.containsUser = [NSNumber numberWithBool:[eventDictionary[@"containsUser"] boolValue]]; //@"YES" gets converted to YES.
        event.country = eventDictionary[@"country"];
        event.importance = eventDictionary[@"importance"];
        event.lastActive = eventDictionary[@"updatedAt"];
        event.latitude = eventDictionary[@"latitude"];
        event.longitude = eventDictionary[@"longitude"];
        event.neighborhood = eventDictionary[@"neighborhood"];
        event.state = eventDictionary[@"state"];
        
        NSString *titleContributionId = eventDictionary[@"titlePhotoId"];
        if(![titleContributionId isEqualToString:event.titleContribution.contributionId] && (titleContributionId || !event.titleContribution)){
            if (!titleContributionId) {
                titleContributionId = event.titleContribution.contributionId;
                if(!titleContributionId){
                    //must create a dummy titleContribution. Note, this one should not be added to contributions
                    //TODO: make sure this is unique
                    titleContributionId = [NSString stringWithFormat:@"%@%@",@"dummy", [self randomStringWithLength:10]];
                }
            }

            Contribution *titleContribution = [self getContributionFromCoreDataWithId:titleContributionId inContext:self.context];
            if(!titleContribution){
                titleContribution = [self createContributionWithId:titleContributionId inContext:self.context];
                titleContribution.contributingUserId = @"";
                titleContribution.contributionType = @"photo";
                titleContribution.createdAt = [event.lastActive copy]; //be careful not to point to the same date object
                titleContribution.imagePath = nil;
                titleContribution.latitude = nil;
                titleContribution.longitude = nil;
                titleContribution.message = nil;
                titleContribution.parentEvent = event;
            }
            event.titleContribution = titleContribution;
        }

        [events addObject:event];
    }
        
    [self saveCoreDataInContext:self.context];
    //set up a separate queue and context and then use those to delete the unused events from core data.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.parentContext = self.context;
        [context performBlock:^{
            [self cleanUpUnusedDataForEventsNotIn:events inContext:context];
        }];
    });

    return events;
}


-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - downloadContributionMetaDataForEvent:%@",event);
    NSDictionary *result = [PFCloud callFunction:@"getContributionIdsInCluster" withParameters:@{@"clusterId" : event.eventId}];
    NSArray *arrayOfContributionData = result[@"contributionIds"];
    NSMutableArray *contributions = [[NSMutableArray alloc] init];
    for(NSDictionary *contributionData in arrayOfContributionData){
        NSString *contributionId = contributionData[@"contributionId"];
        NSLog(@"considering contribution with Id = %@", contributionId);
        Contribution *newContribution = [self getContributionFromCoreDataWithId:contributionId inContext:self.context];
        if(!newContribution){
            NSLog(@"downloadContributionMetaDataForEvent - 1");
            newContribution = [self createContributionWithId:contributionId inContext:self.context];
            NSLog(@"downloadContributionMetaDataForEvent - 2");
            newContribution.imagePath = nil;
            NSLog(@"downloadContributionMetaDataForEvent - 3");
            newContribution.latitude = nil;
            NSLog(@"downloadContributionMetaDataForEvent - 4");
            newContribution.longitude = nil;
            NSLog(@"downloadContributionMetaDataForEvent - 5");
            newContribution.message = nil;
            NSLog(@"downloadContributionMetaDataForEvent - 6");
        }
        NSLog(@"downloadContributionMetaDataForEvent - 7");
        newContribution.createdAt = contributionData[@"createdAt"]; //makes sure that even title contributions get their date set properly
        NSLog(@"downloadContributionMetaDataForEvent - 8");
        newContribution.contributingUserId = contributionData[@"userId"]; //same reason as above.
        NSLog(@"downloadContributionMetaDataForEvent - 9");
        newContribution.contributionType = contributionData[@"type"];
        NSLog(@"downloadContributionMetaDataForEvent - 10");
        
        [event addContributionsObject:newContribution];
        NSLog(@"downloadContributionMetaDataForEvent - 11");
        if([newContribution.contributionType isEqualToString:@"message"]){
            NSLog(@"downloadContributionMetaDataForEvent - 12");
            newContribution.message = contributionData[@"message"];
        }
        NSLog(@"downloadContributionMetaDataForEvent - 13");
        [contributions addObject:newContribution];
    }
    NSLog(@"downloadContributionMetaDataForEvent - 14");
    [self saveCoreDataInContext:context];
    NSLog(@"downloadContributionMetaDataForEvent - 15");
    
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedArray;
    sortedArray = [contributions sortedArrayUsingDescriptors:sortDescriptors];
    return sortedArray;
}


//by now, there should already exist a contribution object in core data. Here we just update the object.
-(Contribution*) downloadMediaForContribution:(Contribution*)contribution inContext:(NSManagedObjectContext*) context{
    NSLog(@"PPLSTDataManager - downloadMediaForContribution:%@",contribution);
    if([[contribution.contributionId substringToIndex:5] isEqualToString:@"dummy"]){
        //TODO: perhaps change this to different images for different events? Maybe create images on the fly with some text indicating their location?
        //TODO: improve the quality of the placeholder image
        contribution.imagePath = [self storeImage:[UIImage imageNamed:@"PlaceholderImage"] forContributionId:contribution.contributionId];
    } else if ([contribution.contributionType isEqualToString:@"message"]) {
        PFQuery *query = [PFQuery queryWithClassName:@"Contribution"];
        PFObject *parseContribution = [query getObjectWithId:contribution.contributionId];
        NSString *message = [parseContribution objectForKey:@"message"];
        contribution.message = message;
        contribution.contributingUserId = [parseContribution objectForKey:@"userId"];
        contribution.createdAt = parseContribution.createdAt;
    } else if([contribution.contributionType isEqualToString:@"photo"]){
        PFQuery *query = [PFQuery queryWithClassName:@"Contribution"];
        PFObject *parsePhoto = [query getObjectWithId:contribution.contributionId];
        PFFile *file = [parsePhoto objectForKey:@"image"];
        NSData *parseImageData = [file getData];
        UIImage *image = [UIImage imageWithData:parseImageData];
        contribution.imagePath = [self storeImage:image forContributionId:contribution.contributionId];
        contribution.contributingUserId = [parsePhoto objectForKey:@"userId"];
        contribution.createdAt = contribution.createdAt;//[parsePhoto objectForKey:@"createdAt"]; TODO: why is this commented out? Shouldn't it come from parse?
    }
    
    [self saveCoreDataInContext:context];
    
    return contribution;
}

//Uploads (and saves to core data) and then returns a contribution to the cloud with the given data dictionary
-(Contribution *) uploadContributionWithData:(NSDictionary*)contributionDictionary andPhoto:(UIImage*)photo{
    NSLog(@"PPLSTDataManager - uploadContributionWithData:%@ andPhoto%@",contributionDictionary, photo);
    Contribution *newContribution = [self createContributionWithId:[NSString stringWithFormat:@"tmpId%i",rand()] inContext:self.context];

    if([[contributionDictionary allKeys] containsObject:@"senderId"]){
        newContribution.contributingUserId = contributionDictionary[@"senderId"];
    } else{
        NSLog(@"Error: contributingUserId is not set");
        newContribution.contributingUserId = nil;
    }
    if([[contributionDictionary allKeys] containsObject:@"contributionType"]){
        newContribution.contributionType = contributionDictionary[@"contributionType"];
    } else{
        NSLog(@"Error: contributionType is not set");
        newContribution.contributionType = nil;
    }
    if([[contributionDictionary allKeys] containsObject:@"createdAt"]){
        newContribution.createdAt = contributionDictionary[@"createdAt"];
    } else{
        newContribution.createdAt = [NSDate date];
    }
    if(photo){
        newContribution.imagePath = [self storeImage:[self imageWithImage:photo scaledToSize:CGSizeMake(320.0, 320.0)] forContributionId:newContribution.contributionId];
    } else{
        newContribution.imagePath = nil;
    }
    if([[contributionDictionary allKeys] containsObject:@"location"]){
        CLLocation *location = contributionDictionary[@"location"];
        newContribution.latitude = [NSNumber numberWithDouble:location.coordinate.latitude];
        newContribution.longitude = [NSNumber numberWithDouble: location.coordinate.longitude];
    } else{
        NSLog(@"Error: location not set");
        newContribution.latitude = nil;
        newContribution.longitude = nil;
    }
    if([[contributionDictionary allKeys] containsObject:@"message"]){
        newContribution.message = contributionDictionary[@"message"];
    } else{
        newContribution.message = nil;
    }

    Event *event;
    if([[contributionDictionary allKeys] containsObject:@"eventId"]){
        event = [self getEventFromCoreDataWithId:contributionDictionary[@"eventId"] inContext:self.context];
        newContribution.event = event;
        [event addContributionsObject:newContribution];
        if([newContribution.contributionType isEqualToString:@"photo"]){
            event.titleContribution = newContribution;
            [self.delegate didUpdateTitleContributionForEvent:event];
        }
    } else{
        NSLog(@"Error: eventId is not set");
    }
    
    [self uploadAndSaveContributionInBackground:newContribution];
    [self.delegate didUpdateLastActiveForEvent:event];
    
    return newContribution;
}

-(void) uploadAndSaveContributionInBackground:(Contribution*) contribution{
    NSLog(@"PPLSTDataManager - uploadAndSaveContributionInBackground:%@",contribution);
    //we grab the data from the contribution before the queue since we want to avoid passing NSManagedObjects between queues (in this case contribution)
    __block NSString *contributionType = contribution.contributionType;
    __block NSString *message = contribution.message;
    __block NSString *imagePath = contribution.imagePath;
    __block NSString *contributingUserId = contribution.contributingUserId;
    __block NSNumber *latitude = contribution.latitude;
    __block NSNumber *longitude = contribution.longitude;
    __block NSString *eventId = contribution.event.eventId;
    //message, imagePath, userId, latitude, longitude, event.eventId,
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        PFObject *parseContribution = [PFObject objectWithClassName:@"Contribution"];
        if([contributionType isEqualToString:@"message"]){
            [parseContribution setObject:@"message" forKey:@"type"];
            [parseContribution setObject:message forKey:@"message"];
        } else if([contributionType isEqualToString:@"photo"]){
            [parseContribution setObject:@"photo" forKey:@"type"];
            
            //Note: compression of 1.0 -> size in the 300-400kb range. 0.5 -> 30-40kb, and 0.0 -> 10-20 kb. Original image -> 1.5 Mb.
            NSData *imageData = UIImageJPEGRepresentation([self getImageWithFileName:imagePath], 0.5f); //TODO: port over to memory-only method
            PFFile *imageFile = [PFFile fileWithName:@"image.jpg" data:imageData];
            [imageFile saveInBackground];
            [parseContribution setObject:imageFile forKey:@"image"];
        }
        [parseContribution setObject:contributingUserId forKey:@"userId"];
        [parseContribution setObject:[[NSArray alloc] init] forKey:@"flaggedBy"];
        [parseContribution setObject:[PFGeoPoint geoPointWithLatitude:[latitude doubleValue] longitude:[longitude doubleValue]] forKey:@"location"];
        [parseContribution setObject:eventId forKey:@"promise"];
        [parseContribution save];
        
        //we return to the main queue since we're modifying an NSManagedObject subclass (contribution) which was originally definied in the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            //get the object id and reassign it locally
            NSString *objectId = [parseContribution valueForKeyPath:@"objectId"];
            //we need to update the contributionId if applicable and also go ahead and move the old file to the new location
            if(![contribution.contributionId isEqualToString:objectId]){
                if([[self.imagesInMemoryForContributionId allKeys] containsObject:contribution.contributionId]){
                    self.imagesInMemoryForContributionId[objectId] = self.imagesInMemoryForContributionId[contribution.contributionId];
                    contribution.contributionId = objectId;
                }
            }
            [self.contributionIds addObject:objectId]; //TODO: we'll end up with a lot of temporary Ids here since we add to it already in the creation process..
            
            //send push notification
            NSMutableDictionary *pushData = [[NSMutableDictionary alloc] init];
            pushData[@"alert"] = @"New stuff at your event!";
            pushData[@"c"] = objectId;
            pushData[@"t"] = contribution.contributionType;
            pushData[@"u"] = contribution.contributingUserId;
            pushData[@"e"] = contribution.event.eventId;
            if([contribution.contributionType isEqualToString:@"message"]){
                if ([contribution.message length] <= maxMessageLengthForPush) {
                    pushData[@"m"] = contribution.message;
                } else{
                    pushData[@"m"] = @""; //send the empty string along, and let the other user download the data from the server
                }
            }
            PFPush *pushNotification = [[PFPush alloc] init];
            [pushNotification setChannels:@[[NSString stringWithFormat:@"event%@",contribution.event.eventId]]];
            [pushNotification setData:pushData];
            [pushNotification expireAfterTimeInterval:5];//expires after 5 sec
            [pushNotification sendPushInBackground];
            
            [self saveCoreDataInContext:self.context];
        });
    });
}

-(NSMutableDictionary *)getStatusDictionaryForEvent:(Event *)event{
    NSLog(@"PPLSTDataManager - getStatusDictionaryForEvent:%@",event);
    
    NSDictionary *result = [PFCloud  callFunction:@"getStatusInCluster" withParameters:@{@"clusterId": event.eventId}];
    NSLog(@"return from parse: %@", result);
    NSArray *statusArray = result[@"statusArray"];
    NSMutableDictionary *statusDictionary = [[NSMutableDictionary alloc] init];
    for(int status = 0; status < [statusArray count]; status++){
        statusDictionary[statusArray[status]] = [NSNumber numberWithInt:status];
    }
    return statusDictionary;
}

//TODO: create a custom server side function to handle this so that we don't have to download all the events each time. That would save a lot of API calls
-(Event *)eventThatUserBelongsTo{
    NSLog(@"PPLSTDataManager - eventThatUserBelongsTo");
    CLLocation *currentLocation = [self.locationManager getCurrentLocation];
    NSString *oldCurrentEventId = [self.currentEvent.eventId copy];
    //TODO: change this to only check the given event instead of downloading everything again
    NSArray *events = [self sendSignalAndDownloadEventMetaDataWithInputLatitude:currentLocation.coordinate.latitude andLongitude:currentLocation.coordinate.longitude andDate:[NSDate date]];
    //note: self.currentEvent should have been updated during the sendSignalAndDownload... call
    if(![self.currentEvent.eventId isEqualToString:oldCurrentEventId]){
        //trigger an update on the explore VC because the event that the user belongs to has changed
        [self.delegate updateEventsTo:events];
    }
    return events[0];
}

-(void) flagContribution:(Contribution*) contributionToBeFlagged{
    [PFCloud callFunctionInBackground:@"flagContribution" withParameters:@{@"contributionId":contributionToBeFlagged.contributionId, @"clusterId":contributionToBeFlagged.event.eventId, @"userId":self.contributingUserId} block:^(id object, NSError *error) {
        NSLog(@"flag error = %@", error);
        if(!error){
            UIAlertView *reportSuccessAlertView = [[UIAlertView alloc] initWithTitle:@"Thanks!" message:@"Thanks for reporting this piece of content! We have forwarded this to one of our reviewers. At Populist we take the integrity of our service very seriously and appreciate people like you who keep an eye out for bad stuff. Keep up the good work!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [reportSuccessAlertView show];
        } else{
            UIAlertView *reportErrorAlertView = [[UIAlertView alloc] initWithTitle:@"Hmmm..." message:@"It seems like we encountered an error when attempting to flag this piece of content. Please try flagging this in a bit." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [reportErrorAlertView show];
        }
    }];
}

#pragma mark - Incoming Data From Push Notifications

-(void) handleIncomingDataFromPush:(NSDictionary*)data{
    NSLog(@"PPLSTDataManager - handleIncomingDataFromPush:%@",data);
    NSString *contributionId = data[@"c"];
    if(![self.contributionIds containsObject:contributionId]){
        [self.contributionIds addObject:contributionId];
        //it's a new contribution
        Contribution *newIncomingContribution = [self createContributionWithId:contributionId inContext:self.context];
        newIncomingContribution.contributingUserId = data[@"u"];
        newIncomingContribution.contributionType = data[@"t"];
        newIncomingContribution.createdAt = [NSDate date]; //TODO: update to actual date to make sure order is the same throughout all feeds
        newIncomingContribution.imagePath = nil;
        newIncomingContribution.latitude = nil;
        newIncomingContribution.longitude = nil;
        if([data[@"t"] isEqualToString:@"message"]){
            newIncomingContribution.message = data[@"m"];
        }
        
        Event *eventToWhichThisContributionBelongs = [self getEventFromCoreDataWithId:data[@"e"] inContext:self.context];
        newIncomingContribution.event = eventToWhichThisContributionBelongs;
        [self.pushDelegate didAddIncomingContribution:newIncomingContribution ForEvent:eventToWhichThisContributionBelongs];
        eventToWhichThisContributionBelongs.lastActive = newIncomingContribution.createdAt;
        [self.delegate didUpdateLastActiveForEvent:eventToWhichThisContributionBelongs];
        if([data[@"t"] isEqualToString:@"photo"]){
            eventToWhichThisContributionBelongs.titleContribution = newIncomingContribution;
            [self.delegate didUpdateTitleContributionForEvent:eventToWhichThisContributionBelongs];
        }
    }
}

-(void)handleIncomingMergePush:(NSDictionary *)data{
    NSLog(@"PPLSTDataManager - handleIncomingMergePush:%@",data);
    NSString *oldEventId = data[@"o"];
    NSString *newEventId = data[@"n"];
    NSNumber *oldCount = data[@"oc"];
    NSNumber *newCount = data[@"nc"];
    
    NSLog(@"oldeventId = %@, newEventId = %@",oldEventId, newEventId);
    //we update the event id for the old event in case we have it
    Event *oldEvent = [self getEventFromCoreDataWithId:oldEventId inContext:self.context];
//    Event *newEvent = [self getEventFromCoreDataWithId:newEventId inContext:self.context];
    if(oldEvent){
        oldEvent.eventId = newEventId;
        [self saveCoreDataInContext:self.context];
    }
    [self.pushDelegate eventIdWasUpdatedFrom:oldEventId to:newEventId oldCount:oldCount newCount:newCount];
}



#pragma mark - Local Data API

-(JSQMessagesAvatarImage *)avatarForStatus:(NSNumber *)status{
    NSLog(@"PPLSTDataManager - avatarForStatus:%@",status);
    if(!status){
        return nil;
    }
    
    if(![[self.avatarForStatus allKeys] containsObject:status]){
        UIImage *image = [UIImage imageNamed:self.avatarImageSourceForStatus[status]];
        if(!image){
            image = [self drawText:self.avatarImageSourceForStatus[status] atCenterOfImage:[UIImage imageNamed:@"grey.jpg"]];
        }
        JSQMessagesAvatarImage *avatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:image diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
        self.avatarForStatus[status] = avatarImage;
    }
    return self.avatarForStatus[status];
}

-(void) increaseImportanceOfEvent:(Event*)event By:(float)amount{
    NSLog(@"PPLSTDataManager - increaseImportanceOfEvent:%@ By:%f",event,amount);
    float oldImportance = [event.importance floatValue];
    event.importance = [NSNumber numberWithFloat:(oldImportance + amount)];
    float newImportance = [event.importance floatValue];
    [self saveCoreDataInContext:self.context];
    
    [self.delegate didUpdateImportanceOfEvent:event From:oldImportance To:newImportance];
}

-(void) resetImagesInMemory{
    [self.imagesAtFilePath removeAllObjects];
}

-(void) cleanUpUnusedDataForEventsNotIn:(NSArray*)eventsToKeep inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - cleanUpUnusedDataForEventsNotIn:%@ inContext:%@",eventsToKeep, context);
    NSMutableArray *eventIdsToKeep = [[NSMutableArray alloc] init];
    for (Event *event in eventsToKeep) {
        [eventIdsToKeep addObject:event.eventId];
    }
    //retrieve all the events from core data not in the array passed in
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Event"];
    NSError *error = nil;
    NSArray *returnedEvents = [context executeFetchRequest:fetchRequest error:&error];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (Event* event in returnedEvents){
        //Note: containsObject calls isEqual which, when acting on NSManagedObjects compares points values. Thus we must not use [eventsToKeep containsObject:event]. Instead, we must compare eventIds.
        if(![eventIdsToKeep containsObject:event.eventId] && ![event.eventId isEqualToString:self.currentEvent.eventId]){
            /*delete the event and all dependent objects of it*/
            //Retrieve all the contributons
            for(Contribution *contribution in event.contributions){
                NSString *fileName = contribution.imagePath;
                NSLog(@"Deleting file with fileName = %@", fileName);
                if(fileName){
                    //delete file at that file path
                    NSError *error = nil;
                    [manager removeItemAtPath:[self filePathForImageWithFileName:fileName] error:&error];
                    NSLog(@"Got Error When Deleting: %@", error);
                }
                NSLog(@"About to delete contribution with ID %@", contribution.contributionId);
                [context deleteObject:contribution];
            }

            //Also deal with title contribution
            Contribution *contribution = event.titleContribution;
            if(contribution){
                NSString *fileName = contribution.imagePath;
                NSLog(@"Deleting file with fileName = %@", fileName);
                if(fileName){
                    //delete file at that file path
                    NSError *error = nil;
                    [manager removeItemAtPath:[self filePathForImageWithFileName:fileName] error:&error];
                    NSLog(@"Got Error When Deleting: %@", error);
                }
                NSLog(@"About to delete contribution with ID %@", contribution.contributionId);
                [context deleteObject:contribution];

                NSLog(@"Deleting Event with ID %@", event.eventId);
                [context deleteObject:event];
            }
        }
    }
    [self saveCoreDataInContext:context];
}

#pragma mark - cell formatters (event and message cell)

-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution{
    NSLog(@"PPLSTDataManager - formatEventCell:%@ ForContribution:%@",cell,contribution);
    //first check to see if the media is already set (or its an image) for this cell. If not, go ahead and download it
    if([contribution.contributionType isEqualToString:@"message"] && contribution.message && ![contribution.message isEqualToString:@""]) return;
    NSLog(@"contributionId = %@, contributionType = %@, imagePath = %@", contribution.contributionId, contribution.contributionType, contribution.imagePath);
    if([contribution.contributionType isEqualToString:@"photo"] && contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
        NSLog(@"it's a photo and the imagePath is not nil, nor is it the empty string");
        UIImage *image = [self getImageWithFileName:contribution.imagePath];
        NSLog(@"Just got the image %@", image);
        if(image){
            NSLog(@"Yay, the image wasn't nil");
            cell.titleImageView.image = [self getImageWithFileName:contribution.imagePath];
            return;
        } else{
            NSLog(@"Darn, the image was nil... let's keep going");
        }
    }
    if([[self.imagesInMemoryForContributionId allKeys] containsObject:contribution.contributionId]){
        cell.titleImageView.image = self.imagesInMemoryForContributionId[contribution.contributionId];
        return;
    }
    
    NSNumber *loading = self.isLoading[contribution.contributionId];
    NSLog(@"loading = %@", loading);
    if([loading isEqualToNumber:@1]){
        NSLog(@"It's loading, let's return");
        return; //wait for first load to complete before initializing a second load.
    }
    NSLog(@"it wasn't loading, so we'll move forward");
    self.isLoading[contribution.contributionId] = @1;
    //add spinner to cell
    cell.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    cell.spinner.center = CGPointMake([UIScreen mainScreen].applicationFrame.size.width/2,[UIScreen mainScreen].applicationFrame.size.width/2);
    [cell addSubview:cell.spinner];
    [cell bringSubviewToFront:cell.spinner];
    [cell.spinner startAnimating];
    NSLog(@"About to dispatch async");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.parentContext = self.context;
        [context performBlock:^{
            NSLog(@"About to download the media for this contribution");
            [self downloadMediaForContribution:contribution inContext:self.context];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isLoading[contribution.contributionId] = @0;
                if(cell.spinner){
                    [cell.spinner stopAnimating];
                    [cell.spinner removeFromSuperview];
                    cell.spinner = nil;
                }
                if(contribution.imagePath){
                    cell.titleImageView.image = [self getImageWithFileName:contribution.imagePath];
                } else{
                    //for some reason the save must have failed. Let's look to memory to see if we can recover it.
                    NSLog(@"The save must have failed. Resorting to looking at the in-memory stuff: %@", self.imagesInMemoryForContributionId);
                    cell.titleImageView.image = self.imagesInMemoryForContributionId[contribution.contributionId];
                }
                [cell.parentTableView reloadData];
            });
        }];
    });
}


-(void) formatJSQMessage:(JSQMessage*)message ForContribution:(Contribution*)contribution inCollectionView:(UITableView *)collectionView{
    NSLog(@"PPLSTDataManager - formatJSQMessage:%@ ForContribution:%@ inCollectionView:%@", message, contribution, collectionView);
    if([contribution.contributionType isEqualToString:@"photo"]){
        if(contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
                JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                mediaItem.image = [self getImageWithFileName:contribution.imagePath];
        } else{
            if([[self.imagesInMemoryForContributionId allKeys] containsObject:contribution.contributionId]){
                JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                mediaItem.image = self.imagesInMemoryForContributionId[contribution.contributionId];
                return;
            }
            NSNumber *loading = self.isLoading[contribution.contributionId];
            if([loading isEqualToNumber:@1]){
                return; //avoid dubble loading while running in background thread
            }
            self.isLoading[contribution.contributionId] = @1;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
                context.parentContext = self.context;
                [context performBlock:^{
                    [self downloadMediaForContribution:contribution inContext:context];
                    //after download is complete, move back to main queue for UI updates
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.isLoading[contribution.contributionId] = @0;
                        JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                        if(contribution.imagePath){
                            mediaItem.image = [self getImageWithFileName:contribution.imagePath];
                        } else{
                            mediaItem.image = self.imagesInMemoryForContributionId[contribution.contributionId];
                        }
                        [collectionView reloadData];
                    });
                }];
            });
        }
    } else if([contribution.contributionType isEqualToString:@"message"]){}
}

#pragma mark - Helper Methods / Private Methods


//retrieves an event object from core data
-(Event *) getEventFromCoreDataWithId:(NSString*) eventId inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - getEventFromCoreDataWithId:%@",eventId);
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Event"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"eventId == %@",eventId];
    NSError *error = nil;
    NSArray *returnedEvents = [context executeFetchRequest:fetchRequest error:&error];
    if([returnedEvents count] == 0){
        NSLog(@"Error: No event found in core data with eventId = %@",eventId);
        return nil;
    }
    return returnedEvents[0];
}

//retreives a contribution object from core data
-(Contribution *) getContributionFromCoreDataWithId:(NSString*)contributionId inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - getContributionFromCoreDataWithId:%@",contributionId);
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Contribution"];
NSLog(@"getContributionFromCoreDataWithId - 1");
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contributionId == %@",contributionId];
NSLog(@"getContributionFromCoreDataWithId - 2");
    NSError *error = nil;
NSLog(@"getContributionFromCoreDataWithId - 3");
    NSArray *returnedContributions = [context executeFetchRequest:fetchRequest error:&error];
NSLog(@"getContributionFromCoreDataWithId - 4");
    if([returnedContributions count] == 0){
        NSLog(@"Error: No contribution found in core data with contributionId = %@",contributionId);
        return nil;
    }
NSLog(@"getContributionFromCoreDataWithId - 5");
    return returnedContributions[0];
}

//just saves the current state to core data
-(void) saveCoreDataInContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - saveCoreData");
    NSError *error = nil;
    if(![context save:&error]){
        NSLog(@"core data save error: %@",error);
    }
}

//creates a new event with a given id
-(Event*) createEventWithId:(NSString*)eventId inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - createEventWithId:%@",eventId);
    Event *event = [NSEntityDescription insertNewObjectForEntityForName:@"Event" inManagedObjectContext:context];
    event.eventId = eventId;
    [self saveCoreDataInContext:context];
    return event;
}


//creates a new contribution with a given id
-(Contribution*) createContributionWithId:(NSString*)contributionId inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - createContributionWithId:%@",contributionId);
    [self.contributionIds addObject:contributionId]; //keep track of which objects are currently being stored
    Contribution *contribution = [NSEntityDescription insertNewObjectForEntityForName:@"Contribution" inManagedObjectContext:context];
    contribution.contributionId = contributionId;
    [self saveCoreDataInContext:context];
    return contribution;
}

//stores an image in the file system and returns the imagePath
-(NSString *) storeImage:(UIImage*)image forContributionId:(NSString*)contributionId{
    NSLog(@"PPLSTDataManager - storeImage:%@",image);
    NSData *imageData = UIImagePNGRepresentation(image);
    NSString *fileName = [self getEmptyFileName];

    if (![imageData writeToFile:[self filePathForImageWithFileName:fileName] atomically:NO]){
        NSLog(@"Failed to cache image data to disk");
        //if the save was unsuccesful, we go ahead and store it in memory at least
        self.imagesInMemoryForContributionId[contributionId] = image;
        fileName = nil;
    }

    return fileName;
}

-(NSString*) filePathForImageWithFileName:(NSString*)fileName{
    NSString *homeDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *fpath = [homeDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",fileName]];
    return fpath;
}

//returns NSString representing a filePath which is guaranteed to be empty
-(NSString*) getEmptyFileName{
    NSLog(@"PPLSTDataManager - getEmptyFileName");
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString *imageName = [self randomStringWithLength:10];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",imageName]];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    while([fileManager fileExistsAtPath:filePath]){
        imageName = [self randomStringWithLength:10];
        filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",imageName]];
    }
    return imageName;
}

//returns a random alphanumeric string of a given length
-(NSString*) randomStringWithLength:(int)length{
    NSLog(@"PPLSTDataManager - randomgStringWithLength:%i",length);
    NSString *allowedCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randString = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [randString appendString:[NSString stringWithFormat:@"%C",[allowedCharacters characterAtIndex:rand()%[allowedCharacters length]]]];
    }
    return randString;
}

/*this method gets the image at the given file path. If it has already been loaded, it gets it from memory, otherwise it loads it into memory. This avoids multiple calls to the filesystem which necessarily slows down the app.*/
-(UIImage*) getImageWithFileName:(NSString*)fileName{
    NSLog(@"PPLSTDataManager - getImageWithFileName:%@",fileName);
    if(![[self.imagesAtFilePath allKeys] containsObject:fileName] || !self.imagesAtFilePath[fileName]){
        NSLog(@"self.imageAtFilePath doesn't already contain the fileName or the filename is nil");
        NSString *filePath = [self filePathForImageWithFileName:fileName];
        NSLog(@"the filePath is %@", filePath);
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSLog(@"the image is %@", image);
        self.imagesAtFilePath[fileName] = image;
    }
    return self.imagesAtFilePath[fileName];
}

//creates a new dummy titleContribution that will only be used locally
-(Contribution *) newDummyTitleContribution{
    NSLog(@"PPLSTDataManager - newDummyTitleContribution");
    NSString *titleContributionId = [NSString stringWithFormat:@"%@%@",@"dummy", [self randomStringWithLength:10]];
    Contribution *titleContribution = [self createContributionWithId:titleContributionId inContext:self.context];
    titleContribution.contributingUserId = self.contributingUserId;
    titleContribution.contributionType = @"photo";
    titleContribution.createdAt = [NSDate date];
    titleContribution.imagePath = nil;
    titleContribution.latitude = nil;
    titleContribution.longitude = nil;
    titleContribution.message = nil;
    return titleContribution;
}

//scales down an image to a new size. Important for compression
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    NSLog(@"PPLSTDataManager - imageWithImage:%@ scaledToSize:(GCSize)newSize",image);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
