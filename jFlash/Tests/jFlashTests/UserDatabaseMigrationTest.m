//
//  UserDatabaseMigrationTest.m
//  jFlash
//
//  The 2.1 in-place user-database migration.  Starts from a 2.0-shaped
//  jFlash.db, including user sets whose ids collide with the new catalog.
//

#import <XCTest/XCTest.h>
#import "SetupDatabaseHelper.h"
#import "JFlashUpdateManager.h"
#import "BrowseModeCardViewDelegate.h"
#import "LWEDatabase.h"
#import "LWEFile.h"
#import "Constants.h"

@interface JFlashUpdateManager (UserDatabaseMigrationTest)
+ (BOOL) _updateSettingsTo21:(NSUserDefaults *)settings;
+ (BOOL) _migrateUserDatabase:(LWEDatabase *)db renamedTags:(NSMutableDictionary *)renames;
+ (BOOL) _giveUpOnStudySetMigration:(NSUserDefaults *)settings;
+ (BOOL) _noteMigrationFailure:(NSUserDefaults *)settings retry:(BOOL)retry;
+ (BOOL) _consumeStudySetFailureNotice:(NSUserDefaults *)settings;
@end

@interface UserDatabaseMigrationTest : XCTestCase
{
  NSString *_savedDataVersion;
  NSString *_savedSettingsVersion;
  NSInteger _savedTagId;
  NSInteger _savedIndex;
  BOOL _savedDidCopy;
  BOOL _savedFailed;
  BOOL _saved21Failed;
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
  // A 2.0 file still has the full Nouns list.  The template no longer ships it.
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (133, 'Nouns', 'Common noun (普通名詞・futsuumeishi)', 0, 9707)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 133)"];
  // Nouns 02–13.  The 2.0 fixture puts them back; 2.1 removes the system rows.
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (620, 'Nouns 02', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9714)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (621, 'Nouns 03', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9640)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (622, 'Nouns 04', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9717)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (623, 'Nouns 05', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9700)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (624, 'Nouns 06', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9706)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (625, 'Nouns 07', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9719)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (626, 'Nouns 08', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9696)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (627, 'Nouns 09', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9716)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (628, 'Nouns 10', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9688)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (629, 'Nouns 11', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9731)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (630, 'Nouns 12', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 9701)"];
  [self _execute:@"INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) VALUES (631, 'Nouns 13', '(cont) Common noun (普通名詞・futsuumeishi)', 0, 7256)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 620)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 621)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 622)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 623)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 624)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 625)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 626)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 627)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 628)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 629)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 630)"];
  [self _execute:@"INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (2, 631)"];
  [self _execute:@"UPDATE tags SET description = replace(description, '普通名詞', '副名詞') WHERE tag_id = 133 OR tag_id BETWEEN 620 AND 631"];
  [self _execute:@"UPDATE tags SET description = replace(description, 'futsuumeishi', 'fukumeishi') WHERE tag_id = 133 OR tag_id BETWEEN 620 AND 631"];

  // Study progress, a starred card, and the active set.
  [self _execute:@"INSERT INTO user_history (card_id, timestamp, user_id, right_count, wrong_count, created_on, card_level) VALUES (2065830, 100, 1, 3, 1, 100, 2)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (0, 150089, 1)"];
  [self _execute:@"UPDATE tags SET count = 99 WHERE tag_id = 0"];
  [self _execute:@"UPDATE last_state SET tag_id = 644 WHERE user_id = 1"];

  // 644 and 700 are chunk ids.  720 is a combined level set.  2000000 stays
  // above every built-in id, including the Nouns and Core 1000 cuts.
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (644, 'My Travel Words', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (644, 145536, 2)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 644)"];
  [self _execute:@"INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (644, 1, 4)"];
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (700, 'My Cooking Words', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (700, 145535, 3)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 700)"];
  [self _execute:@"INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (700, 1, 2)"];
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (720, 'My Whole Level', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (720, 145580, 4)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 720)"];
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (2000000, 'My Later Words', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (2000000, 145593, 5)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 2000000)"];

  // Links the 2.0 template kept for tags that do not exist.
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (18, 3)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (18, 10)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (7, 17)"];
  [self _execute:@"INSERT INTO group_tag_link (group_id, tag_id) VALUES (6, 28)"];
  // Explicit ids above bump sqlite_sequence.  A 2.0 file still says 643.
  [self _execute:@"UPDATE sqlite_sequence SET seq = 643 WHERE name = 'tags'"];
  // A 2.0 file has no Japanese columns.  The first run has to add them.
  [self _execute:@"ALTER TABLE tags DROP COLUMN tag_name_ja"];
  [self _execute:@"ALTER TABLE tags DROP COLUMN description_ja"];
  [self _execute:@"ALTER TABLE groups DROP COLUMN group_name_ja"];
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
  [settings setBool:YES forKey:@"study_sets_21_failed"];
  [settings synchronize];

  XCTAssertTrue([JFlashUpdateManager _updateSettingsTo21:settings], @"2.1 migration should succeed");

  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_1);
  XCTAssertEqualObjects([settings objectForKey:APP_SETTINGS_VERSION], LWE_JF_VERSION_2_1);
  XCTAssertFalse([settings boolForKey:@"study_sets_update_failed"]);
  XCTAssertFalse([settings boolForKey:@"study_sets_21_failed"]);

  [self _openUserDatabase];
  int travelId = [self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Travel Words'"];
  int cookingId = [self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Cooking Words'"];
  int wholeId = [self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Whole Level'"];
  // User tag 2000000 is above the template, so the new ids start at 2000001.
  XCTAssertEqual(travelId, 2000001);
  XCTAssertEqual(cookingId, 2000002);
  XCTAssertEqual(wholeId, 2000003, @"720 collides with the combined Advanced set");
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

  // A user set that did not collide keeps its id.  720 is the system set.
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Later Words'"], 2000000);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM card_tag_link WHERE tag_id = 2000000"], 145593);
  XCTAssertNil([self _stringQuery:@"SELECT tag_name_ja FROM tags WHERE tag_name = 'My Later Words'"]);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name_ja FROM tags WHERE tag_id = 95"], @"初級1（≈N5）01");
  XCTAssertEqualObjects([self _stringQuery:@"SELECT group_name_ja FROM groups WHERE group_id = 28"], @"基本1000語");
  XCTAssertEqual([self _intQuery:@"SELECT editable FROM tags WHERE tag_id = 720"], 0);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 720"], @"Advanced (≈N1) Full Set");
  XCTAssertEqual([self _intQuery:@"SELECT count FROM tags WHERE tag_id = 717"], 626);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 717"], @"Beginner 1 (≈N5) Full Set");
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM card_tag_link WHERE tag_id = 720 AND card_id = 145580"], 0);

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
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Later Words'"], 2000000);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM tags WHERE tag_name = 'My Whole Level'"], wholeId);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM last_state WHERE user_id = 1"], travelId);
  XCTAssertEqual([self _intQuery:@"SELECT right_count FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 3);
  XCTAssertEqual([self _intQuery:@"SELECT count FROM tags WHERE tag_id = 0"], starredCount);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM card_tag_link WHERE tag_id = 0 AND card_id = 150089"], 1);
  XCTAssertEqual([self _intQuery:@"SELECT editable FROM tags WHERE tag_id = 644"], 0);
  XCTAssertNil([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 133"]);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 2346"], @"Common Nouns Full Set");
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM tags WHERE tag_id BETWEEN 620 AND 631"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM group_tag_link WHERE tag_id = 133"], 0);
}

- (void)testRetiredNounSetsMoveToCommonNounsFullSet
{
  [self _rewindToDataVersion20];
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 133"], @"Nouns");
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 625"], @"Nouns 07");
  [self _execute:@"UPDATE last_state SET tag_id = 625 WHERE user_id = 1"];
  [self _execute:@"INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (625, 1, 9)"];
  [self _execute:@"INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (133, 1, 4)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (625, 150090, 9)"];
  // 1000110 is in Common Nouns.  Its level has to survive the tag going away.
  [self _execute:@"INSERT INTO user_history (card_id, timestamp, user_id, right_count, wrong_count, created_on, card_level) VALUES (1000110, 100, 1, 4, 0, 100, 3)"];
  [[LWEDatabase sharedLWEDatabase] closeDatabase];

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_SETTINGS_VERSION];
  [settings setInteger:625 forKey:@"tag_id"];
  [settings setInteger:4000 forKey:@"current_index"];
  [settings setBool:YES forKey:@"db_did_finish_copying"];
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  [settings synchronize];

  XCTAssertTrue([JFlashUpdateManager _updateSettingsTo21:settings], @"A retired Nouns set should move to Common Nouns");
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)2346, @"The active set becomes Common Nouns Full Set");
  XCTAssertEqual([settings integerForKey:@"current_index"], (NSInteger)4000, @"The saved position stays until the set is opened");
  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_1);

  [self _openUserDatabase];
  XCTAssertNil([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 133"]);
  XCTAssertNil([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 625"]);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 2346"], @"Common Nouns Full Set");
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name_ja FROM tags WHERE tag_id = 2346"], @"よく使う名詞全部");
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM tags WHERE tag_id BETWEEN 620 AND 631"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM last_state WHERE user_id = 1"], 2346);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM last_state WHERE user_id = 1"], 2065830);
  XCTAssertEqual([self _intQuery:@"SELECT right_count FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 3);
  XCTAssertEqual([self _intQuery:@"SELECT card_level FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 2);
  XCTAssertEqual([self _intQuery:@"SELECT card_level FROM user_history WHERE card_id = 1000110 AND user_id = 1"], 3);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM tag_user_card_levels WHERE tag_id = 625"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM tag_user_card_levels WHERE tag_id = 133"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM card_tag_link WHERE tag_id = 625"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM group_tag_link WHERE tag_id = 133 OR tag_id = 625"], 0);
}

- (void)testActiveSetOnNounsFollowsSettingsToCommonNouns
{
  [self _rewindToDataVersion20];
  [self _execute:@"UPDATE last_state SET tag_id = 133 WHERE user_id = 1"];
  [[LWEDatabase sharedLWEDatabase] closeDatabase];

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_SETTINGS_VERSION];
  [settings setInteger:133 forKey:@"tag_id"];
  [settings setInteger:12 forKey:@"current_index"];
  [settings setBool:YES forKey:@"db_did_finish_copying"];
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  [settings synchronize];

  XCTAssertTrue([JFlashUpdateManager _updateSettingsTo21:settings], @"An active Nouns set should migrate");
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)2346);
  XCTAssertEqual([settings integerForKey:@"current_index"], (NSInteger)12, @"The position is still the one in the old list");

  [self _openUserDatabase];
  XCTAssertNil([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 133"]);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM last_state WHERE user_id = 1"], 2346);
}

- (void)testUserSetAtNounsIdIsLeftAlone
{
  [self _rewindToDataVersion20];
  [self _execute:@"DELETE FROM group_tag_link WHERE tag_id = 133"];
  [self _execute:@"DELETE FROM tags WHERE tag_id = 133"];
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (133, 'My Nouns', 'kept', 1, 1)"];
  [self _execute:@"INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (133, 145594, 11)"];
  [self _execute:@"UPDATE last_state SET tag_id = 133, card_id = 145594 WHERE user_id = 1"];
  [[LWEDatabase sharedLWEDatabase] closeDatabase];

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_SETTINGS_VERSION];
  [settings setInteger:133 forKey:@"tag_id"];
  [settings setInteger:3 forKey:@"current_index"];
  [settings setBool:YES forKey:@"db_did_finish_copying"];
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  [settings synchronize];

  XCTAssertTrue([JFlashUpdateManager _updateSettingsTo21:settings], @"A user set at tag 133 should migrate around it");
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)133);
  XCTAssertEqual([settings integerForKey:@"current_index"], (NSInteger)3);

  [self _openUserDatabase];
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 133"], @"My Nouns");
  XCTAssertEqual([self _intQuery:@"SELECT editable FROM tags WHERE tag_id = 133"], 1);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM card_tag_link WHERE tag_id = 133"], 145594);
  XCTAssertEqual([self _intQuery:@"SELECT tag_id FROM last_state WHERE user_id = 1"], 133);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM tags WHERE tag_id BETWEEN 620 AND 631"], 0);
}

- (void)testGiveUpMovesARemovedNounSetOffTheEmptyList
{
  [self _rewindToDataVersion20];
  [[LWEDatabase sharedLWEDatabase] closeDatabase];

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_SETTINGS_VERSION];
  [settings setInteger:133 forKey:@"tag_id"];
  [settings setInteger:80 forKey:@"current_index"];
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  [settings synchronize];

  XCTAssertTrue([JFlashUpdateManager _giveUpOnStudySetMigration:settings]);
  // The 2.0 file has no Common Nouns Full Set row, so the fallback is the default set.
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)DEFAULT_TAG_ID);
  XCTAssertEqual([settings integerForKey:@"current_index"], (NSInteger)0);
  XCTAssertTrue([settings boolForKey:@"study_sets_21_failed"]);

  [self _openUserDatabase];
  [self _execute:@"INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (2346, 'Common Nouns Full Set', '', 0, 18142)"];
  [[LWEDatabase sharedLWEDatabase] closeDatabase];
  [settings setInteger:620 forKey:@"tag_id"];
  [settings setInteger:9 forKey:@"current_index"];
  XCTAssertTrue([JFlashUpdateManager _giveUpOnStudySetMigration:settings]);
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)2346);
  XCTAssertEqual([settings integerForKey:@"current_index"], (NSInteger)0);

  Tag *empty = [[Tag alloc] init];
  empty.flattenedCardIdArray = [NSMutableArray array];
  empty.currentIndex = 0;
  BrowseModeCardViewDelegate *browse = [[BrowseModeCardViewDelegate alloc] init];
  XCTAssertNil([browse getNextCard:empty afterCard:nil direction:nil]);
  [browse release];
  [empty release];
}

- (void)testUncommittedMigrationRollsBack
{
  [self _rewindToDataVersion20];
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  NSString *templatePath = [LWEFile createBundlePathWithFilename:LWE_CURRENT_USER_DATABASE];
  XCTAssertTrue([db attachDatabase:templatePath withName:@"tpl"], @"Could not attach the template");
  XCTAssertTrue([db.dao beginDeferredTransaction], @"Could not start a transaction");
  NSMutableDictionary *renames = [NSMutableDictionary dictionary];
  XCTAssertTrue([JFlashUpdateManager _migrateUserDatabase:db renamedTags:renames]);
  XCTAssertEqual([[renames objectForKey:[NSNumber numberWithInt:644]] intValue], 2000001);
  XCTAssertEqual([[renames objectForKey:[NSNumber numberWithInt:720]] intValue], 2000003);
  XCTAssertTrue([db.dao rollback]);
  XCTAssertTrue([db detachDatabase:@"tpl"]);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 644"], @"My Travel Words");
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM groups WHERE group_id = 24"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT count(*) FROM tags WHERE tag_id = 717"], 0);
  XCTAssertEqual([self _intQuery:@"SELECT card_level FROM user_history WHERE card_id = 2065830 AND user_id = 1"], 2);
  XCTAssertEqual([self _intQuery:@"SELECT card_id FROM card_tag_link WHERE tag_id = 720"], 145580);
  XCTAssertEqualObjects([self _stringQuery:@"SELECT tag_name FROM tags WHERE tag_id = 625"], @"Nouns 07");
}

- (void)testGiveUpResetsAMissingActiveSetAndKeepsAMarker
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setInteger:99999 forKey:@"tag_id"];
  [settings setBool:NO forKey:@"study_sets_update_failed"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_SETTINGS_VERSION];
  XCTAssertTrue([JFlashUpdateManager _giveUpOnStudySetMigration:settings]);
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)DEFAULT_TAG_ID);
  XCTAssertTrue([settings boolForKey:@"study_sets_update_failed"]);
  XCTAssertTrue([settings boolForKey:@"study_sets_21_failed"]);
  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_1);
  XCTAssertTrue([JFlashUpdateManager _consumeStudySetFailureNotice:settings]);
  XCTAssertFalse([settings boolForKey:@"study_sets_update_failed"]);
  XCTAssertTrue([settings boolForKey:@"study_sets_21_failed"], @"The alert flag is one-shot; the marker stays");
  XCTAssertFalse([JFlashUpdateManager _consumeStudySetFailureNotice:settings]);
}

- (void)testGiveUpKeepsAnActiveSetThatStillExists
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setInteger:DEFAULT_TAG_ID forKey:@"tag_id"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  XCTAssertTrue([JFlashUpdateManager _giveUpOnStudySetMigration:settings]);
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)DEFAULT_TAG_ID);
  XCTAssertTrue([settings boolForKey:@"study_sets_21_failed"]);
}

- (void)testOpenFailuresRetryTwiceThenGiveUp
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setInteger:0 forKey:@"study_set_migration_21_failures"];
  [settings setInteger:DEFAULT_TAG_ID forKey:@"tag_id"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  [settings setBool:NO forKey:@"study_sets_update_failed"];

  XCTAssertFalse([JFlashUpdateManager _noteMigrationFailure:settings retry:YES]);
  XCTAssertEqual([settings integerForKey:@"study_set_migration_21_failures"], 1);
  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_0);
  XCTAssertFalse([settings boolForKey:@"study_sets_21_failed"]);

  XCTAssertFalse([JFlashUpdateManager _noteMigrationFailure:settings retry:YES]);
  XCTAssertEqual([settings integerForKey:@"study_set_migration_21_failures"], 2);
  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_0);

  XCTAssertTrue([JFlashUpdateManager _noteMigrationFailure:settings retry:YES]);
  XCTAssertEqual([settings integerForKey:@"study_set_migration_21_failures"], 3);
  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_1);
  XCTAssertTrue([settings boolForKey:@"study_sets_21_failed"]);
  XCTAssertTrue([settings boolForKey:@"study_sets_update_failed"]);
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)DEFAULT_TAG_ID);
}

- (void)testStatementFailureGivesUpWithoutRetrying
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setObject:LWE_JF_VERSION_2_0 forKey:APP_DATA_VERSION];
  [settings setInteger:1 forKey:@"study_set_migration_21_failures"];
  [settings setInteger:DEFAULT_TAG_ID forKey:@"tag_id"];
  [settings setBool:NO forKey:@"study_sets_21_failed"];
  XCTAssertTrue([JFlashUpdateManager _noteMigrationFailure:settings retry:NO]);
  XCTAssertEqual([settings integerForKey:@"study_set_migration_21_failures"], 1, @"A bad statement is not retried");
  XCTAssertEqualObjects([settings objectForKey:APP_DATA_VERSION], LWE_JF_VERSION_2_1);
  XCTAssertTrue([settings boolForKey:@"study_sets_21_failed"]);
  XCTAssertEqual([settings integerForKey:@"tag_id"], (NSInteger)DEFAULT_TAG_ID);
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
  _savedIndex = [settings integerForKey:@"current_index"];
  _savedDidCopy = [settings boolForKey:@"db_did_finish_copying"];
  _savedFailed = [settings boolForKey:@"study_sets_update_failed"];
  _saved21Failed = [settings boolForKey:@"study_sets_21_failed"];
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
  [settings setInteger:_savedIndex forKey:@"current_index"];
  [settings setBool:_savedDidCopy forKey:@"db_did_finish_copying"];
  [settings setBool:_savedFailed forKey:@"study_sets_update_failed"];
  [settings setBool:_saved21Failed forKey:@"study_sets_21_failed"];
  [settings setInteger:_savedFailures forKey:@"study_set_migration_21_failures"];
  [settings synchronize];
  [_savedDataVersion release];
  [_savedSettingsVersion release];
  _savedDataVersion = nil;
  _savedSettingsVersion = nil;
  [super tearDown];
}

@end
