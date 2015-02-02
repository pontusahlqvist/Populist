//
//  PPLSTImagePickerController.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/18/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: make major edits to the image picker to make it look nice. Keep square images to avoid having to fix the exploreVC issues that come with non-standard image sizes
#import <UIKit/UIKit.h>

@protocol PPLSTImagePickerController <NSObject>

-(void) didFinishPickingImage:(UIImage*)image;
-(void) didCancelPickingImage;
@end

@interface PPLSTImagePickerController : UIImagePickerController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) UIButton *takePictureButton;
@property (strong, nonatomic) UIButton *reverseCameraButton;
@property (strong, nonatomic) UIButton *dismissCamera;
@property (weak, nonatomic) id<PPLSTImagePickerController> imagePickerDelegate;
@end
