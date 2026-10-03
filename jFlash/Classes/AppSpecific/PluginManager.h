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

//! Returns YES if the plugin is loaded.  Directory plugins always return YES.
- (BOOL) pluginKeyIsLoaded:(NSString *)pluginKey;

- (Plugin *)pluginForKey:(NSString *)pluginKey;

- (NSString*) versionForLoadedPlugin:(NSString*)key;

- (NSDictionary *) loadedPlugins;

- (BOOL) loadPlugin:(Plugin *)plugin error:(NSError **)error;

// Used to fix the plugin paths after a restore/transfer to a different device
//- (void) _updatePluginPaths:(BOOL) debug pluginList:(NSString*)plistFileName;

//! Maintains in memory a list of availavle for download plugin.
@property (nonatomic, retain) NSDictionary *downloadablePlugins;

@end
