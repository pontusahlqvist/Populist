//
//  PPLSTExploreTableViewController.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 1/8/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//TODO: add a progress spinner to loading photos

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

    self.locationManager = [[PPLSTLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.dataManager = [[PPLSTDataManager alloc] init];
    self.dataManager.delegate = self;
    self.dataManager.locationManager = self.locationManager;
    
    //set tableview delegates, datasource
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    //customize look of tableview
    [self.tableView setSeparatorColor:[UIColor colorWithRed:240.0f/255.0f green:91.0f/255.0f blue:98.0f/255.0f alpha:1.0f]];//[UIColor redColor]];
    [self.tableView setSeparatorInset:UIEdgeInsetsMake(0, 15, 10, 15)];
    
    //Initialize the refresh control.
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor colorWithRed:93.0f/255.0f green:151.0f/255.0f blue:174.0f/255.0f alpha:1.0f];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];

    [self updateEvents];
    [self setupChatButton];

}

//creates and adds the chat button that takes you to your local chat
-(void) setupChatButton{
    UIImage *image = [self imageWithImage:[UIImage imageNamed:@"compose.png"] scaledToSize:CGSizeMake(30.0, 30.0)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.bounds = CGRectMake( 0, 0, image.size.width, image.size.height);
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:@selector(openChat) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItem = barButtonItem;
}

//opens the local chat (this is different than looking at other chats in progress)
-(void) openChat{
    [self performSegueWithIdentifier:@"Segue To Chat" sender:self.navigationItem.rightBarButtonItem];
}

-(void)viewDidAppear:(BOOL)animated{
    self.locationManager.delegate = self;
    [self.dataManager resetImagesInMemory];
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
    [self.locationManager updateLocation];
}

-(void) finishUpdatingEvents{
    NSLog(@"finishUpdatingEvents");
    CLLocation *currentLocation = [self.locationManager getCurrentLocation];
    [self.locationManager updateLocationOfLastUpdate:currentLocation];
    [self.locationManager updateTimeOfLastUpdate:[NSDate date]];
    NSLog(@"Current Location - lat = %f and long = %f", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude);
    
    self.events = [[self.dataManager sendSignalAndDownloadEventMetaDataWithInputLatitude:currentLocation.coordinate.latitude andLongitude:currentLocation.coordinate.longitude andDate:[NSDate date]] mutableCopy];
    if([self.events count] > 0){
        self.currentEvent = [self.events objectAtIndex:0];
        self.tableView.backgroundView = nil;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
    
    [self removeInvisibleEvents];
    
    [self.tableView reloadData];
    NSLog(@"About to change isUpdatingEvents from %i", self.isUpdatingEvents);
    self.isUpdatingEvents = NO;
    NSLog(@"Now, it's equal to %i", self.isUpdatingEvents);
}

-(void) updateEvents{
    NSLog(@"updateEvents");
    if(!self.isUpdatingEvents){
        [self startUpdatingEvents];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"didReceiveMemoryWarning called in ExploreVC");
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

    if([self.events count] > 0){
        return 1;
    } else{
        UIImageView *backgroundImageView = [[UIImageView alloc] init];
        backgroundImageView.backgroundColor = [UIColor colorWithRed:93.0f/255.0f green:151.0f/255.0f blue:174.0f/255.0f alpha:1.0f];
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.center = CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0);
        [backgroundImageView addSubview:spinner];
        [spinner startAnimating];
        self.tableView.backgroundView = backgroundImageView;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        return 0;
    }
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    NSLog(@"Number of events: %li", (unsigned long)[self.events count]);
    return [self.events count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    return screenBounds.size.width + 10.0;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"indexPath.row = %li",(long)indexPath.row);
    PPLSTEventTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Event Cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.parentTableView = tableView;
    cell.titleImageView.image = nil;

    Event *event = self.events[indexPath.row];
    Contribution *titleContribution = event.titleContribution;

    //configure cell - lazy approach
    //TODO: decide on how to deal with events without a titleImage
    NSLog(@"Formatting Event Cell for contributionId = %@", titleContribution.contributionId);
    if([titleContribution.contributionType isEqualToString:@"photo"]){
        NSLog(@"Was a photo");
        if(titleContribution.imagePath && ![titleContribution.imagePath isEqualToString:@""]){
            NSLog(@"titleContribution.imagePath was set and not empty");
            /*TODO: for some reason it seems like the image is not persisted in the filesystem between runs if the app is run through xcode (even through a physical device). However, if the same app is run through the iphone directly, the data is persisted perfectly. One can get around this by checking to see if the file actually exists rather than simply checking if the imagePath property has been set in the contribution object.*/
            cell.titleImageView.image = [self.dataManager getImageAtFilePath:titleContribution.imagePath];
        } else{
            NSLog(@"titleContribution.imagePath was either empty or not set at all");
            //we must download the image from the cloud
            if(!self.isDecelerating && !self.isDragging){
                NSLog(@"calling formatEventCellForContribution");
                [self.dataManager formatEventCell:cell ForContribution:titleContribution]; //runs asynchronously in datamanager class
            }
        }
    }
    
    NSLog(@"finished!");

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
            destinationVC.locationManager = self.locationManager;
        }
    } else if([sender isKindOfClass:[UIBarButtonItem class]]){
        if([segue.destinationViewController isKindOfClass:[PPLSTChatViewController class]]){
            PPLSTChatViewController *destinationVC = segue.destinationViewController;
            destinationVC.event = self.currentEvent;
            destinationVC.dataManager = self.dataManager;
            destinationVC.locationManager = self.locationManager;
        }
    }
}

#pragma mark - PPLSTLocationManager Delegate Methods

-(void)locationUpdatedTo:(CLLocation *)newLocation From:(CLLocation *)oldLocation{
    NSLog(@"PPLSTExploreTablewViewController - locationUpdatedTo");
    //if the location is updated while we're loading events, we should continue to the next step and complete the loading process
    if(self.isUpdatingEvents){
        [self finishUpdatingEvents];
    } else if([self.locationManager movedTooFarFromLocationOfLastUpdate] || [self.locationManager waitedToLongSinceTimeOfLastUpdate]){
        //The user moved too far from the old location or they waited to long to refresh, so we update the events
        [self.locationManager updateTimeOfLastUpdate:[NSDate date]];
        [self.locationManager updateLocationOfLastUpdate:self.locationManager.currentLocation];
        [self.dataManager eventThatUserBelongsTo]; //note: this returns an event, but we'll deal with it on the delegate call instead
    }
}

-(void)didAcceptAuthorization{
    NSLog(@"didAcceptAuthorization triggered in ExploreVC");
    [self updateEvents];
}

//TODO: place a link to the settings page here
-(void)didDeclineAuthorization{
    NSLog(@"didDeclineAuthorization triggered in ExploreVC");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"In order for Populist to work, you must allow location services. Please go to the settings page for Populist and enable location services." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

#pragma mark - PPLSTDataManagerDelegate Methods

-(void)didUpdateImportanceOfEvent:(Event *)event From:(float)oldValue To:(float)newValue{
    if(oldValue < 1 && newValue > 1 && event.containsUser) [self.events insertObject:event atIndex:0]; //went from invisible to visible, so insert it first
    [self.tableView reloadData];
}

-(void)didUpdateTitleContributionForEvent:(Event *)event{
    [self.tableView reloadData];
}

-(void) didUpdateLastActiveForEvent:(Event*)event{
    [self.tableView reloadData];
}

-(void) updateEventsTo:(NSArray*)newEventsArray{
    NSLog(@"PPLSTExploreTableViewController - updateEventsTo:");
    self.events = [newEventsArray mutableCopy];
    self.currentEvent = [self.events objectAtIndex:0];
    [self removeInvisibleEvents];
    [self.tableView reloadData];
}

-(void) removeInvisibleEvents{
    NSMutableIndexSet *eventIndexesToRemove = [[NSMutableIndexSet alloc] init];
    int eventIndex = 0;
    for(Event *event in self.events){
        if([event.importance integerValue] < 1){
            [eventIndexesToRemove addIndex:eventIndex];
        }
        eventIndex++;
    }
    [self.events removeObjectsAtIndexes:eventIndexesToRemove];
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
    if([self.locationManager veryNearEvent:event]){
        return @"Here";
    }
    NSString *eventNeighborhood = [event.neighborhood stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *eventCity = [event.city stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *eventState = [event.state stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *eventCountry = [event.country stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    NSLog(@"self.location: -%@-%@-%@-%@",self.locationManager.country,self.locationManager.state,self.locationManager.city,self.locationManager.neighborhood);
    NSLog(@"event.location: -%@-%@-%@-%@",eventCountry, eventState, eventCity, eventNeighborhood);
    
    if([eventNeighborhood isEqualToString:self.locationManager.neighborhood] || [eventCity isEqualToString:self.locationManager.city]){
        return event.neighborhood;
    } else if([eventState isEqualToString:self.locationManager.state]){
        return event.city;
    } else if([eventCountry isEqualToString:self.locationManager.country]){
        return [NSString stringWithFormat:@"%@, %@", event.city, event.state];
    } else{
        return event.country;
    }
}

//TODO: fix the image compose.png to already be 30x30 with high quality so that this method is unnecessary
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

@end
