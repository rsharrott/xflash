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
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  NSError *error = nil;
  BOOL result = [db removeTestDatabaseWithError:&error];
  XCTAssertTrue(result, @"Test database cannot be removed for some reason.\nError: %@", [error localizedDescription]);
}

@end
