//
//  PPLSTExploreTableViewController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/8/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTExploreTableViewController.h"
#import "PPLSTChatViewController.h"
#import "PPLSTEventTableViewCell.h"
#import <Parse/Parse.h>

@interface PPLSTExploreTableViewController ()
@property (nonatomic) BOOL isDecelerating;
@property (nonatomic) BOOL isDragging;

@end

@implementation PPLSTExploreTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    [self setCurrentLocationData]; //TODO: consider moving into separate class
    self.dataManager = [[PPLSTDataManager alloc] init];
    self.locationManager = [[PPLSTLocationManager alloc] init];
//    self.dataManager.delegate = self; //for location updates
    self.locationManager.delegate = self;
    
    //set tableview delegates, datasource
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    //customize look of tableview
    [self.tableView setSeparatorColor:[UIColor redColor]];
    [self.tableView setSeparatorInset:UIEdgeInsetsMake(0, 15, 10, 15)];
    
    //Initialize the refresh control.
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor colorWithRed:93.0f/255.0f green:151.0f/255.0f blue:174.0f/255.0f alpha:1.0f];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];

    //grab events with given location and time data - again, consider passing location data in via another class.
    [self updateEvents];
    
    UIImage *image = [self imageWithImage:[UIImage imageNamed:@"compose.png"] scaledToSize:CGSizeMake(30.0, 30.0)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.bounds = CGRectMake( 0, 0, image.size.width, image.size.height);
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:@selector(openChat) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItem = barButtonItem;
}

-(void) openChat{
    [self performSegueWithIdentifier:@"Segue To Chat" sender:self.navigationItem.rightBarButtonItem];
}

-(void)viewDidAppear:(BOOL)animated{
    //let the data manager know that this is the current VC
    self.dataManager.currentVC = self;
//    self.dataManager.delegate = self;
    self.locationManager.delegate = self;
}

//refresh the uitableview
-(void) refresh{
    //re-download the event meta data from the server
    [self updateEvents];
    [self.refreshControl endRefreshing];
}

-(void) startUpdatingEvents{
    NSLog(@"startUpdatingEvents");
    self.isUpdatingEvents = YES;
//    [self.dataManager updateLocation];
    [self.locationManager updateLocation];
}
-(void) finishUpdatingEvents{
    NSLog(@"finishUpdatingEvents");
//    CLLocation *currentLocation = [self.dataManager getCurrentLocation];
    CLLocation *currentLocation = [self.locationManager getCurrentLocation];
    NSLog(@"Current Location - lat = %f and long = %f", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude);
    self.events = [[self.dataManager downloadEventMetaDataWithInputLatitude:currentLocation.coordinate.latitude andLongitude:currentLocation.coordinate.longitude andDate:[NSDate date]] mutableCopy];
    [self.tableView reloadData];
    self.isUpdatingEvents = NO;
}

-(void) updateEvents{
    NSLog(@"updateEvents");
    [self startUpdatingEvents];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - lazy instantiations

-(NSMutableArray *)events{
    if(!_events) _events = [[NSMutableArray alloc] init];
    return _events;
}

#pragma mark - UITableView Delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"Selected Row Number %li",(long)indexPath.row);
    [self performSegueWithIdentifier:@"Segue To Chat" sender:indexPath];
}

#pragma mark - UITableView Data Source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    NSLog(@"Number of events: %li", [self.events count]);
    return [self.events count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    return screenBounds.size.width + 10.0;
//    return 340.0;
//    return 380.0;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"indexPath.row = %li",(long)indexPath.row);
    PPLSTEventTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Event Cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.parentTableView = tableView;

    Event *event = self.events[indexPath.row];
    Contribution *titleContribution = [event.titleContributions anyObject];

    //configure cell - lazy approach
    //TODO: include also the top few titleMessages
    NSLog(@"The contributionType is %@", titleContribution.contributionType);
    if([titleContribution.contributionType isEqualToString:@"photo"]){
        if(titleContribution.imagePath && ![titleContribution.imagePath isEqualToString:@""]){
            //TODO: consider loading image once-and-for-all into another object so that we avoid grabbing it from the filesystem each time we scroll by it
            cell.titleImageView.image = nil;

            /*TODO: for some reason it seems like the image is not persisted in the filesystem between runs if the app is run through xcode (even through a physical device). However, if the same app is run through the iphone directly, the data is persisted perfectly. One can get around this by checking to see if the file actually exists rather than simply checking if the imagePath property has been set in the contribution object.*/

            cell.titleImageView.image = [UIImage imageWithContentsOfFile:titleContribution.imagePath];
        } else{
            //we must download the image from the cloud
            cell.titleImageView.image = nil;
            if(!self.isDecelerating && !self.isDragging){
                [self.dataManager formatEventCell:cell ForContribution:titleContribution]; //runs asynchronously in datamanager class
            }
        }
    } else if([titleContribution.contributionType isEqualToString:@"message"]){ //TODO: do we need this? Shouldn't we only have images here?
        cell.titleImageView.image = nil; //just in case we dequed a cell with an image
        cell.textLabel.text = titleContribution.message;
    }

    cell.eventLocationTextLabel.text = [self locationStringForEvent:event];
    cell.eventTimeSinceActiveTextLabel.text = [self timeIntervalStringSinceDate:event.lastActive];
    return cell;
}

#pragma mark - UIScrollView Delegates dragging and decelerating

//These methods help with the lazy loading to ensure that we're not spending time loading cells that are being scrolled past
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    self.isDragging = NO;
    //only reload if both are false
    if(!self.isDecelerating){
        [self.tableView reloadData];
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    self.isDecelerating = NO;
    //only reload if both are false
    if(!self.isDragging){
        [self.tableView reloadData];
    }
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    self.isDragging = YES;
}
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
    self.isDecelerating = YES;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([sender isKindOfClass:[NSIndexPath class]]) {
        if([segue.destinationViewController isKindOfClass:[PPLSTChatViewController class]]){
            PPLSTChatViewController *destinationVC = segue.destinationViewController;
            NSIndexPath *indexPath = sender;
            destinationVC.event = self.events[indexPath.row];
            destinationVC.dataManager = self.dataManager;
        }
    }
}

#pragma mark - PPLSTLocationManager Delegate Methods

-(void)locationUpdatedTo:(CLLocation *)newLocation{
    NSLog(@"locationUpdatedTo triggered in ExploreVC");
    //if the location is updated while we're loading events, we should continue to the next step and complete the loading process
    if(self.isUpdatingEvents){
        [self finishUpdatingEvents];
    }
}

-(void)didAcceptAuthorization{
    NSLog(@"didAcceptAuthorization triggered in ExploreVC");
    [self updateEvents];
}

//TODO: implement an alert view etc here to make sure that the location services are enabled
-(void)didDeclineAuthorization{
    NSLog(@"didDeclineAuthorization triggered in ExploreVC");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"In order for Populist to work, you must allow location services. Please go to the settings page for Populist and enable location services." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Helper Methods

//returns a human readable time-since-event string (now, sec, min, h, d, w)
-(NSString *) timeIntervalStringSinceDate:(NSDate*) date{
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:date];
    
    if(timeInterval < 10){
        return @"Now";
    } else if(timeInterval < 60){
        return [NSString stringWithFormat:@"%isec",(int)timeInterval];
    } else if(timeInterval < 3600){
        return [NSString stringWithFormat:@"%imin",(int)(round(timeInterval/60))];
    } else if(timeInterval < 24*3600){
        return [NSString stringWithFormat:@"%ih",(int)(round(timeInterval/3600))];
    } else if(timeInterval < 24*3600*7){
        return [NSString stringWithFormat:@"%id",(int)(round(timeInterval/(3600*24)))];
    } else{
        return [NSString stringWithFormat:@"%iw",(int)(round(timeInterval/(3600*24*7)))];
    }
}

//returns location string relevant to this user (e.g. neighborhood if in the same city but only country if on the other side of the world)
-(NSString *) locationStringForEvent:(Event*)event{
    NSString *eventNeighborhood = [event.neighborhood stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *eventCity = [event.city stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *eventState = [event.state stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *eventCountry = [event.country stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if([eventNeighborhood isEqualToString:self.neighborhood] || [eventCity isEqualToString:self.city]){
        return event.neighborhood;
    } else if([eventState isEqualToString:self.state] || [eventCountry isEqualToString:self.country]){
        return event.city;
    } else{
        return event.country;
    }
}

//sets user's current location strings
-(void) setCurrentLocationData{
    //TODO: replace with correct code (google API)
    self.country = @"USA";
    self.state = @"California";
    self.city = @"Los Angeles";
    self.neighborhood = @"Venice Beach";
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

@end
