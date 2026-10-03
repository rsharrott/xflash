//
//  Plugin.h
//  jFlash
//
//  Created by Mark Makdad on 12/2/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef enum
{
  LWEPluginLocationBundle = 0,
  LWEPluginLocationLibrary = 1,
  LWEPluginLocationDocuments = 2
} LWEPluginLocation;

@interface Plugin : NSObject <NSCoding>

//! For creating a plugin file out of an NSDictionary hash of strings
+ (id) pluginWithDictionary:(NSDictionary *)dict;

//! For legacy PLISTs.
+ (id) pluginWithLegacyDictionary:(NSDictionary *)dict;

- (BOOL) isNewVersionOfPlugin:(Plugin *)plugin;

- (NSString *) fullPath;
- (BOOL) isDirectoryPlugin;
- (BOOL) isDatabasePlugin;

@property LWEPluginLocation fileLocation;
@property (retain) NSString *filePath;
@property (retain) NSString *name;
@property (retain) NSString *details;
@property (retain) NSString *htmlString;
@property (retain) NSString *version;
@property (retain) NSString *pluginType;
@property (retain) NSString *pluginId;
@property (retain) NSString *targetPath;
@property (retain) NSString *targetURL;

@end
