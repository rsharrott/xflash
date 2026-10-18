//
//  CurrentState.m
//  jFlash
//
//  Created by Mark Makdad on 7/12/09.
//  Copyright 2009 LONG WEEKEND INC.. All rights reserved.
//

#import "CurrentState.h"
#import "SynthesizeSingleton.h"

#import "JFlashUpdateManager.h"
#import "CFlashUpdateManager.h"


// For private methods
@interface CurrentState ()
- (void) _createDefaultSettings;
- (void) _setupActiveTag:(Tag *)tag;
@end

NSString * const LWEActiveTagDidChange = @"LWEActiveTagDidChange";

/**
 * Maintains the current state of the application (active set, etc).  Is a singleton.
 * Owns the plugin manager (to be debated whether that is the best design or not)
 */
@implementation CurrentState
@synthesize isFirstLoad, isUpdatable, starredTag, activeTag = _activeTag, isFirstLaunchAfterUpdate;

SYNTHESIZE_SINGLETON_FOR_CLASS(CurrentState);

/**
 * Sets the current active study set/tag - also loads cardIds for the tag
 */
- (void) setActiveTag:(Tag *)activeTag
{
  [self setActiveTag:activeTag completionHandler:nil];
}

/**
 * If a completion handler is passed, loads a tag asynchronously and executes the handler
 * afterward.
 */
- (void) setActiveTag:(Tag*)tag completionHandler:(dispatch_block_t)completionBlock
{
  if (completionBlock)
  {
    dispatch_queue_t queue = dispatch_queue_create("com.longweekendmobile.loadtag",NULL);
    dispatch_async(queue,^
                   {
                     [tag populateCardIds];
                     dispatch_sync(dispatch_get_main_queue(), ^{ [self _setupActiveTag:tag]; });
                     dispatch_sync(dispatch_get_main_queue(),completionBlock);
                     dispatch_release(queue);
                   });
  }
  else
  {
    // Just do this synchronously
    [tag populateCardIds];
    [self _setupActiveTag:tag];
  }
}

- (void) _setupActiveTag:(Tag *)tag
{
  LWE_ASSERT_EXC((tag.cardCount > 0),@"Whoa, somehow we set a tag that has zero cards!");
  BOOL firstRun = (_activeTag == nil);

  @synchronized (self)
  {
    [_activeTag release];
    _activeTag = [tag retain];
  }
  
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setInteger:tag.tagId forKey:@"tag_id"];
  
  // Set the favorites tag, if not already done
  if (self.starredTag == nil)
  {
    self.starredTag = [Tag starredWordsTag];
  }

  // Tell everyone to reload their data (only if we're not just starting up)
  if (firstRun == NO)
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:LWEActiveTagDidChange object:_activeTag];
  }
}


/**
 * Returns the current active study set/tag
 */
- (Tag *) activeTag
{
  if (_activeTag == nil || [_activeTag cardCount] == 0)
  {
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSInteger storedTagId = [settings integerForKey:@"tag_id"];
    [self setActiveTag:[TagPeer retrieveTagById:storedTagId]];
    NSInteger currentIndex = [settings integerForKey:@"current_index"];
    // Do not use getter here - it may cause an infinite loop if the card count of the active tag is 0 (which should never hapen but)
    [_activeTag setCurrentIndex:currentIndex];
  }
  
  return [[_activeTag retain] autorelease];
}

/**
 * Reloads cardIds for active set
 */
- (void) resetActiveTag
{
  [self resetActiveTagWithCompletionHandler:nil];
}

- (void) resetActiveTagWithCompletionHandler:(dispatch_block_t)completionBlock
{
  LWE_ASSERT_EXC(_activeTag,@"Call to resetActiveTag but no tag active");
  [self setActiveTag:_activeTag completionHandler:completionBlock];
}

#pragma mark - Initialization

/**
 * Retrieve & initialize settings from NSUserDefaults to CurrentState object
 * It is vital for jFlash that this be the first thing called before ANY user
 * functionality is called to prevent versioning issues
 */
- (void) initializeSettings
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  
  // STEP 1 - Migrations for settings for different versions of JFlash - returns YES if something changed
  self.isFirstLaunchAfterUpdate = [UpdateManager performMigrations:settings];
  
  // STEP 2 - is this first run after a fresh install?  Do we need to freshly create settings?
  if ([settings objectForKey:@"settings_already_created"] == nil)
  {
    [self _createDefaultSettings];
    self.isFirstLoad = YES;
    self.isFirstLaunchAfterUpdate = NO;
  }
  else
  {
    self.isFirstLoad = NO;
  }
}

#pragma mark - Default - First time run.

/** Create & store default settings to NSUserDefaults */
- (void) _createDefaultSettings
{
  LWE_LOG(@"Creating the default settings");
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  
#if defined(LWE_JFLASH)
  [settings setValue:SET_READING_BOTH forKey:APP_READING];
#elif defined(LWE_CFLASH)
  [settings setValue:SET_HEADWORD_TYPE_SIMP forKey:APP_HEADWORD_TYPE];
  [settings setValue:SET_PINYIN_COLOR_ON forKey:APP_PINYIN_COLOR];
  [settings setValue:SET_PINYIN_CHANGE_TONE_ON forKey:APP_PINYIN_CHANGE_TONE];
#endif
    
  [settings setInteger:DEFAULT_REMINDER_DAYS forKey:APP_REMINDER];
  [settings setValue:DEFAULT_THEME forKey:APP_THEME];
  [settings setValue:SET_MODE_QUIZ forKey:APP_MODE];
  [settings setValue:SET_KANA_ONLY_ON forKey:APP_KANA_ONLY];
  [settings setValue:SET_J_TO_E forKey:APP_HEADWORD];
  [settings setValue:LWE_CURRENT_VERSION forKey:APP_DATA_VERSION];
  [settings setValue:LWE_CURRENT_VERSION forKey:APP_SETTINGS_VERSION];
  [settings setInteger:DEFAULT_TAG_ID forKey:@"tag_id"];
  [settings setInteger:DEFAULT_USER_ID forKey:APP_USER];
  [settings setInteger:DEFAULT_FREQUENCY_MULTIPLIER forKey:APP_FREQUENCY_MULTIPLIER];
  [settings setInteger:DEFAULT_MAX_STUDYING forKey:APP_MAX_STUDYING];
  [settings setInteger:DEFAULT_DIFFICULTY forKey:APP_DIFFICULTY];
  [settings setValue:[NSDictionary dictionary] forKey:APP_PLUGIN];
  [settings setValue:[NSDate dateWithTimeIntervalSince1970:0] forKey:PLUGIN_LAST_UPDATE];
  [settings setBool:NO forKey:APP_HIDE_BURIED_CARDS];
  [settings setBool:NO forKey:@"db_did_finish_copying"];
  [settings setBool:YES forKey:@"settings_already_created"];
  [settings synchronize];
}

#pragma mark -

//! Standard dealloc
- (void) dealloc
{
  [_activeTag release];
  [starredTag release];
  [super dealloc];
}
   
@end
