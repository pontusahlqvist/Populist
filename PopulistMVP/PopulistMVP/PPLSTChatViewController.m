//
//  PPLSTChatViewController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/12/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: make image detail view looks better
//TODO: should the user have to start the conversation with an image?

#import "PPLSTChatViewController.h"
#import "PPLSTImageDetailViewController.h"
#import "PPLSTMutableDictionary.h"

@interface PPLSTChatViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;
//@property (strong, nonatomic) NSMutableDictionary *jsqMessageForContributionId;
@property (strong, nonatomic) NSString *currentEventId; //only for comparison reasons during merges. Otherwise, use self.event.eventId
@property (strong, nonatomic) PPLSTMutableDictionary *jsqMessageForContributionId;
@end

@implementation PPLSTChatViewController

#pragma mark - required methods

-(PPLSTMutableDictionary *)jsqMessageForContributionId{
    if(!_jsqMessageForContributionId) _jsqMessageForContributionId = [[PPLSTMutableDictionary alloc] init];
    return _jsqMessageForContributionId;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:) name: UIApplicationWillEnterForegroundNotification object:nil];
    
    self.senderDisplayName = @"";
    self.senderId = self.dataManager.contributingUserId;
    
    [self prepareForLoad]; //load contributions for this event
    
    //setup delegates and datasources
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
    JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
    self.outgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:[UIColor colorWithRed:138.0f/255.0f green:201.0f/255.0f blue:221.0f/255.0f alpha:1.0f]];
    self.incomingBubbleImageData = [bubbleFactory incomingMessagesBubbleImageWithColor:[UIColor colorWithWhite:0.95f alpha:1.0f]];
    
    UIImage *image = [UIImage imageNamed:@"mappin_glyph"];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.bounds = CGRectMake( 0, 0, image.size.width, image.size.height);
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:@selector(openMap) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItem = barButtonItem;
}

-(void) subscribeToPushNotifications{
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation addUniqueObject:[@"event" stringByAppendingString:self.event.eventId] forKey:@"channels"];
    [currentInstallation addUniqueObject:[@"merge" stringByAppendingString:self.event.eventId] forKey:@"channels"];
    [currentInstallation saveInBackground];
}

-(void)viewWillDisappear:(BOOL)animated{
    //unsubscribe to this push notification channel
    //note: push channels must start with letter so we can't just subscribe to the channel given by the event id since that could begin with a number
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation removeObject:[@"event" stringByAppendingString:self.event.eventId] forKey:@"channels"];
    if(![self.event.containsUser isEqualToNumber:@1]){ //only remove the merge channel if the user is not part of this event
        [currentInstallation removeObject:[@"merge" stringByAppendingString:self.event.eventId] forKey:@"channels"];
    }
    [currentInstallation saveInBackground];
    [super viewWillDisappear:animated];
}
-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated]; //note: in the superclass, I have disabled the automatic scrollToBottom.
}

-(void) appDidEnterForeground:(NSNotification*)notification{
    [self prepareForLoad];
}

//opens the map to the given location
-(void) openMap{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://maps.apple.com/?q=%f,%f",[self.event.latitude floatValue],[self.event.longitude floatValue]]];
    [[UIApplication sharedApplication] openURL:url];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    //let the data manager know that this is the current VC
    self.dataManager.pushDelegate = self;
    [self subscribeToPushNotifications];
    self.currentEventId = [self.event.eventId copy];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"didReceiveMemoryWarning in chatVC");
}

#pragma mark - Lazy Instantiation

-(NSMutableSet *)userIds{
    if(!_userIds) _userIds = [[NSMutableSet alloc] init];
    return _userIds;
}

#pragma mark - Disable Chat Methods

//This method disables the event, i.e. the user will no longer be able to participate/chat
-(void) disableEventBecauseOfPoorLocation{
    [self disableEvent];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Darn, lost your location..." message:@"It seems like your location is not very precise right now. Try moving to a more open space, or go back and refresh." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alertView show];
}

-(void)disableEventBecauseUserLeftIt{
    [self disableEvent];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Thanks for the visit" message:@"It seems like you've left the event you were taking part in, or maybe it just ended. No worries, if you want to keep chatting and the event's still going on, just go back there." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alertView show];
}

-(void) disableEvent{
    [self.inputToolbar.contentView.textView setEditable:NO];
    self.inputToolbar.backgroundColor = [UIColor clearColor];
    [self.inputToolbar.contentView.textView setPlaceHolder:@"You are an observer"];
}
#pragma mark - PPLSTDataManagerPushDelegate

-(void)didAddIncomingContribution:(Contribution *)newContribution ForEvent:(Event *)event{
    NSLog(@"didAddIncomingContribution:%@ ForEvent:%@", newContribution, event);
    if(![event.eventId isEqualToString:self.event.eventId]){
        return; //shouldn't be part of this event
    }
    [self handleUserId:newContribution.contributingUserId];
    [self.contributions addObject:newContribution];
    [self.collectionView reloadData];
    [self scrollToBottomAnimated:YES];
}

-(void)eventIdWasUpdatedFrom:(NSString *)oldEventId to:(NSString *)newEventId oldCount:(NSNumber*)oldCount newCount:(NSNumber*)newCount{
    NSLog(@"eventIdWasUpdatedFrom:%@ to:%@",oldEventId,newEventId);
    NSLog(@"self.event.eventId = %@", self.event.eventId);

    if([self.event.eventId isEqualToString:oldEventId] || [self.event.eventId isEqualToString:newEventId]){
        NSLog(@"calling prepareForLoad");
        //the current event participated in a merge, so we update the stream
        [self prepareForLoad];
        [self subscribeToPushNotifications]; //in case the event id was updated, we need to subscribe to the new channel. Keep subscribing to the old one too just in case... Is this logic correct? Should we still subscribe to the old channel? It can't hurt I guess. Note: we protect against the case where we don't have access to the event in parsing the push in the dataManager so it shouldn't be a problem to get additional pushes.
    }
    NSLog(@"currentEventId = %@, oldEventId = %@, newEventId = %@, oldCount = %@, newCount = %@",self.currentEventId,oldEventId,newEventId, oldCount, newCount);
    if(![newCount isEqualToNumber:@0] && ![oldCount isEqualToNumber:@0]){
        UIAlertView *mergeOccurredAlertView = [[UIAlertView alloc] initWithTitle:@"Your Event Merged" message:@"Hey, it seems like your event just merged with another one neaby. The more the merrier!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [mergeOccurredAlertView show];
    }
    self.currentEventId = [self.event.eventId copy];
}

#pragma mark - Prepare for Load

-(void) prepareForLoad{
    //setup the textfield etc to disallow users to contribute to events that they are not part of
    if(![self.event.containsUser isEqualToNumber:@1]){
        [self.inputToolbar.contentView.textView setEditable:NO];
        [self.inputToolbar.contentView.textView setPlaceHolder:@"You are an observer"];
    } else{
        self.inputToolbar.backgroundColor = [UIColor colorWithRed:138.0f/255.0f green:201.0f/255.0f blue:221.0f/255.0f alpha:1.0f];
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.parentContext = self.dataManager.context;
        [context performBlock:^{
            //TODO: You should really get a new copy of the event here in the proper context. Otherwise there will be issues linking objects in two diff contexts
            //TODO: (same as above, just extending the description) Just noted a crash. It crashed as a result of this call. This calls the DM which then calls getContributionFromCoreDataWithId but not with context. Instead it calls it with self.context which is inconsistent, thereby potentially causing a crash. We must change that context and also modify self.event here to be thread safe. Note: the app crashes because message is nil when attempting to fix this. I believe the reason is that during downloadContributionMetaDataForEvent, the event that's passed in actually gets modified. Thus, if we pass in another context's event there may be multiple events present and some of them might not have any contributions contained in them.
            self.contributions = [[self.dataManager downloadContributionMetaDataForEvent:self.event inContext:context] mutableCopy];
            self.statusForSenderId = [self.dataManager getStatusDictionaryForEvent:self.event];
            self.userIds = [[NSSet setWithArray:[self.statusForSenderId allKeys]] mutableCopy]; //set the userIds at the very beginning.
            NSLog(@"userIds = %@", self.userIds);

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.collectionView reloadData];
                [self scrollToBottomAnimated:NO];
            });
        }];
    });
}

#pragma mark - Lazy Instantiations

-(NSMutableArray *)contributions{
    if(!_contributions){
        _contributions = [[NSMutableArray alloc] init];
    }
    return _contributions;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([sender isKindOfClass:[NSIndexPath class]]){
        if([segue.destinationViewController isKindOfClass:[PPLSTImageDetailViewController class]]){
            NSIndexPath *indexPath = sender;
            PPLSTImageDetailViewController *destinationVC = segue.destinationViewController;
            Contribution *contribution = self.contributions[indexPath.row];
            JSQMessage *message = [self jsqMessageForContribution:contribution];
            JSQPhotoMediaItem *photo = (JSQPhotoMediaItem*)[message media];
            destinationVC.image = photo.image;
            destinationVC.contribution = self.contributions[indexPath.row];
            destinationVC.dataManager = self.dataManager;
        }
    }
}

#pragma mark - JSQMessageCollectionView Data Source

-(id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    NSNumber *status = self.statusForSenderId[contribution.contributingUserId];
    if(status){
        return [self.dataManager avatarForStatus:status];
    } else{
        //if the status has not yet been recorder (e.g. our new contribution has not yet saved) we make our best guess as to what the avatar should be and update it on the next contribution upload. The only time there would be a disagreement would be if another user was able to save a contribution and we submitted ours in between that save and when the push went through. In other words very rarely. This would only apply to new users too.
        NSNumber *maxStatus = [NSNumber numberWithInteger:[[self.statusForSenderId allKeys] count]];
        return [self.dataManager avatarForStatus:maxStatus];
    }
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    if([contribution.contributingUserId isEqualToString:self.senderId]){
        return self.outgoingBubbleImageData;
    } else{
        return self.incomingBubbleImageData;
    }
}

-(id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    JSQMessage *message = [self jsqMessageForContribution:contribution];
    return message;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath{
    return nil;
}

#pragma mark - CollectionView Data Source

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [self.contributions count];
}
-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    Contribution *contribution = self.contributions[indexPath.row];
    JSQMessage *message = [self jsqMessageForContribution:contribution];
    if (!message.isMediaMessage) {
        if ([message.senderId isEqualToString:self.senderId]) {
            cell.textView.textColor = [UIColor whiteColor];
        }
        else {
            cell.textView.textColor = [UIColor blackColor];
        }
        cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor, NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    }
    //This method call runs asynch if image isn't already loaded and synch if it is.
    [self.dataManager formatJSQMessage:message ForContribution:self.contributions[indexPath.row] inCollectionView:collectionView];
    return cell;
}


#pragma mark - JSQMessageCollectionView Delegate

-(void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date{
    NSLog(@"didPressSendButton");
    NSDictionary *metaData = @{@"eventId": self.event.eventId, @"senderId": self.senderId, @"contributionType": @"message", @"message": text, @"location":self.locationManager.currentLocation};
    Contribution *newContribution = [self.dataManager uploadContributionWithData:metaData andPhoto:nil];
    [self handleNewContribution:newContribution];
    [self finishSendingMessageAnimated:YES];
    [self.collectionView reloadData];
}

-(void)didPressAccessoryButton:(UIButton *)sender{
    if(![self.event.containsUser isEqualToNumber:@1]){
        return; //can't contribute to the event
    }
    PPLSTImagePickerController *picker = [[PPLSTImagePickerController alloc] init];
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    
        UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Device has no camera"
                                                        delegate:nil
                                                        cancelButtonTitle:@"OK"
                                                        otherButtonTitles: nil];
        
        [myAlertView show];
        return;
    }

    picker.imagePickerDelegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    [self presentViewController:picker animated:YES completion:NULL];
}

//gets fired when the the bubble itself is tapped
-(void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    if([contribution.contributionType isEqualToString:@"photo"]){
        [self performSegueWithIdentifier:@"Segue To Image Detail" sender:indexPath]; //tapped a photo
    } else if([contribution.contributionType isEqualToString:@"message"]){
        [self displayReportOptionForContribution:contribution];
    }
}

-(void) displayReportOptionForContribution:(Contribution*) contribution{
    self.reportView = [[PPLSTReportView alloc] initWithFrame:[[[UIApplication sharedApplication] keyWindow] bounds] andContribution:contribution];
    self.reportView.delegate = self;
    [[[UIApplication sharedApplication] keyWindow] addSubview:self.reportView];
    [self.reportView animateAdd];
}

#pragma mark - ImagePicker Delegate

-(void)didFinishPickingImage:(UIImage *)originalImage{
    //called from PPLSTImagePickerController
    [self dismissViewControllerAnimated:YES completion:nil];

    UIImage *image = [self cropImage:originalImage AndScaleToPoints:750.0];
    
    //setup the contribution
    NSDictionary *metaData = @{@"eventId": self.event.eventId, @"senderId": self.senderId, @"contributionType": @"photo",@"location":self.locationManager.currentLocation};
    
    Contribution *newContribution = [self.dataManager uploadContributionWithData:metaData andPhoto:image];
    [self handleNewContribution:newContribution];

    [self finishSendingMessageAnimated:YES];
    [self.collectionView reloadData];
}

-(void)didCancelPickingImage{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - PPLSTReportViewDelegate Methods

-(void)didPressReportButtonForContribution:(Contribution *)contribution{
    [self.dataManager flagContribution:contribution];
}
-(void)didPressCancelButton{
    NSLog(@"didPressCancelButton");
}

#pragma mark - Helper Methods

-(NSMutableArray *) createMessagesFromContributions:(NSArray*) contributions{
    NSMutableArray *messages = [[NSMutableArray alloc] init];

    for (Contribution *contribution in contributions) {
        NSLog(@"In the process of converting contributionId = %@ where the senderId = %@", contribution.contributionId, contribution.contributingUserId);
        JSQMessage *newMessage;
        if([contribution.contributionType isEqualToString:@"message"]){
            //create text message
            if(!contribution.message || [contribution.message isEqualToString:@""]){
                [self.dataManager downloadMediaForContribution:contribution inContext:self.dataManager.context]; //sync call
            }
            newMessage = [[JSQMessage alloc] initWithSenderId:contribution.contributingUserId senderDisplayName:@"asdf" date:contribution.createdAt text:contribution.message];
        } else if([contribution.contributionType isEqualToString:@"photo"]){
            //create photo message. Note that we're holding off with loading the photo until it comes into view on the collectionview - i.e. lazy loading
            JSQPhotoMediaItem *photo = [[JSQPhotoMediaItem alloc] initWithMaskAsOutgoing:([contribution.contributingUserId isEqualToString:self.senderId]? YES:NO)];
            if(contribution.imagePath && ![contribution.imagePath isEqualToString:@""]){
                photo.image = [self.dataManager getImageWithFileName:contribution.imagePath];
            } else if([[self.dataManager.imagesInMemoryForContributionId allKeys] containsObject:contribution.contributionId]){
                NSLog(@"calling imagesInMemoryForContributionId from within createMessagesFromContributions with contributionId = %@", contribution.contributionId);
                photo.image = self.dataManager.imagesInMemoryForContributionId[contribution.contributionId];
            }
            newMessage = [JSQMessage messageWithSenderId:contribution.contributingUserId displayName:@"asdf" media:photo];
        }
        [messages addObject:newMessage];
    }
    return messages;
}

-(JSQMessage *) jsqMessageForContribution:(Contribution*)contribution{
    NSString *contributionId = contribution.contributionId;
    if(![[self.jsqMessageForContributionId allKeys] containsObject:contributionId]){
        self.jsqMessageForContributionId[contributionId] = [[self createMessagesFromContributions:@[contribution]] firstObject];
    }
    return self.jsqMessageForContributionId[contributionId];
}

-(void) handleNewContribution:(Contribution*)newContribution{
    [self.contributions addObject:newContribution];
    
    if([self.event.importance floatValue] < 1.0){
        [self.dataManager increaseImportanceOfEvent:self.event By:2.0];
    }
    self.event.lastActive = [NSDate date];
    [self handleUserId:newContribution.contributingUserId];
}

//handles the collection of userIds and determins if we should update avatars.
-(void) handleUserId:(NSString*)userId{
    if(![self.userIds containsObject:userId]){
        self.statusForSenderId = [self.dataManager getStatusDictionaryForEvent:self.event];
        if([[self.statusForSenderId allKeys] containsObject:userId]){
            [self.userIds addObject:userId]; //Note: if for some reason, the save of the object takes too long and the userId hasn't been added to the list yet, we'll make sure to pull the avatar next time.
        }
    }
}

#pragma mark - Image Helper Methods

//scales down an image to the given horizontal size while maintaining the proportions
-(UIImage*) imageWithImage:(UIImage*)image scaledDownToHorizontalPoints:(float)horizontal{
    return [self imageWithImage:image scaledToSize:CGSizeMake(horizontal,(image.size.height/image.size.width)*horizontal)];
}

//scales the image down to a given size
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

-(UIImage*) cropImage:(UIImage*)image ToRect:(CGRect)rect{
    UIGraphicsBeginImageContextWithOptions(rect.size, false, [image scale]);
    [image drawAtPoint:CGPointMake(-rect.origin.x, -rect.origin.y)];
    UIImage *cropped_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return cropped_image;
}


-(UIImage*) flipImageCorrectly:(UIImage*)inputImage{
    NSLog(@"PPLSTChatViewController - flipImageCorrectly:%@",inputImage);

    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (inputImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, inputImage.size.width, inputImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;

        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, inputImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;

        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, inputImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }

    CIImage* coreImage = inputImage.CIImage;

    if (!coreImage) {
        coreImage = [CIImage imageWithCGImage:inputImage.CGImage];
    }

    coreImage = [coreImage imageByApplyingTransform:transform];
    UIImage *newImage = [UIImage imageWithCIImage:coreImage];

    return newImage;
}


-(UIImage*) cropImage:(UIImage*)originalImage AndScaleToPoints:(float)newWidth{
    NSLog(@"PPLSTChatViewController - cropImage:%@ AndScaleToPoints:%f",originalImage,newWidth);
    UIImage *rotatedImage = [self flipImageCorrectly:originalImage];

    float imageWidth = originalImage.size.width;
    float imageHeight = originalImage.size.height;
    UIImage *croppedImage;
    if(imageHeight > imageWidth){
        croppedImage = [self cropImage:rotatedImage ToRect:CGRectMake(0.0, (imageHeight - imageWidth)/2.0, imageWidth, imageWidth)];
    } else{
        croppedImage = [self cropImage:rotatedImage ToRect:CGRectMake((imageWidth-imageHeight)/2.0, 0.0, imageHeight, imageHeight)];
    }
    return [self imageWithImage:croppedImage scaledDownToHorizontalPoints:newWidth];
}










@end
