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

#pragma mark - Setup / Instantiation Methods

//-(void) setupLocationMananger{
//    self.isUpdatingLocation = NO;
//    self.locationManager = [[CLLocationManager alloc] init];
//    [self.locationManager requestWhenInUseAuthorization];
//    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
//    self.locationManager.delegate = self;
//}

-(NSMutableDictionary *)imagesAtFilePath{
    if(!_imagesAtFilePath) _imagesAtFilePath = [[NSMutableDictionary alloc] init];
    return _imagesAtFilePath;
}

-(NSMutableDictionary *)isLoading {
    if(!_isLoading) _isLoading = [[NSMutableDictionary alloc] init];
    return _isLoading;
}

-(CLLocationManager *)locationManager{
    if(!_locationManager) _locationManager = [[CLLocationManager alloc] init];
    return _locationManager;
}

-(CLLocation *)currentLocation{
    if(!_currentLocation) _currentLocation = [[CLLocation alloc] init];
    return _currentLocation;
}

-(NSMutableDictionary *)avatarForStatus{
    if(!_avatarForStatus) _avatarForStatus = [[NSMutableDictionary alloc] init];
    return _avatarForStatus;
}

-(void) createAvatarForStatusDictionary{
    NSMutableArray *avatarRawImages = [[NSMutableArray alloc] init];
    //TODO: add real avatar images (diamond, gold, ....)
    [avatarRawImages addObject:[UIImage imageNamed:@"gold.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"salmon.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"darkGreen.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"lightBlue.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"darkBlue.jpg"]];
    [avatarRawImages addObject:[UIImage imageNamed:@"grey.jpg"]];
    int status = 0;
    for(UIImage *avatarRawImage in avatarRawImages){
        JSQMessagesAvatarImage *avatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:avatarRawImage diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
        [self.avatarForStatus setObject:avatarImage forKey:[NSNumber numberWithInt:status]];
        NSLog(@"Just set the avatar %@ for status %i", avatarImage, status);
        status++;
    }
}

-(id) init{
    self = [super init];
    if(self){
        id delegate = [[UIApplication sharedApplication] delegate];
        self.context = [delegate managedObjectContext];
        [self createAvatarForStatusDictionary];
//        [self setupLocationMananger];
    }
    return self;
}

//#pragma mark - CLLocationManager Delegate methods
//
//-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
//    if(!self.isUpdatingLocation) return; //makes sure that we only update the location once per update cycle.
//    
//    CLLocation *newLocation = [locations lastObject];
//    NSLog(@"locationManager didUpdateLocation lastObject = %@", newLocation);
//    if([[NSDate date] timeIntervalSinceDate:newLocation.timestamp] < 10){ //if the new location is newer than 10s old, we're done.
//        [self.locationManager stopUpdatingLocation];
//        self.isUpdatingLocation = NO;
//        self.currentLocation = newLocation;
//        [self.delegate locationUpdatedTo:newLocation];
//    }
//    
//}
//
//-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
//    NSLog(@"locationManager didFailWithError: %@", error);
//}
//
//-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
//    //TODO: make sure that this works properly, i.e. that we're checking for all correct acceptance codes
//    NSLog(@"locationManager didChangeAuthorizationStatus to status = %i", status);
//    if(status == 4){
//        [self.delegate didAcceptAuthorization];
//    } else if(status != 0){
//        [self.delegate didDeclineAuthorization];
//    }
//}

#pragma mark - Public API

//-(void) updateLocation{
//    [self.locationManager startUpdatingLocation];
//    self.isUpdatingLocation = YES;
//}
//
//-(CLLocation *)getCurrentLocation{
//    //TODO: fix this! It's not certain that this actually gives the current location of the user
//    return self.currentLocation;
//}

-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date{

    NSDictionary *result = [PFCloud  callFunction:@"getClusters" withParameters:@{@"latitude": [NSNumber numberWithFloat:latitude], @"longitude": [NSNumber numberWithFloat:longitude]}];
    NSArray *eventDataArray = result[@"customClusterObjects"];


    NSMutableArray *events = [[NSMutableArray alloc] init];
    for(NSDictionary *eventDictionary in eventDataArray){

        NSString *eventId = eventDictionary[@"objectId"];

        Event *event = [self getEventFromCoreDataWithId:eventId];
        if(!event) event = [self createEventWithId:eventId];
        
        event.containsUser = [NSNumber numberWithBool:[eventDictionary[@"containsUser"] boolValue]];
        event.longitude = eventDictionary[@"longitude"];
        event.latitude = eventDictionary[@"latitude"];
        event.lastActive = eventDictionary[@"updatedAt"];
        event.country = eventDictionary[@"country"];
        event.state = eventDictionary[@"state"];
        event.city = eventDictionary[@"city"];
        event.neighborhood = eventDictionary[@"neighborhood"];
        
        //TODO: fix this by only sending along the titleContributionId for the image, i.e. get rid of titleMessages all together
        NSString *titleContributionId = nil;
        for(NSDictionary *titleContributionDictionary in eventDictionary[@"titleContributionIds"]){
            NSString *key = [[titleContributionDictionary allKeys] firstObject];
            if([titleContributionDictionary[key] isEqualToString:@"photo"]){
                titleContributionId = key;
                break;
            }
        }
        NSLog(@"EventId = %@", eventId);
        NSLog(@"**************************titleContributionId = %@", titleContributionId);
        if (!titleContributionId) {
            NSLog(@"ERROR: none of the titleContributions were images!!");
        }
        
        NSLog(@"titleContributionIds = %@", titleContributionId);
        Contribution *titleContribution = [self getContributionFromCoreDataWithId:titleContributionId];
        if(!titleContribution) titleContribution = [self createContributionWithId:titleContributionId];
        
        //TODO: Fix this setup the basic info for this contribution
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
        
    [self saveCoreData];
    return events;
}


-(NSArray*) downloadContributionMetaDataForEvent:(Event*)event{
    NSDictionary *result = [PFCloud callFunction:@"getContributionIdsInCluster" withParameters:@{@"clusterId" : event.eventId}];
    NSArray *arrayOfContributionData = result[@"contributionIds"];
    NSMutableArray *contributions = [[NSMutableArray alloc] init];
    for(NSDictionary *contributionData in arrayOfContributionData){
        NSString *contributionId = contributionData[@"contributionId"];
        Contribution *newContribution = [self getContributionFromCoreDataWithId:contributionId];
        if(!newContribution) newContribution = [self createContributionWithId:contributionId];
        newContribution.contributingUserId = contributionData[@"userId"];
        newContribution.contributionType = contributionData[@"type"];
        [event addContributionsObject:newContribution];
        if([newContribution.contributionType isEqualToString:@"message"]){
            newContribution.message = contributionData[@"message"];
        }
        newContribution.createdAt = contributionData[@"createdAt"];
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
    NSLog(@"++++++++++++++++++++++++DOWNLOADING MEDIA FOR CONTRIBUTIONID = %@", contribution.contributionId);
    /************* GET FROM CORE DATA ******************/

    //TODO: check to see if this contribution already has its data set. In that case, don't query parse
    //TODO: filler code. Replace with correct parse code
    NSLog(@"About to start");
    if ([contribution.contributionType isEqualToString:@"message"]) {
        NSLog(@"A");
        contribution.message = [NSString stringWithFormat:@"message for %@",contribution.contributionId];
    } else if([contribution.contributionType isEqualToString:@"photo"]){
        NSLog(@"B");
        NSLog(@"Querying Parse for image for contribution with id = %@", contribution.contributionId);
        //TODO: replace with parse code
        PFQuery *query = [PFQuery queryWithClassName:@"Contribution"];
        PFObject *parsePhoto = [query getObjectWithId:contribution.contributionId];
        PFFile *file = [parsePhoto objectForKey:@"image"];
        NSData *parseImageData = [file getData];
        NSLog(@"Got data with length: %lu for contributionId = %@ in file %@", [parseImageData length], contribution.contributionId, file);
        UIImage *image = [UIImage imageWithData:parseImageData];
        contribution.imagePath = [self storeImage:image];
        contribution.contributingUserId = [parsePhoto objectForKey:@"userId"];
        contribution.createdAt = [parsePhoto objectForKey:@"createdAt"];
        NSLog(@"Stored it in imagePath = %@", contribution.imagePath);
    }
    NSLog(@"C");
    
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

-(NSMutableDictionary *)getStatusDictionaryForEvent:(Event *)event{
    //TODO: replace with parse code
    NSSet *contributions = event.contributions;
    NSMutableSet *contributionIds = [[NSMutableSet alloc] init];
    for(Contribution *contribution in contributions){
        [contributionIds addObject:contribution.contributingUserId];
    }
    NSMutableDictionary *statusDictionary = [[NSMutableDictionary alloc] init];
    int status = 0;
    for(NSString *contributionId in contributionIds){
        statusDictionary[contributionId] = [NSNumber numberWithInt:status];
        status++;
    }
    NSLog(@"StatusDictionary = %@", statusDictionary);
    return statusDictionary;
}

-(JSQMessagesAvatarImage *)avatarForStatus:(NSNumber *)status{
    return self.avatarForStatus[status];
}


#pragma mark - cell formatters (event and message cell)

-(void) formatEventCell:(PPLSTEventTableViewCell*)cell ForContribution:(Contribution*) contribution{
    //first check to see if the media is already set (or its an image) for this cell. If not, go ahead and download it
    NSLog(@"contribution.imagePath for contributionId %@ is %@",contribution.contributionId, contribution.imagePath);
    if([contribution.contributionType isEqualToString:@"message"] && contribution.message && ![contribution.message isEqualToString:@""]) return;
    if([contribution.contributionType isEqualToString:@"photo"] && contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
        NSLog(@"------------------GETTING THE PHOTO FROM THE FILE SYSTEM / MEMORY");
        cell.titleImageView.image = [self getImageAtFilePath:contribution.imagePath];
    }

    if(self.isLoading[contribution.contributionId]){
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
    NSLog(@"Formatting JSQMessage");
    //TODO: make asynch
    if([contribution.contributionType isEqualToString:@"photo"]){
        NSLog(@"Dealing with Photo");
        if(contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
                JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                NSLog(@"contribution.imagePath is set to = %@", contribution.imagePath);
                mediaItem.image = [self getImageAtFilePath:contribution.imagePath];
        } else{
            //TODO: put parse code here
            //TODO: add flag here to avoid double loading

            if(self.isLoading[contribution.contributionId]){
                return; //avoid dubble loading while running in background thread
            }
            self.isLoading[contribution.contributionId] = @1;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                [self downloadMediaForContribution:contribution];
                self.isLoading[contribution.contributionId] = @0;
                //after download is complete, move back to main queue for UI updates
                dispatch_async(dispatch_get_main_queue(), ^{
                    JSQPhotoMediaItem *mediaItem = (JSQPhotoMediaItem*)message.media;
                    mediaItem.image = [self getImageAtFilePath:contribution.imagePath];
                    [collectionView reloadData];
                });
            });
        }
    }
}

#pragma mark - Helper Methods / Private Methods

-(void) uploadAndSaveContributionInBackground:(Contribution*) contribution{
    //TODO: replace with parse code
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //TODO: re-assign the contributionId when the upload has completed
        [self saveCoreData];
    });
}

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
    NSLog(@"Saved Core Data!");
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
    [self.contributionIds addObject:contributionId]; //keep track of which objects are currently being stored
    Contribution *contribution = [NSEntityDescription insertNewObjectForEntityForName:@"Contribution" inManagedObjectContext:self.context];
    contribution.contributionId = contributionId;
    [self saveCoreData];
    return contribution;
}

//stores an image in the file system and returns the imagePath
-(NSString *) storeImage:(UIImage*)image{
    NSData *imageData = UIImagePNGRepresentation(image);
    NSLog(@"imageData about to be stored has length: %lu", [imageData length]);
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

/*this method gets the image at the given file path. If it has already been loaded, it gets it from memory, otherwise it loads it into memory. This avoids multiple calls to the filesystem which necessarily slows down the app.*/
-(UIImage*) getImageAtFilePath:(NSString*)filePath{
    if(![[self.imagesAtFilePath allKeys] containsObject:filePath]){
        self.imagesAtFilePath[filePath] = [UIImage imageWithContentsOfFile:filePath];
    }
    return self.imagesAtFilePath[filePath];
}

#pragma mark - Testing Parse stuff




#pragma mark - OLD METHODS - KEPT FOR HISTORICAL REASONS

////TODO: remove this method in favor of the parse one
//-(NSArray*) downloadEventMetaDataWithInputLatitude:(float)latitude andLongitude:(float) longitude andDate:(NSDate*)date{
//    NSMutableArray *events = [[NSMutableArray alloc] init];
//    for(int i = 0; i < 40; i++){
//    
//        NSString *eventId = [NSString stringWithFormat:@"eventId%i",i];
//        
//        Event *event = [self getEventFromCoreDataWithId:eventId];
//        if(!event) event = [self createEventWithId:eventId];
//
//        event.containsUser = @0;
//        if(i == 0) event.containsUser = @1;
//        
//        event.longitude = @(35.00+i);
//        event.latitude = @(43.00+i);
//        event.lastActive = [NSDate dateWithTimeInterval:-(rand()%1000) sinceDate:[NSDate date]];
//        event.country = @"USA";
//        event.state = @"California";
//        event.city = @"Los Angeles";
//        NSArray *possibleNeighborhoods = @[@"Little Osaka", @"Venice Beach", @"Santa Monica Pier", @"Culver City", @"Santa Monica", @"Brentwood", @"Westwood", @"Burbank", @"Beverly Hills", @"Bel Air"];
//        event.neighborhood = possibleNeighborhoods[rand()%[possibleNeighborhoods count]];
//        
//        NSString *titleContributionId = [NSString stringWithFormat: @"titleContributionIdForEvent%i",i];
//        Contribution *titleContribution = [self getContributionFromCoreDataWithId:titleContributionId];
//        if(!titleContribution) titleContribution = [self createContributionWithId:titleContributionId];
//        
//        //setup the basic info for this contribution
//        titleContribution.contributingUserId = @"otherPerson";
//        titleContribution.createdAt = [event.lastActive copy]; //be careful not to point to the same date object
//        titleContribution.contributionType = @"photo";
//        
//        titleContribution.titleEvent = event;
//        titleContribution.contributionType = @"photo";
//        
//        //add as regular contribution too
//        titleContribution.event = event;
//        [event addContributionsObject:titleContribution];
//        
//        //TODO: since it's an NSSet, do we really have to check this? Aren't they unique by default?
//        if(![[event titleContributions] containsObject:titleContribution]){
//            //TODO: instead of adding the title contribution id, replace the old ones with new ones.. Think about perhaps deallocating memory for old contributions here...
//            [event addTitleContributionsObject:titleContribution];
//        }
//        [events addObject:event];
//    }
//    
//    /***************** SAVE DATA *****************/
//    [self saveCoreData];
//    
//    return events;
//
//}



////by now, there should already exist a contribution object in core data. Here we just update the object.
//-(Contribution*) downloadMediaForContribution:(Contribution*)contribution{
//    
//    /************* GET FROM CORE DATA ******************/
//
//    //TODO: check to see if this contribution already has its data set. In that case, don't query parse
//    //TODO: filler code. Replace with correct parse code
//    
//    if ([contribution.contributionType isEqualToString:@"message"]) {
//        NSLog(@"downloading message for contribution %@",contribution.contributionId);
//        contribution.message = [NSString stringWithFormat:@"message for %@",contribution.contributionId];
//    } else if([contribution.contributionType isEqualToString:@"photo"]){
//        //TODO: replace with parse code
//        NSLog(@"downloading image for contribution %@",contribution.contributionId);
//        UIImage *image = [UIImage imageNamed:@"nyc.jpg"];
//        contribution.imagePath = [self storeImage:image];
//    }
//    contribution.contributingUserId = @"otherPerson";
//    contribution.createdAt = [NSDate date];
//    
//
//    [self saveCoreData];
//    
//    return contribution;
//}


@end
