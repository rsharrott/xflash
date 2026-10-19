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
