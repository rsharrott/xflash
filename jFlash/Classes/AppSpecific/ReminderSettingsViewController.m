//
//  ReminderSettingsViewController.m
//  jFlash
//
//  Created by Mark Makdad on 10/19/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import "ReminderSettingsViewController.h"
#import <UserNotifications/UserNotifications.h>
#import "LWEViewAnimationUtils.h"

NSString * const LWEStudyReminderRequestIdentifier = @"LWEStudyReminder";

@interface ReminderSettingsViewController ()
- (void) _writeNumDaysSetting:(NSInteger)numDays;
- (void) _setRemindersOn:(BOOL)on;
- (void) _showNotificationsDeniedAlert;
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

- (void) viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  // If notifications were turned off in the Settings app, show reminders as Off here too
  [[self class] syncReminderSettingWithNotificationPermission:^{
    BOOL on = ([[[NSUserDefaults standardUserDefaults] objectForKey:APP_REMINDER] integerValue] > 0);
    if (on != self.remindersOn)
    {
      self.remindersOn = on;
      self.onOffSwitch.on = on;
      [self.tableView reloadData];
    }
  }];
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
  if (sender.on == NO)
  {
    [self _setRemindersOn:NO];
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[LWEStudyReminderRequestIdentifier]];
    return;
  }

  // Turning reminders on: ask for permission first (iOS only shows the prompt once;
  // after that this returns the user's earlier answer straight away).
  [sender setEnabled:NO];
  UNAuthorizationOptions options = (UNAuthorizationOptionAlert | UNAuthorizationOptionSound);
  [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options
                                                                      completionHandler:^(BOOL granted, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [sender setEnabled:YES];
      if (granted)
      {
        [self _setRemindersOn:YES];
      }
      else
      {
        [sender setOn:NO animated:YES];
        [self _showNotificationsDeniedAlert];
      }
    });
  }];
}

//! Shows/hides the "Reminder Settings" section and stores the setting
- (void) _setRemindersOn:(BOOL)on
{
  if (on == self.remindersOn)
  {
    return;
  }
  self.remindersOn = on;
  NSIndexSet *settingsSection = [NSIndexSet indexSetWithIndex:REMINDER_SETTINGS_TABLE_DAYS_SECTION];
  [self.tableView beginUpdates];
  if (on)
  {
    [self.tableView insertSections:settingsSection withRowAnimation:UITableViewRowAnimationFade];
    [self _writeNumDaysSetting:DEFAULT_REMINDER_DAYS];
  }
  else
  {
    [self.tableView deleteSections:settingsSection withRowAnimation:UITableViewRowAnimationFade];
    [self _writeNumDaysSetting:0];
  }
  [self.tableView endUpdates];
}

- (void) _showNotificationsDeniedAlert
{
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Notifications Are Off", @"ReminderVC.NotificationsDenied.Title")
                                                                 message:NSLocalizedString(@"To get study reminders, allow notifications for this app in the Settings app.", @"ReminderVC.NotificationsDenied.Message")
                                                          preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Open Settings", @"ReminderVC.NotificationsDenied.OpenSettings")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
    NSString *urlString = UIApplicationOpenSettingsURLString;
    if (@available(iOS 16.0, *))
    {
      urlString = UIApplicationOpenNotificationSettingsURLString;
    }
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Global.OK") style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

+ (void) syncReminderSettingWithNotificationPermission:(void (^)(void))completion
{
  void (^finish)(void) = [[completion copy] autorelease];
  [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *notificationSettings) {
    UNAuthorizationStatus status = notificationSettings.authorizationStatus;
    BOOL allowed = (status == UNAuthorizationStatusAuthorized || status == UNAuthorizationStatusProvisional);
    if (@available(iOS 14.0, *))
    {
      allowed = allowed || (status == UNAuthorizationStatusEphemeral);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
      if (allowed == NO && [[settings objectForKey:APP_REMINDER] integerValue] > 0)
      {
        [settings removeObjectForKey:APP_REMINDER];
      }
      if (finish) finish();
    });
  }];
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
