//
//  PPLSTChatViewController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/12/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTChatViewController.h"
#import "PPLSTImagePickerController.h"
#import "PPLSTImageDetailViewController.h"

@interface PPLSTChatViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

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
    
    [self prepareForLoad]; //load contributions for this event
    
    // Do any additional setup after loading the view.
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;

    //TODO: fix these to the correct senderId. Possibly keep @"You" there, or remove completely
    self.senderDisplayName = @"";
    self.senderId = @"tmpSenderId";

    //TODO: add the avatars back in to show icons rather than profile pictures
    self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
    self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;
    
    //TODO: Change this to the camera icon. For now, only support text messages
//    self.inputToolbar.contentView.leftBarButtonItem = nil;
    
    JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
    self.outgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:[UIColor colorWithRed:138.0f/255.0f green:201.0f/255.0f blue:221.0f/255.0f alpha:1.0f]];
    self.incomingBubbleImageData = [bubbleFactory incomingMessagesBubbleImageWithColor:[UIColor colorWithWhite:0.95f alpha:1.0f]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

//TODO: include avatars based on arrival at event
-(id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    return nil;
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath{
    JSQMessage *message = [self.jsqMessages objectAtIndex:indexPath.row];
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
    /**
     *  Override point for customizing cells
     */
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    /**
     *  Configure almost *anything* on the cell
     *
     *  Text colors, label text, label colors, etc.
     *
     *
     *  DO NOT set `cell.textView.font` !
     *  Instead, you need to set `self.collectionView.collectionViewLayout.messageBubbleFont` to the font you want in `viewDidLoad`
     *
     *
     *  DO NOT manipulate cell layout information!
     *  Instead, override the properties you want on `self.collectionView.collectionViewLayout` from `viewDidLoad`
     */
    
    JSQMessage *message = [self.jsqMessages objectAtIndex:indexPath.row];
    
    if (!message.isMediaMessage) {
        
        if ([message.senderId isEqualToString:self.senderId]) {
            cell.textView.textColor = [UIColor blackColor];
        }
        else {
            cell.textView.textColor = [UIColor blackColor];
        }
        
        cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor,
                                              NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    }
    
    return cell;
}


#pragma mark - JSQMessageCollectionView Delegate

-(void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date{
    //TODO: also support images
    NSDictionary *metaData = @{@"eventId": self.event.eventId, @"senderId": self.senderId, @"contributionType": @"message", @"message": text};
    Contribution *newContribution = [self.dataManager uploadContributionWithData:metaData andPhoto:nil];
    [self.contributions addObject:newContribution];
    
    //TODO: also support media messages
    [self.jsqMessages addObject:[[self createMessagesFromContributions:@[newContribution]] firstObject]];

    [self finishSendingMessageAnimated:YES];
    [self.collectionView reloadData];
}

//TODO: customize the imagePicker!
//TODO: make sure that only images taken at the event can be uploaded
-(void)didPressAccessoryButton:(UIButton *)sender{
    PPLSTImagePickerController *picker = [[PPLSTImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    [self presentViewController:picker animated:YES completion:NULL];
}

//gets fired when the the bubble itself is tapped
-(void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath{
    Contribution *contribution = self.contributions[indexPath.row];
    if([contribution.contributionType isEqualToString:@"photo"]){
        //tapped on a photo
        [self performSegueWithIdentifier:@"Segue To Image Detail" sender:indexPath];
    }
}


#pragma mark - ImagePicker Delegate

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    UIImage *image = info[UIImagePickerControllerEditedImage];

    //setup the contribution
    NSDictionary *metaData = @{@"eventId": self.event.eventId, @"senderId": self.senderId, @"contributionType": @"photo"};
    
    Contribution *newContribution = [self.dataManager uploadContributionWithData:metaData andPhoto:image];
    [self.contributions addObject:newContribution];
    
    //TODO: also support media messages
    [self.jsqMessages addObject:[[self createMessagesFromContributions:@[newContribution]] firstObject]];

    [self finishSendingMessageAnimated:YES];
    [self.collectionView reloadData];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helper Methods

-(NSMutableArray *) createMessagesFromContributions:(NSArray*) contributions{
    NSMutableArray *messages = [[NSMutableArray alloc] init];

    for (Contribution *contribution in contributions) {
        NSLog(@"In the process of converting contributionId = %@ where the senderId = %@", contribution.contributionId, contribution.contributingUserId);
        if([contribution.contributionType isEqualToString:@"message"]){
            //create text message
            JSQMessage *newMessage = [[JSQMessage alloc] initWithSenderId:contribution.contributingUserId senderDisplayName:@"asdf" date:contribution.createdAt text:contribution.message];
            [messages addObject:newMessage];
        } else if([contribution.contributionType isEqualToString:@"photo"]){
            //create photo message. Note that we're holding off with loading the photo until it comes into view on the collectionview - i.e. lazy loading
            JSQPhotoMediaItem *photo = [[JSQPhotoMediaItem alloc] initWithMaskAsOutgoing:([contribution.contributingUserId isEqualToString:self.senderId]? YES:NO)];
            JSQMessage *newMessage = [JSQMessage messageWithSenderId:contribution.contributingUserId displayName:@"asdf" media:photo];
            [messages addObject:newMessage];
        }
    }
    return messages;
}

-(void) prepareForLoad{
    self.contributions = [[self.dataManager downloadContributionMetaDataForEvent:self.event] mutableCopy];
    self.jsqMessages = [self createMessagesFromContributions:self.contributions];
}





















@end
