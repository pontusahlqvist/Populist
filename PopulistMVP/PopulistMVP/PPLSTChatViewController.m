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

#import "PPLSTChatViewController.h"
#import "PPLSTImagePickerController.h"
#import "PPLSTImageDetailViewController.h"

@interface PPLSTChatViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;
@end

@implementation PPLSTChatViewController

#pragma mark - required methods

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
    NSLog(@"Inside Chat VC");
    self.senderDisplayName = @"";
    self.senderId = self.dataManager.contributingUserId;
    
    [self prepareForLoad]; //load contributions for this event
    
    //setup delegates and datasources
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.locationManager.delegate = self;
    
    JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
    self.outgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:[UIColor colorWithRed:138.0f/255.0f green:201.0f/255.0f blue:221.0f/255.0f alpha:1.0f]];
    self.incomingBubbleImageData = [bubbleFactory incomingMessagesBubbleImageWithColor:[UIColor colorWithWhite:0.95f alpha:1.0f]];
    
    UIImage *image = [self imageWithImage:[UIImage imageNamed:@"mappin.png"] scaledToSize:CGSizeMake(30.0, 30.0)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.bounds = CGRectMake( 0, 0, image.size.width, image.size.height);
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:@selector(openMap) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItem = barButtonItem;
}

//opens the map to the given location
-(void) openMap{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://maps.apple.com/?q=%f,%f",[self.event.latitude floatValue],[self.event.longitude floatValue]]];
    NSLog(@"Opening URL %@", url);
    [[UIApplication sharedApplication] openURL:url];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated]; //TODO: I think this causes the snap-to-bottom each time, even when the user returns from the image detailed view
    //let the data manager know that this is the current VC
    self.locationManager.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"didReceiveMemoryWarning in chatVC");
}

#pragma mark - PPLSTLocationManagerDelegate Methods

-(void)locationUpdatedTo:(CLLocation *)newLocation From:(CLLocation *)oldLocation{
    if([self.locationManager movedTooFarFromLocationOfLastUpdate] || [self.locationManager waitedToLongSinceTimeOfLastUpdate]){
        NSNumber *thisEventContainsUser = [self.event.containsUser copy];

        Event *bestEvent = [self.dataManager eventThatUserBelongsTo];
        CLLocation *currentLocation = [self.locationManager getCurrentLocation];
        [self.locationManager updateLocationOfLastUpdate:currentLocation];
        [self.locationManager updateTimeOfLastUpdate:[NSDate date]];

        if([thisEventContainsUser isEqualToNumber:@1] && ![bestEvent.eventId isEqualToString:self.event.eventId]){
            //disable chat and perhaps display an alert view
            self.event.containsUser = @0; //don't worry about saving since there will already be a save in progress in the dataManager
            [self.inputToolbar.contentView.textView setEditable:NO];
            [self.inputToolbar.contentView.textView setPlaceHolder:@"You are an observer"];

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Thanks for the visit" message:@"It seems like you've left the event you were taking part in, or maybe it just ended. No worries, if you want to keep chatting and the event's still going on, just go back there." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
        }
    }
}
-(void)didAcceptAuthorization{}
-(void)didDeclineAuthorization{}

#pragma mark - Prepare for Load

-(void) prepareForLoad{
    //setup the textfield etc to disallow users to contribute to events that they are not part of
    if(![self.event.containsUser isEqualToNumber:@1]){
        [self.inputToolbar.contentView.textView setEditable:NO];
        [self.inputToolbar.contentView.textView setPlaceHolder:@"You are an observer"];
    } else{
        self.inputToolbar.backgroundColor = [UIColor colorWithRed:138.0f/255.0f green:201.0f/255.0f blue:221.0f/255.0f alpha:1.0f];
    }

    //TODO: kick these off in parallel async threads rather than doing the avatar AND contribution download back-to-back
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
        self.contributions = [[self.dataManager downloadContributionMetaDataForEvent:self.event] mutableCopy];
        self.jsqMessages = [self createMessagesFromContributions:self.contributions];
        
        self.statusForSenderId = [self.dataManager getStatusDictionaryForEvent:self.event];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView reloadData];
            [self scrollToBottomAnimated:NO];
        });
    });
}

#pragma mark - Lazy Instantiations

-(NSMutableArray *)contributions{
    if(!_contributions){
        _contributions = [[NSMutableArray alloc] init];
    }
    return _contributions;
}

-(NSMutableArray *)jsqMessages{
    if(!_jsqMessages){
        _jsqMessages = [[NSMutableArray alloc] init];
    }
    return _jsqMessages;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
    if([sender isKindOfClass:[NSIndexPath class]]){
        if([segue.destinationViewController isKindOfClass:[PPLSTImageDetailViewController class]]){
            NSIndexPath *indexPath = sender;
            PPLSTImageDetailViewController *destinationVC = segue.destinationViewController;
            JSQMessage *message = self.jsqMessages[indexPath.row];
            //TODO: consider placing image inside contribution instead
            JSQPhotoMediaItem *photo = (JSQPhotoMediaItem*)[message media];
            destinationVC.image = photo.image;
        }
    }
}

#pragma mark - JSQMessageCollectionView Data Source

-(id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    return [self.dataManager avatarForStatus:self.statusForSenderId[contribution.contributingUserId]];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    JSQMessage *message = [self.jsqMessages objectAtIndex:indexPath.row];
    NSLog(@"self.senderId = %@, message.senderId = %@", self.senderId, message.senderId);
    if([message.senderId isEqualToString:self.senderId]){
        return self.outgoingBubbleImageData;
    } else{
        return self.incomingBubbleImageData;
    }
}

-(id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    JSQMessage *message = [self.jsqMessages objectAtIndex:indexPath.row];
    //This method call runs asynch if image isn't already loaded and synch if it is.
    [self.dataManager formatJSQMessage:message ForContribution:self.contributions[indexPath.row] inCollectionView:collectionView];
    return message;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath{
    return nil;
}

#pragma mark - CollectionView Data Source

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [self.jsqMessages count];
}
-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    JSQMessage *message = [self.jsqMessages objectAtIndex:indexPath.row];
    
    if (!message.isMediaMessage) {
        if ([message.senderId isEqualToString:self.senderId]) {
            cell.textView.textColor = [UIColor whiteColor];
        }
        else {
            cell.textView.textColor = [UIColor blackColor];
        }
        cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor, NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    }
    return cell;
}


#pragma mark - JSQMessageCollectionView Delegate

-(void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date{
    NSDictionary *metaData = @{@"eventId": self.event.eventId, @"senderId": self.senderId, @"contributionType": @"message", @"message": text, @"location":self.locationManager.currentLocation};
    Contribution *newContribution = [self.dataManager uploadContributionWithData:metaData andPhoto:nil];
    [self handleNewContribution:newContribution];
    
    [self finishSendingMessageAnimated:YES];
    [self.collectionView reloadData];
}

//TODO: customize the imagePicker!
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

    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    [self presentViewController:picker animated:YES completion:NULL];
}

//gets fired when the the bubble itself is tapped
-(void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    if([contribution.contributionType isEqualToString:@"photo"]){
        [self performSegueWithIdentifier:@"Segue To Image Detail" sender:indexPath]; //tapped a photo
    }
}

#pragma mark - ImagePicker Delegate

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    UIImage *image = [self imageWithImage:info[UIImagePickerControllerEditedImage] scaledDownToHorizontalPoints:750.0];

    NSLog(@"VC should be dismissed...");
    //setup the contribution
    NSDictionary *metaData = @{@"eventId": self.event.eventId, @"senderId": self.senderId, @"contributionType": @"photo",@"location":self.locationManager.currentLocation};
    
    Contribution *newContribution = [self.dataManager uploadContributionWithData:metaData andPhoto:image];
    [self handleNewContribution:newContribution];

    [self finishSendingMessageAnimated:YES];
    [self.collectionView reloadData];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helper Methods

-(NSMutableArray *) createMessagesFromContributions:(NSArray*) contributions{
    NSMutableArray *messages = [[NSMutableArray alloc] init];

    for (Contribution *contribution in contributions) {
        NSLog(@"In the process of converting contributionId = %@ where the senderId = %@", contribution.contributionId, contribution.contributingUserId);
        JSQMessage *newMessage;
        if([contribution.contributionType isEqualToString:@"message"]){
            //create text message
            newMessage = [[JSQMessage alloc] initWithSenderId:contribution.contributingUserId senderDisplayName:@"asdf" date:contribution.createdAt text:contribution.message];
        } else if([contribution.contributionType isEqualToString:@"photo"]){
            //create photo message. Note that we're holding off with loading the photo until it comes into view on the collectionview - i.e. lazy loading
            JSQPhotoMediaItem *photo = [[JSQPhotoMediaItem alloc] initWithMaskAsOutgoing:([contribution.contributingUserId isEqualToString:self.senderId]? YES:NO)];
            newMessage = [JSQMessage messageWithSenderId:contribution.contributingUserId displayName:@"asdf" media:photo];
        }
        [messages addObject:newMessage];
    }
    return messages;
}

-(void) handleNewContribution:(Contribution*)newContribution{
    [self.contributions addObject:newContribution];
    [self.jsqMessages addObject:[[self createMessagesFromContributions:@[newContribution]] firstObject]];
    if([self.event.importance floatValue] < 1.0){
        [self.dataManager increaseImportanceOfEvent:self.event By:2.0];
    }
    self.event.lastActive = [NSDate date];
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
















@end
