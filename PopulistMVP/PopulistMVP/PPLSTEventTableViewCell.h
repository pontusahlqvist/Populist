//
//  PPLSTEventTableViewCell.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/3/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PPLSTEventTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UIImageView *titleImageView2;
@property (strong, nonatomic) IBOutlet UILabel *eventLocationTextLabel2;

@property (strong, nonatomic) IBOutlet UILabel *eventTimeSinceActiveTextLabel2;
@property (strong, nonatomic) IBOutlet UIImageView *titleImageView;
@property (strong, nonatomic) IBOutlet UILabel *eventTimeSinceActiveTextLabel;
@property (strong, nonatomic) IBOutlet UILabel *eventLocationTextLabel;

@property (weak, nonatomic) UITableView *parentTableView;

@end
