//
//  JFlashSearchTest.m
//  jFlash
//
//  Created by Ross Sharrott on 11/25/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "JFlashSearchTest.h"

#import <UIKit/UIKit.h>

#import "SetupDatabaseHelper.h"
#import "CardPeer.h"
#import "JapaneseCard.h"

@implementation JFlashSearchTest

- (NSArray *) _resultsForSearchKeyword:(NSString *)keyword
{
  NSArray *results = [CardPeer searchCardsForKeyword:keyword];
  XCTAssertTrue(([results count] > 0), @"Search should return more than 0 entries for keyword %@", keyword);
  return results;
}

#pragma mark - Search Test Methods

- (void) testBasicSearch
{
  NSArray *results = [CardPeer searchCardsForKeyword:@"日本語"];
  NSInteger resultCount = [results count];
  XCTAssertEqual(resultCount, 1, @"JFlash database should return 1 results for search keyword '日本語'");
}

- (void) testMatchReadingFirst
{
/*
    FROM THE STORY THIS IS INTENDED TO ADDRESS:
    Kieran, while searching for "Teruterubozu", tried putting in "teru".  He was surprised when none
    of the words began with "teru".... good point.  When I tested my hunch and put "terut", there were
    no entries (of course), and then I ran the deep search, and I came back with the single, correct card.
    I think the expected behavior from the search is that it would prioritize results that match the
    beginning of a headword, reading, or meaning.
 */
  // -reading is "kana - romaji" in the default reading setting (see testChokinFix), so check the romaji,
  // which is what "teru" matches.  (This test used to check -reading, which starts with てる.)
  NSArray *results = [self _resultsForSearchKeyword:@"teru"];
  if ([results count] > 0)
  {
    for (NSUInteger i = 0; i < MIN((NSUInteger)3, [results count]); i++)
    {
      JapaneseCard *card = [results objectAtIndex:i];
      [card hydrate];
      XCTAssertTrue([[card.romaji lowercaseString] hasPrefix:@"teru"], @"Result %lu's romaji (%@) should start with the search term", (unsigned long)i, card.romaji);
    }
  }
  else
  {
    XCTFail(@"Couldn't get any cards for search: teru");
  }
}

- (void) testChokinFix
{
  /**
   * User reported that "ちょきん" (savings) was in the database as "chikin" (it was).  This
   * test confirms that it is fixed as of Mar 2012 (MMA).  It was actually a duplicate card
   * (didn't match the real card because of the different reading in the first versions).
   *
   * Since we have trouble " deleting " cards, I just fixed the card.  This test confirms that.
   */
  NSArray *results = [CardPeer searchCardsForKeyword:@"貯金"];
  XCTAssertTrue([results count] > 0,@"Should have gotten some results for this search");
  for (JapaneseCard *card in results)
  {
    [card hydrate];
    // This will be "both" because the "reading" returns the romaji + kana in the ddefault setting
    XCTAssertEqualObjects(card.reading,@"ちょきん - chokin",@"Both readings should be chokin.");
  }
}

- (void)testSearchWithKanaReturnsResults
{
  NSArray *results = [CardPeer searchCardsForKeyword:@"ちょきん"];
  XCTAssertTrue([results count] > 0, @"Kana search for ちょきん should return at least one result");
}

- (void)testSearchWithEnglishReturnsResults
{
  NSArray *results = [CardPeer searchCardsForKeyword:@"water"];
  XCTAssertTrue([results count] > 0, @"English search for 'water' should return results");
}

- (void)testSearchWithNonsenseReturnsEmpty
{
  NSArray *results = [CardPeer searchCardsForKeyword:@"xyzabcnonsense99887"];
  XCTAssertNotNil(results, @"Search result array should not be nil");
  XCTAssertEqual((NSInteger)[results count], (NSInteger)0, @"Nonsense keyword should return no results");
}

// jFlash's FTS table has a single content column (headword, kana, romaji and meaning together), so jFlash
// never narrows a search to a column: keywordIsReading / keywordIsHeadword are NO by design (they are for
// cFlash's headword / reading columns).  These tests used to expect cFlash's classification in jFlash.
- (void)testKeywordIsReadingWithHiragana
{
  XCTAssertFalse([CardPeer keywordIsReading:@"ちょきん"], @"jFlash searches all columns, so no keyword is column-classified");
  NSArray *results = [self _resultsForSearchKeyword:@"ちょきん"];
  BOOL found = NO;
  for (JapaneseCard *card in results)
  {
    [card hydrate];
    if ([card.headword isEqualToString:@"貯金"]) found = YES;
  }
  XCTAssertTrue(found, @"A kana search still finds the card by its reading (貯金)");
}

- (void)testKeywordIsHeadwordWithKanji
{
  XCTAssertFalse([CardPeer keywordIsHeadword:@"日本語"], @"jFlash searches all columns, so no keyword is column-classified");
  NSArray *results = [self _resultsForSearchKeyword:@"日本語"];
  Card *first = [results firstObject];
  [first hydrate];
  XCTAssertEqualObjects(first.headword, @"日本語", @"A kanji search still finds the headword first");
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
