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
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setCurrentLocationData];
    self.dataManager = [[PPLSTDataManager alloc] init];
    
    //set tableview delegates, datasource
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView setSeparatorColor:[UIColor redColor]];
    [self.tableView setSeparatorInset:UIEdgeInsetsMake(0, 15, 10, 15)];
    
    // Initialize the refresh control.
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor colorWithRed:93.0f/255.0f green:151.0f/255.0f blue:174.0f/255.0f alpha:1.0f];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    
    
    self.events = [[self.dataManager downloadEventMetaDataWithInputLatitude:0 andLongitude:0 andDate:[NSDate date]] mutableCopy];
}

-(void) refresh{
    [self.dataManager downloadEventMetaDataWithInputLatitude:0.0 andLongitude:0.0 andDate:[NSDate date]];
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
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
    NSLog(@"Selected Row Number %i",indexPath.row);
    [self performSegueWithIdentifier:@"Segue To Chat" sender:indexPath];
}

#pragma mark - UITableView Data Source

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"indexPath.row = %i",indexPath.row);
    PPLSTEventTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Event Cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.parentTableView = tableView;

    Event *event = self.events[indexPath.row];
    Contribution *titleContribution = [event.titleContributions anyObject];

    //configure cell - lazy approach
    //TODO: include also the top few titleMessages
    if([titleContribution.contributionType isEqualToString:@"photo"]){
        //this title contribution is a photo
        if(![titleContribution.imagePath isEqualToString:@""] && titleContribution.imagePath){
            cell.titleImageView.image = [UIImage imageWithContentsOfFile:titleContribution.imagePath];
        } else{
            //we must download the image from the cloud
            cell.titleImageView.image = nil;
            if(!self.isDecelerating && !self.isDragging){
                [self.dataManager formatEventCell:cell ForContribution:titleContribution];
            }
        }
    } else if([titleContribution.contributionType isEqualToString:@"message"]){
        //this title contribution is a message
        cell.textLabel.text = titleContribution.message;
    }

    cell.eventLocationTextLabel.text = [self locationStringForEvent:event];
    cell.eventTimeSinceActiveTextLabel.text = [self timeIntervalStringSinceDate:event.lastActive];
    return cell;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [self.events count];
}
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 340.0;
}

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

#pragma mark - UIScrollView Delegates dragging and decelerating

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


#pragma mark - Helper Methods

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
    } else{
        return [NSString stringWithFormat:@"%id",(int)(round(timeInterval/(3600*24)))];
    }
}


-(NSString *) locationStringForEvent:(Event*)event{
    if([event.neighborhood isEqualToString:self.neighborhood] || [event.city isEqualToString:self.city]){
        return event.neighborhood;
    } else if([event.state isEqualToString:self.state] || [event.country isEqualToString:self.country]){
        return event.city;
    } else{
        return event.country;
    }
}

-(void) setCurrentLocationData{
    //TODO: replace with correct code
    self.country = @"USA";
    self.state = @"California";
    self.city = @"Los Angeles";
    self.neighborhood = @"Venice Beach";
}


@end
