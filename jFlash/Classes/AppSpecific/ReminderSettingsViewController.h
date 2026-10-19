//
//  ReminderSettingsViewController.h
//  jFlash
//
//  Created by Mark Makdad on 10/19/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Identifier of the single pending "time to study" notification request
extern NSString * const LWEStudyReminderRequestIdentifier;

@interface ReminderSettingsViewController : UITableViewController
{
  NSInteger _numDays;
}

- (void) switchValueChanged:(UISwitch*)sender;

/**
 * Turns the reminder setting off if the app isn't allowed to post notifications
 * (denied, or never asked), so Settings never shows "On" for reminders that can't
 * be delivered. Calls completion on the main queue.
 */
+ (void) syncReminderSettingWithNotificationPermission:(void (^)(void))completion;

@property BOOL remindersOn;
@property (nonatomic,retain) UISwitch *onOffSwitch;

@end