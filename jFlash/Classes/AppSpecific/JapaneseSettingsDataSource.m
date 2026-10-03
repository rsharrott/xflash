//
//  JapaneseSettingsDataSource.m
//  jFlash
//
//  Created by Mark Makdad on 8/21/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import "JapaneseSettingsDataSource.h"
#import "UpdateManager.h"
#import "Constants.h"

@implementation JapaneseSettingsDataSource

@synthesize settingsHash;

#pragma mark - Class Plumbing

- (void) dealloc
{
  [settingsHash release];
  [super dealloc];
}

#pragma mark - Settings Data Source

/** Returns all the arrays to configure the settings table */
- (NSArray*) settingsArrayWithPluginManager:(PluginManager *)pluginManager
{
	NSInteger newAvailableUpdate = 0; // plugin catalog is no longer fetched online
	
	//This is to set up the very top row and section in the settings table view.
	NSArray *newUpdateNames = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%d Update%@ Available", newAvailableUpdate, (newAvailableUpdate>1) ? @"s" : @""], nil];
  NSArray *newUpdateKeys = [NSArray arrayWithObjects:APP_NEW_UPDATE,nil];
  NSArray *newUpdateArray = [NSArray arrayWithObjects:newUpdateNames,newUpdateKeys, [NSString stringWithFormat:@"Available Update%@", (newAvailableUpdate>1) ? @"s" : @""], nil];
	
  // The following dictionaries contain all the mappings from actual settings to how they display on the phone
  NSArray *modeObjects = [NSArray arrayWithObjects:NSLocalizedString(@"Practice",@"SettingsViewController.Practice"), NSLocalizedString(@"Browse",@"SettingsViewController.Browse"), nil];
  NSArray *modeKeys = [NSArray arrayWithObjects:SET_MODE_QUIZ,SET_MODE_BROWSE,nil];
  NSDictionary *modeDict = [NSDictionary dictionaryWithObjects:modeObjects forKeys:modeKeys];
  
  NSArray *headwordObjects = [NSArray arrayWithObjects:NSLocalizedString(@"Japanese",@"SettingsViewController.HeadwordLanguage_Japanese"), 
                              NSLocalizedString(@"English",@"SettingsViewController.HeadwordLanguage_English"), nil];
  NSArray *headwordKeys = [NSArray arrayWithObjects:SET_J_TO_E,SET_E_TO_J,nil];
  NSDictionary *headwordDict = [NSDictionary dictionaryWithObjects:headwordObjects forKeys:headwordKeys];
  
  // Source theme information from the ThemeManager
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  NSDictionary *themeDict = [NSDictionary dictionaryWithObjects:[tm themeNameList] forKeys:[tm themeKeysList]];
  
  NSArray *readingObjects = [NSArray arrayWithObjects:NSLocalizedString(@"Kana",@"SettingsViewController.DisplayReading_Kana"),
                             NSLocalizedString(@"Romaji",@"SettingsViewController.DisplayReading_Romaji"),
                             NSLocalizedString(@"Both",@"SettingsViewController.DisplayReading_Both"),nil];
  NSArray *readingKeys = [NSArray arrayWithObjects:SET_READING_KANA,SET_READING_ROMAJI,SET_READING_BOTH,nil];
  NSDictionary *readingDict = [NSDictionary dictionaryWithObjects:readingObjects forKeys:readingKeys];

  NSArray *kanaObjects = [NSArray arrayWithObjects:NSLocalizedString(@"Prefer Kana",@"SettingsViewController.On"),
                                                   NSLocalizedString(@"Prefer Kanji",@"SettingsViewController.Off"),nil];
  NSArray *kanaKeys = [NSArray arrayWithObjects:SET_KANA_ONLY_ON,SET_KANA_ONLY_OFF,nil];
  NSDictionary *kanaDict = [NSDictionary dictionaryWithObjects:kanaObjects forKeys:kanaKeys];
  
  // Create a complete dictionary of all settings display names & their setting constants
  NSArray *dictObjects = [NSArray arrayWithObjects:headwordDict,themeDict,readingDict,kanaDict,modeDict,nil];
  NSArray *dictKeys = [NSArray arrayWithObjects:APP_HEADWORD,APP_THEME,APP_READING,APP_KANA_ONLY,APP_MODE,nil];
  self.settingsHash = [NSDictionary dictionaryWithObjects:dictObjects forKeys:dictKeys];

  //======================================
  // This controls what the user actually sees in the table
  //======================================
  
  // These are the keys and display names of each row
  NSArray *cardSettingNames = [NSArray arrayWithObjects:NSLocalizedString(@"Study Mode",@"SettingsViewController.SettingNames_StudyMode"),
                               NSLocalizedString(@"Study Language",@"SettingsViewController.SettingNames_StudyLanguage"),
                               NSLocalizedString(@"Furigana / Reading",@"SettingsViewController.SettingNames_DisplayFuriganaReading"),
                               NSLocalizedString(@"Common Kana Words",@"SettingsViewController.SettingNames_KanaOnlyWords"),
                               NSLocalizedString(@"Difficulty",@"SettingsViewController.SettingNames_ChangeDifficulty"),nil];
  NSArray *cardSettingKeys = [NSArray arrayWithObjects:APP_MODE,APP_HEADWORD,APP_READING,APP_KANA_ONLY,APP_ALGORITHM,nil];
  NSArray *cardSettingArray = [NSArray arrayWithObjects:cardSettingNames,cardSettingKeys,NSLocalizedString(@"Studying",@"SettingsViewController.TableHeader_Studying"),nil]; // Puts single section together, 3rd index is header name
  
  NSMutableArray *userSettingNames = [NSMutableArray arrayWithObjects:NSLocalizedString(@"Theme",@"SettingsViewController.SettingNames_Theme"),
                                      NSLocalizedString(@"Study Reminders",@"SettingsViewController.SettingNames_Reminders"),
                                      NSLocalizedString(@"Active User",@"SettingsViewController.SettingNames_ActiveUser"),
                                      NSLocalizedString(@"Updates",@"SettingsViewController.SettingNames_DownloadExtras"),nil];
  NSMutableArray *userSettingKeys = [NSMutableArray arrayWithObjects:APP_THEME,APP_REMINDER,APP_USER,APP_PLUGIN,nil];
  NSMutableArray *userSettingArray = [NSMutableArray arrayWithObjects:userSettingNames,userSettingKeys,NSLocalizedString(@"Application",@"SettingsViewController.TableHeader_Application"),nil];
  
  NSArray *aboutNames = [NSArray arrayWithObjects:NSLocalizedString(@"Japanese Flash was created on a Long Weekend over a few steaks and a few more Coronas. Special thanks goes to Teja for helping us write and simulate the frequency algorithm. This application also uses data from the EDICT dictionary and Tanaka Corpus. The EDICT files are property of the Electronic Dictionary Research and Development Group, and are used in conformance with the Group's license. Some icons by Joseph Wain / glyphish.com. The Japanese Flash Logo & Product Name are original creations and any perceived similarities to other trademarks is unintended and purely coincidental.",@"SettingsViewController.Acknowledgements"),nil];
  NSArray *aboutKeys = [NSArray arrayWithObjects:APP_ABOUT,nil];
  NSArray *aboutArray = [NSArray arrayWithObjects:aboutNames,aboutKeys,NSLocalizedString(@"Acknowledgements",@"SettingsViewController.TableHeader_Acknowledgements"),nil];
  
  // Make the order
	// If there is a new available update plugin, it will show in the first section, however, if it does not have anything, it will show nothing. 
	if (newAvailableUpdate > 0)
  {
		return [NSArray arrayWithObjects:newUpdateArray,cardSettingArray,userSettingArray,aboutArray,nil];
  }
	else
  {
		return [NSArray arrayWithObjects:cardSettingArray,userSettingArray,aboutArray,nil];
  }
}


@end
