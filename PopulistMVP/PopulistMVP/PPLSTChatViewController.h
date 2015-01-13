//
//  PPLSTChatViewController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/12/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "JSQMessagesViewController.h"
#import "JSQMessages.h"
#import "Event.h"
#import "PPLSTDataManager.h"

@interface PPLSTChatViewController : JSQMessagesViewController
@property (strong, nonatomic) Event *event;
@property (strong, nonatomic) PPLSTDataManager *dataManager;
@end
