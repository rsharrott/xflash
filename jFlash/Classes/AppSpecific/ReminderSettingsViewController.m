//
//  ReminderSettingsViewController.m
//  jFlash
//
//  Created by Mark Makdad on 10/19/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import "ReminderSettingsViewController.h"
#import <UserNotifications/UserNotifications.h>
#import "SettingsViewController.h"   // LWEMenuSettingCell

NSString * const LWEStudyReminderRequestIdentifier = @"LWEStudyReminder";

@interface ReminderSettingsViewController ()
- (void) _writeNumDaysSetting:(NSInteger)numDays;
- (void) _setRemindersOn:(BOOL)on;
- (void) _showNotificationsDeniedAlert;
+ (NSInteger) _rememberedNumDays;
- (NSString *) _titleForNumDays:(NSInteger)days;
@property (retain) NSArray *numDaysArray;
@end

#define REMINDER_SETTINGS_TABLE_TOGGLE_SECTION 0
#define REMINDER_SETTINGS_TABLE_DAYS_SECTION 1

@implementation ReminderSettingsViewController

@synthesize remindersOn, onOffSwitch, numDaysArray;

- (id) init
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self)
  {
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSInteger reminderDays = [[settings objectForKey:APP_REMINDER] integerValue];
    self.remindersOn = (reminderDays > 0);
    _numDays = (reminderDays > 0) ? reminderDays : [[self class] _rememberedNumDays];
    self.numDaysArray = [NSArray arrayWithObjects:@1,@2,@3,@4,@5,@7,@10,@14,@21,@30,nil];
  }
  return self;
}

//! The last "Days After Last Session" choice (kept while reminders are off), or the default
+ (NSInteger) _rememberedNumDays
{
  NSInteger days = [[NSUserDefaults standardUserDefaults] integerForKey:APP_REMINDER_DAYS_CHOICE];
  return (days > 0) ? days : DEFAULT_REMINDER_DAYS;
}

- (NSString *) _titleForNumDays:(NSInteger)days
{
  NSString *daysFormat = (days == 1) ? NSLocalizedString(@"%@ day",@"ReminderVC.pickerFormatSingle")
                                     : NSLocalizedString(@"%@ days",@"ReminderVC.pickerFormatPlural");
  return [NSString stringWithFormat:daysFormat,[NSString stringWithFormat:@"%ld",(long)days]];
}

#pragma mark - View lifecycle

- (void) viewDidLoad
{
  [super viewDidLoad];
  self.navigationItem.title = NSLocalizedString(@"Study Reminders",@"ReminderVC.Title");
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 50;

  UISwitch *reminderSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
  [reminderSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
  reminderSwitch.accessibilityLabel = NSLocalizedString(@"Study Reminders", @"RemindersVC.StudyRemindersSwitchLabel");
  self.onOffSwitch = reminderSwitch;
  self.onOffSwitch.on = self.remindersOn;
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

#pragma mark - Actions

- (void) switchValueChanged:(UISwitch*)sender
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
    // Bring back the last choice instead of resetting to the default
    [self.tableView insertSections:settingsSection withRowAnimation:UITableViewRowAnimationFade];
    [self _writeNumDaysSetting:[[self class] _rememberedNumDays]];
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
      NSInteger days = [[settings objectForKey:APP_REMINDER] integerValue];
      if (allowed == NO && days > 0)
      {
        // Keep the user's choice so turning reminders back on restores it
        [settings setInteger:days forKey:APP_REMINDER_DAYS_CHOICE];
        [settings removeObjectForKey:APP_REMINDER];
      }
      if (finish) finish();
    });
  }];
}

#pragma mark - UITableViewDelegate Methods

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
    return NSLocalizedString(@"Reminders are reset each time the app is opened. If you're diligent about studying, you may never see one!", @"ReminderVC.SettingsSectionFooter");
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
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    self.onOffSwitch.onTintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
    cell.accessoryView = self.onOffSwitch;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
  }
  else if (indexPath.section == 1)
  {
    LWEMenuSettingCell *menuCell = [lclTableView dequeueReusableCellWithIdentifier:@"days"];
    if (menuCell == nil)
    {
      menuCell = [[[LWEMenuSettingCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"days"] autorelease];
    }
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[self.numDaysArray count]];
    for (NSNumber *days in self.numDaysArray)
    {
      [titles addObject:[self _titleForNumDays:[days integerValue]]];
    }
    __block ReminderSettingsViewController *blockSelf = self;
    [menuCell configureWithTitle:NSLocalizedString(@"Days After Last Session",@"RemindersVC.DaysAfterLastSesssionLabel")
                    optionTitles:titles
                    optionValues:self.numDaysArray
                    currentValue:[NSNumber numberWithInteger:_numDays]
                       tintColor:[[ThemeManager sharedThemeManager] currentThemeTintColor]
                         handler:^(id value) {
      [blockSelf _writeNumDaysSetting:[value integerValue]];
    }];
    cell = menuCell;
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
    [settings setInteger:numDays forKey:APP_REMINDER_DAYS_CHOICE];
  }
}

#pragma mark -

- (void) dealloc
{
  [numDaysArray release];
  [onOffSwitch release];
  [super dealloc];
}

@end
