//
//  CardTagTest.m
//  jFlash
//
//  Created by Rendy Pranata on 19/07/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import "CardTagTest.h"
#import "SetupDatabaseHelper.h"
#import "PracticeModeCardViewDelegate.h"
#import "BrowseModeCardViewDelegate.h"
#import "TagPeer.h"
#import "PracticeCardSelector.h"
#import "PracticeCardSelectorMath.h"
#import "CardPeer.h"
#import "UserHistoryPeer.h"

#if defined(LWE_JFLASH)
#import <mach/mach.h>
#endif

static NSString * const kTagTestDefaultName             = @"TestTag";
static NSString * const kLWEFavoriteTagName = @"Long Weekend Favorites";

@interface CardTagTest ()
@property (retain) Tag *tag;
#if defined(LWE_JFLASH)
- (NSArray *)_legacyBlankCardsByLevelForTag:(Tag *)tag flattened:(NSMutableArray **)flattened;
#endif
@end


#if defined(LWE_JFLASH)
static uint64_t LWEPhysicalFootprint(void)
{
  task_vm_info_data_t info;
  mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
  if (result != KERN_SUCCESS)
  {
    return 0;
  }
  return info.phys_footprint;
}
#endif

@implementation CardTagTest

@synthesize tag = tag_;

// Regression: once more cards were seen than the study pool size, (maxCardsToStudy - cardsSeenTotal)
// was computed unsigned, wrapped to ~2^64, and p_unseen came out in the tens of thousands -- so seen
// cards were never picked again. Pure math only, no database needed.
- (void)testProbabilityOfUnseenWhenMoreSeenThanPoolSize
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  id oldMax = [[settings objectForKey:APP_MAX_STUDYING] retain];
  id oldFreq = [[settings objectForKey:APP_FREQUENCY_MULTIPLIER] retain];
  [settings setInteger:30 forKey:APP_MAX_STUDYING];
  [settings setInteger:2 forKey:APP_FREQUENCY_MULTIPLIER];

  // Medium: 40 seen (10 Studying, 10 each at Right 1x/2x/3x -> mean level 2.5), 100 cards in the set
  PracticeCardSelector *cardSelector = [[PracticeCardSelector alloc] init];
  CGFloat p = [cardSelector calculateProbabilityOfUnseenWithCardsSeen:40 totalCards:100 numerator:100 levelOneCards:10];
  XCTAssertEqualWithAccuracy(p, 0.140625, 1e-6, @"Over the pool size only the 'how well known' term should remain: ((2.5-1)/4)^2");
  [cardSelector release];

  // Put the settings back exactly as they were (absent stays absent)
  if (oldMax) { [settings setObject:oldMax forKey:APP_MAX_STUDYING]; } else { [settings removeObjectForKey:APP_MAX_STUDYING]; }
  if (oldFreq) { [settings setObject:oldFreq forKey:APP_FREQUENCY_MULTIPLIER]; } else { [settings removeObjectForKey:APP_FREQUENCY_MULTIPLIER]; }
  [oldMax release];
  [oldFreq release];
}

- (void)testProbabilityOfUnseenStaysInRange
{
  for (long maxCards = MIN_MAX_STUDYING; maxCards <= MAX_MAX_STUDYING; maxCards++)
  {
    for (long freq = MIN_FREQUENCY_MULTIPLIER; freq <= MAX_FREQUENCY_MULTIPLIER; freq++)
    {
      for (long seen = 0; seen <= 120; seen++)
      {
        long levelOne = seen / 3;
        long numerator = levelOne + (seen - levelOne) * 3;
        double p = LWEProbabilityOfUnseenCard(seen, 150, numerator, levelOne, maxCards, freq);
        XCTAssertTrue(p >= 0.0 && p <= 1.0, @"p_unseen %f out of range (seen %ld, pool %ld, freq %ld)", p, seen, maxCards, freq);
      }
    }
  }
  XCTAssertEqual(LWEProbabilityOfUnseenCard(0, 10, 0, 0, 30, 2), 1.0, @"Nothing seen yet -> new card, and no 0/0");
  XCTAssertEqual(LWEProbabilityOfUnseenCard(10, 10, 30, 0, 30, 2), 0.0, @"Everything seen -> no new card");
}

- (void)testPickCardLevelPicksSeenCardsAndNeverAnEmptyLevel
{
  long counts[6] = {60, 10, 10, 10, 10, 0};
  NSInteger picks[6] = {0};
  for (NSInteger i = 0; i < 1000; i++)
  {
    long level = LWEPickCardLevel(counts, 5, 0.140625, (i + 0.5) / 1000.0);
    XCTAssertTrue(level >= 0 && level <= 4, @"Picked empty level %ld", level);
    picks[level]++;
  }
  XCTAssertTrue(picks[0] > 100 && picks[0] < 200, @"~14%% should be new cards, got %ld/1000", (long)picks[0]);
  XCTAssertTrue(picks[1] > picks[4], @"Studying cards should come up more than Right 3x cards");

  // Inputs where the roulette loop can't return, so the old code fell through to the (empty) unseen level:
  // (a) randomNum == 1.0 (the old rand()/RAND_MAX could produce it): the only slice sums to exactly 1.0, never > 1.0
  long onlyStudying[6] = {0, 1, 0, 0, 0, 0};
  XCTAssertEqual(LWEPickCardLevel(onlyStudying, 5, 0.0, 1.0), 1L, @"Fall-through with no unseen cards must pick a seen level");
  // (b) a non-zero p_unseen with no unseen cards: seen slices only cover [0, 0.5), so 0.9 falls through
  long noUnseen[6] = {0, 3, 0, 2, 0, 0};
  XCTAssertEqual(LWEPickCardLevel(noUnseen, 5, 0.5, 0.9), 3L, @"Fall-through must pick the highest non-empty seen level, not empty unseen");
}

- (void)testFrequencySliderMoreOftenMeansMoreNewCards
{
  double previous = -1.0;
  for (long freq = MIN_FREQUENCY_MULTIPLIER; freq <= MAX_FREQUENCY_MULTIPLIER; freq++)
  {
    double p = LWEProbabilityOfUnseenCard(40, 100, 100, 10, 30, freq);
    XCTAssertTrue(p > previous, @"Frequency %ld should give more new cards than %ld", freq, freq - 1);
    previous = p;
  }
}

- (void)testCalculateNextCardLevelWithError
{
  // Init a practice mode delegate so we have access to the "random card" logic
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  PracticeCardSelector *cardSelector = [[PracticeCardSelector alloc] init];

  Tag *longWeekendFavTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [longWeekendFavTag populateCardIds];
  NSError *error = nil;
  
  NSInteger nextCardLevel = [cardSelector calculateNextCardLevelForTag:longWeekendFavTag error:&error];
  XCTAssertTrue(nextCardLevel < 6, @"Next card level is outside of possible range");
  XCTAssertNil(error, @"There should not be an error getting the next level: %@", error);
  
  // Now we cause an error but it's robust enough to work anyway
  Card *card = [practiceMode getNextCard:longWeekendFavTag afterCard:nil direction:nil];
  [longWeekendFavTag moveCard:card toLevel:1];
  [longWeekendFavTag setCardCount:1];
  nextCardLevel = [cardSelector calculateNextCardLevelForTag:longWeekendFavTag error:&error];
  XCTAssertTrue(nextCardLevel < 6, @"Next card level is outside of possible range");
  
  [cardSelector release];
  [practiceMode release];
}

- (void) testUpdateLevelCounts
{
  // Init a practice mode delegate so we have access to the "random card" logic
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];

  Tag *longWeekendFavTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [longWeekendFavTag populateCardIds];
  Card *card = [practiceMode getNextCard:longWeekendFavTag afterCard:nil direction:nil];
  XCTAssertNotNil(card,@"Could not get random card");
  
  [longWeekendFavTag moveCard:card toLevel:5];
  NSInteger count = [[[longWeekendFavTag cardsByLevel] objectAtIndex:5] count];
  XCTAssertTrue(count > 0, @"Moved card to level 5 but level 5 is empty");
  
  [practiceMode release];
}

- (void)testAddThenRemoveCardsFromStudySet
{
  Tag *newlyCreatedTag = [TagPeer createTagNamed:kTagTestDefaultName inGroup:[GroupPeer topLevelGroup]];
  Tag *longWeekendFavTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];

  //get the list of card ids on the sample group study set and copy it over the newly created tag.
  NSArray *cardIds = [CardPeer retrieveFaultedCardsForTag:longWeekendFavTag];
  for (Card *card in cardIds)
  {
    BOOL subscribed = [TagPeer subscribeCard:card toTag:newlyCreatedTag];
    XCTAssertTrue(subscribed,@"Could not subscribe card %@ to tag %@",card,newlyCreatedTag);
  }
  
  //Make sure that the test study set has the same count as the sample study set.
  NSArray *newCardIds = [CardPeer retrieveFaultedCardsForTag:newlyCreatedTag];
  XCTAssertEqual([cardIds count],[newCardIds count],@"Count number is diferent from default tag and the newly created group study: %@", [newlyCreatedTag tagName]);
  
  //Remove the card one by one.
  NSUInteger count = [newCardIds count];
  for (NSInteger i = 0; i < count; i++)
  {
    Card *card = [newCardIds objectAtIndex:i];
    NSError *error = nil;
    BOOL success = [TagPeer cancelMembership:card fromTag:newlyCreatedTag error:&error]; 
    if ((i != (count-1)) && (success == NO)) 
    {
      XCTFail(@"Fail in removing a card from the newly created study set.\nCard with id: %d cannot be removed with error: %@", card.cardId, [error localizedDescription]);
    }
    else if ((i == (count-1)) && (success == NO))
    {
      XCTAssertTrue(((success == NO) && error && ([error code] == kAllBuriedAndHiddenError)), @"Last card also get 'removed' which should not be removed.");
      NSLog(@"[TEST LOG]Last card in an active set couldn't be removed. Error from the TagPeer: %@", error);
    }
    else
    {
      NSLog(@"[TEST LOG]Card with id %d has been successfuly removed from an active set.", card.cardId);
    }
  }
}

#pragma mark - Database Integrity

- (void)testCardTagLinkIntegrity
{
  FMResultSet *rs = nil;
  NSString *testSql = nil;
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  XCTAssertNotNil(db, @"Couldn't get DB");
  
  // This will return any card IDs in card_tag_link that are not associated with cards in cards
  testSql = @"SELECT l.* FROM card_tag_link l LEFT JOIN cards c ON l.card_id = c.card_id WHERE c.card_id IS NULL";
  rs = [db.dao executeQuery:testSql];
  NSMutableArray *cardResults = [NSMutableArray array];
  while ([rs next])
  {
    [cardResults addObject:[NSNumber numberWithInt:0]];
  }
  XCTAssertTrue([cardResults count] == 0, @"There should not be any unpaired card IDs!  Array: %@",cardResults);

  // This will return any tag IDs in card_tag_link that are not associated with tags in tags
  testSql = @"SELECT l.* FROM card_tag_link l LEFT JOIN tags t ON l.tag_id = t.tag_id WHERE t.tag_id IS NULL";
  rs = [db.dao executeQuery:testSql];
  NSMutableArray *tagResults = [NSMutableArray array];
  while ([rs next])
  {
    [cardResults addObject:[NSNumber numberWithInt:0]];
  }
  XCTAssertTrue([tagResults count] == 0, @"There should not be any unpaired card IDs!  Array: %@",tagResults);
}

#pragma mark - Card Retrieval

- (void)testRetrieveFaultedCardsForFavoritesTagReturnsCards
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  NSArray *cards = [CardPeer retrieveFaultedCardsForTag:tag];
  XCTAssertNotNil(cards, @"retrieveFaultedCardsForTag should not return nil");
  XCTAssertTrue([cards count] > 0, @"Favorites tag should have at least one card");
}

- (void)testFaultedCardIsFaultBeforeHydration
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  NSArray *cards = [CardPeer retrieveFaultedCardsForTag:tag];
  XCTAssertTrue([cards count] > 0, @"Need at least one card to test");
  Card *card = [cards objectAtIndex:0];
  XCTAssertTrue(card.isFault, @"Card retrieved via retrieveFaultedCardsForTag should start as a fault");
}

- (void)testCardHydrationLoadsHeadword
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  NSArray *cards = [CardPeer retrieveFaultedCardsForTag:tag];
  XCTAssertTrue([cards count] > 0, @"Need at least one card to test");
  Card *card = [cards objectAtIndex:0];
  [card hydrate];
  XCTAssertFalse(card.isFault, @"Card should not be a fault after hydration");
  XCTAssertNotNil(card._headword, @"Hydrated card must have a headword");
  XCTAssertTrue([card._headword length] > 0, @"Headword should be non-empty");
}

- (void)testBlankCardWithIdPreservesCardId
{
  NSInteger testId = 42;
  Card *card = [CardPeer blankCardWithId:testId];
  XCTAssertNotNil(card, @"blankCardWithId should return a card object");
  XCTAssertEqual(testId, card.cardId, @"Card ID should match the value passed to blankCardWithId:");
}

#pragma mark - Tag Structure

- (void)testFlattenCardArraysReturnsNonEmptyArray
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  NSMutableArray *flattened = [tag flattenCardArrays];
  XCTAssertNotNil(flattened, @"flattenCardArrays should not return nil");
  XCTAssertTrue([flattened count] > 0, @"Favorites tag should have cards across levels");
}

- (void)testSeenCardCountIsNonNegative
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  NSInteger seenCount = [tag seenCardCount];
  XCTAssertTrue(seenCount >= 0, @"Seen card count must be non-negative, got %ld", (long)seenCount);
}

- (void)testTagCardCountIsPositive
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  XCTAssertTrue(tag.cardCount > 0, @"Favorites tag should have at least one card, got %ld", (long)tag.cardCount);
}

#pragma mark - Tag Membership

- (void)testSubscribeCardToNewTagAndVerifyMembership
{
  Tag *newTag = [TagPeer createTagNamed:@"MembershipTestTag" inGroup:[GroupPeer topLevelGroup]];
  XCTAssertNotNil(newTag, @"Should be able to create a new tag");

  Tag *favTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  NSArray *cards = [CardPeer retrieveFaultedCardsForTag:favTag];
  XCTAssertTrue([cards count] > 0, @"Need at least one card to test");
  Card *card = [cards objectAtIndex:0];

  BOOL subscribed = [TagPeer subscribeCard:card toTag:newTag];
  XCTAssertTrue(subscribed, @"Subscribing card to new tag should succeed");
  XCTAssertTrue([TagPeer card:card isMemberOfTag:newTag], @"Card should be a member after subscribe");
}

- (void)testCancelMembershipRemovesCard
{
  Tag *newTag = [TagPeer createTagNamed:@"CancelMemberTestTag" inGroup:[GroupPeer topLevelGroup]];
  Tag *favTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  NSArray *cards = [CardPeer retrieveFaultedCardsForTag:favTag];

  // Subscribe two cards so we can remove one without hitting the "last card" error
  XCTAssertTrue([cards count] >= 2, @"Need at least 2 cards");
  Card *card1 = [cards objectAtIndex:0];
  Card *card2 = [cards objectAtIndex:1];
  [TagPeer subscribeCard:card1 toTag:newTag];
  [TagPeer subscribeCard:card2 toTag:newTag];

  NSError *error = nil;
  BOOL removed = [TagPeer cancelMembership:card1 fromTag:newTag error:&error];
  XCTAssertTrue(removed, @"Should be able to remove card1 from tag: %@", error);
  XCTAssertFalse([TagPeer card:card1 isMemberOfTag:newTag], @"Card should not be a member after removal");
}

#pragma mark - UserHistoryPeer

- (void)testRecordCorrectFromLevel0MovesCardToLevel2
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card from the favorites tag");

  [tag moveCard:card toLevel:0];
  card.levelId = 0;

  [UserHistoryPeer recordCorrectForCard:card inTag:tag];

  NSMutableArray *level2 = [[tag cardsByLevel] objectAtIndex:2];
  XCTAssertTrue([level2 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Correct from level 0 should place card at level 2");
  [practiceMode release];
}

- (void)testRecordCorrectFromLevel1MovesCardToLevel2
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:1];
  card.levelId = 1;

  [UserHistoryPeer recordCorrectForCard:card inTag:tag];

  NSMutableArray *level2 = [[tag cardsByLevel] objectAtIndex:2];
  XCTAssertTrue([level2 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Correct from level 1 should place card at level 2");
  [practiceMode release];
}

- (void)testRecordCorrectFromLevel4MovesCardToLevel5
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:4];
  card.levelId = 4;

  [UserHistoryPeer recordCorrectForCard:card inTag:tag];

  NSMutableArray *level5 = [[tag cardsByLevel] objectAtIndex:5];
  XCTAssertTrue([level5 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Correct from level 4 should place card at level 5");
  [practiceMode release];
}

- (void)testRecordCorrectFromLevel5StaysAtLevel5
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:5];
  card.levelId = 5;

  [UserHistoryPeer recordCorrectForCard:card inTag:tag];

  NSMutableArray *level5 = [[tag cardsByLevel] objectAtIndex:5];
  XCTAssertTrue([level5 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Correct from level 5 should keep card at level 5");
  [practiceMode release];
}

- (void)testRecordWrongMovesCardToLevel1
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:3];
  card.levelId = 3;

  [UserHistoryPeer recordWrongForCard:card inTag:tag];

  NSMutableArray *level1 = [[tag cardsByLevel] objectAtIndex:1];
  XCTAssertTrue([level1 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Wrong answer from any level should place card at level 1");
  [practiceMode release];
}

- (void)testBuryCardMovesCardToLevel5
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:1];
  card.levelId = 1;

  [UserHistoryPeer buryCard:card inTag:tag];

  NSMutableArray *level5 = [[tag cardsByLevel] objectAtIndex:5];
  XCTAssertTrue([level5 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Buried card should be at level 5");
  [practiceMode release];
}

- (void)testRecordCorrectFromLevel2MovesCardToLevel3
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:2];
  card.levelId = 2;

  [UserHistoryPeer recordCorrectForCard:card inTag:tag];

  NSMutableArray *level3 = [[tag cardsByLevel] objectAtIndex:3];
  XCTAssertTrue([level3 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Correct from level 2 should place card at level 3");
  [practiceMode release];
}

- (void)testRecordCorrectFromLevel3MovesCardToLevel4
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:3];
  card.levelId = 3;

  [UserHistoryPeer recordCorrectForCard:card inTag:tag];

  NSMutableArray *level4 = [[tag cardsByLevel] objectAtIndex:4];
  XCTAssertTrue([level4 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Correct from level 3 should place card at level 4");
  [practiceMode release];
}

- (void)testRecordWrongFromLevel0MovesCardToLevel1
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:0];
  card.levelId = 0;

  [UserHistoryPeer recordWrongForCard:card inTag:tag];

  NSMutableArray *level1 = [[tag cardsByLevel] objectAtIndex:1];
  XCTAssertTrue([level1 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Wrong answer from level 0 should place card at level 1");
  [practiceMode release];
}

- (void)testRecordWrongFromLevel5MovesCardToLevel1
{
  PracticeModeCardViewDelegate *practiceMode = [[PracticeModeCardViewDelegate alloc] init];
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  [tag populateCardIds];
  Card *card = [practiceMode getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(card, @"Should get a card");

  [tag moveCard:card toLevel:5];
  card.levelId = 5;

  [UserHistoryPeer recordWrongForCard:card inTag:tag];

  NSMutableArray *level1 = [[tag cardsByLevel] objectAtIndex:1];
  XCTAssertTrue([level1 containsObject:[NSNumber numberWithInteger:card.cardId]], @"Wrong answer from level 5 should place card at level 1");
  [practiceMode release];
}

//! Opening a set keeps card ids. The card on screen is a real Card, loaded then.
- (void)testOpeningASetKeepsIdsUntilACardIsShown
{
  Tag *tag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  NSInteger expectedCount = tag.cardCount;
  [tag populateCardIds];
  XCTAssertEqual([tag.cardsByLevel count], (NSUInteger)6, @"Six study levels");

  NSInteger total = 0;
  NSInteger previousId = -1;
  for (NSArray *level in tag.cardsByLevel)
  {
    total += [level count];
    for (id entry in level)
    {
      XCTAssertTrue([entry isKindOfClass:[NSNumber class]], @"A level holds card ids, not Card objects");
    }
  }
  XCTAssertEqual(total, expectedCount, @"Opening loads every card id (%ld)", (long)total);
  XCTAssertEqual([tag.flattenedCardIdArray count], (NSUInteger)expectedCount);
  for (NSNumber *cardId in tag.flattenedCardIdArray)
  {
    XCTAssertGreaterThanOrEqual([cardId integerValue], previousId, @"Browse order is ascending card id");
    previousId = [cardId integerValue];
  }

  NSInteger firstId = [[tag.flattenedCardIdArray objectAtIndex:0] integerValue];
  XCTAssertGreaterThan(firstId, 0, @"The first browse card has a real id");
  tag.currentIndex = 0;
  BrowseModeCardViewDelegate *browse = [[BrowseModeCardViewDelegate alloc] init];
  Card *shown = [browse getNextCard:tag afterCard:nil direction:nil];
  XCTAssertNotNil(shown);
  XCTAssertFalse(shown.isFault, @"The card on screen is loaded (id %ld, shown %ld)", (long)firstId, (long)shown.cardId);
  XCTAssertGreaterThan([[shown headwordIgnoringMode:YES] length], (NSUInteger)0, @"Headword for card %ld", (long)shown.cardId);
  XCTAssertEqual(firstId, shown.cardId);
  XCTAssertTrue([[tag.flattenedCardIdArray objectAtIndex:0] isKindOfClass:[NSNumber class]]);
  [browse release];

  [tag freezeCardIds];
  NSMutableArray *thawed = [tag thawCardIds];
  XCTAssertEqualObjects(thawed, tag.cardsByLevel, @"A saved session reloads the same ids and levels");
  NSString *path = [LWEFile createCachesPathWithFilename:@"ids.plist"];
  if ([[NSFileManager defaultManager] fileExistsAtPath:path])
  {
    [LWEFile deleteFile:path];
  }
}

#if defined(LWE_JFLASH)

//! The pre-change open path: one blank Card per member, then a sort. Held so the footprint includes it.
- (NSArray *)_legacyBlankCardsByLevelForTag:(Tag *)tag flattened:(NSMutableArray **)flattened
{
  NSMutableArray *levels = [NSMutableArray arrayWithCapacity:6];
  NSInteger i = 0;
  for (i = 0; i < 6; i++)
  {
    [levels addObject:[NSMutableArray array]];
  }
  NSString *tableName = ([tag isEditable] || tag.tagId == 0) ? @"card_tag_link" : @"system_card_tag_link";
  NSString *sql = [NSString stringWithFormat:@"SELECT l.card_id AS card_id,u.card_level as card_level "
                   "FROM %@ l LEFT OUTER JOIN user_history u ON u.card_id = l.card_id "
                   "AND u.user_id = ? WHERE l.tag_id = ?", tableName];
  FMResultSet *rs = [[LWEDatabase sharedLWEDatabase].dao executeQuery:sql,
                     [[NSUserDefaults standardUserDefaults] objectForKey:APP_USER],
                     [NSNumber numberWithInt:tag.tagId]];
  while ([rs next])
  {
    Card *card = [CardPeer blankCardWithId:[rs intForColumn:@"card_id"]];
    NSInteger levelId = [rs intForColumn:@"card_level"];
    [[levels objectAtIndex:levelId] addObject:card];
  }
  [rs close];

  NSMutableArray *allCards = [NSMutableArray array];
  for (NSArray *level in levels)
  {
    [allCards addObjectsFromArray:level];
  }
  [allCards sortUsingSelector:@selector(compare:)];
  if (flattened != NULL)
  {
    *flattened = allCards;
  }
  return levels;
}

/**
 * Logs how long and how much memory it takes to open the big sets, against the old
 * "one blank Card per member" path. Nothing here asserts on time or bytes.
 * Nouns also checks that a Nouns 02–13 session file keeps its browse card.
 */
- (void)testLargeSetOpenLogsIdLoadAgainstFullCardLoad
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setInteger:DEFAULT_USER_ID forKey:APP_USER];
  [settings setInteger:0 forKey:@"current_index"];

  // tag id, name, card count. The largest set in 2.0 was Common Words 02 at 9,949 cards.
  NSArray *sets = [NSArray arrayWithObjects:
                   [NSArray arrayWithObjects:[NSNumber numberWithInteger:133], @"Nouns", [NSNumber numberWithInteger:122197], nil],
                   [NSArray arrayWithObjects:[NSNumber numberWithInteger:2346], @"Common Nouns Full Set", [NSNumber numberWithInteger:18142], nil],
                   [NSArray arrayWithObjects:[NSNumber numberWithInteger:2152], @"Common Words Full Set", [NSNumber numberWithInteger:22325], nil],
                   nil];
  for (NSArray *spec in sets)
  {
    NSInteger tagId = [[spec objectAtIndex:0] integerValue];
    NSString *name = [spec objectAtIndex:1];
    NSInteger expectedCount = [[spec objectAtIndex:2] integerValue];
    Tag *tag = [TagPeer retrieveTagById:tagId];
    XCTAssertEqualObjects(tag.tagName, name);
    XCTAssertEqual(tag.cardCount, expectedCount, @"%@ membership", name);

    NSInteger carriedCardId = 0;
    if (tagId == 133)
    {
      FMResultSet *idRs = [[LWEDatabase sharedLWEDatabase].dao executeQuery:
                           @"SELECT card_id FROM system_card_tag_link WHERE tag_id = 133 ORDER BY card_id LIMIT 1 OFFSET 50"];
      XCTAssertTrue([idRs next], @"Nouns has a card past the start of the list");
      carriedCardId = [idRs intForColumn:@"card_id"];
      [idRs close];

      NSArray *empty = [NSArray array];
      NSArray *one = [NSArray arrayWithObject:[NSNumber numberWithInteger:carriedCardId]];
      // Same keys as Tag's ids.plist. Tag 620 is Nouns 02, folded into 133.
      NSDictionary *frozen = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInteger:620], @"tagId",
                              [NSNumber numberWithInteger:DEFAULT_USER_ID], @"userId",
                              [NSArray arrayWithObjects:one, empty, empty, empty, empty, empty, nil], @"levels",
                              nil];
      NSString *path = [LWEFile createCachesPathWithFilename:@"ids.plist"];
      XCTAssertTrue([frozen writeToFile:path atomically:YES], @"write retired Nouns session");
      [settings setInteger:0 forKey:@"current_index"];
      tag.currentIndex = 7;
    }

    uint64_t beforeIds = LWEPhysicalFootprint();
    CFAbsoluteTime idStart = CFAbsoluteTimeGetCurrent();
    [tag populateCardIds];
    double idsMs = (CFAbsoluteTimeGetCurrent() - idStart) * 1000.0;
    uint64_t afterIds = LWEPhysicalFootprint();

    XCTAssertEqual(tag.cardCount, expectedCount, @"%@ still has every card", name);
    NSInteger levelTotal = 0;
    for (NSArray *level in tag.cardsByLevel)
    {
      levelTotal += [level count];
      if ([level count] > 0)
      {
        XCTAssertTrue([[level objectAtIndex:0] isKindOfClass:[NSNumber class]]);
      }
    }
    XCTAssertEqual(levelTotal, expectedCount);

    if (tagId == 133)
    {
      XCTAssertEqual(tag.currentIndex, (NSInteger)50, @"Browse position follows the card, not the old 9k-card index");
      XCTAssertEqual([[tag.flattenedCardIdArray objectAtIndex:tag.currentIndex] integerValue], carriedCardId);
      XCTAssertEqual([settings integerForKey:@"current_index"], tag.currentIndex);
      NSString *path = [LWEFile createCachesPathWithFilename:@"ids.plist"];
      XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:path], @"The retired session file is consumed");
    }

    NSNumber *sampleId = [tag.flattenedCardIdArray objectAtIndex:0];
    Card *shown = [CardPeer hydratedCardWithId:[sampleId integerValue]];
    XCTAssertNotNil(shown);
    XCTAssertFalse(shown.isFault);
    XCTAssertGreaterThan([[shown headwordIgnoringMode:YES] length], (NSUInteger)0);

    // Its own pool so the blank Cards are freed before the next set is measured.
    NSAutoreleasePool *legacyPool = [[NSAutoreleasePool alloc] init];
    NSMutableArray *legacyFlat = nil;
    uint64_t beforeCards = LWEPhysicalFootprint();
    CFAbsoluteTime cardStart = CFAbsoluteTimeGetCurrent();
    NSArray *legacyLevels = [[self _legacyBlankCardsByLevelForTag:tag flattened:&legacyFlat] retain];
    [legacyFlat retain];
    double cardsMs = (CFAbsoluteTimeGetCurrent() - cardStart) * 1000.0;
    uint64_t afterCards = LWEPhysicalFootprint();

    NSLog(@"LWESetLoad tag=%ld name=%@ cards=%ld ids_ms=%.0f cards_ms=%.0f ids_delta_kb=%lld cards_delta_kb=%lld ids_footprint_kb=%llu cards_footprint_kb=%llu",
          (long)tagId, name, (long)expectedCount, idsMs, cardsMs,
          (long long)afterIds / 1024 - (long long)beforeIds / 1024,
          (long long)afterCards / 1024 - (long long)beforeCards / 1024,
          (unsigned long long)(afterIds / 1024),
          (unsigned long long)(afterCards / 1024));

    XCTAssertEqual([legacyFlat count], [tag.flattenedCardIdArray count], @"%@ old and new paths see the same cards", name);
    for (NSUInteger index = 0; index < [legacyFlat count]; index++)
    {
      Card *oldCard = [legacyFlat objectAtIndex:index];
      NSInteger newId = [[tag.flattenedCardIdArray objectAtIndex:index] integerValue];
      if (oldCard.cardId != newId)
      {
        XCTFail(@"%@ browse order differs at %lu (old %ld, new %ld)", name, (unsigned long)index, (long)oldCard.cardId, (long)newId);
        break;
      }
    }
    for (NSInteger level = 0; level < 6; level++)
    {
      NSArray *oldLevel = [legacyLevels objectAtIndex:level];
      NSArray *newLevel = [tag.cardsByLevel objectAtIndex:level];
      XCTAssertEqual([oldLevel count], [newLevel count], @"%@ level %ld", name, (long)level);
      for (NSUInteger index = 0; index < [oldLevel count]; index++)
      {
        NSInteger oldId = [(Card *)[oldLevel objectAtIndex:index] cardId];
        NSInteger newId = [[newLevel objectAtIndex:index] integerValue];
        if (oldId != newId)
        {
          XCTFail(@"%@ level %ld order differs at %lu (old %ld, new %ld)", name, (long)level, (unsigned long)index, (long)oldId, (long)newId);
          break;
        }
      }
    }

    [legacyLevels release];
    [legacyFlat release];
    [legacyPool drain];
    tag.cardsByLevel = nil;
    tag.flattenedCardIdArray = nil;
  }
  [settings setInteger:0 forKey:@"current_index"];
}

#endif

#pragma mark - Setting up

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
  
  // Try to set the current tag to be LWE favorites
  Tag *favoritesTag = [TagPeer retrieveTagByName:kLWEFavoriteTagName];
  CurrentState *state = [CurrentState sharedCurrentState];
  [state setActiveTag:favoritesTag];
}

- (void)tearDown
{
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  NSError *error = nil;
  BOOL result = [db removeTestDatabaseWithError:&error];
  XCTAssertTrue(result, @"Test database cannot be removed for some reason.\nError: %@", [error localizedDescription]);
}

@end