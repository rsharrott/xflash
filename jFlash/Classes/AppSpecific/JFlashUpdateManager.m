//
//  JFlashUpdateManager.m
//  xFlash
//
//  Created by Mark Makdad on 6/7/12.
//  Copyright (c) 2012 Long Weekend LLC. All rights reserved.
//

#import "JFlashUpdateManager.h"

@interface JFlashUpdateManager ()
// JFLASH 1.1 -> 1.2
+ (void) _createDefaultSettingsFor11:(NSUserDefaults *)settings;
+ (void) _updateSettingsFrom11to12:(NSUserDefaults *)settings;
+ (BOOL) _needs11to12SettingsUpdate:(NSUserDefaults *)settings;

// JFLASH 1.2 -> 1.3
+ (void) _updateSettingsFrom12to13:(NSUserDefaults *)settings;
+ (BOOL) _needs12to13SettingsUpdate:(NSUserDefaults *)settings;
+ (BOOL) _updatePlistFrom12to13;

// JFLASH 1.4 -> 1.5
+ (BOOL) _needs14to15SettingsUpdate:(NSUserDefaults *)settings;
+ (void) _updateSettingsFrom14to15:(NSUserDefaults *)settings;

// JFLASH 1.5 -> 1.6
+ (BOOL) _needs15to16SettingsUpdate:(NSUserDefaults *) settings;
+ (void) _updateSettingsFrom15to16:(NSUserDefaults *)settings;

// JFLASH 1.6 -> 1.6.1
+ (BOOL) _needs16to161SettingsUpdate:(NSUserDefaults *) settings;
+ (void) _updateSettingsFrom16to161:(NSUserDefaults *)settings;

// JFLASH 1.6.1 -> 1.6.2
+ (BOOL) _needs161to162SettingsUpdate:(NSUserDefaults *) settings;
+ (void) _updateSettingsFrom161to162:(NSUserDefaults *)settings;

// JFLASH 1.6.2 -> 1.7
+ (BOOL) _needs162to17SettingsUpdate:(NSUserDefaults *) settings;
+ (void) _updateSettingsFrom162to17:(NSUserDefaults *)settings;

// JFLASH 1.7 -> 1.8
+ (BOOL) _needs17to18SettingsUpdate:(NSUserDefaults *) settings;
+ (void) _updateSettingsFrom17to18:(NSUserDefaults *)settings;

// JFLASH 1.x -> 2.0 (JMdict dictionary refresh)
+ (BOOL) _needsUpdateTo20:(NSUserDefaults *) settings;
+ (void) _updateSettingsTo20:(NSUserDefaults *)settings;

@end


@implementation JFlashUpdateManager

#pragma mark - JFLASH 
#pragma mark Version 1.1

/** DEBUG ONLY method to simulate settings for JFlash 1.1 **/
+ (void) _createDefaultSettingsFor11:(NSUserDefaults*) settings
{
	LWE_LOG(@"Program runs, and creating the default settings");
	NSArray *keys = [[NSArray alloc] initWithObjects:APP_THEME,APP_HEADWORD,APP_READING,APP_MODE,APP_PLUGIN,APP_DATA_VERSION,nil];
  // Write this manually w/o any constants as this is how it was in v1.1.  jFlash-CARD-1.1.db is
  // deliberately the old name: it no longer ships, and simulating a 1.1 install exercises the 2.0
  // path that replaces it (_updateSettingsTo20 and -[PluginManager bundledPluginsNeedRegistering:]).
  NSDictionary *preinstalledPlugins = [NSDictionary dictionaryWithObjectsAndKeys:@"jFlash-CARD-1.1.db",CARD_DB_KEY,nil];
	NSArray *objects = [[NSArray alloc] initWithObjects:DEFAULT_THEME,SET_J_TO_E,SET_READING_BOTH,SET_MODE_QUIZ,preinstalledPlugins,LWE_JF_VERSION_1_1,nil];
	for (int i = 0; i < [keys count]; i++)
	{
		[settings setValue:[objects objectAtIndex:i] forKey:[keys objectAtIndex:i]];
	}  
	[keys release];
	[objects release];
	
	[settings setInteger:DEFAULT_TAG_ID forKey:@"tag_id"];
	[settings setInteger:DEFAULT_USER_ID forKey:APP_USER];
	[settings setInteger:DEFAULT_FREQUENCY_MULTIPLIER forKey:APP_FREQUENCY_MULTIPLIER];
	[settings setInteger:DEFAULT_MAX_STUDYING forKey:APP_MAX_STUDYING];
	[settings setInteger:DEFAULT_DIFFICULTY forKey:APP_DIFFICULTY];
	
	[settings setBool:NO forKey:@"db_did_finish_copying"];
	[settings setBool:YES forKey:@"settings_already_created"];
}

#pragma mark Version 1.2

/** Updates NSUserDefaults to add 1.2 values*/
+ (void) _updateSettingsFrom11to12:(NSUserDefaults*) settings
{
	LWE_LOG(@"Update from 1.1 to 1.2 Yatta!");
	[settings setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:PLUGIN_LAST_UPDATE];                    
	
  // Now change the app version and the data version
	[settings setValue:LWE_JF_VERSION_1_2 forKey:APP_SETTINGS_VERSION];
  [settings setValue:LWE_JF_VERSION_1_2 forKey:APP_DATA_VERSION];
}


/** Returns YES if the user needs to update settings from 1.1 to 1.2, otherwise returns NO */
+ (BOOL) _needs11to12SettingsUpdate:(NSUserDefaults*) settings
{
	// First things first, do a check to make sure this is not a first run after an upgrade
	if (![settings objectForKey:PLUGIN_LAST_UPDATE] && [settings valueForKey:@"settings_already_created"])
	{
		return YES;
	}
	return NO;
}


#pragma mark Version 1.3

/**
 * Adds the plugin_html_content key to each downloadable plugin
 * \return YES if successful, NO if not
 */
+ (BOOL) _updatePlistFrom12to13
{
  BOOL returnVal = NO;
  
  // Add stuff to the PLIST for the plugin manager
  NSString *docPath = [LWEFile createDocumentPathWithFilename:LWE_AVAILABLE_PLUGIN_PLIST];
  NSMutableDictionary *pluginSettingsPlist = [NSMutableDictionary dictionaryWithContentsOfFile:docPath];
  if (pluginSettingsPlist)
  {
    // Set up the new dictionary
    NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
    
    // EXAMPLES
    if ([pluginSettingsPlist valueForKey:EXAMPLE_DB_KEY])
    {
      NSMutableDictionary *newExamplePlugin = [NSMutableDictionary dictionaryWithDictionary:[pluginSettingsPlist valueForKey:EXAMPLE_DB_KEY]];
      NSString *exampleString = [NSString stringWithContentsOfFile:[LWEFile createBundlePathWithFilename:@"plugin-resources/example-sentences.html"] encoding:NSUTF8StringEncoding error:NULL];
      [newExamplePlugin setObject:exampleString forKey:@"plugin_html_content"];
      [newDict setObject:newExamplePlugin forKey:EXAMPLE_DB_KEY];
    }
    
    // FTS
    if ([pluginSettingsPlist valueForKey:FTS_DB_KEY])
    {
      NSMutableDictionary *newSearchPlugin = [NSMutableDictionary dictionaryWithDictionary:[pluginSettingsPlist valueForKey:FTS_DB_KEY]];
      NSString *searchString = [NSString stringWithContentsOfFile:[LWEFile createBundlePathWithFilename:@"plugin-resources/full-text-search.html"] encoding:NSUTF8StringEncoding error:NULL];
      [newSearchPlugin setObject:searchString forKey:@"plugin_html_content"];
      [newDict setObject:newSearchPlugin forKey:FTS_DB_KEY];
    }
    
    // Now write it out
    if ([newDict writeToFile:docPath atomically:YES])
    {
      returnVal = YES;
    }
    [newDict release];
  }
  else
  {
    LWE_LOG(@"Unable to load PLIST!");
  }
  return returnVal;
}

/** Updates NSUserDefaults to add 1.2 values*/
+ (void) _updateSettingsFrom12to13:(NSUserDefaults *) settings
{
	LWE_LOG(@"Update from 1.2 to 1.3 - we need to make a tag for favorites!");
  
  // Now do the PLIST as well
  [JFlashUpdateManager _updatePlistFrom12to13];
  
  [JFlashUpdateManager _upgradeDBtoVersion:LWE_JF_VERSION_1_3 withSQLStatements:LWE_JF_12_TO_13_SQL_FILENAME forSettings:settings];
}


/** Returns YES if the user needs to update settings from 1.2 to 1.3, otherwise returns NO */
+ (BOOL) _needs12to13SettingsUpdate:(NSUserDefaults*) settings
{
  // We do not want to update the settings if we are STILL waiting on a 1.0 upgrade
  return ([[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_2] &&
          [settings valueForKey:@"settings_already_created"]);
}


#pragma mark Version 1.4

/** Returns YES if the user needs to update settings from 1.3 to 1.4, otherwise returns NO */
+ (BOOL) _needs13to14SettingsUpdate:(NSUserDefaults*) settings
{
  // We do not want to update the settings if we are STILL waiting on a 1.0 upgrade
  return ([[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_3] && 
          [settings valueForKey:@"settings_already_created"]);
}

#pragma mark Version 1.5

+ (BOOL) _needs14to15SettingsUpdate:(NSUserDefaults*) settings
{
  // We do not want to update the settings if we are STILL waiting on a 1.0 upgrade
  return ([[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_4] && 
          [settings valueForKey:@"settings_already_created"]);
}

+ (void) _updateSettingsFrom14to15:(NSUserDefaults *)settings
{
  //New key for the user settings preference in version 1.5
  [settings setBool:NO forKey:APP_HIDE_BURIED_CARDS];
  [settings setObject:LWE_JF_VERSION_1_5 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_1_5 forKey:APP_SETTINGS_VERSION];
}

#pragma mark Version 1.6

+ (BOOL) _needs15to16SettingsUpdate:(NSUserDefaults*) settings
{
  // We do not want to update the settings if we are STILL waiting on a 1.0 upgrade
  return ([[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_5] && 
          [settings valueForKey:@"settings_already_created"]);
}

+ (void) _updateSettingsFrom15to16:(NSUserDefaults *)settings
{
  // We don't use this anymore -- iOS4.0+ state control does most of the heavy lifting for us now.
  [settings removeObjectForKey:@"card_id"];
  [settings setInteger:DEFAULT_REMINDER_DAYS forKey:APP_REMINDER];
  
  //New key for the user settings preference in version 1.6
  [settings setObject:LWE_JF_VERSION_1_6 forKey:APP_SETTINGS_VERSION];
  
  // 1. Execute SQL update file for bad data fixes
  [UpdateManager _upgradeDBtoVersion:LWE_JF_VERSION_1_6 withSQLStatements:LWE_JF_15_TO_16_SQL_FILENAME forSettings:settings];
  [TagPeer recacheCountsForUserTags];
  
  // 2. Update settings inre: plugins -- read from the PLIST file, store everything back to the NSUserDefaults
  NSMutableDictionary *pluginsDict = [[[settings objectForKey:APP_PLUGIN] mutableCopy] autorelease];
  NSString *installedPluginPlistPath = [LWEFile createDocumentPathWithFilename:LWE_DOWNLOADED_PLUGIN_PLIST];
  NSDictionary *installedPluginHash = [NSDictionary dictionaryWithContentsOfFile:installedPluginPlistPath];
  if (installedPluginHash)
  {
    for (NSString *key in installedPluginHash)
    {
      NSDictionary *oldPluginHash = [installedPluginHash objectForKey:key];
      Plugin *newPlugin = [Plugin pluginWithLegacyDictionary:oldPluginHash];
      [pluginsDict setObject:[NSKeyedArchiver archivedDataWithRootObject:newPlugin requiringSecureCoding:NO error:NULL] forKey:newPlugin.pluginId];
    }
  }
  [settings setValue:pluginsDict forKey:APP_PLUGIN];
  
  // Delete old plugin file now
  [LWEFile deleteFile:[LWEFile createDocumentPathWithFilename:LWE_DOWNLOADED_PLUGIN_PLIST]];
}

#pragma mark Version 1.6.1

+ (BOOL) _needs16to161SettingsUpdate:(NSUserDefaults*) settings
{
  // We do not want to update the settings if we are STILL waiting on a 1.0 upgrade
  return ([[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_6] && 
          [settings valueForKey:@"settings_already_created"]);
}

+ (void) _updateSettingsFrom16to161:(NSUserDefaults *)settings
{
  //New key for the user settings preference in version 1.6
  [settings setObject:LWE_JF_VERSION_1_6_1 forKey:APP_SETTINGS_VERSION];
  
  // 1. Execute SQL update file for bad data fixes
  [UpdateManager _upgradeDBtoVersion:LWE_JF_VERSION_1_6_1 withSQLStatements:LWE_JF_16_TO_161_SQL_FILENAME forSettings:settings];
  [TagPeer recacheCountsForUserTags];
}

#pragma mark Version 1.6.2

+ (BOOL) _needs161to162SettingsUpdate:(NSUserDefaults *) settings
{
  return [[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_6_1];
}

+ (void) _updateSettingsFrom161to162:(NSUserDefaults *)settings
{
  //New key for the user settings preference in version 1.6.2
  [settings setObject:LWE_JF_VERSION_1_6_2 forKey:APP_SETTINGS_VERSION];
  
  // 1. Execute SQL update file for bad data fixes
  [UpdateManager _upgradeDBtoVersion:LWE_JF_VERSION_1_6_2 withSQLStatements:LWE_JF_161_TO_162_SQL_FILENAME forSettings:settings];
  [TagPeer recacheCountsForUserTags];
}

#pragma mark Version 1.7

+ (BOOL) _needs162to17SettingsUpdate:(NSUserDefaults *) settings
{
  return [[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_6_2];
}

+ (void) _updateSettingsFrom162to17:(NSUserDefaults *)settings
{
  //New key for the user settings preference in version 1.6.2
  [settings setObject:LWE_JF_VERSION_1_7 forKey:APP_SETTINGS_VERSION];
  
  // 1. Execute SQL update file for bad data fixes
  [UpdateManager _upgradeDBtoVersion:LWE_JF_VERSION_1_7 withSQLStatements:LWE_JF_162_TO_17_SQL_FILENAME forSettings:settings];
  [TagPeer recacheCountsForUserTags];
}

#pragma mark Version 1.8

+ (BOOL) _needs17to18SettingsUpdate:(NSUserDefaults *) settings
{
  return [[settings objectForKey:APP_DATA_VERSION] isEqualToString:LWE_JF_VERSION_1_7];
}

+ (void) _updateSettingsFrom17to18:(NSUserDefaults *)settings
{
  [settings setObject:SET_KANA_ONLY_ON forKey:APP_KANA_ONLY];
  
  [settings setObject:LWE_JF_VERSION_1_8 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_1_8 forKey:APP_SETTINGS_VERSION];
}

#pragma mark Version 2.0

/**
 * 2.0 replaced the 2010 EDICT card data with JMdict (jFlash-CARD-2.0.db): card_ids changed, so study
 * history, sets and the last-studied card from any 1.x install point at cards that are gone or are now
 * different words.  There is no remapping: 1.x user data is reset to the bundled template.  Runs after
 * all the 1.x steps above, so any data version < 2.0 (including 1.8/1.9, which have no step of their
 * own) gets here.  A 2.0 install is not reset; data version 2.1 updates that user database in place.
 */
+ (BOOL) _needsUpdateTo20:(NSUserDefaults *) settings
{
  NSString *dataVersion = [settings objectForKey:APP_DATA_VERSION];
  return ([settings valueForKey:@"settings_already_created"] && [dataVersion isKindOfClass:[NSString class]] &&
          [dataVersion compare:LWE_JF_VERSION_2_0 options:NSNumericSearch] == NSOrderedAscending);
}

+ (void) _updateSettingsTo20:(NSUserDefaults *)settings
{
  // 1. Start the user database over: delete it, and the launch sequence copies the bundled
  //    template again (jFlashAppDelegate _needToCopyDatabase), exactly like a fresh install.
  NSString *userDBPath = [LWEFile createDocumentPathWithFilename:LWE_CURRENT_USER_DATABASE];
  if ([LWEFile fileExists:userDBPath])
  {
    [LWEFile deleteFile:userDBPath];
  }
  [settings setBool:NO forKey:@"db_did_finish_copying"];

  // 2. Point the settings at things the fresh template has.
  [settings setInteger:DEFAULT_TAG_ID forKey:@"tag_id"];
  [settings setInteger:DEFAULT_USER_ID forKey:APP_USER];

  // 3. The plugin registrations (jFlash-CARD-1.1.db etc.) are replaced at launch by the bundled 2.0
  //    plugins: see -[PluginManager bundledPluginsNeedRegistering:].
  // The recopied template already has the new study sets, so the data version skips 2.1 (that step
  // would open the database this one just deleted).  The settings version stays 2.0 so the alert
  // still says study progress was reset.
  [settings setObject:LWE_JF_VERSION_2_1 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_SETTINGS_VERSION];
}

#pragma mark Version 2.1

/**
 * 2.1 changes the built-in study sets (vocabulary levels, hidden sets, names) without changing card
 * ids.  An install that is already at data version 2.0 has its own copy of jFlash.db and will not
 * copy the new template, so this updates that file in place.  Study progress, My Starred Words,
 * user-created sets and last_state stay.  A user-created tag whose id collides with a new system
 * tag (644 and up) is renumbered.  The built-in Nouns list (tag 133) and Nouns 02–13
 * (tags 620–631) are removed.  An active set on one of them moves to Common Nouns Full Set.
 * Card progress on user_history stays, so a card that is also in Common Nouns keeps its level.
 * An editable row at one of those ids is a user set and is left alone.
 *
 * Built-in set names also gain Japanese columns (tag_name_ja, description_ja,
 * group_name_ja).  A 2.0 file does not have those columns, so this adds them
 * before copying.  User-created sets are not given a Japanese name.
 *
 * Same statements as tools/dictbuild/user_db_migration.py.  Keep the two in step.
 */
+ (BOOL) _needsUpdateTo21:(NSUserDefaults *)settings
{
  // The 1.0 App Store build stores exactly "2.0": a fresh install writes
  // LWE_CURRENT_VERSION, and a 1.x upgrade writes LWE_JF_VERSION_2_0.  Both
  // constants have been @"2.0" since the dictionary refresh in #8 (b213301a).
  // #35 and #36 did not change them.  Nothing in that tree writes "2.0.0" or
  // leaves the key empty once settings exist.  A missing or 1.x value still
  // belongs to the reset above.
  NSString *dataVersion = [settings objectForKey:APP_DATA_VERSION];
  if ([dataVersion isEqualToString:LWE_JF_VERSION_2_0] == NO)
  {
    return NO;
  }
  // The 1.x → 2.0 step deletes the user database and the launch sequence copies the new template.
  // Migrating that missing file would do nothing useful.
  if ([settings boolForKey:@"db_did_finish_copying"] == NO)
  {
    return NO;
  }
  NSString *userDBPath = [LWEFile createDocumentPathWithFilename:LWE_CURRENT_USER_DATABASE];
  return [LWEFile fileExists:userDBPath];
}

+ (BOOL) _migrationUpdate:(LWEDatabase *)db sql:(NSString *)sql
{
  [db.dao executeUpdate:sql];
  if ([db.dao hadError])
  {
    LWE_LOG(@"2.1 migration failed: %@ (%@)", sql, [db.dao lastErrorMessage]);
    return NO;
  }
  return YES;
}

+ (BOOL) _migrationUpdate:(LWEDatabase *)db sql:(NSString *)sql withId:(int)newId oldId:(int)oldId
{
  [db.dao executeUpdate:sql, [NSNumber numberWithInt:newId], [NSNumber numberWithInt:oldId]];
  if ([db.dao hadError])
  {
    LWE_LOG(@"2.1 migration failed: %@ (%@)", sql, [db.dao lastErrorMessage]);
    return NO;
  }
  return YES;
}

+ (BOOL) _migrationInt:(LWEDatabase *)db sql:(NSString *)sql into:(int *)outValue
{
  FMResultSet *rs = [db.dao executeQuery:sql];
  if (rs == nil || [db.dao hadError])
  {
    LWE_LOG(@"2.1 migration failed: %@ (%@)", sql, [db.dao lastErrorMessage]);
    [rs close];
    return NO;
  }
  int value = 0;
  if ([rs next])
  {
    value = [rs intForColumnIndex:0];
  }
  [rs close];
  if ([db.dao hadError])
  {
    LWE_LOG(@"2.1 migration failed: %@ (%@)", sql, [db.dao lastErrorMessage]);
    return NO;
  }
  if (outValue != NULL)
  {
    *outValue = value;
  }
  return YES;
}

// Give-up leaves the user database unchanged, so a built-in Nouns row can still
// be there while the new card database has no cards for it.  Opening that set
// is an empty list.  Point the active set at Common Nouns Full Set when that
// row exists, otherwise the default set, and drop the old browse index.
// A user-created set at one of those ids is left alone.  Any other missing id
// still falls back to the default set.
+ (void) _resetActiveSetIfMissing:(NSUserDefaults *)settings
{
  NSString *userPath = [LWEFile createDocumentPathWithFilename:LWE_CURRENT_USER_DATABASE];
  if ([LWEFile fileExists:userPath] == NO)
  {
    return;
  }
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  [db closeDatabase];
  if ([db openDatabase:userPath] == NO)
  {
    return;
  }
  NSInteger tagId = [settings integerForKey:@"tag_id"];
  int editable = 0;
  BOOL found = NO;
  FMResultSet *rs = [db.dao executeQuery:@"SELECT editable FROM tags WHERE tag_id = ?",
                     [NSNumber numberWithInteger:tagId]];
  if (rs == nil || [db.dao hadError])
  {
    [rs close];
    [db closeDatabase];
    return;
  }
  if ([rs next])
  {
    found = YES;
    editable = [rs intForColumnIndex:0];
  }
  [rs close];
  BOOL retiredNoun = (tagId == 133 || (tagId >= 620 && tagId <= 631));
  BOOL userOwned = (found && editable == 1);
  BOOL removedBuiltIn = (retiredNoun && userOwned == NO);
  if (removedBuiltIn || found == NO)
  {
    NSInteger replacement = DEFAULT_TAG_ID;
    if (removedBuiltIn)
    {
      int fullSet = 0;
      if ([JFlashUpdateManager _migrationInt:db sql:
           @"SELECT count(*) FROM tags WHERE tag_id = 2346 AND editable = 0" into:&fullSet] && fullSet > 0)
      {
        replacement = 2346;
      }
    }
    [settings setInteger:replacement forKey:@"tag_id"];
    [settings setInteger:0 forKey:@"current_index"];
  }
  [db closeDatabase];
}

// A failed in-place update must not run again on every launch.  The user database
// is left as it was (progress kept).  Data version moves to 2.1 so the next launch
// continues, and the update alert says the built-in sets could not be changed.
// study_sets_update_failed is cleared once that alert has been shown.
// study_sets_21_failed stays set so a later build can tell this update did not land.
+ (BOOL) _giveUpOnStudySetMigration:(NSUserDefaults *)settings
{
  LWE_LOG(@"2.1 migration stopped. Keeping the existing study sets and progress.");
  [JFlashUpdateManager _resetActiveSetIfMissing:settings];
  [settings setObject:LWE_JF_VERSION_2_1 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_1 forKey:APP_SETTINGS_VERSION];
  [settings setBool:YES forKey:@"study_sets_update_failed"];
  [settings setBool:YES forKey:@"study_sets_21_failed"];
  [settings synchronize];
  return YES;
}

// Open and attach can fail because the file is busy.  Retry those a few times, then
// give up.  A statement that fails inside the transaction will not succeed next time.
+ (BOOL) _noteMigrationFailure:(NSUserDefaults *)settings retry:(BOOL)retry
{
  if (retry == NO)
  {
    return [JFlashUpdateManager _giveUpOnStudySetMigration:settings];
  }
  NSInteger attempts = [settings integerForKey:@"study_set_migration_21_failures"] + 1;
  [settings setInteger:attempts forKey:@"study_set_migration_21_failures"];
  [settings synchronize];
  LWE_LOG(@"2.1 migration could not open the user database (attempt %ld).", (long)attempts);
  if (attempts >= 3)
  {
    return [JFlashUpdateManager _giveUpOnStudySetMigration:settings];
  }
  return NO;
}

+ (BOOL) _column:(NSString *)column existsOn:(NSString *)table db:(LWEDatabase *)db
{
  FMResultSet *rs = [db.dao executeQuery:[NSString stringWithFormat:@"PRAGMA table_info(%@)", table]];
  BOOL found = NO;
  while ([rs next])
  {
    if ([[rs stringForColumn:@"name"] isEqualToString:column])
    {
      found = YES;
    }
  }
  [rs close];
  return found;
}

+ (BOOL) _ensureLocaleColumns:(LWEDatabase *)db
{
  // A 2.0 user file has none of these.  A second run finds them and skips the ALTER.
  NSArray *columns = [NSArray arrayWithObjects:
                      [NSArray arrayWithObjects:@"tags", @"tag_name_ja", nil],
                      [NSArray arrayWithObjects:@"tags", @"description_ja", nil],
                      [NSArray arrayWithObjects:@"groups", @"group_name_ja", nil],
                      nil];
  for (NSArray *pair in columns)
  {
    NSString *table = [pair objectAtIndex:0];
    NSString *column = [pair objectAtIndex:1];
    if ([JFlashUpdateManager _column:column existsOn:table db:db])
    {
      continue;
    }
    NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, column];
    if ([JFlashUpdateManager _migrationUpdate:db sql:sql] == NO)
    {
      return NO;
    }
  }
  return YES;
}

+ (BOOL) _migrateUserDatabase:(LWEDatabase *)db renamedTags:(NSMutableDictionary *)renames
{
  if ([JFlashUpdateManager _ensureLocaleColumns:db] == NO)
  {
    return NO;
  }
  NSString *systemTags = @"SELECT tag_id FROM tpl.tags WHERE editable = 0 AND tag_id != 0";
  FMResultSet *rs = [db.dao executeQuery:
    [NSString stringWithFormat:@"SELECT tag_id FROM tags WHERE editable = 1 AND tag_id IN (%@) ORDER BY tag_id", systemTags]];
  NSMutableArray *collisions = [NSMutableArray array];
  while ([rs next])
  {
    [collisions addObject:[NSNumber numberWithInt:[rs intForColumnIndex:0]]];
  }
  [rs close];
  if ([db.dao hadError])
  {
    LWE_LOG(@"2.1 migration failed while reading colliding tags: %@", [db.dao lastErrorMessage]);
    return NO;
  }

  int maxUser = 0;
  int maxTemplate = 0;
  if ([JFlashUpdateManager _migrationInt:db sql:@"SELECT COALESCE(MAX(tag_id), 0) FROM tags" into:&maxUser] == NO ||
      [JFlashUpdateManager _migrationInt:db sql:@"SELECT COALESCE(MAX(tag_id), 0) FROM tpl.tags" into:&maxTemplate] == NO)
  {
    return NO;
  }
  int nextId = (maxUser > maxTemplate ? maxUser : maxTemplate) + 1;
  for (NSNumber *oldNumber in collisions)
  {
    int oldId = [oldNumber intValue];
    int newId = nextId;
    nextId += 1;
    [renames setObject:[NSNumber numberWithInt:newId] forKey:oldNumber];
    NSArray *statements = [NSArray arrayWithObjects:
      @"UPDATE card_tag_link SET tag_id = ? WHERE tag_id = ?",
      @"UPDATE group_tag_link SET tag_id = ? WHERE tag_id = ?",
      @"UPDATE last_state SET tag_id = ? WHERE tag_id = ?",
      @"UPDATE tag_user_card_levels SET tag_id = ? WHERE tag_id = ?",
      @"UPDATE tags SET tag_id = ? WHERE tag_id = ?",
      nil];
    for (NSString *sql in statements)
    {
      if ([JFlashUpdateManager _migrationUpdate:db sql:sql withId:newId oldId:oldId] == NO)
      {
        return NO;
      }
    }
  }

  if ([JFlashUpdateManager _migrationUpdate:db sql:
       @"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, tag_name_ja, description_ja, editable, count) "
       "SELECT tag_id, tag_name, description, tag_name_ja, description_ja, editable, count FROM tpl.tags "
       "WHERE editable = 0 AND tag_id != 0"] == NO)
  {
    return NO;
  }
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       @"INSERT OR REPLACE INTO groups (group_id, group_name, group_name_ja, owner_id, tag_count, recommended) "
       "SELECT group_id, group_name, group_name_ja, owner_id, tag_count, recommended FROM tpl.groups"] == NO)
  {
    return NO;
  }
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       [NSString stringWithFormat:@"DELETE FROM group_tag_link WHERE tag_id IN (%@)", systemTags]] == NO)
  {
    return NO;
  }
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       [NSString stringWithFormat:
        @"INSERT INTO group_tag_link (group_id, tag_id) "
        "SELECT group_id, tag_id FROM tpl.group_tag_link WHERE tag_id IN (%@)", systemTags]] == NO)
  {
    return NO;
  }
  // Built-in Nouns (133) and Nouns 02–13.  The template no longer has these system
  // tags.  Point the active set at Common Nouns Full Set and drop the old rows.
  // user_history is per card and stays.  Same statements as
  // user_db_migration._fold_retired_noun_tags.  This step is jFlash only: cFlash
  // tag 133 is a different set and does not run this migration.
  int fullSetId = 0;
  if ([JFlashUpdateManager _migrationInt:db sql:
       @"SELECT tag_id FROM tpl.tags WHERE tag_name = 'Common Nouns Full Set' AND editable = 0"
       into:&fullSetId] == NO || fullSetId == 0)
  {
    LWE_LOG(@"2.1 migration could not find Common Nouns Full Set");
    return NO;
  }
  NSString *retiredNouns = @"(tag_id = 133 OR tag_id BETWEEN 620 AND 631)";
  NSString *notUserOwned = @"AND tag_id NOT IN (SELECT tag_id FROM tags WHERE editable = 1)";
  FMResultSet *nounRs = [db.dao executeQuery:[NSString stringWithFormat:
    @"SELECT tag_id FROM tags WHERE editable = 0 AND %@ "
    "UNION SELECT tag_id FROM last_state WHERE %@ %@",
    retiredNouns, retiredNouns, notUserOwned]];
  if (nounRs == nil || [db.dao hadError])
  {
    LWE_LOG(@"2.1 migration failed while reading retired Nouns tags: %@", [db.dao lastErrorMessage]);
    [nounRs close];
    return NO;
  }
  while ([nounRs next])
  {
    [renames setObject:[NSNumber numberWithInt:fullSetId] forKey:[NSNumber numberWithInt:[nounRs intForColumnIndex:0]]];
  }
  [nounRs close];
  if ([db.dao hadError])
  {
    LWE_LOG(@"2.1 migration failed while reading retired Nouns tags: %@", [db.dao lastErrorMessage]);
    return NO;
  }
  NSArray *nounFold = [NSArray arrayWithObjects:
    [NSString stringWithFormat:
     @"UPDATE last_state SET tag_id = %d WHERE %@ %@", fullSetId, retiredNouns, notUserOwned],
    [NSString stringWithFormat:
     @"DELETE FROM tag_user_card_levels WHERE %@ %@", retiredNouns, notUserOwned],
    [NSString stringWithFormat:
     @"DELETE FROM card_tag_link WHERE %@ %@", retiredNouns, notUserOwned],
    [NSString stringWithFormat:
     @"DELETE FROM group_tag_link WHERE %@ %@", retiredNouns, notUserOwned],
    [NSString stringWithFormat:
     @"DELETE FROM tags WHERE editable = 0 AND %@", retiredNouns],
    nil];
  for (NSString *sql in nounFold)
  {
    if ([JFlashUpdateManager _migrationUpdate:db sql:sql] == NO)
    {
      return NO;
    }
  }
  // The 2.0 template has group links whose tags were removed.  Readers join tags,
  // so they were invisible, but they are not part of the catalog.
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       @"DELETE FROM group_tag_link WHERE tag_id NOT IN (SELECT tag_id FROM tags)"] == NO)
  {
    return NO;
  }
  // Tag 0 keeps its card count.  Copy only the Japanese columns.
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       @"UPDATE tags SET tag_name_ja = (SELECT tag_name_ja FROM tpl.tags WHERE tag_id = 0), "
       "description_ja = (SELECT description_ja FROM tpl.tags WHERE tag_id = 0) "
       "WHERE tag_id = 0"] == NO)
  {
    return NO;
  }
  // An editable built-in keeps a Japanese name only while its English name still
  // matches the template.  A renamed set, and every user-created set, stays as named.
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       @"UPDATE tags SET tag_name_ja = (SELECT tag_name_ja FROM tpl.tags t WHERE t.tag_id = tags.tag_id), "
       "description_ja = (SELECT description_ja FROM tpl.tags t WHERE t.tag_id = tags.tag_id) "
       "WHERE editable = 1 AND tag_id IN (SELECT tag_id FROM tpl.tags WHERE editable = 1) "
       "AND tag_name = (SELECT tag_name FROM tpl.tags t WHERE t.tag_id = tags.tag_id)"] == NO)
  {
    return NO;
  }
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       @"UPDATE tags SET tag_name_ja = NULL, description_ja = NULL "
       "WHERE editable = 1 AND tag_id IN (SELECT tag_id FROM tpl.tags WHERE editable = 1) "
       "AND tag_name != (SELECT tag_name FROM tpl.tags t WHERE t.tag_id = tags.tag_id)"] == NO)
  {
    return NO;
  }
  if ([JFlashUpdateManager _migrationUpdate:db sql:
       @"UPDATE groups SET tag_count = ("
       "SELECT count(*) FROM group_tag_link g JOIN tags t ON t.tag_id = g.tag_id "
       "WHERE g.group_id = groups.group_id AND g.tag_id != 0)"] == NO)
  {
    return NO;
  }
  int starred = 0;
  if ([JFlashUpdateManager _migrationInt:db sql:@"SELECT count(*) FROM card_tag_link WHERE tag_id = 0" into:&starred] == NO)
  {
    return NO;
  }
  if ([JFlashUpdateManager _migrationUpdate:db sql:@"UPDATE tags SET count = ? WHERE tag_id = ?"
                                         withId:starred oldId:0] == NO)
  {
    return NO;
  }
  int maxId = 0;
  int seqRows = 0;
  if ([JFlashUpdateManager _migrationInt:db sql:@"SELECT COALESCE(MAX(tag_id), 0) FROM tags" into:&maxId] == NO ||
      [JFlashUpdateManager _migrationInt:db sql:@"SELECT count(*) FROM sqlite_sequence WHERE name = 'tags'" into:&seqRows] == NO)
  {
    return NO;
  }
  if (seqRows == 0)
  {
    [db.dao executeUpdate:@"INSERT INTO sqlite_sequence (name, seq) VALUES ('tags', ?)",
     [NSNumber numberWithInt:maxId]];
    if ([db.dao hadError])
    {
      LWE_LOG(@"2.1 migration failed: sqlite_sequence insert (%@)", [db.dao lastErrorMessage]);
      return NO;
    }
  }
  else
  {
    int seq = 0;
    if ([JFlashUpdateManager _migrationInt:db sql:@"SELECT seq FROM sqlite_sequence WHERE name = 'tags'" into:&seq] == NO)
    {
      return NO;
    }
    if (seq < maxId)
    {
      [db.dao executeUpdate:@"UPDATE sqlite_sequence SET seq = ? WHERE name = 'tags'",
       [NSNumber numberWithInt:maxId]];
      if ([db.dao hadError])
      {
        LWE_LOG(@"2.1 migration failed: sqlite_sequence update (%@)", [db.dao lastErrorMessage]);
        return NO;
      }
    }
  }
  return YES;
}

+ (BOOL) _updateSettingsTo21:(NSUserDefaults *)settings
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  NSString *userPath = [LWEFile createDocumentPathWithFilename:LWE_CURRENT_USER_DATABASE];
  NSString *templatePath = [LWEFile createBundlePathWithFilename:LWE_CURRENT_USER_DATABASE];
  if ([db openDatabase:userPath] == NO)
  {
    LWE_LOG(@"2.1 migration could not open %@", userPath);
    return [JFlashUpdateManager _noteMigrationFailure:settings retry:YES];
  }
  BOOL attached = [db attachDatabase:templatePath withName:@"tpl"];
  if (attached == NO)
  {
    LWE_LOG(@"2.1 migration could not attach the template at %@", templatePath);
    [db closeDatabase];
    return [JFlashUpdateManager _noteMigrationFailure:settings retry:YES];
  }

  // If BEGIN failed, later statements would autocommit and rollback would do nothing.
  if ([db.dao beginDeferredTransaction] == NO)
  {
    LWE_LOG(@"2.1 migration could not start a transaction: %@", [db.dao lastErrorMessage]);
    [db detachDatabase:@"tpl"];
    [db closeDatabase];
    return [JFlashUpdateManager _noteMigrationFailure:settings retry:NO];
  }
  NSMutableDictionary *renames = [NSMutableDictionary dictionary];
  BOOL ok = [JFlashUpdateManager _migrateUserDatabase:db renamedTags:renames];
  NSInteger previousTag = [settings integerForKey:@"tag_id"];
  BOOL retiredNounTag = (previousTag == 133 || (previousTag >= 620 && previousTag <= 631));
  if (ok && retiredNounTag)
  {
    // The continuation row is gone.  A crash after the tag delete and before this
    // settings write would otherwise leave the active set on a missing id.  An
    // editable row here is a user set and keeps its id.
    FMResultSet *tagRs = [db.dao executeQuery:@"SELECT editable FROM tags WHERE tag_id = ?",
                          [NSNumber numberWithInteger:previousTag]];
    if (tagRs == nil || [db.dao hadError])
    {
      LWE_LOG(@"2.1 migration failed while folding the active Nouns set: %@", [db.dao lastErrorMessage]);
      [tagRs close];
      ok = NO;
    }
    else
    {
      BOOL userOwned = NO;
      if ([tagRs next] && [tagRs intForColumnIndex:0] == 1)
      {
        userOwned = YES;
      }
      [tagRs close];
      if (userOwned == NO)
      {
        int fullSetId = 0;
        if ([JFlashUpdateManager _migrationInt:db sql:
             @"SELECT tag_id FROM tpl.tags WHERE tag_name = 'Common Nouns Full Set' AND editable = 0"
             into:&fullSetId] == NO || fullSetId == 0)
        {
          LWE_LOG(@"2.1 migration could not find Common Nouns Full Set");
          ok = NO;
        }
        else
        {
          [renames setObject:[NSNumber numberWithInt:fullSetId] forKey:[NSNumber numberWithInteger:previousTag]];
        }
      }
    }
  }
  // The new id is written only after the database commit.  A failed commit
  // leaves the saved active set where it was.  current_index stays too: the
  // session carry reads it to find the card the user was on, then stores that
  // card's place in Common Nouns, or 0 when the card is not in the set.
  NSNumber *moved = nil;
  if (ok)
  {
    moved = [renames objectForKey:[NSNumber numberWithInteger:previousTag]];
    ok = [db.dao commit];
    if (ok == NO)
    {
      LWE_LOG(@"2.1 migration could not commit: %@", [db.dao lastErrorMessage]);
    }
  }
  if (ok == NO)
  {
    [db.dao rollback];
    moved = nil;
  }
  // DETACH while the transaction is still open fails with "database is locked".
  [db detachDatabase:@"tpl"];
  [db closeDatabase];
  if (ok == NO)
  {
    return [JFlashUpdateManager _noteMigrationFailure:settings retry:NO];
  }
  if (moved != nil)
  {
    [settings setInteger:[moved integerValue] forKey:@"tag_id"];
  }

  [settings setObject:LWE_JF_VERSION_2_1 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_1 forKey:APP_SETTINGS_VERSION];
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  [settings removeObjectForKey:@"study_set_migration_21_failures"];
  [settings synchronize];
  return YES;
}

// The alert shows the failure once.  study_sets_21_failed is not cleared here.
+ (BOOL) _consumeStudySetFailureNotice:(NSUserDefaults *)settings
{
  if ([settings boolForKey:@"study_sets_update_failed"] == NO)
  {
    return NO;
  }
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings synchronize];
  return YES;
}

#pragma mark -

+ (BOOL) performMigrations:(NSUserDefaults*)settings
{
  BOOL migrated = NO;
  /**
   * JFLASH MIGRATIONS
   */
  // NOTE THAT THESE ARE MIGRATIONS!!!!  They should be in order of version.
	
  //In the jFlash 1.2, jFlash included some new features, and it requires the plugin manager to be updated.
  //The plugin manager will have to look at the last time it gets updated, there is the list of the data
  if ([JFlashUpdateManager _needs11to12SettingsUpdate:settings])
  {
		LWE_LOG(@"[Migration Log]Oops, we need update to 1.2 version");
	  [JFlashUpdateManager _updateSettingsFrom11to12:settings];
    migrated = YES;
  }
  
  // JFlash 1.3 - does small database migration for favorites!
  if ([JFlashUpdateManager _needs12to13SettingsUpdate:settings])
  {
		LWE_LOG(@"[Migration Log]Oops, we need update to 1.3 version");
	  [JFlashUpdateManager _updateSettingsFrom12to13:settings];
    migrated = YES;
  }
  
  if ([JFlashUpdateManager _needs13to14SettingsUpdate:settings])
  {
    LWE_LOG(@"[Migration Log]Updating to 1.4 version");
    [JFlashUpdateManager _upgradeDBtoVersion:LWE_JF_VERSION_1_4 withSQLStatements:LWE_JF_13_TO_14_SQL_FILENAME forSettings:settings];
    [TagPeer recacheCountsForUserTags];
    migrated = YES;
  }
  
  if ([JFlashUpdateManager _needs14to15SettingsUpdate:settings])
  {
    LWE_LOG(@"[Migration Log]YAY! Updating to 1.5 version");
    [JFlashUpdateManager _updateSettingsFrom14to15:settings];
    migrated = YES;
  }
  
  if ([JFlashUpdateManager _needs15to16SettingsUpdate:settings])
  {
    LWE_LOG(@"[Migration Log]YAY! Updating to 1.6 version");
    [JFlashUpdateManager _updateSettingsFrom15to16:settings];
    migrated = YES;
  }
  
  if ([JFlashUpdateManager _needs16to161SettingsUpdate:settings])
  {
    LWE_LOG(@"[Migration Log]YAY! Updating to 1.6.1 version");
    [JFlashUpdateManager _updateSettingsFrom16to161:settings];
    migrated = YES;
  }
  
  if ([JFlashUpdateManager _needs161to162SettingsUpdate:settings])
  {
    LWE_LOG(@"[Migration Log]YAY! Updating to 1.6.2 version");
    [JFlashUpdateManager _updateSettingsFrom161to162:settings];
    migrated = YES;
  }
  
  if ([JFlashUpdateManager _needs162to17SettingsUpdate:settings])
  {
    LWE_LOG(@"[Migration Log]YAY! Updating to 1.7 version");
    [JFlashUpdateManager _updateSettingsFrom162to17:settings];
    migrated = YES;
  }
  
  if ([JFlashUpdateManager _needs17to18SettingsUpdate:settings])
  {
    LWE_LOG(@"[Migration Log]YAY! Updating to 1.8 version");
    [JFlashUpdateManager _updateSettingsFrom17to18:settings];
    migrated = YES;
  }

  // Must stay after every 1.x step: it catches every pre-2.0 data version.
  if ([JFlashUpdateManager _needsUpdateTo20:settings])
  {
    LWE_LOG(@"[Migration Log] Updating to 2.0: new dictionary, resetting 1.x study data");
    [JFlashUpdateManager _updateSettingsTo20:settings];
    migrated = YES;
  }

  // 2.0 installs keep their user database.  Bring tags, groups and links up to the new catalog.
  if ([JFlashUpdateManager _needsUpdateTo21:settings])
  {
    LWE_LOG(@"[Migration Log] Updating to 2.1: study sets, keeping study progress");
    if ([JFlashUpdateManager _updateSettingsTo21:settings])
    {
      migrated = YES;
    }
  }

  return migrated;
}

+ (void) showUpgradeAlertView:(NSUserDefaults *)settings delegate:(id<UIAlertViewDelegate>)alertDelegate
{
  NSString *version = [settings objectForKey:APP_SETTINGS_VERSION];
  // The 1.6.x alerts promoted Rikai Browser, which is no longer on the App Store; removed.
  if ([JFlashUpdateManager _consumeStudySetFailureNotice:settings])
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Couldn't update study sets",@"JFlash2.1 upgrade failed alert title")
                                       message:NSLocalizedString(@"Your study progress, starred words, and sets you created were kept. The built-in study sets are unchanged.",@"JFlash2.1 upgrade failed alert msg")];
  }
  else if ([version isEqualToString:LWE_JF_VERSION_2_0])
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Updated to Japanese in a Flash! 2.0",@"JFlash2.0 upgrade alert title")
                                       message:NSLocalizedString(@"The dictionary has been updated to the current JMdict, with new example sentences from Tatoeba. Because the cards changed, your study progress and sets from the previous version have been reset.",@"JFlash2.0 upgrade alert msg")];
  }
  else if ([version isEqualToString:LWE_JF_VERSION_2_1])
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Updated study sets",@"JFlash2.1 upgrade alert title")
                                       message:NSLocalizedString(@"The built-in study sets have been updated. Your study progress, starred words, and sets you created were kept.",@"JFlash2.1 upgrade alert msg")];
  }
  else if ([version isEqualToString:LWE_JF_VERSION_1_7])
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Updated to Japanese in a Flash! 1.7",@"JFlash1.7 upgrade alert title")
                                       message:NSLocalizedString(@"Thanks for updating!  Cool new feature: you can browse example sentences for a card within the Search feature.  Also, thanks to Kobe and Murray, who helped us update about 8 dictionary entries.",@"JFlash1.7 upgrade alert msg")];
  }
}



@end
