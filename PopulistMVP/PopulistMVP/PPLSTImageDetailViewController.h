//
//  PPLSTImageDetailViewController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/18/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>
//TODO: Allow the user to zoom
//TODO: Make this view look better. Perhaps use modal instead of push segue and add some close functionality

@interface PPLSTImageDetailViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) UIImage *image;
@end
