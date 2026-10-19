//
//  CFlashSearchTest.m
//  jFlash
//
//  Created by Mark Makdad on 11/15/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "CFlashSearchTest.h"

#import <UIKit/UIKit.h>

#import "SetupDatabaseHelper.h"
#import "CardPeer.h"
#import "LWEDatabase.h"

// The private FTS query, so the test can look at the ranked card_ids of one column on their own
@interface CardPeer (CFlashSearchTestPrivate)
+ (FMResultSet *) _FTSResultSetForKeyword:(NSString *)keyword column:(NSString *)columnName queryLimit:(NSInteger)limit;
@end

@implementation CFlashSearchTest

- (NSArray *) _searchKeywordExpectingResults:(NSString*)keyword
{
  NSArray *results = [CardPeer searchCardsForKeyword:keyword];
  XCTAssertTrue(([results count] > 0), @"FTS search returned no results for keyword: %@!", keyword);
  return results;
}

#pragma mark - Search Test Methods

- (void) testBasicSearch
{
  NSArray *results = [CardPeer searchCardsForKeyword:@"keyword"];
  NSInteger resultCount = [results count];
  XCTAssertEqual(3, resultCount, @"CFlash database should return 3 results for search keyword 'keyword'");
}

// When I search for "gong1", I would expect to see results whose pinyin *starts* with gong1 first.
- (void) testMatchPinyinFirst
{
  // The first card's reading should match
  NSArray *results = [self _searchKeywordExpectingResults:@"gong1"];
  Card *resultCard = [results objectAtIndex:0];
  [resultCard hydrate];
  XCTAssertEqualObjects(@"gong1", resultCard.reading, @"First search results should match pinyin search.");
}

// When I search for "人", the first match should be only that
- (void) testMatchExactHeadwordFirst
{
  // The first card's headword should match
  NSArray *results = [self _searchKeywordExpectingResults:@"拼音"];
  Card *resultCard = [results objectAtIndex:0];
  [resultCard hydrate];
  XCTAssertEqualObjects(@"拼音", resultCard.headword, @"HW of these cards should be the same");
}

- (void) testMatchMultiplePinyin
{
  NSArray *results = [self _searchKeywordExpectingResults:@"duo1 gong1"];
  Card *resultCard = [results objectAtIndex:0];
  [resultCard hydrate];
  
  XCTAssertEqualObjects(@"duo1 gong1", resultCard.reading, @"First search results should match pinyin search.");
}

- (void) testMatchMultipleUnknownTonePinyin
{
  NSArray *results = [self _searchKeywordExpectingResults:@"pin? yin?"];
  Card *resultCard = [results objectAtIndex:0];
  [resultCard hydrate];
}

- (void) testOnlyMatchACardOnce
{
  NSArray *results = [self _searchKeywordExpectingResults:@"nang4"];
  XCTAssertTrue(([results count] == 1), @"There should only be 1 card reading with 'nang4'");
}

// Results that tie on match length and ptag come back in card_id order, so the list is the same every run
- (void) testTiedResultsAreOrderedByCardId
{
  FMDatabase *dao = [LWEDatabase sharedLWEDatabase].dao;
  FMResultSet *rs = [CardPeer _FTSResultSetForKeyword:@"gong1" column:@"reading" queryLimit:100];
  NSMutableArray *cardIds = [NSMutableArray array];
  while ([rs next]) [cardIds addObject:[NSNumber numberWithInt:[rs intForColumn:@"card_id"]]];
  [rs close];
  XCTAssertTrue([cardIds count] > 1, @"Expected several 'gong1' reading matches");

  NSInteger prevLength = -1, prevPtag = 0, prevCardId = 0, ties = 0;
  for (NSNumber *cardId in cardIds)
  {
    FMResultSet *keys = [dao executeQuery:@"SELECT LENGTH(reading) AS len, ptag FROM cards_search_content WHERE card_id = ?", cardId];
    XCTAssertTrue([keys next], @"No search row for card %@", cardId);
    NSInteger length = [keys intForColumn:@"len"];
    NSInteger ptag = [keys intForColumn:@"ptag"];
    [keys close];
    XCTAssertGreaterThanOrEqual(length, prevLength, @"Shortest reading first");
    if (length == prevLength && ptag == prevPtag)
    {
      ties++;
      XCTAssertLessThan(prevCardId, [cardId integerValue], @"Tied results should be in card_id order");
    }
    prevLength = length; prevPtag = ptag; prevCardId = [cardId integerValue];
  }
  XCTAssertGreaterThan(ties, 0, @"The fixture should have tied results for 'gong1'");
}

#pragma mark - Setup & Teardown

- (void)setUp
{
  //get the cloned database as a test database.
  NSError *error = nil;
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  BOOL result = [db setupTestDatabaseAndOpenConnectionWithError:&error];
  XCTAssertTrue(result, @"Failed in setup the test database with error: %@", [error localizedDescription]);
  
  //Setup FTS
  result = [db setupAttachedDatabase:CURRENT_FTS_TEST_DATABASE asName:@"fts"];
  XCTAssertTrue(result, @"Failed to setup search database");
  
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
