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

#pragma mark - Required Methods

-(id) init{
    self = [super init];
    if(self){
        id delegate = [[UIApplication sharedApplication] delegate];
        self.context = [delegate managedObjectContext];
        self.contributingUserId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        [self createAvatarForStatusDictionary];
    }
    return self;
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

-(void) createAvatarForStatusDictionary{
    NSLog(@"PPLSTDataManager - createAvatarForStatusDictionary");
    NSMutableArray *avatarRawImages = [[NSMutableArray alloc] init];
    //TODO: add more avatars
    [avatarRawImages addObject:[UIImage imageNamed:@"gold.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"salmon.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"lightBlue.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"darkGreen.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"darkBlue.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"grey.jpg"]];
    int status = 0;
    for(UIImage *avatarRawImage in avatarRawImages){
        JSQMessagesAvatarImage *avatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:avatarRawImage diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
        [self.avatarForStatus setObject:avatarImage forKey:[NSNumber numberWithInt:status]];
        status++;
    }
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
    [newEvent setObject:[dateFormatter dateFromString:@"1-1-2101"] forKey:@"validUntil"]; //TODO: do I need to allocate memory for this?
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
        Event *currentEvent = [self createEventWithId:eventId];
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

        [self saveCoreData];
        
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

        Event *event = [self getEventFromCoreDataWithId:eventId];
        if(!event) event = [self createEventWithId:eventId];
        
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

            Contribution *titleContribution = [self getContributionFromCoreDataWithId:titleContributionId];
            if(!titleContribution){
                titleContribution = [self createContributionWithId:titleContributionId];
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
        
    [self saveCoreData];
    return events;
}


-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event{
    NSLog(@"PPLSTDataManager - downloadContributionMetaDataForEvent:%@",event);
    NSDictionary *result = [PFCloud callFunction:@"getContributionIdsInCluster" withParameters:@{@"clusterId" : event.eventId}];
    NSArray *arrayOfContributionData = result[@"contributionIds"];
    NSMutableArray *contributions = [[NSMutableArray alloc] init];
    for(NSDictionary *contributionData in arrayOfContributionData){
        NSString *contributionId = contributionData[@"contributionId"];
        Contribution *newContribution = [self getContributionFromCoreDataWithId:contributionId];
        if(!newContribution) newContribution = [self createContributionWithId:contributionId];

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

    [self saveCoreData];
    
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedArray;
    sortedArray = [contributions sortedArrayUsingDescriptors:sortDescriptors];
    return sortedArray;
}


//by now, there should already exist a contribution object in core data. Here we just update the object.
-(Contribution*) downloadMediaForContribution:(Contribution*)contribution{
    NSLog(@"PPLSTDataManager - downloadMediaForContribution:%@",contribution);
    if([[contribution.contributionId substringToIndex:5] isEqualToString:@"dummy"]){
        //TODO: perhaps change this to different images for different events? Maybe create images on the fly with some text indicating their location?
        contribution.imagePath = [self storeImage:[UIImage imageNamed:@"Populist-60@2x.png"]];
    } else if ([contribution.contributionType isEqualToString:@"message"]) {
        //TODO: we might have to download messages that are too long for a push notification
        NSLog(@"A");
    } else if([contribution.contributionType isEqualToString:@"photo"]){
        NSLog(@"B");
        NSLog(@"Querying Parse for image for contribution with id = %@", contribution.contributionId);

        PFQuery *query = [PFQuery queryWithClassName:@"Contribution"];
        PFObject *parsePhoto = [query getObjectWithId:contribution.contributionId];
        PFFile *file = [parsePhoto objectForKey:@"image"];
        NSData *parseImageData = [file getData];
        NSLog(@"Got data with length: %lu for contributionId = %@ in file %@", [parseImageData length], contribution.contributionId, file);
        UIImage *image = [UIImage imageWithData:parseImageData];
        contribution.imagePath = [self storeImage:image];
        NSLog(@"just set the imagePath = %@ for contributionId = %@ and contribution = %@", contribution.imagePath, contribution.contributionId, contribution);
        contribution.contributingUserId = [parsePhoto objectForKey:@"userId"];
        contribution.createdAt = [parsePhoto objectForKey:@"createdAt"];
        NSLog(@"Stored it in imagePath = %@", contribution.imagePath);
    }
    NSLog(@"C");
    
    [self saveCoreData];
    
    return contribution;
}


-(Contribution *) uploadContributionWithData:(NSDictionary*)contributionDictionary andPhoto:(UIImage*)photo{
    NSLog(@"PPLSTDataManager - uploadContributionWithData:%@ andPhoto%@",contributionDictionary, photo);
    Contribution *newContribution = [self createContributionWithId:[NSString stringWithFormat:@"tmpId%i",rand()]];

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
        event = [self getEventFromCoreDataWithId:contributionDictionary[@"eventId"]];
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

-(void) uploadAndSaveContributionInBackground:(Contribution*) contribution{
    NSLog(@"PPLSTDataManager - uploadAndSaveContributionInBackground:%@",contribution);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        PFObject *parseContribution = [PFObject objectWithClassName:@"Contribution"];
        if([contribution.contributionType isEqualToString:@"message"]){
            [parseContribution setObject:@"message" forKey:@"type"];
            [parseContribution setObject:contribution.message forKey:@"message"];
        } else if([contribution.contributionType isEqualToString:@"photo"]){
            [parseContribution setObject:@"photo" forKey:@"type"];
            
            //Note: compression of 1.0 -> size in the 300-400kb range. 0.5 -> 30-40kb, and 0.0 -> 10-20 kb. Original image -> 1.5 Mb.
            NSData *imageData = UIImageJPEGRepresentation([self getImageAtFilePath:contribution.imagePath], 0.5f);
            PFFile *imageFile = [PFFile fileWithName:@"image.jpg" data:imageData];
            [imageFile saveInBackground];
            [parseContribution setObject:imageFile forKey:@"image"];
        }
        [parseContribution setObject:contribution.contributingUserId forKey:@"userId"];
        [parseContribution setObject:[[NSArray alloc] init] forKey:@"flaggedBy"];
        [parseContribution setObject:[PFGeoPoint geoPointWithLatitude:[contribution.latitude doubleValue] longitude:[contribution.longitude doubleValue]] forKey:@"location"];
        [parseContribution setObject:contribution.event.eventId forKey:@"promise"];

        [parseContribution saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            //get the object id and reassign it locally
            NSString *objectId = [parseContribution valueForKeyPath:@"objectId"];
            contribution.contributionId = objectId;
            [self saveCoreData]; //TODO: does this screw things up because it's in a different thread as far as the ManagedObjectContext goes?
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

#pragma mark - Local Data API

-(JSQMessagesAvatarImage *)avatarForStatus:(NSNumber *)status{
    NSLog(@"PPLSTDataManager - avatarForStatus:%@",status);
    return self.avatarForStatus[status];
}

-(void) increaseImportanceOfEvent:(Event*)event By:(float)amount{
    NSLog(@"PPLSTDataManager - increaseImportanceOfEvent:%@ By:%f",event,amount);
    float oldImportance = [event.importance floatValue];
    event.importance = [NSNumber numberWithFloat:(oldImportance + amount)];
    float newImportance = [event.importance floatValue];
    [self saveCoreData];
    
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
    //TODO: make sure this asynch call is correct (i.e. uses the correct queues etc.)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        [self downloadMediaForContribution:contribution];
        //after download is complete, move back to main queue for UI updates
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading[contribution.contributionId] = @0;
            cell.titleImageView.image = [self getImageAtFilePath:contribution.imagePath];
            [cell.parentTableView reloadData];
        });
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
                NSLog(@"imagePath = %@", contribution.imagePath);
                [self downloadMediaForContribution:contribution];
                NSLog(@"now, imagePath = %@", contribution.imagePath);
                //after download is complete, move back to main queue for UI updates
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"async loading is complete, and we're back in the main queue");
                    self.isLoading[contribution.contributionId] = @0;
                    JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                    mediaItem.image = [self getImageAtFilePath:contribution.imagePath];
                    [collectionView reloadData];
                });
            });
        }
    }
}

#pragma mark - Helper Methods / Private Methods


//retrieves an event object from core data
-(Event *) getEventFromCoreDataWithId:(NSString*) eventId{
    NSLog(@"PPLSTDataManager - getEventFromCoreDataWithId:%@",eventId);
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Event"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"eventId == %@",eventId];
    NSError *error = nil;
    NSArray *returnedEvents = [self.context executeFetchRequest:fetchRequest error:&error];
    NSLog(@"Found %lu events in coredata with eventId = %@", [returnedEvents count], eventId);
    if([returnedEvents count] == 0){
        NSLog(@"Error: No event found in core data with eventId = %@",eventId);
        return nil;
    }
    return returnedEvents[0];
}

//retreives a contribution object from core data
-(Contribution *) getContributionFromCoreDataWithId:(NSString*)contributionId{
    NSLog(@"PPLSTDataManager - getContributionFromCoreDataWithId:%@",contributionId);
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Contribution"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contributionId == %@",contributionId];
    NSError *error = nil;
    NSArray *returnedContributions = [self.context executeFetchRequest:fetchRequest error:&error];
    NSLog(@"Found %lu contributions in core data with ContributionId = %@", [returnedContributions count], contributionId);
    if([returnedContributions count] == 0){
        NSLog(@"Error: No contribution found in core data with contributionId = %@",contributionId);
        return nil;
    }
    return returnedContributions[0];
}

//just saves the current state to core data
-(void) saveCoreData{
    NSLog(@"PPLSTDataManager - saveCoreData");
    NSError *error = nil;
    if(![self.context save:&error]){
        NSLog(@"error: %@",error);
    }
    NSLog(@"Saved Core Data!");
}

//creates a new event with a given id
-(Event*) createEventWithId:(NSString*)eventId{
    NSLog(@"PPLSTDataManager - createEventWithId:%@",eventId);
    Event *event = [NSEntityDescription insertNewObjectForEntityForName:@"Event" inManagedObjectContext:self.context];
    event.eventId = eventId;
    [self saveCoreData];
    return event;
}


//creates a new contribution with a given id
-(Contribution*) createContributionWithId:(NSString*)contributionId{
    NSLog(@"PPLSTDataManager - createContributionWithId:%@",contributionId);
    [self.contributionIds addObject:contributionId]; //keep track of which objects are currently being stored
    Contribution *contribution = [NSEntityDescription insertNewObjectForEntityForName:@"Contribution" inManagedObjectContext:self.context];
    contribution.contributionId = contributionId;
    [self saveCoreData];
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
    Contribution *titleContribution = [self createContributionWithId:titleContributionId];
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
