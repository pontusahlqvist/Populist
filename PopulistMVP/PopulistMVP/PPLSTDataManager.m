//
//  PPLSTDataManager.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/5/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTDataManager.h"
#import <Parse/Parse.h>


@implementation PPLSTDataManager

int maxMessageLengthForPush = 250;

#pragma mark - Required Methods

-(id) init{
    self = [super init];
    if(self){
        id delegate = [[UIApplication sharedApplication] delegate];
        self.context = [delegate managedObjectContext];
        //setup a listener to see if other contexts on other threads have been saved
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextHasChanged:) name:NSManagedObjectContextDidSaveNotification object:nil];
        self.contributingUserId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
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

-(NSMutableDictionary *)imagesAtFilePath{
    if(!_imagesAtFilePath) _imagesAtFilePath = [[NSMutableDictionary alloc] init];
    return _imagesAtFilePath;
}

-(NSMutableDictionary *)isLoading {
    if(!_isLoading) _isLoading = [[NSMutableDictionary alloc] init];
    return _isLoading;
}

-(NSMutableDictionary *)avatarForStatus{
    if(!_avatarForStatus) _avatarForStatus = [[NSMutableDictionary alloc] init];
    return _avatarForStatus;
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
    NSMutableArray *avatarRawImages = [[NSMutableArray alloc] init];

    [avatarRawImages addObject:[UIImage imageNamed:@"gold.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"salmon.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"lightBlue.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"darkGreen.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"lightGreen.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"purple.png"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"red.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"black.png"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"orange.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"grey.jpg"]];
    
    UIImage *greyBackground = [UIImage imageNamed:@"grey.jpg"];
    NSArray *firstLetter = [NSArray arrayWithObjects: @"", @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
    NSArray *secondLetter = [NSArray arrayWithObjects: @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
    for(int i = 0; i < [firstLetter count]; i++){
        for(int j = 0; j < [secondLetter count]; j++){
            [avatarRawImages addObject:[self drawText:[NSString stringWithFormat:@"%@%@",firstLetter[i],secondLetter[j]] atCenterOfImage:greyBackground]];
        }
    }

    int status = 0;
    for(UIImage *avatarRawImage in avatarRawImages){
        JSQMessagesAvatarImage *avatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:avatarRawImage diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
        [self.avatarForStatus setObject:avatarImage forKey:[NSNumber numberWithInt:status]];
        status++;
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
        NSLog(@"already contains user");
        self.currentEvent = firstEvent;
        return eventsFromCloud;
    } else{
        NSLog(@"doesn't already contain the user so we create a new one...");
        PFObject *newEvent = [self sendSignalWithLatitude:latitude andLongitude:longitude andDate:date];
        NSString *eventId = newEvent.objectId;
        NSLog(@"about to create core data event with id = %@", eventId);
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
        event.containsUser = [NSNumber numberWithBool:[eventDictionary[@"containsUser"] boolValue]];
        event.country = eventDictionary[@"country"];
        event.importance = eventDictionary[@"importance"];
        event.lastActive = eventDictionary[@"updatedAt"];
        event.latitude = eventDictionary[@"latitude"];
        event.longitude = eventDictionary[@"longitude"];
        event.neighborhood = eventDictionary[@"neighborhood"];
        event.state = eventDictionary[@"state"];
        
        //TODO: fix this by only sending along the titleContributionId for the image, i.e. get rid of titleMessages all together
        NSString *titleContributionId = nil;
        for(NSDictionary *titleContributionDictionary in eventDictionary[@"titleContributionIds"]){
            NSString *key = [[titleContributionDictionary allKeys] firstObject];
            if([titleContributionDictionary[key] isEqualToString:@"photo"]){
                titleContributionId = key;
                break;
            }
        }
        if(![titleContributionId isEqualToString:event.titleContribution.contributionId] && (titleContributionId || !event.titleContribution)){
            if (!titleContributionId) {
                titleContributionId = event.titleContribution.contributionId;
                if(!titleContributionId){
                    //must create a dummy titleContribution. Note, this one should not be added to contributions
                    NSLog(@"ERROR: none of the titleContributions were images!! We're creating a dummy titleContribution as a placeholder for now");
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
    return events;
}


-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - downloadContributionMetaDataForEvent:%@",event);
    NSDictionary *result = [PFCloud callFunction:@"getContributionIdsInCluster" withParameters:@{@"clusterId" : event.eventId}];
    NSArray *arrayOfContributionData = result[@"contributionIds"];
    NSMutableArray *contributions = [[NSMutableArray alloc] init];
    for(NSDictionary *contributionData in arrayOfContributionData){
        NSString *contributionId = contributionData[@"contributionId"];
        Contribution *newContribution = [self getContributionFromCoreDataWithId:contributionId inContext:self.context];
        if(!newContribution) newContribution = [self createContributionWithId:contributionId inContext:self.context];

        newContribution.contributingUserId = contributionData[@"userId"];
        newContribution.contributionType = contributionData[@"type"];
        newContribution.createdAt = contributionData[@"createdAt"];
        newContribution.imagePath = nil;
        newContribution.latitude = nil;
        newContribution.longitude = nil;
        newContribution.message = nil;
        
        [event addContributionsObject:newContribution];
        if([newContribution.contributionType isEqualToString:@"message"]){
            newContribution.message = contributionData[@"message"];
        }

        [contributions addObject:newContribution];
    }

    [self saveCoreDataInContext:context];
    
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
        contribution.imagePath = [self storeImage:[UIImage imageNamed:@"Populist-60@2x.png"]];
    } else if ([contribution.contributionType isEqualToString:@"message"]) {
        NSLog(@"A");
        PFQuery *query = [PFQuery queryWithClassName:@"Contribution"];
        PFObject *parseContribution = [query getObjectWithId:contribution.contributionId];
        NSString *message = [parseContribution objectForKey:@"message"];
        contribution.message = message;
        contribution.contributingUserId = [parseContribution objectForKey:@"userId"];
        contribution.createdAt = parseContribution.createdAt;
    } else if([contribution.contributionType isEqualToString:@"photo"]){
        NSLog(@"B");
        NSLog(@"Querying Parse for image for contribution with id = %@", contribution.contributionId);

        PFQuery *query = [PFQuery queryWithClassName:@"Contribution"];
        PFObject *parsePhoto = [query getObjectWithId:contribution.contributionId];
        NSLog(@"photo - parseContribution = %@", parsePhoto);
        PFFile *file = [parsePhoto objectForKey:@"image"];
        NSData *parseImageData = [file getData];
        NSLog(@"Got data with length: %lu for contributionId = %@ in file %@", [parseImageData length], contribution.contributionId, file);
        UIImage *image = [UIImage imageWithData:parseImageData];
        contribution.imagePath = [self storeImage:image];
        NSLog(@"just set the imagePath = %@ for contributionId = %@ and contribution = %@", contribution.imagePath, contribution.contributionId, contribution);
        contribution.contributingUserId = [parsePhoto objectForKey:@"userId"];
        contribution.createdAt = contribution.createdAt;//[parsePhoto objectForKey:@"createdAt"];
        NSLog(@"Stored it in imagePath = %@", contribution.imagePath);
    }
    NSLog(@"C");
    
    [self saveCoreDataInContext:context];
    
    return contribution;
}


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
        //TODO: make the resizing better - this is intended to save space / memory
        newContribution.imagePath = [self storeImage:[self imageWithImage:photo scaledToSize:CGSizeMake(320.0, 320.0)]];
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
    }
    
    [self uploadAndSaveContributionInBackground:newContribution];
    [self.delegate didUpdateLastActiveForEvent:event];
    
    return newContribution;
}

//TODO: this method takes in a contribution object and then modifies it in another queue. This may pose a problem with Core Data. What should you do? Copy the object over?
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
            NSData *imageData = UIImageJPEGRepresentation([self getImageAtFilePath:imagePath], 0.5f);
            PFFile *imageFile = [PFFile fileWithName:@"image.jpg" data:imageData];
            [imageFile saveInBackground];
            [parseContribution setObject:imageFile forKey:@"image"];
        }
        [parseContribution setObject:contributingUserId forKey:@"userId"];
        [parseContribution setObject:[[NSArray alloc] init] forKey:@"flaggedBy"];
        [parseContribution setObject:[PFGeoPoint geoPointWithLatitude:[latitude doubleValue] longitude:[longitude doubleValue]] forKey:@"location"];
        [parseContribution setObject:eventId forKey:@"promise"];

        [parseContribution saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            //we return to the main queue since we're modifying an NSManagedObject subclass (contribution) which was originally definied in the main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                //get the object id and reassign it locally
                NSString *objectId = [parseContribution valueForKeyPath:@"objectId"];
                contribution.contributionId = objectId;
                NSLog(@"just found out that the objectId = %@", objectId);
                NSLog(@"before - self.contributionIds = %@", self.contributionIds);
                [self.contributionIds addObject:objectId]; //TODO: we'll end up with a lot of temporary Ids here since we add to it already in the creation process..
                NSLog(@"after - self.contributionIds = %@", self.contributionIds);
                //send push notification
                NSMutableDictionary *pushData = [[NSMutableDictionary alloc] init];
                pushData[@"alert"] = @"New stuff at your event!";
                pushData[@"c"] = objectId;
                pushData[@"t"] = contribution.contributionType;
                pushData[@"u"] = contribution.contributingUserId;
                pushData[@"e"] = contribution.event.eventId;
                if([contribution.contributionType isEqualToString:@"message"]){
                    if ([contribution.message length] <= maxMessageLengthForPush) {
                        pushData[@"m"] = contribution.message; //TODO: what if message is too long?
                    } else{
                        pushData[@"m"] = @""; //send the empty string along, and let the other user download the data from the server
                    }
                }
                PFPush *pushNotification = [[PFPush alloc] init];
                [pushNotification setChannels:@[[NSString stringWithFormat:@"event%@",contribution.event.eventId]]];
                [pushNotification setData:pushData];
                [pushNotification expireAfterTimeInterval:5];//expires after 5 sec
                [pushNotification sendPushInBackground];
                
                [self saveCoreDataInContext:self.context]; //TODO: does this screw things up because it's in a different thread as far as the ManagedObjectContext goes?
            });
        }];
    });
}

-(NSMutableDictionary *)getStatusDictionaryForEvent:(Event *)event{
    NSLog(@"PPLSTDataManager - getStatusDictionaryForEvent:%@",event);
    //TODO: replace with parse code. Must make sure that avatars are consistent across users!
    NSSet *contributions = event.contributions;

    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedContributions = [contributions sortedArrayUsingDescriptors:sortDescriptors];
    
    NSMutableArray *userIds = [[NSMutableArray alloc] init];
    for(Contribution *contribution in sortedContributions){
        if(![userIds containsObject:contribution.contributingUserId]){
            [userIds addObject:contribution.contributingUserId];
        }
    }
    NSMutableDictionary *statusDictionary = [[NSMutableDictionary alloc] init];
    int status = 0;
    for(NSString *contributionId in userIds){
        statusDictionary[contributionId] = [NSNumber numberWithInt:status];
        status++;
    }
    NSLog(@"StatusDictionary = %@", statusDictionary);
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
        NSLog(@"it did not contain the id:%@ so we're adding it now...", contributionId);
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
            newIncomingContribution.message = data[@"m"]; //TODO: include this!
        }
        Event *eventToWhichThisContributionBelongs = [self getEventFromCoreDataWithId:data[@"e"] inContext:self.context];
        newIncomingContribution.event = eventToWhichThisContributionBelongs;
        Event *eventForIncomingContribution = [self getEventFromCoreDataWithId:data[@"e"] inContext:self.context];
        [self.pushDelegate didAddIncomingContribution:newIncomingContribution ForEvent:eventForIncomingContribution];
        eventToWhichThisContributionBelongs.lastActive = newIncomingContribution.createdAt;
        [self.delegate didUpdateLastActiveForEvent:eventForIncomingContribution];
        if([data[@"t"] isEqualToString:@"photo"]){
            eventForIncomingContribution.titleContribution = newIncomingContribution;
            [self.delegate didUpdateTitleContributionForEvent:eventForIncomingContribution];
        }
    }
}

#pragma mark - Local Data API

-(JSQMessagesAvatarImage *)avatarForStatus:(NSNumber *)status{
    NSLog(@"PPLSTDataManager - avatarForStatus:%@",status);
    if([status integerValue] >= [self.avatarForStatus count] - 1){
        return self.avatarForStatus[[NSNumber numberWithInteger:[self.avatarForStatus count] - 1 ]];
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

#pragma mark - cell formatters (event and message cell)

-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution{
    NSLog(@"PPLSTDataManager - formatEventCell:%@ ForContribution:%@",cell,contribution);
    //first check to see if the media is already set (or its an image) for this cell. If not, go ahead and download it
    if([contribution.contributionType isEqualToString:@"message"] && contribution.message && ![contribution.message isEqualToString:@""]) return;
    NSLog(@"contributionId = %@, contributionType = %@, imagePath = %@", contribution.contributionId, contribution.contributionType, contribution.imagePath);
    if([contribution.contributionType isEqualToString:@"photo"] && contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
        cell.titleImageView.image = [self getImageAtFilePath:contribution.imagePath];
    }
    NSNumber *loading = self.isLoading[contribution.contributionId];
    if([loading isEqualToNumber:@1]){
        return; //wait for first load to complete before initializing a second load.
    }
    self.isLoading[contribution.contributionId] = @1;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.parentContext = self.context;
        [context performBlock:^{
            [self downloadMediaForContribution:contribution inContext:self.context];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isLoading[contribution.contributionId] = @0;
                cell.titleImageView.image = [self getImageAtFilePath:contribution.imagePath];
                [cell.parentTableView reloadData];
            });
        }];
    });
}


-(void) formatJSQMessage:(JSQMessage*)message ForContribution:(Contribution*)contribution inCollectionView:(UITableView *)collectionView{
    NSLog(@"PPLSTDataManager - formatJSQMessage:%@ ForContribution:%@ inCollectionView:%@", message, contribution, collectionView);
    if([contribution.contributionType isEqualToString:@"photo"]){
        NSLog(@"it's a photo");
        if(contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
                NSLog(@"imagepath != nil && imagePath != empty string");
                JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                mediaItem.image = [self getImageAtFilePath:contribution.imagePath];
        } else{
            NSLog(@"either nil or empty");
            NSNumber *loading = self.isLoading[contribution.contributionId];
            if([loading isEqualToNumber:@1]){
                NSLog(@"avoiding double loading, %@", self.isLoading[contribution.contributionId]);
                return; //avoid dubble loading while running in background thread
            }
            self.isLoading[contribution.contributionId] = @1;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
                context.parentContext = self.context;
                [context performBlock:^{
                    NSLog(@"imagePath = %@", contribution.imagePath);
                    [self downloadMediaForContribution:contribution inContext:self.context]; //TODO: shouldn't this be context?
                    NSLog(@"now, imagePath = %@", contribution.imagePath);
                    //after download is complete, move back to main queue for UI updates
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"async loading is complete, and we're back in the main queue");
                        self.isLoading[contribution.contributionId] = @0;
                        JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                        mediaItem.image = [self getImageAtFilePath:contribution.imagePath];
                        [collectionView reloadData];
                    });
                }];
            });
        }
    } else if([contribution.contributionType isEqualToString:@"message"]){
        //TODO: note that the message should have already been downloaded if it was too long in the chatVC's createMessagesFromContributions
//        NSLog(@"inside jsqformat with message");
//        //TODO: check if the message is set. If not, we must download it from parse.
//        if(!contribution.message || [contribution.message isEqualToString:@""]){
//            NSLog(@"message is nil or empty");
//            NSNumber *loading = self.isLoading[contribution.contributionId];
//            if([loading isEqualToNumber:@1]){
//                NSLog(@"avoiding double loading, %@", self.isLoading[contribution.contributionId]);
//                return; //avoid dubble loading while running in background thread
//            }
//            self.isLoading[contribution.contributionId] = @1;
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
//            ^{
//                NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
//                context.parentContext = self.context;
//                [context performBlock:^{
//                    [self downloadMediaForContribution:contribution inContext:self.context]; //TODO: shouldn't this be context?
//                    //after download is complete, move back to main queue for UI updates
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        NSLog(@"async loading is complete, and we're back in the main queue");
//                        self.isLoading[contribution.contributionId] = @0;
//                        NSString *messageText = message.text;
//                        
//
//                    
//
//                        [collectionView reloadData];
//                    });
//                }];
//            });
//
//        }
    }
}

#pragma mark - Helper Methods / Private Methods


//retrieves an event object from core data
-(Event *) getEventFromCoreDataWithId:(NSString*) eventId inContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - getEventFromCoreDataWithId:%@",eventId);
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Event"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"eventId == %@",eventId];
    NSError *error = nil;
    NSArray *returnedEvents = [context executeFetchRequest:fetchRequest error:&error];
    NSLog(@"Found %lu events in coredata with eventId = %@", [returnedEvents count], eventId);
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
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contributionId == %@",contributionId];
    NSError *error = nil;
    NSArray *returnedContributions = [context executeFetchRequest:fetchRequest error:&error];
    NSLog(@"Found %lu contributions in core data with ContributionId = %@", [returnedContributions count], contributionId);
    if([returnedContributions count] == 0){
        NSLog(@"Error: No contribution found in core data with contributionId = %@",contributionId);
        return nil;
    }
    return returnedContributions[0];
}

//just saves the current state to core data
-(void) saveCoreDataInContext:(NSManagedObjectContext*)context{
    NSLog(@"PPLSTDataManager - saveCoreData");
    NSError *error = nil;
    if(![context save:&error]){
        NSLog(@"core data save error: %@",error);
    }
    NSLog(@"Saved Core Data!");
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
-(NSString *) storeImage:(UIImage*)image{
    NSLog(@"PPLSTDataManager - storeImage:%@",image);
    NSData *imageData = UIImagePNGRepresentation(image);
    NSString *imagePath = [self getEmptyFilePath];
    if (![imageData writeToFile:imagePath atomically:NO]){
        NSLog(@"Failed to cache image data to disk");
    } else{
        NSLog(@"the cachedImagedPath is %@",imagePath);
    }
    return imagePath;
}

//returns NSString representing a filePath which is guaranteed to be empty
-(NSString*) getEmptyFilePath{
    NSLog(@"PPLSTDataManager - getEmptyFilePath");
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
    NSLog(@"PPLSTDataManager - randomgStringWithLength:%i",length);
    NSString *allowedCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randString = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [randString appendString:[NSString stringWithFormat:@"%C",[allowedCharacters characterAtIndex:rand()%[allowedCharacters length]]]];
    }
    return randString;
}

/*this method gets the image at the given file path. If it has already been loaded, it gets it from memory, otherwise it loads it into memory. This avoids multiple calls to the filesystem which necessarily slows down the app.*/
-(UIImage*) getImageAtFilePath:(NSString*)filePath{
    NSLog(@"PPLSTDataManager - getImageAtFilePath:%@",filePath);
    NSLog(@"inside getImageAtFilePath");
    if(![[self.imagesAtFilePath allKeys] containsObject:filePath]){
        NSLog(@"getting image from filePath = %@ and storing it into memory", filePath);
        self.imagesAtFilePath[filePath] = [UIImage imageWithContentsOfFile:filePath];
    }
    return self.imagesAtFilePath[filePath];
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
