//
//  ReminderSettingsViewController.m
//  jFlash
//
//  Created by Mark Makdad on 10/19/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import "ReminderSettingsViewController.h"
#import "LWEViewAnimationUtils.h"

@interface ReminderSettingsViewController ()
- (void) _writeNumDaysSetting:(NSInteger)numDays;
@property (retain) NSArray *numDaysArray;
@end

#define REMINDER_SETTINGS_TABLE_TOGGLE_SECTION 0
#define REMINDER_SETTINGS_TABLE_DAYS_SECTION 1

@implementation ReminderSettingsViewController

@synthesize remindersOn, onOffSwitch, numDaysArray, picker;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self)
  {
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSNumber *reminderSetting = [settings objectForKey:APP_REMINDER];
    self.remindersOn = ([reminderSetting integerValue] > 0);
    _numDays = [reminderSetting integerValue];
    
    // Implementation is naive: using the same dataset for values & display, DO NOT put non-integer strings in here
    self.numDaysArray = [NSArray arrayWithObjects:@"1",@"2",@"3",@"4",@"5",@"7",@"10",@"14",@"21",@"30",nil];
  }
  return self;
}

#pragma mark - View lifecycle

- (void) viewDidLoad
{
  [super viewDidLoad];

  self.onOffSwitch.on = self.remindersOn;
  self.navigationItem.title = NSLocalizedString(@"Study Reminders",@"ReminderVC.Title");
  
  // Render the picker just below the visible screen, we will animate it in.
  CGRect viewFrame = [UIScreen mainScreen].bounds;
  CGRect pickerFrame = CGRectZero;
  int tabBarHeight = 113;
  pickerFrame.origin = CGPointMake(0, viewFrame.origin.y + viewFrame.size.height - tabBarHeight);
  pickerFrame.size = self.picker.frame.size;
  self.picker.frame = pickerFrame;
  [self.view addSubview:self.picker];
}

- (void) viewDidUnload
{
  [super viewDidUnload];
  self.onOffSwitch = nil;
  self.picker = nil;
}

#pragma mark - IBActions

- (IBAction) switchValueChanged:(UISwitch*)sender
{
  self.remindersOn = sender.on;
  
  // Now animate the changes
  NSIndexSet *settingsSection = [NSIndexSet indexSetWithIndex:1];
  [self.tableView beginUpdates];
  if (sender.on)
  {
    [self.tableView insertSections:settingsSection withRowAnimation:UITableViewRowAnimationFade];
    [self _writeNumDaysSetting:4];
  }
  else
  {
    [self.tableView deleteSections:settingsSection withRowAnimation:UITableViewRowAnimationFade];
    [self _writeNumDaysSetting:0];
  }
  [self.tableView endUpdates];
}

#pragma mark - UIPickerViewDataSource Methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
  return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
  return [self.numDaysArray count];
}

#pragma mark - UIPickerViewDelegate Methods

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
  NSString *value = [self.numDaysArray objectAtIndex:row];
  NSString *formatString = NSLocalizedString(@"%@ days",@"ReminderVC.pickerFormatPlural");
  if ([value isEqualToString:@"1"])
  {
    formatString = NSLocalizedString(@"%@ day",@"ReminderVC.pickerFormatSingle");
  }
  return [NSString stringWithFormat:formatString,value];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
  NSString *value = [self.numDaysArray objectAtIndex:row];
  [self _writeNumDaysSetting:[value integerValue]];
  
  // Dismiss the picker
  [LWEViewAnimationUtils translateView:self.picker byPoint:CGPointMake(0, 0) withInterval:0.5f];
  
  // If our value changed, update the section
  [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UITableViewDelegate Methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
  
  if (indexPath.section == REMINDER_SETTINGS_TABLE_DAYS_SECTION)
  {
    // Select the active row first
    NSInteger index = [self.numDaysArray indexOfObject:[NSString stringWithFormat:@"%d",_numDays]];
    [self.picker selectRow:index inComponent:0 animated:NO];
    
    // Bring up a picker to let the user choose how many days
    CGSize pickerSize = self.picker.frame.size;
    [LWEViewAnimationUtils translateView:self.picker byPoint:CGPointMake(0, -(pickerSize.height)) withInterval:0.5f];
  }
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == 1)
  {
    return NSLocalizedString(@"Reminder Settings", @"ReminderVC.SettingsSectionHeader");
  }
  else
  {
    return nil;
  }
}

- (NSString*) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
  if (section == 1)
  {
    return NSLocalizedString(@"Reminders are reset each time the app is opened.  If you're diligent about studying, you may never see one!", @"ReminderVC.SettingsSectionFooter");
  }
  else
  {
    return nil;
  }
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
  if (self.remindersOn)
  {
    // Switch + settings
    return 2;
  }
  else
  {
    // Switch only
    return 1;
  }
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0)
  {
    // On/off switch
    return 1;
  }
  else
  {
    // Reminder settings
    return 1;
  }
}

- (UITableViewCell *)tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  if (indexPath.section == 0)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"reminder" onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
    cell.textLabel.text = NSLocalizedString(@"Study Reminders", @"RemindersVC.StudyRemindersSwitchLabel");
    cell.accessoryView = self.onOffSwitch;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
  }
  else if (indexPath.section == 1)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"settings" onTable:lclTableView usingStyle:UITableViewCellStyleValue1];
    if (indexPath.row == 0)
    {
      cell.textLabel.text = NSLocalizedString(@"Days After Last Session",@"RemindersVC.DaysAfterLastSesssionLabel");
      // Same "%@ day(s)" wording as the picker rows
      NSString *daysFormat = (_numDays == 1) ? NSLocalizedString(@"%@ day",@"ReminderVC.pickerFormatSingle")
                                             : NSLocalizedString(@"%@ days",@"ReminderVC.pickerFormatPlural");
      cell.detailTextLabel.text = [NSString stringWithFormat:daysFormat,[NSString stringWithFormat:@"%ld",(long)_numDays]];
      cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
  }
  return cell;
}

#pragma mark - Privates

- (void) _writeNumDaysSetting:(NSInteger)numDays
{
  _numDays = numDays;
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  if (numDays == 0)
  {
    [settings removeObjectForKey:APP_REMINDER];
  }
  else
  {
    [settings setInteger:numDays forKey:APP_REMINDER];
  }
}

#pragma mark -

- (void) dealloc
{
  [picker release];
  [numDaysArray release];
  [onOffSwitch release];
  [super dealloc];
}

@end
