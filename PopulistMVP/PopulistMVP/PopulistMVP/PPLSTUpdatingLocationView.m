//
//  PPLSTUpdatingLocationView.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 2/9/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTUpdatingLocationView.h"

@implementation PPLSTUpdatingLocationView

-(id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if(self){
//        float width = frame.size.width*0.2;
//        float height = width;
//        float x = (frame.size.width - width)/2.0;
//        float y = (frame.size.height - height)/2.0;
//        self.frame = CGRectMake(x, y, width, height);
//        self.layer.cornerRadius = 10.0;
        float width = frame.size.width;
        float height = frame.size.height;
        self.frame = frame;
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];

        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.center = CGPointMake(width/2.0, height/2.0);
        [self addSubview:spinner];
        [spinner startAnimating];
        

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, height*0.8, width, height*0.2)];
        label.font = [UIFont systemFontOfSize:20.0];
        label.textAlignment = NSTextAlignmentCenter;
        label.text = @"Updating your location...";
        label.textColor = [UIColor whiteColor];
        [label setNumberOfLines:0];
//        [label sizeToFit];
        [self addSubview:label];


//        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(width*0.1, width*0.1, width*0.8, height)];
//        label.font = [UIFont systemFontOfSize:25.0];
//        label.textAlignment = UITextAlignmentCenter;
//        label.text = @"Updating your location...";
//        label.textColor = [UIColor whiteColor];
//        [label setNumberOfLines:0];
//        [label sizeToFit];
//        [self addSubview:label];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end