//
//  JFlashPluginMigrationTest.m
//  jFlash
//
//  Created by Mark Makdad on 12/11/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "JFlashPluginMigrationTest.h"
#import "Plugin.h"
#import "Constants.h"

/**
 * THIS CLASS TESTS THE 1.5=>1.6 JFLASH MIGRATION
 * OF PLUGINS FROM DOCS DIR PLIST+SETTINGS TO SETTINGS ONLY.
 */
@implementation JFlashPluginMigrationTest

- (void) testParseLegacyPlugin
{
  NSDictionary *legacyPluginHash = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"FTS-DB",@"plugin_key",
                                    @"1.1",@"plugin_version",
                                    @"my awesome plugin",@"plugin_name",
                                    @"some details about my awesome plugin",@"plugin_details",
                                    @"<html> some html here </html>",@"plugin_html_content",
                                    @"localfilename.db",@"plugin_target_path",
                                    @"THIS VALUE SHOULD NOT MAKE US CRASH",@"some_unknown_key_we_dont_use_now",
                                    @"http://yourmom.com/backdoor.php",@"plugin_target_url",
                                    @"localfilename.db",@"plugin_file_name",
                                    nil];
  Plugin *newPlugin = [Plugin pluginWithLegacyDictionary:legacyPluginHash];
  
  XCTAssertEqualObjects([legacyPluginHash objectForKey:@"plugin_key"], newPlugin.pluginId, @"Should be equal");
  XCTAssertEqualObjects([legacyPluginHash objectForKey:@"plugin_name"], newPlugin.name, @"Should be equal");
  XCTAssertEqualObjects([legacyPluginHash objectForKey:@"plugin_details"], newPlugin.details, @"Should be equal");
  XCTAssertEqualObjects([legacyPluginHash objectForKey:@"plugin_html_content"], newPlugin.htmlString, @"Should be equal");
  XCTAssertEqualObjects([legacyPluginHash objectForKey:@"plugin_version"], newPlugin.version, @"Should be equal");
  XCTAssertEqualObjects([legacyPluginHash objectForKey:@"plugin_target_url"], newPlugin.targetURL, @"Should be equal");
  XCTAssertEqualObjects([legacyPluginHash objectForKey:@"plugin_target_path"], newPlugin.filePath, @"Should be equal");
  
  // Default to "Documents" for file location (this is a new feature).  Plugin uses its own
  // LWEPluginLocation enum (Documents = 2); the test used to compare with LWEFile's kLWEFileLocationDocuments (1).
  XCTAssertEqual(LWEPluginLocationDocuments, newPlugin.fileLocation, @"Should be equal");

  // The cards DB is the one exception: it ships in the bundle
  NSMutableDictionary *cardsHash = [[legacyPluginHash mutableCopy] autorelease];
  [cardsHash setObject:CARD_DB_KEY forKey:@"plugin_key"];
  Plugin *cardsPlugin = [Plugin pluginWithLegacyDictionary:cardsHash];
  XCTAssertEqual(LWEPluginLocationBundle, cardsPlugin.fileLocation, @"CARD_DB stays in the bundle");
  
  // Default to "database" type, this is a new feature
  XCTAssertEqualObjects(@"database", newPlugin.pluginType, @"Should be equal");
}

- (void)testLegacyPluginUnknownKeysDoNotCrash
{
  NSDictionary *legacyDict = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"SOME-KEY",     @"plugin_key",
                              @"2.0",          @"plugin_version",
                              @"Test Plugin",  @"plugin_name",
                              @"Details here", @"plugin_details",
                              @"<html/>",      @"plugin_html_content",
                              @"file.db",      @"plugin_target_path",
                              @"file.db",      @"plugin_file_name",
                              @"UNKNOWN_KEY_1", @"some_future_key",
                              @"UNKNOWN_KEY_2", @"another_future_key",
                              nil];
  Plugin *plugin = nil;
  XCTAssertNoThrow(plugin = [Plugin pluginWithLegacyDictionary:legacyDict],
                   @"Parsing a legacy dictionary with unknown keys must not throw");
  XCTAssertNotNil(plugin, @"Plugin should be created despite unknown keys");
}

- (void)testLegacyPluginVersionCanBeComparedWithModernPlugin
{
  NSDictionary *legacyDict = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"FTS-DB",          @"plugin_key",
                              @"1.1",             @"plugin_version",
                              @"Legacy Plugin",   @"plugin_name",
                              @"Details",         @"plugin_details",
                              @"<html/>",         @"plugin_html_content",
                              @"legacy.db",       @"plugin_target_path",
                              @"legacy.db",       @"plugin_file_name",
                              nil];
  Plugin *legacyPlugin = [Plugin pluginWithLegacyDictionary:legacyDict];

  NSDictionary *modernDict = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"Modern Plugin",    @"name",
                              @"FTS-DB",           @"pluginId",
                              @"database",         @"pluginType",
                              @"2.0",              @"version",
                              [NSNumber numberWithInt:LWEPluginLocationDocuments], @"fileLocation",
                              @"modern.db",        @"filePath", nil];
  Plugin *modernPlugin = [Plugin pluginWithDictionary:modernDict];

  XCTAssertTrue([modernPlugin isNewVersionOfPlugin:legacyPlugin],
                @"Modern plugin v2.0 should be newer than legacy plugin v1.1");
  XCTAssertFalse([legacyPlugin isNewVersionOfPlugin:modernPlugin],
                 @"Legacy plugin v1.1 should NOT be newer than modern plugin v2.0");
}

@end
