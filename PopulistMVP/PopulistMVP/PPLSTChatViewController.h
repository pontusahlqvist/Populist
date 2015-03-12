//
//  PPLSTChatViewController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/12/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#import "JSQMessagesViewController.h"
#import "JSQMessages.h"
#import "JSQMessagesBubbleImageFactory.h"
#import "Event.h"
#import "PPLSTDataManager.h"
#import "PPLSTImagePickerController.h"
#import "PPLSTReportView.h"

//TODO: make uiimagepicker disappear faster. It currently lags for a few seconds before disappearing. This might just be because various processes are running in the main thread and might be linked to e.g. core data...

@interface PPLSTChatViewController : JSQMessagesViewController <JSQMessagesCollectionViewDataSource, JSQMessagesCollectionViewDelegateFlowLayout, PPLSTImagePickerController, PPLSTDataManagerPushDelegate, PPLSTReportViewDelegate>
//loads contributions for this event
-(void) prepareForLoad;
-(void) disableEventBecauseOfPoorLocation;
-(void) disableEventBecauseUserLeftIt;

@property (strong, nonatomic) PPLSTDataManager *dataManager;
@property (strong, nonatomic) PPLSTLocationManager *locationManager;
@property (strong, nonatomic) Event *event;

@property (strong, nonatomic) NSMutableArray *contributions;
@property (strong, nonatomic) NSMutableDictionary *statusForSenderId;
@property (strong, nonatomic) NSMutableSet *userIds;

@property (strong, nonatomic) PPLSTReportView *reportView;
@end
