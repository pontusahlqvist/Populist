//
//  PPLSTImagePickerController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/18/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: make the image processing faster!

#import "PPLSTImagePickerController.h"

@interface PPLSTImagePickerController ()

@end

@implementation PPLSTImagePickerController

-(UIView *)previewBackgroundView{
    if(!_previewBackgroundView) _previewBackgroundView = [[UIView alloc] init];
    return _previewBackgroundView;
}

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
    float height = self.view.bounds.size.height;
    float width = self.view.bounds.size.width;
    
    UIView *overlayTop = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, (height-width)/2.0 - 4.0)];
    UIView *overlayBottom = [[UIView alloc] initWithFrame:CGRectMake(0.0, (height+width)/2.0 + 4.0, width, (height-width)/2.0)];

    overlayTop.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5f];
    overlayBottom.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5f];

    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(width/10.0, (height-width)/2.0-2, width*4.0/5.0, 2.0)];
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(width/10.0, (height+width)/2.0, width*4.0/5.0, 2.0)];

    topBar.backgroundColor = [UIColor colorWithRed:240.0f/255.0f green:91.0f/255.0f blue:98.0f/255.0f alpha:1.0f];
    bottomBar.backgroundColor = [UIColor colorWithRed:240.0f/255.0f green:91.0f/255.0f blue:98.0f/255.0f alpha:1.0f];


    self.takePictureButton = [[UIButton alloc] init];
    [self.takePictureButton setImage:[UIImage imageNamed:@"takePicture@2x.png"] forState:UIControlStateNormal];
    self.takePictureButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.takePictureButton addTarget:self action:@selector(handleTakePictureButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [overlayBottom addConstraint:[NSLayoutConstraint constraintWithItem:self.takePictureButton
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayBottom
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.0f
                                                           constant:0.0f]];
    [overlayBottom addConstraint:[NSLayoutConstraint constraintWithItem:self.takePictureButton
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayBottom
                                                          attribute:NSLayoutAttributeCenterY
                                                         multiplier:1.0f
                                                           constant:0.0f]];
    [overlayBottom addSubview:self.takePictureButton];
    
    self.dismissCamera = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.dismissCamera.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dismissCamera setTitle:@"Cancel" forState:UIControlStateNormal];
    [self.dismissCamera.titleLabel setFont:[UIFont systemFontOfSize:20.0f]];
    [self.dismissCamera setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.dismissCamera sizeToFit];
    [self.dismissCamera addTarget:self action:@selector(handleCancelButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [overlayBottom addConstraint:[NSLayoutConstraint constraintWithItem:self.dismissCamera
                                                          attribute:NSLayoutAttributeLeft
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayBottom
                                                          attribute:NSLayoutAttributeLeft
                                                         multiplier:1.0f
                                                           constant:10.0f]];
    [overlayBottom addConstraint:[NSLayoutConstraint constraintWithItem:self.dismissCamera
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayBottom
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0f
                                                           constant:-10.0f]];
    [overlayBottom addSubview:self.dismissCamera];
    
    
    
    
    self.reverseCameraButton = [[UIButton alloc] init];
    [self.reverseCameraButton setImage:[UIImage imageNamed:@"reverseCameraWhite32.png"] forState:UIControlStateNormal];
    self.reverseCameraButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.reverseCameraButton addTarget:self action:@selector(handleReverseCameraButton:) forControlEvents:UIControlEventTouchUpInside];
    [overlayTop addConstraint:[NSLayoutConstraint constraintWithItem:self.reverseCameraButton
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayTop
                                                          attribute:NSLayoutAttributeRight
                                                         multiplier:1.0f
                                                           constant:-30.0f]];
    [overlayTop addConstraint:[NSLayoutConstraint constraintWithItem:self.reverseCameraButton
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayTop
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0f
                                                           constant:25.0f]];
    [overlayTop addSubview:self.reverseCameraButton];
    
    self.toggleFlash = [[UIButton alloc] init];

    NSString *flashPreference = [[NSUserDefaults standardUserDefaults] objectForKey:@"flashPreference"];
    if([flashPreference isEqualToString:@"auto"]){
        self.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        [self.toggleFlash setImage:[UIImage imageNamed:@"flashAuto_glyph"] forState:UIControlStateNormal];
    } else if([flashPreference isEqualToString:@"on"]){
        self.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        [self.toggleFlash setImage:[UIImage imageNamed:@"flashOn_glyph"] forState:UIControlStateNormal];
    } else{
        self.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        [self.toggleFlash setImage:[UIImage imageNamed:@"flashOff_glyph"] forState:UIControlStateNormal];
    }
    
    self.toggleFlash.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toggleFlash addTarget:self action:@selector(handleToggleFlash:) forControlEvents:UIControlEventTouchUpInside];
    [overlayTop addConstraint:[NSLayoutConstraint constraintWithItem:self.toggleFlash
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayTop
                                                          attribute:NSLayoutAttributeLeft
                                                         multiplier:1.0f
                                                           constant:30.0f]];
    [overlayTop addConstraint:[NSLayoutConstraint constraintWithItem:self.toggleFlash
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:overlayTop
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0f
                                                           constant:25.0f]];
    [overlayTop addSubview:self.toggleFlash];

    
    self.showsCameraControls = NO;
    [self.cameraOverlayView addSubview:topBar];
    [self.cameraOverlayView addSubview:bottomBar];
    [self.cameraOverlayView addSubview:overlayTop];
    [self.cameraOverlayView addSubview:overlayBottom];

    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    float cameraAspectRatio = 4.0/3.0; //TODO: check for different screen sizes to support multiple iPhone models
    float imageHeight = screenSize.width * cameraAspectRatio;
    float scale = screenSize.height / imageHeight;

    CGAffineTransform cameraTransform = CGAffineTransformMakeScale(scale, scale);
    CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0.0, (scale*imageHeight - imageHeight)/2.0);
    self.cameraViewTransform = CGAffineTransformConcat(cameraTransform, translationTransform);
    
    self.delegate = self;

}

-(void) handleTakePictureButton:(UIButton*) takePictureButton{
    NSLog(@"taking picture!!");
    [self takePicture];
}

-(void) handleReverseCameraButton:(UIButton*) reverseCameraButton{
    //reverse camera
    NSLog(@"reverse Camera");
    if(self.cameraDevice == UIImagePickerControllerCameraDeviceFront){
    [UIView transitionWithView:self.view duration:1.0 options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionTransitionFlipFromLeft animations:^{
            self.cameraDevice = UIImagePickerControllerCameraDeviceRear;
            //reset the flash image to the appropriate value
            if(self.cameraFlashMode == UIImagePickerControllerCameraFlashModeAuto){
                [self.toggleFlash setImage:[UIImage imageNamed:@"flashAuto_glyph"] forState:UIControlStateNormal];
            } else if(self.cameraFlashMode == UIImagePickerControllerCameraFlashModeOff){
                [self.toggleFlash setImage:[UIImage imageNamed:@"flashOff_glyph"] forState:UIControlStateNormal];
            } else{
                [self.toggleFlash setImage:[UIImage imageNamed:@"flashOn_glyph"] forState:UIControlStateNormal];
            }

        } completion:NULL];
    } else{
    [UIView transitionWithView:self.view duration:1.0 options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionTransitionFlipFromLeft animations:^{
            self.cameraDevice = UIImagePickerControllerCameraDeviceFront;
            [self.toggleFlash setImage:[UIImage imageNamed:@"flashOff48.png"] forState:UIControlStateNormal];
        } completion:NULL];
        self.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    }
}

-(void) handleCancelButton:(UIButton*) dismissCameraButton{
    NSLog(@"handleCancelButton");
    [self.imagePickerDelegate didCancelPickingImage];
}

-(void) handleToggleFlash:(UIButton*)toggleFlashButton{
    NSLog(@"handleToggleFlash");
    if(self.cameraDevice == UIImagePickerControllerCameraDeviceFront){
        //can't toggle flash when front facing.
        return;
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if(self.cameraFlashMode == UIImagePickerControllerCameraFlashModeAuto){
        self.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        [self.toggleFlash setImage:[UIImage imageNamed:@"flashOff_glyph"] forState:UIControlStateNormal];
        [userDefaults setObject:@"off" forKey:@"flashPreference"];
    } else if(self.cameraFlashMode == UIImagePickerControllerCameraFlashModeOff){
        self.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        [self.toggleFlash setImage:[UIImage imageNamed:@"flashOn_glyph"] forState:UIControlStateNormal];
        [userDefaults setObject:@"on" forKey:@"flashPreference"];
    } else{
        self.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        [self.toggleFlash setImage:[UIImage imageNamed:@"flashAuto_glyph"] forState:UIControlStateNormal];
        [userDefaults setObject:@"auto" forKey:@"flashPreference"];
    }
    [userDefaults synchronize];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    NSLog(@"PPLSTImagePickerController - imagePickerController didFinishPicking!");

    UIImage *originalImage = info[UIImagePickerControllerOriginalImage];
    UIImage *flippedImage = [self flipImageCorrectly:originalImage];
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    float cropSize = flippedImage.size.height*screenSize.width/screenSize.height;
    float x = 0.5*(flippedImage.size.width - cropSize);
    float y = 0.5*(flippedImage.size.height - cropSize);
    NSLog(@"x = %f, y = %f, cropSize = %f", x, y, cropSize);
    
    UIImage *croppedImage = [self cropImage:flippedImage ToRect:CGRectMake(x, y, cropSize, cropSize)];
    UIImage *scaledImage = [self imageWithImage:croppedImage scaledDownToHorizontalPoints:750.0];
    self.chosenImage = scaledImage;
    [self showImagePreview];
}

-(void) showImagePreview{
    float screenWidth = self.view.bounds.size.width;
    float screenHeight = self.view.bounds.size.height;
    self.previewBackgroundView.frame = CGRectMake(0.0, 0.0, screenWidth, screenHeight);
    [self.previewBackgroundView setBackgroundColor:[UIColor blackColor]];

    UIImageView *previewImage = [[UIImageView alloc] initWithImage:self.chosenImage];
    previewImage.frame = CGRectMake(0.0, (screenHeight-screenWidth)/2.0, screenWidth, screenWidth);
    previewImage.image = self.chosenImage;
    [self.previewBackgroundView addSubview:previewImage];

    UIButton *acceptImageButton = [[UIButton alloc] init];
    [acceptImageButton setImage:[UIImage imageNamed:@"accept@2x.png"] forState:UIControlStateNormal];
    acceptImageButton.translatesAutoresizingMaskIntoConstraints = NO;
    [acceptImageButton addTarget:self action:@selector(handleAcceptImage:) forControlEvents:UIControlEventTouchUpInside];
    [self.previewBackgroundView addConstraint:[NSLayoutConstraint constraintWithItem:acceptImageButton
                                                          attribute:NSLayoutAttributeRight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.previewBackgroundView
                                                          attribute:NSLayoutAttributeRight
                                                         multiplier:1.0f
                                                           constant:-30.0f]];
    [self.previewBackgroundView addConstraint:[NSLayoutConstraint constraintWithItem:acceptImageButton
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.previewBackgroundView
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0f
                                                           constant:-30.0f]];
    [self.previewBackgroundView addSubview:acceptImageButton];


    UIButton *retakeImageButton = [[UIButton alloc] init];
    [retakeImageButton setImage:[UIImage imageNamed:@"cancel@2x.png"] forState:UIControlStateNormal];
    retakeImageButton.translatesAutoresizingMaskIntoConstraints = NO;
    [retakeImageButton addTarget:self action:@selector(handleRetakeImage:) forControlEvents:UIControlEventTouchUpInside];
    [self.previewBackgroundView addConstraint:[NSLayoutConstraint constraintWithItem:retakeImageButton
                                                          attribute:NSLayoutAttributeLeft
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.previewBackgroundView
                                                          attribute:NSLayoutAttributeLeft
                                                         multiplier:1.0f
                                                           constant:30.0f]];
    [self.previewBackgroundView addConstraint:[NSLayoutConstraint constraintWithItem:retakeImageButton
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.previewBackgroundView
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0f
                                                           constant:-30.0f]];
    [self.previewBackgroundView addSubview:retakeImageButton];

    [self.view addSubview:self.previewBackgroundView];
}

-(void) handleAcceptImage:(UIButton*) acceptImageButton{
    NSLog(@"handleAcceptImage");
    [self.imagePickerDelegate didFinishPickingImage:self.chosenImage];
}
-(void) handleRetakeImage:(UIButton*)retakeImageButton{
    NSLog(@"handleRetakeImage");
    [self.previewBackgroundView removeFromSuperview];
}

#pragma mark - Image Manipulation Methods

//scales down an image to the given horizontal size while maintaining the proportions
-(UIImage*) imageWithImage:(UIImage*)image scaledDownToHorizontalPoints:(float)horizontal{
    return [self imageWithImage:image scaledToSize:CGSizeMake(horizontal,(image.size.height/image.size.width)*horizontal)];
}

//scales the image down to a given size
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

-(UIImage*) cropImage:(UIImage*)image ToRect:(CGRect)rect{
    UIGraphicsBeginImageContextWithOptions(rect.size, false, [image scale]);
    NSLog(@"image scale = %f", [image scale]);
    NSLog(@"rect.size.width = %f, rect.size.height = %f", rect.size.width, rect.size.height);
    [image drawAtPoint:CGPointMake(-rect.origin.x, -rect.origin.y)];
    UIImage *cropped_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return cropped_image;
}


-(UIImage*) flipImageCorrectly:(UIImage*)inputImage{
    NSLog(@"PPLSTChatViewController - flipImageCorrectly:%@",inputImage);

    CGAffineTransform transform = CGAffineTransformIdentity;
    NSLog(@"transform before: %f,%f,%f,%f,%f,%f", transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty);
    switch (inputImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, inputImage.size.width, inputImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;

        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, inputImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;

        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, inputImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }

    CIImage* coreImage = inputImage.CIImage;

    if (!coreImage) {
        coreImage = [CIImage imageWithCGImage:inputImage.CGImage];
    }

    coreImage = [coreImage imageByApplyingTransform:transform];
    UIImage *newImage = [UIImage imageWithCIImage:coreImage];

    NSLog(@"image - %f,%f", newImage.size.width, newImage.size.height);
    return newImage;
}


-(UIImage*) cropImage:(UIImage*)originalImage AndScaleToPoints:(float)newWidth{
    NSLog(@"PPLSTChatViewController - cropImage:%@ AndScaleToPoints:%f",originalImage,newWidth);
    UIImage *rotatedImage = [self flipImageCorrectly:originalImage];

    float imageWidth = originalImage.size.width;
    float imageHeight = originalImage.size.height;
    NSLog(@"size - %f,%f", originalImage.size.width, originalImage.size.height);
    UIImage *croppedImage;
    if(imageHeight > imageWidth){
        croppedImage = [self cropImage:rotatedImage ToRect:CGRectMake(0.0, (imageHeight - imageWidth)/2.0, imageWidth, imageWidth)];
    } else{
        croppedImage = [self cropImage:rotatedImage ToRect:CGRectMake((imageWidth-imageHeight)/2.0, 0.0, imageHeight, imageHeight)];
    }
    NSLog(@"image size = %f,%f", croppedImage.size.width, croppedImage.size.height);
    return [self imageWithImage:croppedImage scaledDownToHorizontalPoints:newWidth];
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
