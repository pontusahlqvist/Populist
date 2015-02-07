//
//  PPLSTReportView.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 2/6/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTReportView.h"

@implementation PPLSTReportView

float verticalFramePositionOnScreen;
float verticalFramePositionOffScreen;
float separation;
float buttonHeight;
float buttonWidth;
float maxAlpha = 0.3;

-(id) initWithFrame:(CGRect)frame andContribution:(Contribution*)contribution{
    self = [super initWithFrame:frame];
    if(self){
        self.contributionToReport = contribution;
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
        
        buttonHeight = 43.0;
        separation = 0.02*self.frame.size.width;
        buttonWidth = self.frame.size.width - 2*separation;

        int numButtons = 2;
        
        verticalFramePositionOffScreen = self.frame.size.height;
        verticalFramePositionOnScreen = self.frame.size.height - (numButtons * buttonHeight + (numButtons+1)*separation);

        self.frame = frame;
        UIColor *buttonBackgroundColor = [UIColor whiteColor];
        UIColor *cancelTextColor = nil;//[UIColor blueColor];
        UIColor *reportTextColor = [UIColor redColor];//[UIColor colorWithRed:240.0f/255.0f green:91.0f/255.0f blue:98.0f/255.0f alpha:1.0f];

        //Add report button
        self.reportButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.reportButton.frame = CGRectMake(separation, verticalFramePositionOffScreen + separation, buttonWidth, buttonHeight);
        self.reportButton.backgroundColor = buttonBackgroundColor;
        self.reportButton.layer.cornerRadius = 5.0;
        self.reportButton.tintColor = reportTextColor;
        [self.reportButton.titleLabel setFont:[UIFont systemFontOfSize:22.0]];
        if([self.contributionToReport.contributionType isEqualToString:@"photo"]){
            [self.reportButton setTitle:@"Report Photo" forState:UIControlStateNormal];
        } else{
            [self.reportButton setTitle:@"Report Comment" forState:UIControlStateNormal];
        }
        [self.reportButton addTarget:self action:@selector(didPressReportButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.reportButton];

        //setup cancel button
        self.cancelButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.cancelButton.frame = CGRectMake(separation, verticalFramePositionOffScreen + 2*separation + buttonHeight, buttonWidth, buttonHeight);
        self.cancelButton.backgroundColor = buttonBackgroundColor;
        self.cancelButton.layer.cornerRadius = 5.0;
        self.cancelButton.tintColor = cancelTextColor;
        [self.cancelButton.titleLabel setFont:[UIFont systemFontOfSize:22.0]];
        [self.cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
        [self.cancelButton addTarget:self action:@selector(didPressCancelButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.cancelButton];
    }
    return self;
}

-(void) animateAdd{
    //This makes the view transition into the view from below
    [UIView beginAnimations:@"FakeModalTransition" context:nil];
    [UIView setAnimationDuration:0.25];
    self.reportButton.frame = CGRectMake(separation, verticalFramePositionOnScreen + separation, buttonWidth, buttonHeight);
    self.cancelButton.frame = CGRectMake(separation, verticalFramePositionOnScreen + 2*separation + buttonHeight, buttonWidth, buttonHeight);
    self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:maxAlpha];
    [UIView commitAnimations];
}

-(void) animateRemove{
    //This makes the view transition into the view from below
    [UIView beginAnimations:@"FakeModalTransition" context:nil];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:)];
    [UIView setAnimationDuration:0.25];
    self.reportButton.frame = CGRectMake(separation, verticalFramePositionOffScreen + separation, buttonWidth, buttonHeight);
    self.cancelButton.frame = CGRectMake(separation, verticalFramePositionOffScreen + 2*separation + buttonHeight, buttonWidth, buttonHeight);
    self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    [UIView commitAnimations];
}

-(void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag{
    //TODO: also check for type of animation
    [self removeFromSuperview];
}


-(void)didPressCancelButton:(UIButton*)cancelButton{
    [self animateRemove];
    [self.delegate didPressCancelButton];
}
-(void)didPressReportButton:(UIButton*)reportButton{
    [self animateRemove];
    [self.delegate didPressReportButtonForContribution:self.contributionToReport];
}
@end
