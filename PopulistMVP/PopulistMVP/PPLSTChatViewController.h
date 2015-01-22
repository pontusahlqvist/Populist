//
//  PPLSTChatViewController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/12/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JSQMessagesViewController.h"
#import "JSQMessages.h"
#import "JSQMessagesBubbleImageFactory.h"
#import "Event.h"
#import "PPLSTDataManager.h"

//TODO: make uiimagepicker disappear faster. It currently lags for a few seconds before disappearing. This might just be because various processes are running in the main thread and might be linked to e.g. core data...

@interface PPLSTChatViewController : JSQMessagesViewController <JSQMessagesCollectionViewDataSource, JSQMessagesCollectionViewDelegateFlowLayout>
//loads contributions for this event
-(void) prepareForLoad;

@property (strong, nonatomic) PPLSTDataManager *dataManager;
@property (strong, nonatomic) Event *event;

@property (strong, nonatomic) NSMutableArray *contributions;
@property (strong, nonatomic) NSMutableArray *jsqMessages;
@property (strong, nonatomic) NSMutableDictionary *avatarForSenderId;
@property (strong, nonatomic) NSMutableDictionary *statusForSenderId;

@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;
@end
