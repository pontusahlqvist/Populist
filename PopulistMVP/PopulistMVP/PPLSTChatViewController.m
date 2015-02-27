//
//  PPLSTChatViewController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/12/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: fix avatars to make sure that they work properly accross multiple users and also that there's an avatar right away. Perhaps outsource to parse.
//TODO: move all the styling into a separate class
//TODO: create imageediting class where all the image editing methods can live
//TODO: make image detail view looks better
//TODO: implement 'load earlier'
//TODO: must start the conversation with an image

//TODO: in order to reduce memory usage, we can't keep all the jsqmessages in memory. Instead, we have to only keep a few in memory and create the other ones on the fly. We may very well save the other images to the filesystem, but we should only keep a few jsqmessages in memory. Perhaps, create a dictionary from contributionId -> jsqMessage. Then, make this dictionary of type PPLSTMutableDictionary with a finite size limit. Finally, in the method that normally returns self.jsqmessages[indexPath.row], fetch the objectValue for key = self.contributions[indexPath.row].contributionId instead. If this key is not in the dictionary, create a new one on the fly.

#import "PPLSTChatViewController.h"
#import "PPLSTImageDetailViewController.h"
#import "PPLSTMutableDictionary.h"

@interface PPLSTChatViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;
//@property (strong, nonatomic) NSMutableDictionary *jsqMessageForContributionId;
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
    
    //TODO: just make the image the right size from the beginning
    UIImage *image = [self imageWithImage:[UIImage imageNamed:@"mappin_glyph"] scaledToSize:CGSizeMake(30.0, 30.0)];
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
    [currentInstallation saveInBackground];
}

-(void)viewWillDisappear:(BOOL)animated{
    //unsubscribe to this push notification channel
    //note: push channels must start with letter so we can't just subscribe to the channel given by the event id since that could begin with a number
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation removeObject:[@"event" stringByAppendingString:self.event.eventId] forKey:@"channels"];
    [currentInstallation saveInBackground];
    [super viewWillDisappear:animated];
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
    [super viewDidAppear:animated]; //TODO: I think this causes the snap-to-bottom each time, even when the user returns from the image detailed view
    //let the data manager know that this is the current VC
    self.dataManager.pushDelegate = self;
    [self subscribeToPushNotifications];
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
        NSLog(@"1");
        [context performBlock:^{
            NSLog(@"2");
            self.contributions = [[self.dataManager downloadContributionMetaDataForEvent:self.event inContext:context] mutableCopy];
            NSLog(@"3");
            self.statusForSenderId = [self.dataManager getStatusDictionaryForEvent:self.event];
            NSLog(@"4");
            self.userIds = [[NSSet setWithArray:[self.statusForSenderId allKeys]] mutableCopy]; //set the userIds at the very beginning. In the future the prior call will be async, and we'll have to move this line of code into a delegate callback.
            NSLog(@"5");
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
    return [self.dataManager avatarForStatus:self.statusForSenderId[contribution.contributingUserId]];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    JSQMessage *message = [self jsqMessageForContribution:contribution];
    if([message.senderId isEqualToString:self.senderId]){
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
        [self.userIds addObject:userId];
        self.statusForSenderId = [self.dataManager getStatusDictionaryForEvent:self.event];
        //TODO: do we need to reload the collection view? It should be updated in the calling functions code anyway, so likely not.
        //on the other hand, we will be handing this off to parse, so it will run in a background thread. As a result, we'll have to wait for a call-back. This callback will potentially occur after the collection view has already been reloaded.
    }
}

#pragma mark - Image Helper Methods
//TODO: get rid of all of these image methods. We shouldn't need them if we already scale the image properly in the imagepicker.

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
