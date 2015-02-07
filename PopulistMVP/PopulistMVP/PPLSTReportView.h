//
//  PPLSTReportView.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 2/6/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Contribution.h"

@protocol PPLSTReportViewDelegate <NSObject>
-(void) didPressReportButtonForContribution:(Contribution*) contribution;
-(void) didPressCancelButton;
@end


@interface PPLSTReportView : UIView
@property (strong, nonatomic) UIButton *reportButton;
@property (strong, nonatomic) UIButton *cancelButton;
@property (weak, nonatomic) Contribution *contributionToReport; //TODO: should it be weak or strong?
@property (weak, nonatomic) id <PPLSTReportViewDelegate> delegate;

-(instancetype)initWithFrame:(CGRect)frame andContribution:(Contribution*) contribution;
-(void) animateAdd;
@end
