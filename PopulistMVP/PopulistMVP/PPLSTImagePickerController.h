//
//  PPLSTImagePickerController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/18/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PPLSTImagePickerController <NSObject>

-(void) didFinishPickingImage:(UIImage*)image;
-(void) didCancelPickingImage;
@end

@interface PPLSTImagePickerController : UIImagePickerController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) UIButton *takePictureButton;
@property (strong, nonatomic) UIButton *reverseCameraButton;
@property (strong, nonatomic) UIButton *dismissCamera;
@property (strong, nonatomic) UIButton *toggleFlash;
@property (weak, nonatomic) id<PPLSTImagePickerController> imagePickerDelegate;
@property (strong, nonatomic) UIImage *chosenImage;
@property (strong, nonatomic) UIView *previewBackgroundView;
@end
