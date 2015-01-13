//
//  PPLSTNavigationController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/7/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTNavigationController.h"

@interface PPLSTNavigationController ()

@end

@implementation PPLSTNavigationController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if(self){
        self.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor colorWithRed:93.0f/255.0f green:151.0f/255.0f blue:174.0f/255.0f alpha:1.0f], NSFontAttributeName: [UIFont fontWithName:@"AvenirNext-DemiBold" size:25]};
        self.navigationBar.barTintColor = [UIColor whiteColor];
        self.navigationBar.translucent = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
