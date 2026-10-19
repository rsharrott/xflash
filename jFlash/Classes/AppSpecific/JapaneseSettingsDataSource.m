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

@synthesize settingsHash, settingsOrder;

#pragma mark - Class Plumbing

- (void) dealloc
{
  [settingsHash release];
  [settingsOrder release];
  [super dealloc];
}

#pragma mark - Settings Data Source

/** Returns all the arrays to configure the settings table */
- (NSArray*) settingsArrayWithPluginManager:(PluginManager *)pluginManager
{
	NSInteger newAvailableUpdate = [pluginManager.downloadablePlugins count];
	
	//This is to set up the very top row and section in the settings table view.
  NSString *newUpdateName = (newAvailableUpdate == 1) ? NSLocalizedString(@"1 Update Available", @"SettingsViewController.OneUpdateAvailable")
                                                       : [NSString stringWithFormat:NSLocalizedString(@"%d Updates Available", @"SettingsViewController.NUpdatesAvailable"), newAvailableUpdate];
  NSString *newUpdateHeader = (newAvailableUpdate == 1) ? NSLocalizedString(@"Available Update", @"SettingsViewController.TableHeader_AvailableUpdate")
                                                         : NSLocalizedString(@"Available Updates", @"SettingsViewController.TableHeader_AvailableUpdates");
	NSArray *newUpdateNames = [NSArray arrayWithObjects:newUpdateName, nil];
  NSArray *newUpdateKeys = [NSArray arrayWithObjects:APP_NEW_UPDATE,nil];
  NSArray *newUpdateArray = [NSArray arrayWithObjects:newUpdateNames,newUpdateKeys,newUpdateHeader, nil];
	
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
  // Theme names are display-only here (the keys are what get saved), so translate them for the table.
  // Keys: NSLocalizedString(@"Paper",@"Theme name"), NSLocalizedString(@"Fire",@"Theme name"), NSLocalizedString(@"Water",@"Theme name"), NSLocalizedString(@"Kimono",@"Theme name"), NSLocalizedString(@"Kutani",@"Theme name")
  NSMutableArray *themeNames = [NSMutableArray array];
  for (NSString *themeName in [tm themeNameList])
  {
    [themeNames addObject:[[NSBundle mainBundle] localizedStringForKey:themeName value:themeName table:nil]];
  }
  NSDictionary *themeDict = [NSDictionary dictionaryWithObjects:themeNames forKeys:[tm themeKeysList]];
  
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

  // The order the options appear in each row's pop-up menu (dictionaries have no order)
  // Theme menu order follows ThemeManager (Paper, Fire, Water, …) — never hard-code removed keys
  NSArray *themeOrder = [tm themeKeysList];
  NSArray *orderObjects = [NSArray arrayWithObjects:headwordKeys,themeOrder,readingKeys,kanaKeys,modeKeys,nil];
  self.settingsOrder = [NSDictionary dictionaryWithObjects:orderObjects forKeys:dictKeys];

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
                                      NSLocalizedString(@"Installed Data",@"SettingsViewController.SettingNames_DownloadExtras"),nil];
  NSMutableArray *userSettingKeys = [NSMutableArray arrayWithObjects:APP_THEME,APP_REMINDER,APP_USER,APP_PLUGIN,nil];
  NSMutableArray *userSettingArray = [NSMutableArray arrayWithObjects:userSettingNames,userSettingKeys,NSLocalizedString(@"Application",@"SettingsViewController.TableHeader_Application"),nil];
  
  NSArray *aboutNames = [NSArray arrayWithObjects:NSLocalizedString(@"Japanese in a Flash! (formerly Japanese Flash) was created on a Long Weekend over a few steaks and a few more Coronas. Special thanks goes to Teja for helping us write and simulate the frequency algorithm. This application includes material from the JMdict (EDICT, etc.) dictionary files in accordance with the licence provisions of the Electronic Dictionary Research and Development Group (EDRDG). The files are the property of the EDRDG and are used, converted and modified here under the Creative Commons Attribution-ShareAlike 4.0 licence (CC BY-SA 4.0); the modified dictionary data is shared under the same licence at https://github.com/rsharrott/xflash. EDRDG licence: https://www.edrdg.org/edrdg/licence.html  JMdict project: https://www.edrdg.org/jmdict/j_jmdict.html  Example sentences are from the Tatoeba Project (https://tatoeba.org, originally the Tanaka Corpus) and are used under the Creative Commons Attribution 2.0 France licence (CC BY 2.0 FR): https://creativecommons.org/licenses/by/2.0/fr/. The Japanese in a Flash! logo & product name are original creations and any perceived similarities to other trademarks is unintended and purely coincidental.",@"SettingsViewController.Acknowledgements"),nil];
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
