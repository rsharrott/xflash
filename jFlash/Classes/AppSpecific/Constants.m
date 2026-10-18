//
//  Constants.m
//  jFlash
//
//  Created by シャロット ロス on 2/13/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//
#import "Constants.h"

NSString * const LWETableBackgroundImage = @"/table-background.jpg";

/*
 WARNING: Do not change any of the values of these strings.  It will break
 backwards compatibility.  The only way you would ever be allowed to do so
 is if you wrote a migration that migrated the user's setting(s) that you 
 changed.

 Note: JFlash and CFlash-specific constants are in their respective sections.
 */
NSString * const APP_MODE            = @"mode";
NSString * const SET_MODE_QUIZ       = @"QUIZ";
NSString * const SET_MODE_BROWSE     = @"BROWSE";

NSString * const APP_HEADWORD        = @"headword";
NSString * const SET_J_TO_E          = @"JPN";
NSString * const SET_E_TO_J          = @"ENG";

NSString * const APP_HEADWORD_TYPE        = @"headword_type";
NSString * const SET_HEADWORD_TYPE_TRAD   = @"TRAD";
NSString * const SET_HEADWORD_TYPE_SIMP   = @"SIMP";

// These setting types do not have discrete set values, their setting values are
// determined in code.
NSString * const APP_THEME                = @"theme";
NSString * const APP_ALGORITHM            = @"algorithm";
NSString * const APP_USER                 = @"user_id";
NSString * const APP_PLUGIN               = @"plugin";
NSString * const APP_REMINDER             = @"reminder";
NSString * const APP_MAX_STUDYING         = @"maxStudying";
NSString * const APP_FREQUENCY_MULTIPLIER = @"frequency_multiplier";
NSString * const APP_DIFFICULTY           = @"app_difficulty";
NSString * const APP_DATA_VERSION         = @"data_version";
NSString * const APP_SETTINGS_VERSION     = @"settings_version";
NSString * const APP_HIDE_BURIED_CARDS    = @"app_hide_buried_cards";

NSString * const LWEShouldSwitchTab           = @"LWEShouldSwitchTab";
NSString * const LWEShouldShowModal				    = @"LWEShouldShowModal";
NSString * const LWEShouldShowDownloadModal	  = @"LWEShouldShowDownloadModal";


//Rendy did add this - For the plugin manager feature
NSString * const PLUGIN_LAST_UPDATE		  = @"last_update";

// Tag for "favorites" - zero, because it wasn't taken!
const NSInteger STARRED_TAG_ID = 0;

// Support contact for card corrections and general support.
// (The old longweekendmobile.com addresses no longer exist.)
NSString * const LWE_BAD_DATA_EMAIL       = @"help@japaneseinaflash.com";
NSString * const LWE_SUPPORT_EMAIL        = @"help@japaneseinaflash.com";
NSString * const LWE_SUPPORT_URL          = @"https://japaneseinaflash.com/support";
NSString * const LWE_PRIVACY_URL          = @"https://japaneseinaflash.com/privacy";

// App Store ID of the current app, used to build the share link.
// TODO(Ross): set this once App Store Connect assigns the new app an ID.
// While it is empty, the "Tell a Friend" / share-app UI stays hidden so users
// never get a dead link. (The old Japanese Flash ID, 367216357, now 404s.)
NSString * const kAppStoreID              = @"";

NSString * LWEAppStoreURLString(void)
{
  if ([kAppStoreID length] == 0)
  {
    return nil;
  }
  return [NSString stringWithFormat:@"https://apps.apple.com/app/id%@", kAppStoreID];
}

#if defined(LWE_JFLASH)
      NSString * const LWE_APP_SPLASH_IMAGE = @"Default.png";
      NSString * const LWE_APP_SPLASH_IMAGE_568h = @"Default-568h@2x.png";

      // This setting is JFlash-specific
      NSString * const APP_READING         = @"reading";
      NSString * const SET_READING_KANA    = @"KANA";
      NSString * const SET_READING_ROMAJI  = @"ROMAJI";
      NSString * const SET_READING_BOTH    = @"BOTH";
      NSString * const APP_KANA_ONLY       = @"kana_only";
      NSString * const SET_KANA_ONLY_ON    = @"ON";
      NSString * const SET_KANA_ONLY_OFF   = @"OFF";

      NSString * const LWE_XFLASH_HOMEPAGE       = @"https://japaneseinaflash.com";

      // These constants are general to the flashes
      NSString * const LWE_CURRENT_VERSION       = @"1.9";
      NSString * const LWE_CURRENT_USER_DATABASE = @"jFlash.db";
      NSString * const LWE_CURRENT_CARD_DATABASE = @"jFlash-CARD-1.1.db";

      // These constants are JF specific
      NSString * const LWE_JF_10_USER_DATABASE       = @"jFlash.db";
      NSString * const LWE_JF_10_TO_11_SQL_FILENAME  = @"jflash_10_to_11.sql";
      NSString * const LWE_JF_12_TO_13_SQL_FILENAME  = @"jflash_12_to_13.sql";
      NSString * const LWE_JF_13_TO_14_SQL_FILENAME  = @"jflash_13_to_14.sql";
      NSString * const LWE_JF_15_TO_16_SQL_FILENAME  = @"jflash_15_to_16.sql";
      NSString * const LWE_JF_16_TO_161_SQL_FILENAME = @"jflash_16_to_161.sql";
      NSString * const LWE_JF_161_TO_162_SQL_FILENAME = @"jflash_161_to_162.sql";
      NSString * const LWE_JF_162_TO_17_SQL_FILENAME = @"jflash_162_to_17.sql";
      NSString * const LWE_JF_VERSION_1_0           = @"1.0";
      NSString * const LWE_JF_VERSION_1_1           = @"1.1"; 
      NSString * const LWE_JF_VERSION_1_2           = @"1.2";
      NSString * const LWE_JF_VERSION_1_3           = @"1.3";
      NSString * const LWE_JF_VERSION_1_4           = @"1.4";
      NSString * const LWE_JF_VERSION_1_5           = @"1.5";
      NSString * const LWE_JF_VERSION_1_6           = @"1.6";
      NSString * const LWE_JF_VERSION_1_6_1         = @"1.6.1";
      NSString * const LWE_JF_VERSION_1_6_2         = @"1.6.2";
      NSString * const LWE_JF_VERSION_1_7           = @"1.7";
      NSString * const LWE_JF_VERSION_1_8           = @"1.8";
      NSString * const LWE_JF_VERSION_1_9           = @"1.9";

      // This pertains to the plugin manager
      NSString * const LWE_AVAILABLE_PLUGIN_PLIST   = @"jFlash-available.plist";
      NSString * const LWE_PREINSTALLED_PLUGIN_PLIST= @"jFlash-installed.plist";

      // This is here for legacy migration only, as of JFLash 1.6.
      NSString * const LWE_DOWNLOADED_PLUGIN_PLIST  = @"downloadedPlugin.plist";
// Remote plugin updates are switched off in every build: the old S3 buckets
// (japanese-flash / chinese-flash) and CloudFront distributions are gone, so
// the check and any download would only fail. Bundled plugins still load.
// TODO: re-host the available-plugins plist and plugin packages, then set
// LWE_PLUGIN_SERVER / LWE_PLUGIN_LIST_REL_URL here (and the targetURLs in
// Plugins/*-available.plist) to turn updates back on.
      NSString * const LWE_PLUGIN_SERVER            = @"";
      NSString * const LWE_PLUGIN_LIST_REL_URL      = @"";

#elif defined(LWE_CFLASH)
      NSString * const LWE_APP_SPLASH_IMAGE         = @"chinese-flash-splash.png";
      // cFlash never shipped a 4-inch splash; reuse the standard one
      NSString * const LWE_APP_SPLASH_IMAGE_568h    = @"chinese-flash-splash.png";


      // These settings are CFlash only - pinyin coloring & tone changes
      NSString * const APP_PINYIN_COLOR             = @"pinyin_color";
      NSString * const SET_PINYIN_COLOR_ON          = @"ON";
      NSString * const SET_PINYIN_COLOR_OFF         = @"OFF";

      NSString * const APP_PINYIN_CHANGE_TONE       = @"pinyin_tone_change";
      NSString * const SET_PINYIN_CHANGE_TONE_ON    = @"ON";
      NSString * const SET_PINYIN_CHANGE_TONE_OFF   = @"OFF";


      NSString * const LWE_XFLASH_HOMEPAGE       = @"http://www.chineseflashapp.com";

      // These constants are general to the flashes
      NSString * const LWE_CURRENT_VERSION          = @"1.2";
      NSString * const LWE_CURRENT_CARD_DATABASE    = @"cFlash-CARD-1.0.db";
      NSString * const LWE_CURRENT_USER_DATABASE    = @"cFlash.db";

      // These constants are CF specific
      NSString * const LWE_CF_VERSION_1_0           = @"1.0";
      NSString * const LWE_CF_VERSION_1_1           = @"1.1";
      NSString * const LWE_CF_VERSION_1_2           = @"1.2";

      // Migration files
      NSString * const LWE_CF_11_TO_12_SQL_FILENAME = @"cflash_11_to_12.sql";

      //CFlash specific plugins
      NSString * const AUDIO_HSK_KEY = @"AUDIO_HSK";
      NSString * const AUDIO_PINYIN_KEY = @"AUDIO_PINYIN";

      // This pertains to the plugin manager
      NSString * const LWE_AVAILABLE_PLUGIN_PLIST   = @"cFlash-available.plist";
      NSString * const LWE_PREINSTALLED_PLUGIN_PLIST   = @"cFlash-installed.plist";
      // Remote plugin updates are switched off in every build: the old S3 buckets
      // (japanese-flash / chinese-flash) and CloudFront distributions are gone, so
      // the check and any download would only fail. Bundled plugins still load.
      // TODO: re-host the available-plugins plist and plugin packages, then set
      // LWE_PLUGIN_SERVER / LWE_PLUGIN_LIST_REL_URL here (and the targetURLs in
      // Plugins/*-available.plist) to turn updates back on.
      NSString * const LWE_PLUGIN_SERVER            = @"";
      NSString * const LWE_PLUGIN_LIST_REL_URL      = @"";
#endif


// Plugin keys - DO NOT change
NSString * const CARD_DB_KEY = @"CARD_DB";
NSString * const FTS_DB_KEY = @"FTS_DB";
NSString * const EXAMPLE_DB_KEY = @"EX_DB";
