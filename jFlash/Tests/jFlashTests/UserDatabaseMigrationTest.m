//
//  UserDatabaseMigrationTest.m
//  jFlash
//
//  The 2.1 in-place user-database migration.  Starts from a 2.0-shaped
//  jFlash.db, including user sets whose ids collide with the new catalog.
//

#import "SetupDatabaseHelper.h"
#import "JFlashUpdateManager.h"
#import "LWEDatabase.h"
#import "LWEFile.h"
#import "Constants.h"

@interface JFlashUpdateManager (UserDatabaseMigrationTest)
+ (BOOL) _updateSettingsTo21:(NSUserDefaults *)settings;
@end

@interface UserDatabaseMigrationTest : XCTestCase
{
  NSString *_savedDataVersion;
  NSString *_savedSettingsVersion;
  NSInteger _savedTagId;
  BOOL _savedDidCopy;
  BOOL _savedFailed;
  NSInteger _savedFailures;
  BOOL _hadDataVersion;
  BOOL _hadSettingsVersion;
}
@end

@implementation UserDatabaseMigrationTest

- (void) _execute:(NSString *)sql
{
  FMDatabase *dao = [LWEDatabase sharedLWEDatabase].dao;
  [dao executeUpdate:sql];
  XCTAssertFalse([dao hadError], @"SQL failed: %@ (%@)", sql, [dao lastErrorMessage]);
}

- (int) _intQuery:(NSString *)sql
{
  FMDatabase *dao = [LWEDatabase sharedLWEDatabase].dao;
  FMResultSet *rs = [dao executeQuery:sql];
  XCTAssertNotNil(rs, @"Query failed: %@", sql);
  int value = 0;
  if ([rs next])
  {
    value = [rs intForColumnIndex:0];
  }
  [rs close];
  XCTAssertFalse([dao hadError], @"Query failed: %@ (%@)", sql, [dao lastErrorMessage]);
  return value;
}

- (NSString *) _stringQuery:(NSString *)sql
{
  FMDatabase *dao = [LWEDatabase sharedLWEDatabase].dao;
  FMResultSet *rs = [dao executeQuery:sql];
  NSString *value = nil;
  if ([rs next])
  {
    value = [rs stringForColumnIndex:0];
  }
  [rs close];
  return value;
}

- (void) _openUserDatabase
{
  NSString *path = [LWEFile createDocumentPathWithFilename:LWE_CURRENT_USER_DATABASE];
  XCTAssertTrue([[LWEDatabase sharedLWEDatabase] openDatabase:path], @"Could not reopen the user database");
}

- (void) _rewindToDataVersion20
{
  // The copied template is the new catalog.  Put it back to the 2.0 shape
  // (old level names, hidden-set links, sequence still on 643) before adding
  // the user's own rows.
  [self _execute:@"DELETE FROM group_tag_link WHERE tag_id >= 644 OR group_id >= 24"];
  [self _execute:@"DELETE FROM tags WHERE tag_id >= 644"];
  [self _execute:@"DELETE FROM groups WHERE group_id >= 24"];
  [self _execute:@"UPDATE tags SET tag_name = 'JLPT Level N1' WHERE tag_id = 92"];
  [self _execute:@"UPDATE tags SET tag_name = 'JLPT Level N2' WHERE tag_id = 93"];
  [self _execute:@"UPDATE tags SET tag_name = 'JLPT Level N3' WHERE tag_id = 94"];
  [self _execute:@"UPDATE tags SET tag_name = 'JLPT Level N4' WHERE tag_id = 95"];
  [self _execute:@"UPDATE groups SET group_name = 'JLPT N1~N4' WHERE group_id = 10"];
  [self _execute:@"DELETE FROM group_tag_link WHERE group_id = 10"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (10, 92)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (10, 93)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (10, 94)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (10, 95)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (13, 15)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (13, 51)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (13, 135)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (13, 136)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (13, 161)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (13, 168)"];
  [self _execute:@"DELETE FROM group_tag_link WHERE group_id = 23 AND tag_id IN (73, 95, 200, 208)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (23, 80)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (23, 91)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (23, 170)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (1, 7)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (1, 8)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (1, 9)"];
  [self _execute:@"UPDATE tags SET description = 'Rude or X-Rated' WHERE tag_id = 161"];
  [self _execute:@"UPDATE tags SET description = replace(description, '普通名詞', '副名詞') WHERE tag_id = 133 OR tag_id BETWEEN 620 AND 631"];
  [self _execute:@"UPDATE tags SET description = replace(description, 'futsuumeishi', 'fukumeishi') WHERE tag_id = 133 OR tag_id BETWEEN 620 AND 631"];

  // Study progress, a starred card, and the active set.
  [self _execute:@"INSERT INTO user_history (card_id, timestamp, user_id, right_count, wrong_count, created_on, card_level) VALUES (2065830, 100, 1, 3, 1, 100, 2)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (0, 150089, 1)"];
  [self _execute:@"UPDATE tags SET count = 99 WHERE tag_id = 0"];
  [self _execute:@"UPDATE last_state SET tag_id = 644 WHERE user_id = 1"];

  // 644 and 700 are system ids in the new template.  720 is not.
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (644, 'My Travel Words', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (644, 145536, 2)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 644)"];
  [self _execute:@"INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (644, 1, 4)"];
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (700, 'My Cooking Words', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (700, 145535, 3)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 700)"];
  [self _execute:@"INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (700, 1, 2)"];
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (720, 'My Later Words', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (720, 145580, 4)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 720)"];

  // Links the 2.0 template kept for tags that do not exist.
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (18, 3)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (18, 10)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (7, 17)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (6, 28)"];
  // Explicit ids above bump sqlite_sequence.  A 2.0 file still says 643.
  [self _execute:@"UPDATE sqlite_sequence SET seq = 643 WHERE name = 'tags'"];
}

- (void)testUpdateSettingsTo21KeepsUserDataAndRemapsCollisions
{
  [self _rewindToDataVersion20];
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 95"], @"JLPT Level N4");
  XCTAssertEqual([self _intQuery:@"SELECT seq FROM sqlite_sequence WHERE name = 'tags'"], 643);
  [[LWEDatabase sharedLWEDatabase] closeDatabase];

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_SETTINGS_VERSION];
  [settings setInteger:644 forKey:@"tag_id"];
  [settings setBool:YES forKey:@"db_did_finish_copying"];
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings synchronize];

  XCTAssertTrue([JFlashUpdateManager _updateSettingsTo21:settings], @"2.1 migration should succeed");

  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_1);
  XCTAssertEqualObjects([settings objectForKey:APP_SETTINGS_VERSION], LWE_JF_VERSION_2_1);
  XCTAssertFalse([settings boolForKey:@"study_sets_update_failed"]);

  [self _openUserDatabase];
  int travelId = [self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Travel Words'"];
  int cookingId = [self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Cooking Words'"];
  XCTAssertGreaterThan(travelId, 720, @"Colliding sets move above the template and the user's own ids");
  XCTAssertEqual(cookingId, travelId + 1, @"644 is renumbered before 700");
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)travelId, @"The active set follows the user's set");
  XCTAssertNotEqual(travelId, 644);
  XCTAssertNotEqual(cookingId, 700);

  // 644 and 700 are the new system sets, not the user's.
  XCTAssertEqual([self _intQuery:@"SELECT editable FROM tags WHERE tag_id = 644"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT editable FROM tags WHERE tag_id = 700"], 0);
  XCTAssertFalse([[self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 644"] isEqualToString:@"My Travel Words"]);
  XCTAssertEqual([self _intQuery:@"SELECT editable FROM tags WHERE tag_name = 'My Travel Words'"], 1);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM card_tag_link WHERE tag_id = (SELECT tag_id FROM tags WHERE tag_name = 'My Travel Words')"], 145536);
  XCTAssertEqual([self _intQuery:@"SELECT group_id FROM group_tag_link WHERE tag_id = (SELECT tag_id FROM tags WHERE tag_name = 'My Travel Words')"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT card_level_1_count FROM tag_user_card_levels WHERE tag_id = (SELECT tag_id FROM tags WHERE tag_name = 'My Travel Words')"], 4);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM card_tag_link WHERE tag_id = (SELECT tag_id FROM tags WHERE tag_name = 'My Cooking Words')"], 145535);

  // A user set that did not collide keeps its id.
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Later Words'"], 720);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM card_tag_link WHERE tag_id = 720"], 145580);

  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM last_state WHERE user_id = 1"], travelId);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM last_state WHERE user_id = 1"], 2065830);
  XCTAssertEqual([self _intQuery:@"SELECT right_count FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 3);
  XCTAssertEqual([self _intQuery:@"SELECT wrong_count FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 1);
  XCTAssertEqual([self _intQuery:@"SELECT card_level FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 2);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM card_tag_link WHERE tag_id = 0 AND card_id = 150089"], 1);
  XCTAssertEqual([self _intQuery:@"SELECT count FROM tags WHERE tag_id = 0"],
                 [self _intQuery:@"SELECT count(*) FROM card_tag_link WHERE tag_id = 0"],
                 @"The starred count is recomputed");
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM group_tag_link g WHERE NOT EXISTS (SELECT 1 FROM tags t WHERE t.tag_id = g.tag_id)"], 0);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 95"], @"Beginner 1 (≈N5) 01");

  int starredCount = [self _intQuery:@"SELECT count FROM tags WHERE tag_id = 0"];
  [[LWEDatabase sharedLWEDatabase] closeDatabase];

  XCTAssertTrue([JFlashUpdateManager _updateSettingsTo21:settings], @"A second run should succeed and change nothing");
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)travelId);
  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_1);

  [self _openUserDatabase];
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Travel Words'"], travelId);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Cooking Words'"], cookingId);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Later Words'"], 720);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM last_state WHERE user_id = 1"], travelId);
  XCTAssertEqual([self _intQuery:@"SELECT right_count FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 3);
  XCTAssertEqual([self _intQuery:@"SELECT count FROM tags WHERE tag_id = 0"], starredCount);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM card_tag_link WHERE tag_id = 0 AND card_id = 150089"], 1);
  XCTAssertEqual([self _intQuery:@"SELECT editable FROM tags WHERE tag_id = 644"], 0);
}

- (void)setUp
{
  [super setUp];
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  _hadDataVersion = ([settings objectForKey:APP_DATA_VERSION] != nil);
  _hadSettingsVersion = ([settings objectForKey:APP_SETTINGS_VERSION] != nil);
  _savedDataVersion = [[settings objectForKey:APP_DATA_VERSION] retain];
  _savedSettingsVersion = [[settings objectForKey:APP_SETTINGS_VERSION] retain];
  _savedTagId = [settings integerForKey:@"tag_id"];
  _savedDidCopy = [settings boolForKey:@"db_did_finish_copying"];
  _savedFailed = [settings boolForKey:@"study_sets_update_failed"];
  _savedFailures = [settings integerForKey:@"study_set_migration_21_failures"];

  NSError *error = nil;
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  BOOL result = [db setupTestDatabaseAndOpenConnectionWithError:&error];
  XCTAssertTrue(result, @"Failed to set up the test database: %@", [error localizedDescription]);
}

- (void)tearDown
{
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  NSError *error = nil;
  BOOL result = [db removeTestDatabaseWithError:&error];
  XCTAssertTrue(result, @"Failed to remove the test database: %@", [error localizedDescription]);

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  if (_hadDataVersion)
  {
    [settings setObject:_savedDataVersion forKey:APP_DATA_VERSION];
  }
  else
  {
    [settings removeObjectForKey:APP_DATA_VERSION];
  }
  if (_hadSettingsVersion)
  {
    [settings setObject:_savedSettingsVersion forKey:APP_SETTINGS_VERSION];
  }
  else
  {
    [settings removeObjectForKey:APP_SETTINGS_VERSION];
  }
  [settings setInteger:_savedTagId forKey:@"tag_id"];
  [settings setBool:_savedDidCopy forKey:@"db_did_finish_copying"];
  [settings setBool:_savedFailed forKey:@"study_sets_update_failed"];
  [settings setInteger:_savedFailures forKey:@"study_set_migration_21_failures"];
  [settings synchronize];
  [_savedDataVersion release];
  [_savedSettingsVersion release];
  _savedDataVersion = nil;
  _savedSettingsVersion = nil;
  [super tearDown];
}

@end
