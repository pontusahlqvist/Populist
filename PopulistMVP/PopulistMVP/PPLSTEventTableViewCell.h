//
//  PPLSTEventTableViewCell.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/3/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PPLSTEventTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UIImageView *titleImageView;
@property (strong, nonatomic) IBOutlet UILabel *eventTimeSinceActiveTextLabel;
@property (strong, nonatomic) IBOutlet UILabel *eventLocationTextLabel;
@property (strong, nonatomic) IBOutlet UIView *coloredBackgroundView;

@property (weak, nonatomic) UITableView *parentTableView;
@property (nonatomic) BOOL loading; //keeps track of if the image for the cell has already been requested to avoid multiple requests.
@property (strong, nonatomic) UIActivityIndicatorView *spinner;
@end
