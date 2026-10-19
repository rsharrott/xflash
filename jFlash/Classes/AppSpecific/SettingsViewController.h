//
//  SettingsViewController.h
//  jFlash
//
//  Created by シャロット ロス on 5/17/09.
//  Copyright 2009 Long Weekend LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DownloadManager.h"
#import "PluginManager.h"

extern NSString * const APP_ABOUT;
extern NSString * const APP_NEW_UPDATE;

@protocol LWESettingsDataSource <NSObject>
@required
- (NSArray*) settingsArrayWithPluginManager:(PluginManager *)pluginManager;
- (NSDictionary*) settingsHash;
//! Setting key -> the value keys in the order the row's pop-up menu lists them
- (NSDictionary*) settingsOrder;
@end

/**
 * A settings row whose value is a pop-up menu button: "Title        Value ⌃⌄".
 * The button shows the current value; tapping it opens a menu with a checkmark on the current choice.
 * At accessibility text sizes the value moves under the title.
 */
@interface LWEMenuSettingCell : UITableViewCell
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UIButton *menuButton;
//! Optional, parallel to optionTitles: what VoiceOver reads as the button value for each option (NSNull = the title).
//! UIAction has no public accessibility label, so menu rows still read their titles. Set before -configureWithTitle:...
@property (nonatomic, copy) NSArray *optionAccessibilityLabels;
//! titles/values are parallel arrays; handler is called with the chosen value (not called for the current one)
- (void) configureWithTitle:(NSString *)title
                optionTitles:(NSArray *)optionTitles
                optionValues:(NSArray *)optionValues
                currentValue:(id)currentValue
                   tintColor:(UIColor *)tintColor
                     handler:(void (^)(id value))handler;
@end

@class SettingsViewController;

@interface SettingsViewController : UITableViewController
- (void) updateBadgeValue;

//! This data source is not quite a model in the traditional sense; it is retained - 100% used by this VC
@property (retain) id<LWESettingsDataSource> dataSource;
@property (retain, nonatomic) NSArray *sectionArray;

@property (retain) IBOutlet DownloadManager *downloadManager;
@property (retain) IBOutlet PluginManager *pluginManager;
@end