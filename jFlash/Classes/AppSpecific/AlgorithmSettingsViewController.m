//
//  algorithmSettingsViewController.m
//  jFlash
//
//  Created by シャロット ロス on 6/9/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "AlgorithmSettingsViewController.h"
#import "LWELocalization.h"

#define FREQUENCY_SLIDER_TAG 100
#define MAX_CARDS_SLIDER_TAG 101

@implementation AlgorithmSettingsViewController
@synthesize maxCardsSlider, frequencySlider, difficultySegmentControl, tableView;

enum AlgorithmSections {
  kControlsSection = 0,
  kFrequencyMultiplierSection = 1,
  kShowBuriedCardsSection = 2,
  NUM_SECTIONS
};

enum ControlSectionRows
{
  kMaxCardsRow = 0,
  NUM_CONTROL_SECTION_ROWS
};

#pragma mark - UIViewController Methods

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.navigationItem.title = NSLocalizedString(@"Change Difficulty",@"AlgorithmSettingsViewController.NavBarTitle");
  // Easy / Medium / Hard / Custom segment titles come from the XIB (Interface.strings)
  LWELocalizeInterface(self.view);
  LWELocalizeInterface(self.difficultySegmentControl);

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  self.maxCardsSlider.minimumValue = MIN_MAX_STUDYING;
  self.maxCardsSlider.maximumValue = MAX_MAX_STUDYING;
  self.maxCardsSlider.tag = MAX_CARDS_SLIDER_TAG;
  self.maxCardsSlider.value = (CGFloat)[settings integerForKey:APP_MAX_STUDYING];

  self.frequencySlider.minimumValue = MIN_FREQUENCY_MULTIPLIER;
  self.frequencySlider.maximumValue = MAX_FREQUENCY_MULTIPLIER;
  self.frequencySlider.tag = FREQUENCY_SLIDER_TAG;
  self.frequencySlider.value = (CGFloat)[settings integerForKey:APP_FREQUENCY_MULTIPLIER];

  self.difficultySegmentControl.selectedSegmentIndex = [settings integerForKey:APP_DIFFICULTY];

  // Build a table header view so the segment control sits inside the scroll area
  // and is never obscured by the navigation bar.
  CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
  UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 74)];
  headerView.backgroundColor = [UIColor clearColor];
  headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

  UILabel *diffLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, screenWidth - 32, 26)];
  diffLabel.text = NSLocalizedString(@"Difficulty", @"AlgorithmVC.Difficulty");
  diffLabel.font = [UIFont boldSystemFontOfSize:17];
  diffLabel.textColor = [UIColor colorWithRed:0.233f green:0.265f blue:0.348f alpha:0.89f];
  diffLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [headerView addSubview:diffLabel];
  [diffLabel release];

  self.difficultySegmentControl.frame = CGRectMake(16, 44, screenWidth - 32, 32);
  self.difficultySegmentControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [headerView addSubview:self.difficultySegmentControl];

  self.tableView.tableHeaderView = headerView;
  [headerView release];

  [self setDifficulty:self.difficultySegmentControl];
}

- (void)viewDidUnload 
{
  [super viewDidUnload];
  self.maxCardsSlider = nil;
  self.frequencySlider = nil;
  self.difficultySegmentControl = nil;
  self.tableView = nil;
}

- (void)viewWillAppear:(BOOL)animated 
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  self.difficultySegmentControl.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];

  // TODO: iPad customization!
  self.view.backgroundColor = [[ThemeManager sharedThemeManager] backgroundColor];
  self.tableView.backgroundColor = [UIColor clearColor];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
  return NUM_SECTIONS;
}

// these numbers are controlled by enums at top of this page
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
  return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)lcltableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  if(indexPath.section == kControlsSection)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"maxCards" onTable:lcltableView usingStyle:UITableViewCellStyleValue1];
    // TODO: iPad customization!
    self.maxCardsSlider.frame = CGRectMake(40, 0, 230, 48);

    // the label on the left of the cell
    // TODO: iPad customization!
    UILabel *leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 5, 20, 35)];
    leftLabel.font = [UIFont boldSystemFontOfSize:17];
    leftLabel.text = [NSString stringWithFormat:@"%d", MIN_MAX_STUDYING];
    [cell addSubview:leftLabel];
    [leftLabel release];
    
    // the slider
    [cell addSubview:self.maxCardsSlider];
    
    // the label on the right
    // TODO: iPad customization!
    UILabel *rightLabel = [[UILabel alloc] initWithFrame:CGRectMake(280, 5, 20, 35)];
    // TODO: iPad customization!
    rightLabel.font = [UIFont boldSystemFontOfSize:17];
    rightLabel.text = [NSString stringWithFormat:@"%d", MAX_MAX_STUDYING];
    [cell addSubview:rightLabel];
    
    [rightLabel release];
  }
  else if (indexPath.section == kFrequencyMultiplierSection)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"frequency" onTable:lcltableView usingStyle:UITableViewCellStyleValue1];

    // TODO: iPad customization!
    self.frequencySlider.frame = CGRectMake(20, 0, 180, 50);
    [cell addSubview:self.frequencySlider];
    // TODO: iPad customization!
    UILabel *rightLabel = [[UILabel alloc] initWithFrame:CGRectMake(210, 5, 95, 35)];
    // TODO: iPad customization!
    rightLabel.font = [UIFont boldSystemFontOfSize:17];
    rightLabel.text = NSLocalizedString(@"More Often", @"AlgorithmVC.NewCardFrequency_MoreOften");
    [cell addSubview:rightLabel];
    [rightLabel release];
  }
  else if (indexPath.section == kShowBuriedCardsSection)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"showBuried" onTable:lcltableView usingStyle:UITableViewCellStyleDefault];
    BOOL hideBuriedCard = [settings boolForKey:APP_HIDE_BURIED_CARDS];
    
    cell.textLabel.text = NSLocalizedString(@"Hide Learned Cards",@"AlgorithmVC.HideLearnedCards");
    
    //Documentation says that the size component will be completely ignored
    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    [switchView setOn:hideBuriedCard];
    [switchView addTarget:self action:@selector(switchView_eventValueChanged:) forControlEvents:UIControlEventValueChanged];
    [cell setAccessoryView:switchView];
    [switchView release];
  }
  else 
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"cell" onTable:lcltableView usingStyle:UITableViewCellStyleDefault];
  }
  
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  return cell;  
}

#pragma mark - UITableViewDelegate Methods

- (NSString*) tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
  NSString *returnVal = nil;
  if (section == kControlsSection)
  {
    returnVal = NSLocalizedString(@"Number of Cards in Study Pool",@"AlgorithmVC.NumberCards");
  }
  else if (section == kFrequencyMultiplierSection)
  {
    returnVal = NSLocalizedString(@"Frequency of New Cards",@"AlgorithmVC.NewCardFrequency");
  }
  return returnVal;
}

#pragma mark - UISegmentedControl

/**
 * Sets the ui sliders values based on the segmented value selected by the user
 * \param sender UISegmentedControl object that called this
 */
- (IBAction) setDifficulty:(UISegmentedControl *)sender
{
  NSInteger selectedIndex = [sender selectedSegmentIndex];
  LWE_ASSERT_EXC((selectedIndex < 4),@"We should only have 4 levels, zero-indexed (0,1,2,3).");
  
  // store the result
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];  
  [settings setInteger:selectedIndex forKey:APP_DIFFICULTY];
  
  if (selectedIndex == 3)
  {
    // The last index - custom value
    self.maxCardsSlider.enabled = YES;
    self.frequencySlider.enabled = YES;
  }
  else
  {
    // Otherwise pull from these predefined values
    NSInteger maxCardsValue[3] = {10,30,40};
    NSInteger freqValue[3] = {1,2,3};
    self.maxCardsSlider.enabled = NO;
    self.frequencySlider.enabled = NO;
    self.maxCardsSlider.value = maxCardsValue[selectedIndex];
    self.frequencySlider.value = freqValue[selectedIndex];
  }
  
  // Manually update the values
  [self sliderValueChanged:self.maxCardsSlider];
  [self sliderValueChanged:self.frequencySlider];
}

#pragma mark - Slider

- (IBAction)sliderValueChanged:(UISlider *)sender
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSInteger value = lroundf([sender value]);
  if(sender.tag == MAX_CARDS_SLIDER_TAG)
  {
    LWE_ASSERT_EXC((value >= MIN_MAX_STUDYING),@"Trying to set max studying to be lower than minimum");
    LWE_ASSERT_EXC((value <= MAX_MAX_STUDYING),@"Trying to set max studying to be higher than max");
    [settings setInteger:value forKey:APP_MAX_STUDYING];
  }
  else if (sender.tag == FREQUENCY_SLIDER_TAG)
  {
    LWE_ASSERT_EXC((value >= MIN_FREQUENCY_MULTIPLIER),@"Trying to set max studying to be lower than minimum");
    LWE_ASSERT_EXC((value <= MAX_FREQUENCY_MULTIPLIER),@"Trying to set frequency to be higher than max");
    [settings setInteger:value forKey:APP_FREQUENCY_MULTIPLIER];
  }
}

#pragma mark - UISwitch

- (void)switchView_eventValueChanged:(id)sender
{
  UISwitch *switchView = (UISwitch *)sender; 
  BOOL newValue = [switchView isOn];
  
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setBool:newValue forKey:APP_HIDE_BURIED_CARDS];
}


#pragma mark - Class Plumbing

- (void)dealloc 
{
  [maxCardsSlider release];
  [frequencySlider release];
  [difficultySegmentControl release];
  [tableView release];
  [super dealloc];
}

@end