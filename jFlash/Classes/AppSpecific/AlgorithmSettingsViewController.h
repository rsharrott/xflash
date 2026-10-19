//
//  AlgorithmSettingsViewController.h
//  jFlash
//
//  Created by シャロット ロス on 6/9/10.
//  Copyright 2010 LONG WEEKEND INC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ThemeManager.h"
#import "Constants.h"

//! Number of difficulty presets (Easy, Medium, Hard, Custom); APP_DIFFICULTY is 0...3
#define LWE_NUM_DIFFICULTIES 4
#define LWE_CUSTOM_DIFFICULTY 3

/**
 * "Change Difficulty": a checkmark list of the presets (each showing its real values).
 * The two sliders only appear for Custom. Custom keeps its own values
 * (APP_CUSTOM_MAX_STUDYING / APP_CUSTOM_FREQUENCY_MULTIPLIER), so picking a preset and
 * coming back to Custom restores them.
 */
@interface AlgorithmSettingsViewController : UITableViewController

//! Localized preset name ("Easy", "Medium", "Hard", "Custom") for an APP_DIFFICULTY value
+ (NSString *) displayNameForDifficulty:(NSInteger)difficulty;

@end
