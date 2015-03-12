//
//  PPLSTImageDetailViewController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/18/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PPLSTReportView.h"
#import "Contribution.h"
#import "PPLSTDataManager.h"
//TODO: Allow the user to zoom
//TODO: Make this view look better. Perhaps use modal instead of push segue and add some close functionality

@interface PPLSTImageDetailViewController : UIViewController <PPLSTReportViewDelegate, UIScrollViewDelegate>
@property (strong, nonatomic) IBOutlet UIScrollView *imageScrollView;

@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) Contribution *contribution;

@property (strong, nonatomic) PPLSTReportView *reportView;
@property (strong, nonatomic) PPLSTDataManager *dataManager;
@end
