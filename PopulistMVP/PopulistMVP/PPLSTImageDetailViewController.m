//
//  PPLSTImageDetailViewController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/18/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTImageDetailViewController.h"

@interface PPLSTImageDetailViewController ()

@end

@implementation PPLSTImageDetailViewController

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
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor blackColor];
    self.imageView.image = [self scaledImageForImage:self.image];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Helper Methods

-(UIImage*) scaledImageForImage:(UIImage*)originalImage {
    float originalWidth = originalImage.size.width;
    float originalHeight = originalImage.size.height;
    float originalAspectRatio = originalWidth/originalHeight;
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    float screenWidth = screenBounds.size.width;
    float screenHeight = screenBounds.size.height;
    float screenAspectRatio = screenWidth/screenHeight;
    
    float newWidth, newHeight;
    if(originalAspectRatio > screenAspectRatio){
        //fit to height
        newHeight = screenHeight;
        newWidth = originalAspectRatio * newHeight;
    } else{
        //fit to width
        newWidth = screenWidth;
        newHeight = newWidth/originalAspectRatio;
    }
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [originalImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
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
