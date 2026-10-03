//
//  PluginManager.m
//  jFlash
//
//  Created by Mark Makdad on 6/3/10.
//  Copyright 2010 Long Weekend Inc. All rights reserved.
//

#import "PluginManager.h"
NSString * const LWEPluginDidInstall = @"LWEPluginDidInstall";

@interface PluginManager ()
- (void)_initDownloadablePluginsDict;
- (void) _registerPlugin:(Plugin *)plugin;
- (BOOL) _loadDatabasePlugin:(Plugin *)plugin error:(NSError **)error;
@end

@implementation PluginManager

@synthesize downloadablePlugins;

/**
 * Customized initializer - the available plugin dictionary is defined in this method
 *
 * In this intializer, it also loads the downloadable plist file (to persist the available plugin to download)
 * and also downloaded plist file (to persist the list of downloaded plugin).
 * If, both of the plist does not exist, we provide one with the bundle of the app. Load from there, and
 * write it to the document immediately. That case only happens in the first time the program runs.
 *
 */
- (id) init
{
  if ((self = [super init]))
  {
    _loadedPlugins = [[NSMutableDictionary alloc] init];
		[self _initDownloadablePluginsDict];
	}
  return self;
}

/** 
 * This method will try to load the "available for download" plugin list from the user document folder,
 * if it is not there it means the program first launched (after upgrade, or after install).
 *
 * It has default bundle plist file which contains all of the "should be available for download"
 * plugin list file, read from that, and check with the user settings, if the user has not downloaded
 * the plugin, it means that it should copy the one from the bundle, and populate the path to the plugin,
 * and last step would be write the file back to the DOCUMENT folder.
 *
 * However, if its not the first run, the user should already has the file in the DOCUMENT folder, and
 * just load it from there directly.
 *
 * UPDATE: After given some thought, it would be best to read from file only if the device not
 * connected to the internet, if the device is connected, it should check for update right away.
 */

- (void) _initDownloadablePluginsDict
{
	NSString *docPath = [LWEFile createDocumentPathWithFilename:LWE_AVAILABLE_PLUGIN_PLIST];
  NSString *bundlePath = [LWEFile createBundlePathWithFilename:LWE_AVAILABLE_PLUGIN_PLIST];
  
  BOOL docPathExists = [LWEFile fileExists:docPath];
  BOOL bundlePathExists = [LWEFile fileExists:bundlePath];
  LWE_ASSERT_EXC((docPathExists || bundlePathExists), @"PLIST must exist somewhere!  Checked: %@ AND %@",docPath,bundlePath);
    
	if (docPathExists)
	{
    self.downloadablePlugins = [NSDictionary dictionaryWithContentsOfFile:docPath];
	}
	else if (bundlePathExists)
	{
    // If Doc path doesn't exist, it must be first load
    NSDictionary *installedPluginsDict = [[NSUserDefaults standardUserDefaults] objectForKey:APP_PLUGIN];
    NSArray *plugins = [[NSDictionary dictionaryWithContentsOfFile:bundlePath] objectForKey:@"Plugins"];
    
    NSMutableDictionary *availablePlugins = [NSMutableDictionary dictionary];
    for (NSDictionary *pluginHash in plugins)
    {
      Plugin *plugin = [Plugin pluginWithDictionary:pluginHash];
      if ([installedPluginsDict objectForKey:plugin.pluginId] == nil)
      {
        [availablePlugins setValue:plugin forKey:plugin.pluginId];
      }
    }
    self.downloadablePlugins = (NSDictionary *)availablePlugins;
	}
}

#pragma mark - Public Methods - Enable, load, disable plugins

/**
 * Takes the plugin out of active use. NOOP for file-based add-ons
 */
- (BOOL) disablePlugin:(Plugin*)plugin
{
  // First, make sure the plugin is actually loaded
  BOOL returnVal = NO;
  if ([_loadedPlugins objectForKey:plugin.pluginId] && plugin.isDatabasePlugin)
  {
    LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
    if ([db detachDatabase:plugin.name])
    {
      [_loadedPlugins removeObjectForKey:plugin.pluginId];
      returnVal = YES;
    }
  }
  return returnVal;
}


/**
 * Load all plugins from settings file, after loading all of the downloaded plugin.
 * It also checks whether this is the right time for checking the new update. 
 */
- (BOOL) loadInstalledPlugins
{
  BOOL success = YES;
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSDictionary *plugins = [settings objectForKey:APP_PLUGIN];
  for (NSString *pluginKey in plugins)
  {
    // Re-instantiate the plugins here
    NSData *data = [plugins objectForKey:pluginKey];
    Plugin *plugin = (Plugin*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    // Now try to load it
    NSError *error = nil;
    success = (success && [self loadPlugin:plugin error:&error]);
  }
  return success;
}  


/**
 * Loads a plugin from a file, returns plugin key name
 */
- (BOOL) loadPlugin:(Plugin *)plugin error:(NSError **)error;
{
  // You can't reload a plugin that's already loaded.
  if ([_loadedPlugins objectForKey:plugin.pluginId])
  {
    return YES;
  }
  
  // If it's a directory, just make sure it exists only.
  BOOL pathExists = [LWEFile fileExists:[plugin fullPath]];
  if (pathExists == NO)
  {
    // TODO: MORE ROBUST CODE HERE PLEEEZE
    // Make sure we can find the file - if not, it's probably after the user did a restore.  Try to recover!
    if (error != NULL)
    {
      *error = [NSError errorWithCode:5 localizedDescription:@"Cannot find plugin file/directory."];
    }
    return NO;
  }
  
  BOOL returnVal = YES;
  
  // Test drive database plugins to verify an OK plugin
  if (plugin.isDatabasePlugin)
  {
    returnVal = [self _loadDatabasePlugin:plugin error:error];
  }
  
  // If we were successful, add to the array
  if (returnVal)
  {
    [_loadedPlugins setValue:plugin forKey:plugin.pluginId];
  }
  return returnVal;
}

- (BOOL) _loadDatabasePlugin:(Plugin *)plugin error:(NSError **)error
{
  LWE_ASSERT_EXC(plugin.isDatabasePlugin, @"You must pass a database plugin to use this method.");
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  
  // 1) Can we attach the database?
  if ([db attachDatabase:[plugin fullPath] withName:LWEDatabaseTempAttachName] == NO)
  {
    // Fail and return!
    if (error != NULL)
    {
      *error = [NSError errorWithCode:1 localizedDescription:@"Failed to attach database"];
    }
    return NO;
  }
  
  // 2) Does it pass a version test?
  NSString *version = [db databaseVersionForDatabase:LWEDatabaseTempAttachName];
  [db detachDatabase:LWEDatabaseTempAttachName];
  if (version == nil)
  {
    if (error != NULL)
    {
      *error = [NSError errorWithCode:2 localizedDescription:@"Attached database, but could not find version table data"];
    }
    return NO;
  }
  
  // 3) Reattach with proper name
  if ([db attachDatabase:[plugin fullPath] withName:plugin.pluginId] == NO)
  {		  
    if (error != NULL)
    {
      *error = [NSError errorWithCode:3 localizedDescription:@"Could not re-attach database w/ new name - pluginId invalid?"];
    }
    return NO;
  }
  return YES;
}

/**
 * Installs a plugin.
 * Returns YES on success, no on failure (with error)
 */
- (BOOL) installPlugin:(Plugin *)plugin error:(NSError **)error;
{
  LWE_ASSERT_EXC((plugin && [plugin isKindOfClass:[Plugin class]]), @"Don't be like that, fool. I take plugins.");
  
  // 1. Get our previous version if we have one, disable it
  Plugin *oldPlugin = [_loadedPlugins objectForKey:plugin.pluginId];
  if (oldPlugin)
  {
    [self disablePlugin:oldPlugin];
  }
  
  // 2. Load it -- quick return on failure
  if ([self loadPlugin:plugin error:error] == NO)
  {
    // Well, put the old one back - no need to keep track of the error
    [self loadPlugin:oldPlugin error:NULL];
    return NO;
  }
  
  // 3. Register it
  [self _registerPlugin:plugin];
  
  // 4. Set not to be backed up from Docs dir
  if (plugin.fileLocation == kLWEFileLocationDocuments)
  {
    BOOL isNotBackedUp = [LWEFile addSkipBackupAttributeToItemAtPath:[plugin fullPath]];
    LWE_ASSERT_EXC(isNotBackedUp, @"Failed to set skip backup attribute for file at %@", plugin.filePath);
  }
  
  // 5. Be nice, delete the old plugin
  if (oldPlugin)
  {
    [LWEFile deleteFile:oldPlugin.filePath];
  }
  
  // 6. Finally, remove from available downloads
  NSMutableDictionary *tmpDict = [NSMutableDictionary dictionaryWithDictionary:self.downloadablePlugins];
  [tmpDict removeObjectForKey:plugin.pluginId];
  self.downloadablePlugins = (NSDictionary *)tmpDict;
  
  // 8. Tell anyone who cares that we've just successfully installed a plugin
  [[NSNotificationCenter defaultCenter] postNotificationName:LWEPluginDidInstall object:plugin userInfo:nil];

  return YES;
}

#pragma mark - Public Methods - Find out about plugin state

//! Returns the version string of a plugin, or nil if the key is not a loaded plugin
- (NSString *) versionForLoadedPlugin:(NSString*)key
{
  NSString *returnVal = nil;
  for (NSString *pluginId in _loadedPlugins)
  {
    if ([pluginId isEqualToString:key])
    {
      Plugin *plugin = [_loadedPlugins objectForKey:pluginId];
      returnVal =  plugin.version;
    }
  }
  return returnVal;
}

//! Tells whether or not a plugin is in the dictionary as loaded
- (BOOL) pluginKeyIsLoaded:(NSString *)pluginKey
{
  return ([_loadedPlugins objectForKey:pluginKey] != nil);
}

- (Plugin *)pluginForKey:(NSString *)pluginKey
{
  return [_loadedPlugins objectForKey:pluginKey];
}

- (NSDictionary *) loadedPlugins
{
  return [NSDictionary dictionaryWithDictionary:_loadedPlugins];
}

#pragma mark - Private methods

/**
 * Register plugin filename with NSUserDefaults
 *
 * Returns NO means that the system user setting has already had the key, so this is a plugin update
 * YES means this is a refresh plugin install.
 *
 */
- (void) _registerPlugin:(Plugin *)plugin
{
  // Update the settings so we maintain this on startup
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSDictionary *pluginSettings = [settings objectForKey:APP_PLUGIN];
  LWE_ASSERT_EXC(pluginSettings,@"Whoa, how can we run this method without default plugin settings?");
  
  // We have to change one key, so create a mutable dict.  Kind of a waste, but.  Serialize the plugin
  NSMutableDictionary *tmpDict = [NSMutableDictionary dictionaryWithDictionary:pluginSettings];
  [tmpDict setObject:[NSKeyedArchiver archivedDataWithRootObject:plugin] forKey:plugin.pluginId];
  [settings setValue:tmpDict forKey:APP_PLUGIN];
  [settings synchronize];
}


#pragma mark - Memory Management

- (void)dealloc
{
	[downloadablePlugins release];
  [_loadedPlugins release];
  [super dealloc];
}

@end
