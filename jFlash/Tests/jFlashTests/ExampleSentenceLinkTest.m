//
//  ExampleSentenceLinkTest.m
//  jFlash
//
//  Copyright (c) 2026 Long Weekend LLC. All rights reserved.
//
//  Example sentences against the bundled EX 2.0 database: an expanded sentence lists every
//  word linked to it, while a card still lists at most 10 sentences and the sentence search is capped.
//

#import <XCTest/XCTest.h>

#import "SetupDatabaseHelper.h"
#import "CardPeer.h"
#import "ExampleSentencePeer.h"
#import "ExampleSentence.h"
#import "JapaneseCard.h"
#import "jFlashAppDelegate.h"
#import "PluginManager.h"
#import "Plugin.h"

static NSString * const kTestEXDatabase = @"jFlash-EX-2.0.db";
static NSInteger const kKajiCardId = 1191980;   // 家事 かじ
static NSInteger const kHahaCardId = 1514990;   // 母 はは: in hundreds of sentences
static NSInteger const kNoCardId = 1469800;     // 乃 の (the B-lines' の)
static NSInteger const kNaCardId = 2029110;     // な
static NSInteger const kNoniCardId = 1009980;   // のに

@interface ExampleSentenceLinkTest : XCTestCase
@end

@implementation ExampleSentenceLinkTest

#pragma mark - Helpers

- (NSInteger)_sentenceIdForText:(NSString *)japanese
{
  FMResultSet *rs = [[LWEDatabase sharedLWEDatabase].dao executeQuery:@"SELECT sentence_id FROM sentences WHERE sentence_ja = ?", japanese];
  NSInteger sentenceId = 0;
  if ([rs next])
  {
    sentenceId = [rs intForColumn:@"sentence_id"];
  }
  [rs close];
  XCTAssertTrue(sentenceId > 0, @"The EX database should ship the sentence %@", japanese);
  return sentenceId;
}

- (NSArray *)_headwordsForSentence:(NSString *)japanese
{
  NSArray *cards = [CardPeer retrieveCardSetForExampleSentenceId:[self _sentenceIdForText:japanese]];
  NSMutableArray *headwords = [NSMutableArray array];
  for (Card *card in cards)
  {
    [headwords addObject:[card headwordIgnoringMode:YES]];
  }
  return headwords;
}

- (NSInteger)_intForSQL:(NSString *)sql argument:(id)argument
{
  FMResultSet *rs = [[LWEDatabase sharedLWEDatabase].dao executeQuery:sql, argument];
  NSInteger value = [rs next] ? [rs intForColumnIndex:0] : -1;
  [rs close];
  return value;
}

#pragma mark - A sentence lists all its words

- (void)testSentenceListsEveryLinkedWord
{
  // Reported from TestFlight: only 家事 and 切り盛り were listed; 母 and 忙しい were missing.
  NSArray *headwords = [self _headwordsForSentence:@"母は家事を切り盛りするのに忙しい。"];
  for (NSString *word in [NSArray arrayWithObjects:@"母", @"家事", @"切り盛り", @"忙しい", nil])
  {
    XCTAssertTrue([headwords containsObject:word], @"%@ should be listed for 母は家事を切り盛りするのに忙しい。 (got %@)", word, headwords);
  }
  XCTAssertFalse([headwords containsObject:@"は"], @"Particles are never linked");
  XCTAssertFalse([headwords containsObject:@"を"], @"Particles are never linked");
  XCTAssertFalse([headwords containsObject:@"のに"], @"The particle のに gets no extra links");
  // Listed in the order the words appear in the sentence
  NSArray *expected = [NSArray arrayWithObjects:@"母", @"家事", @"切り盛り", @"忙しい", nil];
  XCTAssertEqualObjects(headwords, expected, @"Words in sentence order");
}

- (void)testParticlesGetNoExtraLinks
{
  // The B-lines write の (which resolves to the 乃 card) and な: neither may be listed under
  // sentences other than their own top 20.  This one has both.
  NSArray *headwords = [self _headwordsForSentence:@"お庭の方にも縁台を並べれば、かなり座席数を確保できそうだなーと思いました。"];
  XCTAssertTrue([headwords containsObject:@"庭"], @"The sentence lists its words (got %@)", headwords);
  XCTAssertTrue([headwords indexOfObject:@"庭"] < [headwords indexOfObject:@"縁台"] &&
                [headwords indexOfObject:@"縁台"] < [headwords indexOfObject:@"思う"], @"Words in sentence order (got %@)", headwords);
  for (NSString *particle in [NSArray arrayWithObjects:@"乃", @"の", @"な", nil])
  {
    XCTAssertFalse([headwords containsObject:particle], @"%@ should not be listed (got %@)", particle, headwords);
  }
  for (NSNumber *cardId in [NSArray arrayWithObjects:[NSNumber numberWithInteger:kNoCardId], [NSNumber numberWithInteger:kNaCardId], [NSNumber numberWithInteger:kNoniCardId], nil])
  {
    NSInteger links = [self _intForSQL:@"SELECT COUNT(*) FROM card_sentence_link WHERE card_id = ?" argument:cardId];
    XCTAssertTrue(links <= 20, @"Card %@ keeps only its own top 20 sentences, no extra links (has %ld)", cardId, (long)links);
  }
}

- (void)testSecondSentenceListsHerToo
{
  NSArray *headwords = [self _headwordsForSentence:@"彼女は家事をせっせとした。"];
  for (NSString *word in [NSArray arrayWithObjects:@"彼女", @"家事", @"せっせと", nil])
  {
    XCTAssertTrue([headwords containsObject:word], @"%@ should be listed for 彼女は家事をせっせとした。 (got %@)", word, headwords);
  }
}

- (void)testSentenceWordsIncludeHiddenLinks
{
  // 母 picked 10 other (shorter) sentences to show, so its link to this sentence is should_show = 0.
  NSInteger sentenceId = [self _sentenceIdForText:@"母は家事を切り盛りするのに忙しい。"];
  NSInteger shown = [self _intForSQL:[NSString stringWithFormat:@"SELECT should_show FROM card_sentence_link WHERE card_id = %ld AND sentence_id = ?", (long)kHahaCardId]
                            argument:[NSNumber numberWithInteger:sentenceId]];
  XCTAssertEqual(shown, 0, @"母's link to this sentence is a hidden one");
  BOOL found = NO;
  for (Card *card in [CardPeer retrieveCardSetForExampleSentenceId:sentenceId])
  {
    found = found || (card.cardId == kHahaCardId);
  }
  XCTAssertTrue(found, @"Hidden links are still listed under the sentence");
}

#pragma mark - A card still lists at most 10 sentences

- (void)testCardSentenceListStaysCappedAtTen
{
  XCTAssertTrue([ExampleSentencePeer isNewVersion], @"EX 2.0 has card_sentence_link.should_show");
  NSInteger links = [self _intForSQL:@"SELECT COUNT(*) FROM card_sentence_link WHERE card_id = ?" argument:[NSNumber numberWithInteger:kHahaCardId]];
  XCTAssertTrue(links > 10, @"母 is linked to many sentences (%ld)", (long)links);

  for (NSNumber *cardId in [NSArray arrayWithObjects:[NSNumber numberWithInteger:kHahaCardId], [NSNumber numberWithInteger:kKajiCardId], nil])
  {
    NSArray *sentences = [ExampleSentencePeer getExampleSentencesByCardId:[cardId integerValue]];
    XCTAssertEqual((NSInteger)[sentences count], 10, @"Card %@ still lists exactly its 10 best sentences", cardId);
    for (ExampleSentence *sentence in sentences)
    {
      NSInteger shown = [self _intForSQL:[NSString stringWithFormat:@"SELECT should_show FROM card_sentence_link WHERE card_id = %ld AND sentence_id = ?", (long)[cardId integerValue]]
                                argument:[NSNumber numberWithInteger:sentence.sentenceId]];
      XCTAssertEqual(shown, 1, @"Card %@ only lists its should_show = 1 sentences (sentence %ld)", cardId, (long)sentence.sentenceId);
    }
  }
  XCTAssertTrue([ExampleSentencePeer sentencesExistForCardId:kKajiCardId], @"家事 has example sentences");
}

#pragma mark - The sentence search is capped

- (void)testSentenceSearchIsLimited
{
  // 母 is linked to ~400 sentences now.
  NSArray *sentences = [ExampleSentencePeer searchSentencesForKeyword:@"母"];
  XCTAssertEqual((NSInteger)[sentences count], kLWESentenceSearchLimit, @"The sentence search returns at most kLWESentenceSearchLimit sentences");
  NSMutableSet *ids = [NSMutableSet set];
  for (ExampleSentence *sentence in sentences)
  {
    [ids addObject:[NSNumber numberWithInteger:sentence.sentenceId]];
  }
  XCTAssertEqual([ids count], [sentences count], @"No sentence is returned twice");
}

#pragma mark - Setup & Teardown

- (void)setUp
{
  [super setUp];
  NSError *error = nil;
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  BOOL result = [db setupTestDatabaseAndOpenConnectionWithError:&error];
  XCTAssertTrue(result, @"Failed in setup the test database with error: %@", [error localizedDescription]);
  XCTAssertTrue([db setupAttachedDatabase:CURRENT_FTS_TEST_DATABASE asName:@"fts"], @"Failed to attach the search database");
  XCTAssertTrue([db setupAttachedDatabase:CURRENT_CARD_TEST_DATABASE asName:@"cards"], @"Failed to attach the cards database");
  // The EX database is attached under its plugin key, as the app does: +[ExampleSentencePeer isNewVersion]
  // asks the loaded EX_DB plugin for its version and EX_DB's card_sentence_link for a should_show column.
  PluginManager *pluginManager = [(jFlashAppDelegate *)[[UIApplication sharedApplication] delegate] pluginManager];
  if ([pluginManager pluginKeyIsLoaded:EXAMPLE_DB_KEY])
  {
    XCTAssertTrue([db setupAttachedDatabase:kTestEXDatabase asName:EXAMPLE_DB_KEY], @"Failed to attach the example sentences database");
  }
  else
  {
    // The test host hasn't loaded its plugins (yet): load the bundled EX plugin the way the app does at
    // launch, which attaches it as EX_DB.  Later tests find it loaded and only re-attach the file.
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:LWE_PREINSTALLED_PLUGIN_PLIST ofType:nil];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    Plugin *plugin = [Plugin pluginWithDictionary:[plist objectForKey:EXAMPLE_DB_KEY]];
    XCTAssertEqualObjects(plugin.filePath, kTestEXDatabase, @"The app bundles EX 2.0");
    NSError *loadError = nil;
    XCTAssertTrue([pluginManager loadPlugin:plugin error:&loadError], @"Failed to load the example sentences plugin: %@", [loadError localizedDescription]);
  }
}

- (void)tearDown
{
  NSError *error = nil;
  BOOL result = [[JFlashDatabase sharedJFlashDatabase] removeTestDatabaseWithError:&error];
  XCTAssertTrue(result, @"Test database cannot be removed for some reason.\nError: %@", [error localizedDescription]);
  [super tearDown];
}

@end
