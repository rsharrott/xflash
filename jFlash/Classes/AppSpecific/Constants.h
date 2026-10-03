// Long weekend values
#define PREV_BTN 100
#define NEXT_BTN 200
#define RIGHT_BTN 300
#define WRONG_BTN 400
#define BURY_BTN 600

#define DEFAULT_USER_ID 1
#define DEFAULT_FREQUENCY_MULTIPLIER 1
#define DEFAULT_MAX_STUDYING 30
#define DEFAULT_DIFFICULTY 1
#define DEFAULT_REMINDER_DAYS 4

// algorithm controls
#define MAX_MAX_STUDYING 50
#define MIN_MAX_STUDYING 5
#define MAX_FREQUENCY_MULTIPLIER 4
#define MIN_FREQUENCY_MULTIPLIER 1
#define NUM_CARDS_IN_NOT_NEXT_QUEUE 5

#define FONT_SIZE_ADD_TAG_VC 14
#define FONT_SIZE_CELL_HEADWORD 16

#define STUDY_VIEW_CONTROLLER_TAB_INDEX     0
#define STUDY_SET_VIEW_CONTROLLER_TAB_INDEX 1
#define SEARCH_VIEW_CONTROLLER_TAB_INDEX    2
#define SETTINGS_VIEW_CONTROLLER_TAB_INDEX  3

#define BUNDLE_APP_NAME [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey]

// default background image for UITableViews
extern NSString * const LWETableBackgroundImage;

// Notification names
extern NSString * const LWEShouldSwitchTab;
extern NSString * const LWEShouldShowModal;


// Settings - do not change
// JFlash and CFlash-specific constants are in their respective sections.
extern NSString * const APP_MODE;
extern NSString * const SET_MODE_QUIZ;
extern NSString * const SET_MODE_BROWSE;

extern NSString * const APP_HEADWORD;
extern NSString * const SET_J_TO_E;
extern NSString * const SET_E_TO_J;

extern NSString * const APP_HEADWORD_TYPE;
extern NSString * const SET_HEADWORD_TYPE_TRAD;
extern NSString * const SET_HEADWORD_TYPE_SIMP;

extern NSString * const APP_THEME;
extern NSString * const APP_ALGORITHM;
extern NSString * const APP_USER;
extern NSString * const APP_PLUGIN;
extern NSString * const APP_REMINDER;
extern NSString * const APP_FREQUENCY_MULTIPLIER;
extern NSString * const APP_MAX_STUDYING;
extern NSString * const APP_DIFFICULTY;
extern NSString * const APP_DATA_VERSION;
extern NSString * const APP_SETTINGS_VERSION;
extern NSString * const APP_HIDE_BURIED_CARDS;

extern NSString * const PLUGIN_LAST_UPDATE;

extern const NSInteger STARRED_TAG_ID;

// Talk to MMA about these - do NOT edit them
extern NSString * const LWE_CURRENT_VERSION;
extern NSString * const LWE_CURRENT_CARD_DATABASE;
extern NSString * const LWE_CURRENT_USER_DATABASE;

extern NSString * const LWE_BAD_DATA_EMAIL;
extern NSString * const LWE_SUPPORT_EMAIL;

// Tapjoy ID - should be updated for each app!
extern NSString * const LWE_TAPJOY_APP_ID;

extern NSString * const LWE_XFLASH_HOMEPAGE;

#if defined(LWE_JFLASH)

  // LWE Favorites - JFlash
  #define DEFAULT_TAG_ID 124

  extern NSString * const APP_READING;
  extern NSString * const SET_READING_KANA;
  extern NSString * const SET_READING_ROMAJI;
  extern NSString * const SET_READING_BOTH;
  extern NSString * const APP_KANA_ONLY;
  extern NSString * const SET_KANA_ONLY_ON;
  extern NSString * const SET_KANA_ONLY_OFF;

  extern NSString * const LWE_JF_VERSION_1_0;
  extern NSString * const LWE_JF_VERSION_1_1;
  extern NSString * const LWE_JF_VERSION_1_2;
  extern NSString * const LWE_JF_VERSION_1_3;
  extern NSString * const LWE_JF_VERSION_1_4;
  extern NSString * const LWE_JF_VERSION_1_5;
  extern NSString * const LWE_JF_VERSION_1_6;
  extern NSString * const LWE_JF_VERSION_1_6_1;
  extern NSString * const LWE_JF_VERSION_1_6_2;
  extern NSString * const LWE_JF_VERSION_1_7;
  extern NSString * const LWE_JF_VERSION_1_8;
  extern NSString * const LWE_JF_VERSION_1_9;
  extern NSString * const LWE_JF_10_USER_DATABASE;
  extern NSString * const LWE_JF_10_TO_11_SQL_FILENAME;
  extern NSString * const LWE_JF_12_TO_13_SQL_FILENAME;
  extern NSString * const LWE_JF_13_TO_14_SQL_FILENAME;
  extern NSString * const LWE_JF_15_TO_16_SQL_FILENAME;
  extern NSString * const LWE_JF_16_TO_161_SQL_FILENAME;
  extern NSString * const LWE_JF_161_TO_162_SQL_FILENAME;
  extern NSString * const LWE_JF_162_TO_17_SQL_FILENAME;

  // This is here for legacy JFlash reasons - before v1.6 this was used.  Used for upgrade path now.
  extern NSString * const LWE_DOWNLOADED_PLUGIN_PLIST;

#elif defined(LWE_CFLASH)

  // LWE Favorites - CFlash
  #define DEFAULT_TAG_ID 158

  extern NSString * const APP_PINYIN_COLOR;
  extern NSString * const SET_PINYIN_COLOR_ON;
  extern NSString * const SET_PINYIN_COLOR_OFF;

  extern NSString * const APP_PINYIN_CHANGE_TONE;
  extern NSString * const SET_PINYIN_CHANGE_TONE_ON;
  extern NSString * const SET_PINYIN_CHANGE_TONE_OFF;

  extern NSString * const LWE_CF_VERSION_1_0;
  extern NSString * const LWE_CF_VERSION_1_1;
  extern NSString * const LWE_CF_VERSION_1_2;

  extern NSString * const LWE_CF_11_TO_12_SQL_FILENAME;

  // Plugins - CFlash
  extern NSString * const AUDIO_PINYIN_KEY;  //! Key for referring to the Pinyin Audio plugin
  extern NSString * const AUDIO_HSK_KEY;      //! Key for referring to the HSK Audio plugin
#endif 

// PLugins - global
extern NSString * const LWE_PREINSTALLED_PLUGIN_PLIST;
extern NSString * const LWE_AVAILABLE_PLUGIN_PLIST;
extern NSString * const CARD_DB_KEY;        //! Dictionary key to refer to main card database
extern NSString * const FTS_DB_KEY;         //! Dictionary key to refer to FTS database filename
extern NSString * const EXAMPLE_DB_KEY;     //! Dictionary key to refer to example database filename

extern NSString * const LWE_FLURRY_API_KEY;   // FLurry key for this app
extern NSString * const LWE_APP_SPLASH_IMAGE; // App splash image - different between the flashes
extern NSString * const LWE_APP_SPLASH_IMAGE_568h;
