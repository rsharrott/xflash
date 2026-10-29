//
//  TagTest.m
//  jFlash
//
//  Created by Ross Sharrott on 12/2/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "TagTest.h"
#import "SetupDatabaseHelper.h"
#import "TagPeer.h"
#import "Tag.h"
#import "GroupPeer.h"
#import "Constants.h"
#import "FirstRunViewController.h"
#import "LWEDatabase.h"

#import <UIKit/UIKit.h>

static NSString * const kLWEFavoriteTagName = @"Long Weekend Favorites";

@implementation TagTest

// All code under test is in the iOS Application

- (void)testTagNameAfterRetrieval
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  XCTAssertNotNil(tag, @"Should retrieve favorites tag");
  XCTAssertEqualObjects(kLWEFavoriteTagName, tag.tagName, @"Tag name should match what was requested");
}

- (void)testFavoritesTagIsNotEditable
{
  // The system "favorites" set is My Starred Words (STARRED_TAG_ID).  This test used to look up
  // "Long Weekend Favorites", which is an ordinary curated set (editable = 1 in both bundled user DBs),
  // so it could never pass.
  Tag *starred = [TagPeer retrieveTagById:STARRED_TAG_ID];
  XCTAssertEqual(starred.tagId, STARRED_TAG_ID, @"Should retrieve the Starred tag");
  XCTAssertTrue([starred.tagName length] > 0, @"Starred tag should exist");
  XCTAssertFalse([starred isEditable], @"System tags must not be editable (cFlash.db marks Starred editable; Tag overrides it)");
  XCTAssertFalse([[Tag starredWordsTag] isEditable], @"Same through the convenience accessor");

  Tag *lwFavorites = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  XCTAssertNotNil(lwFavorites, @"Should retrieve the Long Weekend Favorites set");
  XCTAssertTrue([lwFavorites isEditable], @"Long Weekend Favorites is an ordinary, editable set");
}

- (void)testCreateUserTagIsEditable
{
  Tag *created = [TagPeer createTagNamed:@"EditableTestTag" inGroup:[GroupPeer topLevelGroup]];
  XCTAssertNotNil(created, @"Should be able to create a user tag");
  XCTAssertTrue([created isEditable], @"User-created tags should be editable");
}

- (void)testCreateTagCanBeRetrievedByName
{
  NSString *name = @"RetrievalTestTag";
  Tag *created = [TagPeer createTagNamed:name inGroup:[GroupPeer topLevelGroup]];
  XCTAssertNotNil(created, @"Tag creation should succeed");

  Tag *fetched = [TagPeer retrieveTagByName:name];
  XCTAssertNotNil(fetched, @"Should retrieve the newly created tag by name");
  XCTAssertEqualObjects(name, fetched.tagName, @"Fetched tag name should match");
}

- (void)testRetrieveTagByIdMatchesTagByName
{
  Tag *byName = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  XCTAssertNotNil(byName, @"Should retrieve favorites by name");

  Tag *byId = [TagPeer retrieveTagById:byName.tagId];
  XCTAssertNotNil(byId, @"Should retrieve the same tag by its ID");
  XCTAssertEqualObjects(byName.tagName, byId.tagName, @"Tag name should be the same whether retrieved by name or ID");
}

- (void)testSysTagListIsNonEmpty
{
  NSArray *sysTags = [TagPeer retrieveSysTagList];
  XCTAssertNotNil(sysTags, @"System tag list should not be nil");
  XCTAssertTrue([sysTags count] > 0, @"There should be at least one system tag");
}

- (void)testDeleteTagRemovesItFromList
{
  NSString *name = @"DeleteTestTag";
  Tag *created = [TagPeer createTagNamed:name inGroup:[GroupPeer topLevelGroup]];
  XCTAssertNotNil(created, @"Should create tag before deletion test");

  BOOL deleted = [TagPeer deleteTag:created];
  XCTAssertTrue(deleted, @"deleteTag should return YES for a user-created tag");

  Tag *shouldBeGone = [TagPeer retrieveTagByName:name];
  XCTAssertNil(shouldBeGone, @"Deleted tag should not be retrievable by name");
}

- (void)testRetrieveTagByNameReturnsNilForAnUnknownName
{
  // It used to return an empty Tag (tag_id 0, the Starred id) instead of nil
  XCTAssertNil([TagPeer retrieveTagByName:@"No Such Tag 9f3a"], @"Unknown name gives nil");
  XCTAssertNotNil([TagPeer retrieveTagByName:[kLWEFavoriteTagName uppercaseString]], @"Lookup is case-insensitive (LIKE)");
}

#if defined(LWE_JFLASH)
- (void)testVocabularyLevelListsFullSetBeforeTheChunks
{
  NSArray *names = [NSArray arrayWithObjects:
                    @"Beginner 1 (≈N5) Full Set",
                    @"Beginner 2 (≈N4) Full Set",
                    @"Intermediate (≈N3–N2) Full Set",
                    @"Advanced (≈N1) Full Set",
                    nil];
  NSInteger groupId = 24;
  for (NSString *name in names)
  {
    NSArray *tags = [TagPeer retrieveTagListByGroupId:groupId];
    XCTAssertTrue([tags count] > 1, @"group %ld", (long)groupId);
    XCTAssertEqualObjects([[tags objectAtIndex:0] tagName], name, @"group %ld", (long)groupId);
    XCTAssertTrue([[[tags objectAtIndex:1] tagName] hasSuffix:@" 01"], @"group %ld", (long)groupId);
    groupId += 1;
  }
}
#endif

- (void)testRetrieveTagListByGroupIdReturnsNonEmpty
{
  Group *topGroup = [GroupPeer topLevelGroup];
  XCTAssertNotNil(topGroup, @"Should have a top-level group");

  NSArray *tags = [TagPeer retrieveTagListByGroupId:topGroup.groupId];
  XCTAssertNotNil(tags, @"retrieveTagListByGroupId should not return nil");
  XCTAssertTrue([tags count] > 0, @"Top-level group should contain at least one tag");
}

- (void)testSave
{
  NSString* description = @"Monkeys Fly Out of My Butt";
  Tag *favoritesTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  favoritesTag.tagDescription = description;
  [favoritesTag save];
  
  Tag *seperatelyRetrivedFavTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  XCTAssertEqualObjects(favoritesTag.tagDescription, seperatelyRetrivedFavTag.tagDescription, @"The DB does not contain the saved description");
  
  description = @"' foo";
  favoritesTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  favoritesTag.tagDescription = description;
  [favoritesTag save];
  
  seperatelyRetrivedFavTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  XCTAssertEqualObjects(favoritesTag.tagDescription, seperatelyRetrivedFavTag.tagDescription, @"The DB does not contain the saved description");
}

- (void)testBrowseSearchSkipsTagsThatAreNotInAGroup
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  [db.dao executeUpdate:@"INSERT INTO tags (tag_name, description, editable) VALUES (?,?,1)",
   @"ZZZ Ungrouped Hidden", @""];
  XCTAssertFalse([db.dao hadError], @"Should insert an ungrouped tag");
  NSInteger tagId = (NSInteger)db.dao.lastInsertRowId;

  NSArray *hits = [TagPeer retrieveTagListLike:@"ZZZ Ungrouped"];
  XCTAssertEqual([hits count], (NSUInteger)0, @"A tag with no group_tag_link stays out of browse search");

  Tag *created = [TagPeer createTagNamed:@"ZZZ Grouped Visible" inGroup:[GroupPeer topLevelGroup]];
  XCTAssertNotNil(created, @"A user-created set is linked to a group");
  NSArray *visible = [TagPeer retrieveTagListLike:@"ZZZ Grouped"];
  XCTAssertEqual([visible count], (NSUInteger)1, @"A grouped tag is still searchable");

  [db.dao executeUpdate:@"DELETE FROM tags WHERE tag_id = ?", [NSNumber numberWithInteger:tagId]];
  [TagPeer deleteTag:created];
}

- (void)testBuiltInNamesFollowTheAppLanguageAndUserSetsDoNot
{
  Tag *created = [TagPeer createTagNamed:@"マイセット" inGroup:[GroupPeer topLevelGroup]];
  XCTAssertNotNil(created, @"Should create a user set");
#if defined(LWE_JFLASH)
  LWESetBuiltInCatalogLanguageOverride(@"en");
  Tag *beginner = [TagPeer retrieveTagById:95];
  XCTAssertEqualObjects(beginner.tagName, @"Beginner 1 (≈N5) 01");
  XCTAssertEqualObjects([beginner displayName], beginner.tagName, @"English stays the stored name");
  NSArray *englishOnly = [TagPeer retrieveTagListLike:@"初級1"];
  XCTAssertEqual([englishOnly count], (NSUInteger)0, @"English search does not use the Japanese column");

  LWESetBuiltInCatalogLanguageOverride(@"ja");
  beginner = [TagPeer retrieveTagById:95];
  XCTAssertEqualObjects(beginner.tagName, @"Beginner 1 (≈N5) 01", @"The stored name stays English");
  XCTAssertEqualObjects([beginner displayName], @"初級1（≈N5）01");
  XCTAssertTrue([[beginner displayDescription] length] > 0);
  Tag *full = [TagPeer retrieveTagByName:@"Beginner 1 (≈N5) Full Set"];
  XCTAssertEqualObjects([full displayName], @"初級1（≈N5）全部");
  Group *level = [GroupPeer retrieveGroupById:24];
  XCTAssertEqualObjects(level.groupName, @"1. Beginner 1 (≈N5)");
  XCTAssertEqualObjects([level displayName], @"初級1（≈N5）");

  NSArray *byJapanese = [TagPeer retrieveTagListLike:@"初級1"];
  XCTAssertTrue([byJapanese count] > 1, @"Japanese search matches tag_name_ja");
  NSArray *byEnglish = [TagPeer retrieveTagListLike:@"Beginner 1"];
  XCTAssertTrue([byEnglish count] > 1, @"The English name still matches while the app is in Japanese");
  BOOL foundFull = NO;
  for (Tag *tag in byEnglish)
  {
    if ([tag.tagName isEqualToString:@"Beginner 1 (≈N5) Full Set"])
    {
      foundFull = YES;
    }
  }
  XCTAssertTrue(foundFull, @"Full Set stays findable by its English name");

  NSArray *nouns = [TagPeer retrieveTagListByGroupId:2];
  XCTAssertEqualObjects([[nouns objectAtIndex:0] tagName], @"Common Nouns Full Set");
  XCTAssertEqualObjects([[nouns objectAtIndex:0] displayName], @"よく使う名詞全部");
  Tag *nounChunk = [TagPeer retrieveTagByName:@"Common Nouns 001"];
  XCTAssertNotNil(nounChunk);
  XCTAssertEqualObjects([nounChunk displayName], @"よく使う名詞001");
  XCTAssertGreaterThanOrEqual(nounChunk.cardCount, (NSInteger)50);
  XCTAssertLessThanOrEqual(nounChunk.cardCount, (NSInteger)100);
  XCTAssertNil([TagPeer retrieveTagByName:@"Nouns"], @"The full Nouns list is not a built-in set");
  XCTAssertNil([TagPeer retrieveTagByName:@"Nouns Full Set"]);
  XCTAssertNil([TagPeer retrieveTagByName:@"Nouns 0001"]);
  Group *nounGroup = [GroupPeer retrieveGroupById:2];
  XCTAssertEqualObjects([nounGroup displayName], @"名詞");

  NSArray *common = [TagPeer retrieveTagListByGroupId:11];
  XCTAssertEqualObjects([[common objectAtIndex:0] tagName], @"Common Words Full Set");
  XCTAssertEqualObjects([[common objectAtIndex:0] displayName], @"よく使う単語全部");

  NSArray *core = [TagPeer retrieveTagListByGroupId:28];
  XCTAssertEqualObjects([[core objectAtIndex:0] tagName], @"Core 1000 Full Set");
  XCTAssertEqualObjects([[core objectAtIndex:0] displayName], @"基本1000語全部");
  XCTAssertEqual([[core objectAtIndex:0] cardCount], (NSInteger)993);
  XCTAssertEqualObjects([[core objectAtIndex:1] tagName], @"Core 1000 01");
  XCTAssertEqualObjects([[core objectAtIndex:1] displayName], @"基本1000語01");

  Tag *mine = [TagPeer retrieveTagById:created.tagId];
  XCTAssertEqualObjects([mine displayName], @"マイセット", @"A user-created set is never renamed");
  XCTAssertNil(mine.tagNameJa);

  Tag *favorites = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  XCTAssertEqualObjects([favorites displayName], @"ロングウィークエンドのお気に入り");
  favorites.tagDescription = @"renamed by the user";
  [favorites save];
  Tag *saved = [TagPeer retrieveTagById:favorites.tagId];
  XCTAssertEqualObjects([saved displayName], kLWEFavoriteTagName, @"Saving an editable set clears the shipped Japanese name");
  XCTAssertNil(saved.tagNameJa);
#else
  LWESetBuiltInCatalogLanguageOverride(@"ja");
  XCTAssertFalse(LWEBuiltInCatalogUsesJapanese(), @"cFlash stays English");
  Tag *tag = [TagPeer retrieveTagById:DEFAULT_TAG_ID];
  XCTAssertEqualObjects([tag displayName], tag.tagName);
  XCTAssertEqualObjects([created displayName], @"マイセット");
#endif
  [TagPeer deleteTag:created];
}

- (void)testDefaultTagAndStarterSets
{
#if defined(LWE_JFLASH)
  XCTAssertEqual(DEFAULT_TAG_ID, 200, @"A new install starts on Hiragana (1 Basic)");
  XCTAssertEqual(LWEStarterSetCount(), (NSInteger)4);
  NSInteger expected[4][2] = { {16, 200}, {9, 208}, {21, 73}, {24, 95} };
  for (NSInteger i = 0; i < LWEStarterSetCount(); i++)
  {
    NSInteger groupId = 0;
    NSInteger tagId = 0;
    LWEStarterSetAtIndex(i, &groupId, &tagId);
    XCTAssertEqual(groupId, expected[i][0], @"starter %ld group", (long)i);
    XCTAssertEqual(tagId, expected[i][1], @"starter %ld tag", (long)i);
    FMResultSet *rs = [[LWEDatabase sharedLWEDatabase].dao executeQuery:
                       @"SELECT 1 FROM group_tag_link WHERE group_id = ? AND tag_id = ?",
                       [NSNumber numberWithInteger:groupId], [NSNumber numberWithInteger:tagId]];
    XCTAssertTrue([rs next], @"starter group %ld tag %ld is linked", (long)groupId, (long)tagId);
    [rs close];
    Tag *tag = [TagPeer retrieveTagById:tagId];
    XCTAssertTrue([tag.tagName length] > 0, @"starter tag %ld has a name", (long)tagId);
  }
  Tag *hiragana = [TagPeer retrieveTagById:DEFAULT_TAG_ID];
  XCTAssertEqualObjects(hiragana.tagName, @"Hiragana (1 Basic)");
#else
  XCTAssertEqual(DEFAULT_TAG_ID, 158, @"cFlash still starts on its own default set");
#endif
}

#pragma mark -
#pragma mark Setting up

- (void)setUp
{
  //get the cloned database as a test database.
  NSError *error = nil;
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  BOOL result = [db setupTestDatabaseAndOpenConnectionWithError:&error];
  XCTAssertTrue(result, @"Failed in setup the test database with error: %@", [error localizedDescription]);
  
  //Setup Cards
  result = [db setupAttachedDatabase:CURRENT_CARD_TEST_DATABASE asName:@"cards"];
  XCTAssertTrue(result, @"Failed to setup cards database");
}

- (void)tearDown
{
  LWESetBuiltInCatalogLanguageOverride(nil);
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  NSError *error = nil;
  BOOL result = [db removeTestDatabaseWithError:&error];
  XCTAssertTrue(result, @"Test database cannot be removed for some reason.\nError: %@", [error localizedDescription]);
}

@end
