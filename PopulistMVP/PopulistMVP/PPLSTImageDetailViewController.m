//
//  PPLSTImageDetailViewController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/18/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//
//TODO: figure out why the buttons move when zooming.
#import "PPLSTImageDetailViewController.h"

@interface PPLSTImageDetailViewController ()
@property (strong, nonatomic) UIImageView *imageView;
- (void)centerScrollViewContents;
- (void)scrollViewDoubleTapped:(UITapGestureRecognizer*)recognizer;
- (void)scrollViewTwoFingerTapped:(UITapGestureRecognizer*)recognizer;
@end

@implementation PPLSTImageDetailViewController

BOOL showControls = YES;
float padding = 20.0; //padding between the close button and the edge

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
    showControls = YES;
    
    UIImage *buttonImage = [UIImage imageNamed:@"close"];
    self.closeDetailImageButton = [[UIButton alloc] initWithFrame:CGRectMake(padding, padding, buttonImage.size.width, buttonImage.size.height)];
    [self.closeDetailImageButton setImage:buttonImage forState:UIControlStateNormal];
    [self.closeDetailImageButton addTarget:self action:@selector(closeDetailImageButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeDetailImageButton];
    
    //setup scroll view
    self.imageScrollView.delegate = self;
    self.imageView = [[UIImageView alloc] initWithImage:self.image];
    self.imageView.frame = (CGRect){.origin=CGPointMake(0.0f, 0.0f), .size=self.image.size};
    [self.imageScrollView addSubview:self.imageView];
    self.imageScrollView.contentSize = self.image.size;

    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewDoubleTapped:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [self.imageScrollView addGestureRecognizer:doubleTapRecognizer];

    UITapGestureRecognizer *twoFingerTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTwoFingerTapped:)];
    twoFingerTapRecognizer.numberOfTapsRequired = 1;
    twoFingerTapRecognizer.numberOfTouchesRequired = 2;
    [self.imageScrollView addGestureRecognizer:twoFingerTapRecognizer];

    UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewSingleTapped:)];
    singleTapGestureRecognizer.numberOfTapsRequired = 1;
    singleTapGestureRecognizer.enabled = YES;
    singleTapGestureRecognizer.cancelsTouchesInView = NO;
    [self.imageScrollView addGestureRecognizer:singleTapGestureRecognizer];

    UIImage *image = [UIImage imageNamed:@"flag_glyph"];
    self.flagContentButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.flagContentButton.frame = CGRectMake(self.view.frame.size.width - padding - image.size.width, padding, image.size.width, image.size.height);
    [self.flagContentButton setImage:image forState:UIControlStateNormal];
    [self.flagContentButton addTarget:self action:@selector(flagContentPressed:) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.flagContentButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
 
    CGRect scrollViewFrame = self.imageScrollView.frame;
    CGFloat scaleWidth = scrollViewFrame.size.width / self.imageScrollView.contentSize.width;
    CGFloat scaleHeight = scrollViewFrame.size.height / self.imageScrollView.contentSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    self.imageScrollView.minimumZoomScale = minScale;
    
    self.imageScrollView.maximumZoomScale = 2.0f;
    self.imageScrollView.zoomScale = minScale;
 
    [self centerScrollViewContents];
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

-(void) flagContentPressed:(UIBarButtonItem*)flagBarButtonItem{
    self.reportView = [[PPLSTReportView alloc] initWithFrame:[[[UIApplication sharedApplication] keyWindow] bounds] andContribution:self.contribution];
    self.reportView.delegate = self;
    [[[UIApplication sharedApplication] keyWindow] addSubview:self.reportView];
    [self.reportView animateAdd];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIScrollViewDelegate Methods

- (void)centerScrollViewContents {
    CGSize boundsSize = self.imageScrollView.bounds.size;
    CGRect contentsFrame = self.imageView.frame;
 
    if (contentsFrame.size.width < boundsSize.width) {
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0f;
    } else {
        contentsFrame.origin.x = 0.0f;
    }
 
    if (contentsFrame.size.height < boundsSize.height) {
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0f;
    } else {
        contentsFrame.origin.y = 0.0f;
    }
 
    self.imageView.frame = contentsFrame;
}

- (void)scrollViewDoubleTapped:(UITapGestureRecognizer*)recognizer {
    CGPoint pointInView = [recognizer locationInView:self.imageView];
 
    CGFloat newZoomScale = self.imageScrollView.zoomScale * 1.5f;
    newZoomScale = MIN(newZoomScale, self.imageScrollView.maximumZoomScale);
 
    CGSize scrollViewSize = self.imageScrollView.bounds.size;
 
    CGFloat w = scrollViewSize.width / newZoomScale;
    CGFloat h = scrollViewSize.height / newZoomScale;
    CGFloat x = pointInView.x - (w / 2.0f);
    CGFloat y = pointInView.y - (h / 2.0f);
 
    CGRect rectToZoomTo = CGRectMake(x, y, w, h);
 
    [self.imageScrollView zoomToRect:rectToZoomTo animated:YES];
}

- (void)scrollViewTwoFingerTapped:(UITapGestureRecognizer*)recognizer {
    // Zoom out slightly, capping at the minimum zoom scale specified by the scroll view
    CGFloat newZoomScale = self.imageScrollView.zoomScale / 1.5f;
    newZoomScale = MAX(newZoomScale, self.imageScrollView.minimumZoomScale);
    [self.imageScrollView setZoomScale:newZoomScale animated:YES];
}

- (UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    // Return the view that you want to zoom
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    // The scroll view has zoomed, so you need to re-center the contents
    [self centerScrollViewContents];
}

-(void)scrollViewSingleTapped:(UIScrollView*)scrollView{
    showControls = !showControls;
    [self toggleControlsToState:showControls withDuration:0.25];
}

-(void) toggleControlsToState:(BOOL)show withDuration:(float)duration{
    float closeButtonWidth = self.closeDetailImageButton.frame.size.width;
    float closeButtonHeight = self.closeDetailImageButton.frame.size.height;
    float flagButtonWidth = self.flagContentButton.frame.size.width;
    float flagButtonHeight = self.flagContentButton.frame.size.height;
    if(show){
        NSLog(@"showing controls!");
        [UIView animateWithDuration:duration animations:^{
            self.closeDetailImageButton.frame = CGRectMake(padding, padding, closeButtonWidth, closeButtonHeight);
            self.closeDetailImageButton.alpha = 1.0;
            self.flagContentButton.frame = CGRectMake(self.view.frame.size.width - padding - flagButtonWidth, padding, flagButtonWidth, flagButtonHeight);
            self.flagContentButton.alpha = 1.0;
        }];
    } else{
        NSLog(@"hiding controls!");
        [UIView animateWithDuration:duration animations:^{
            self.closeDetailImageButton.frame = CGRectMake(padding, -closeButtonHeight, closeButtonWidth, closeButtonHeight);
            self.closeDetailImageButton.alpha = 0.0;
            self.flagContentButton.frame = CGRectMake(self.view.frame.size.width - padding - flagButtonWidth, -flagButtonHeight, flagButtonWidth, flagButtonHeight);
            self.flagContentButton.alpha = 0.0;
        }];
    }
}

#pragma mark - Button Presses

-(void) closeDetailImageButtonPressed:(UIButton*)closeDetailImageButton{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - PPLLSTReportViewDelegate Methods

-(void) didPressCancelButton{}
-(void) didPressReportButtonForContribution:(Contribution *)contribution{
    [self.dataManager flagContribution:contribution];
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

//scales the image down to a given size
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
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
