//
//  PluginManager.h
//  jFlash
//
//  Created by Mark Makdad on 6/3/10.
//  Copyright 2010 Long Weekend Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMResultSet.h"
#import "Plugin.h"
#import "NSDate+LWEUtilities.h"

extern NSString * const LWEPluginDidInstall;

//! Handles downloaded plugins' installation and versioning
@interface PluginManager : NSObject
{
  NSMutableDictionary *_loadedPlugins;
}

// ======= THESE DO SOMETHING =========

//! Returns YES if the plugin was able to be disabled.  Directory plugins always return YES.
- (BOOL) disablePlugin:(Plugin*)plugin;

//! Returns YES after successfully loading (enabling) all installed plugins.
- (BOOL) loadInstalledPlugins;

/**
 * Pass the full pathname to a plugin, as well as the type.
 * Potential types are "database" and "directory".  In the case of "directory", pass
 * the path as a path with trailing slash.
 *
 * In the case of a database, point directly at the database file.
 */
- (BOOL) installPlugin:(Plugin *)plugin error:(NSError **)error;

//========= THESE GIVE STATE ========

//! NO while LWE_PLUGIN_SERVER is empty (see Constants.m): no update checks, no downloads
+ (BOOL) remotePluginsEnabled;
- (BOOL) isTimeForCheckingUpdate;

//! Fetches the latest available-plugins plist from the server using NSURLSession.
//! The completion block is invoked on the main queue with success=YES if the
//! plist was downloaded and applied, NO otherwise. The completion block may be
//! nil for fire-and-forget callers.
- (void) checkNewPluginsWithCompletion:(void (^)(BOOL success))completion;


//! Returns YES if the plugin is loaded.  Directory plugins always return YES.
- (BOOL) pluginKeyIsLoaded:(NSString *)pluginKey;

- (Plugin *)pluginForKey:(NSString *)pluginKey;

- (NSString*) versionForLoadedPlugin:(NSString*)key;

- (NSDictionary *) loadedPlugins;

- (BOOL) loadPlugin:(Plugin *)plugin error:(NSError **)error;

//! YES if any plugin in bundledPlist (the preinstalled-plugins plist) is not registered, is registered
//! with a file that no longer exists, or is registered at an older version than the bundled one --
//! e.g. a build from before the 2.0 dictionary refresh, whose settings point at jFlash-CARD-1.1.db.
- (BOOL) bundledPluginsNeedRegistering:(NSDictionary *)bundledPlist;

- (void) processPlistHash:(NSDictionary*)plistHash;

// Used to fix the plugin paths after a restore/transfer to a different device
//- (void) _updatePluginPaths:(BOOL) debug pluginList:(NSString*)plistFileName;

//! Maintains in memory a list of availavle for download plugin.
@property (nonatomic, retain) NSDictionary *downloadablePlugins;

@end