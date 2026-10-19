#import "CardPeer.h"
#import "JapaneseCard.h"
#import "ChineseCard.h"
#import "ExampleSentencePeer.h"

@interface CardPeer ()
+ (FMResultSet *) _FTSResultSetForKeyword:(NSString*)keyword column:(NSString *)columnName queryLimit:(NSInteger)limit;
+ (Card*) _retrieveCardWithResultSet:(FMResultSet *)rs;
+ (NSMutableArray*) _addCardsToList:(NSMutableArray*)cardList fromResultSet:(FMResultSet*)rs hydrate:(BOOL)shouldHydrate;
+ (NSString *) _tagLinkTableName:(Tag *)tag;
@end

@implementation CardPeer

/**
 * Factory that cares about what language we are using
 */
+ (Card *) blankCardWithId:(NSInteger)cardId
{
  Card *card = nil;
#if defined(LWE_JFLASH)
  card = [[[JapaneseCard alloc] init] autorelease];
#elif defined(LWE_CFLASH)
  card = [[[ChineseCard alloc] init] autorelease];
#endif
  card.cardId = cardId;
  return card;
}

/**
 * When we *REALLY* want a blank card
 */
+ (Card *) blankCard
{
  return [[self class] blankCardWithId:kLWEUninitializedCardId];
}

#pragma mark - Search APIs

/**
 * Returns YES if the keyword appears to be reading-like.  Note that this
 * current implementation is specific to Chinese Flash (it would actually not
 * work at all for JFlash).
 */
+ (BOOL) keywordIsReading:(NSString *)keyword
{
#if defined (LWE_CFLASH)
  // If it has any string components longer than 5 chars, it's not pinyin.
  NSArray *components = [keyword componentsSeparatedByString:@" "];
  for (NSString *item in components)
  {
    if ([item length] > 5)
    {
      return NO;
    }
  }
  
  // OK, it has short bits.  So make sure there are no kanji/hanzi in there.
  BOOL hasIdeograph = NO;
  for (NSInteger charIndex = 0; charIndex < [keyword length]; charIndex++)
  {
    unichar testChar = [keyword characterAtIndex:charIndex];
    //4E00 is the first code point for Unicode characters in the CJK kanji mix
    if (testChar >= 0x4E00)
    {
      hasIdeograph = YES;
    }
  }
  return (hasIdeograph == NO);
#elif defined (LWE_JFLASH)
  return NO;
#endif
}

/**
 *
 */
+ (BOOL) keywordIsHeadword:(NSString *)keyword
{
#if defined (LWE_CFLASH)
  // Strip out numbers, symbols & whitespace
  NSCharacterSet *stripChars = [NSCharacterSet characterSetWithCharactersInString:@"? "];
  NSArray *components = [keyword componentsSeparatedByCharactersInSet:stripChars];
  for (NSString *part in components)
  {
    for (NSInteger charIndex = 0; charIndex < [part length]; charIndex++)
    {
      unichar testChar = [part characterAtIndex:charIndex];
      // 2E80 is the first code point for Unicode characters in the CJK mix (kana, etc), 9FFF the last
      if (testChar < 0x2E80 || testChar > 0x9FFF)
      {
        return NO;
      }
    }
  }
  return YES;
#elif defined (LWE_JFLASH)
  return NO;
#endif
}

/**
 * Returns an array of Card objects after searching keyword
 */
+ (NSArray*) searchCardsForKeyword:(NSString*)keyword
{
  NSMutableArray *cardList = [NSMutableArray array];
  NSInteger queryLimit = 100;
  
  // Do not hydrate these cards, we will flywheel it on the table view.
  NSString *column = nil;
  if ([[self class] keywordIsHeadword:keyword])
  {
    column = @"headword";
  }
  else if ([[self class] keywordIsReading:keyword])
  {
    column = @"reading";
  }
  cardList = [CardPeer _addCardsToList:cardList fromResultSet:[CardPeer _FTSResultSetForKeyword:keyword column:column queryLimit:queryLimit] hydrate:NO];
  
  // Now, did we get enough cards, query "content" column as well (if it was a no-column search, don't re-run)
  if (column != nil && [cardList count] < queryLimit)
  {
    NSInteger newLimit = queryLimit - [cardList count];
    cardList = [CardPeer _addCardsToList:cardList fromResultSet:[CardPeer _FTSResultSetForKeyword:keyword column:@"content" queryLimit:newLimit] hydrate:NO];
  }
  
  return (NSArray*)cardList;
}

#pragma mark - Private Methods

/**
 * Runs the FTS query for the keyword and returns the card_id result set.
 * The keyword is passed to SQLite as a bound parameter (MATCH ?), never
 * interpolated into the SQL -- it can come from a jflash:// URL.
 */
+ (FMResultSet *) _FTSResultSetForKeyword:(NSString*)keyword column:(NSString *)columnName queryLimit:(NSInteger)limit
{
  // Users understand "?" better than "*".  Well, maybe not geeks.
  NSString *keywordWildcard = [keyword stringByReplacingOccurrencesOfString:@"?" withString:@"*"];
  NSString *column = nil;
  NSString *searchString = nil;

  if (columnName)
  {
    // If we are searching a specific column, and not the whole table, wrap it in quotes for exact match.
    // FTS3 phrases can't contain a double quote, so drop any from the keyword.
    NSString *phrase = [keywordWildcard stringByReplacingOccurrencesOfString:@"\"" withString:@" "];
    searchString = [NSString stringWithFormat:@"\"%@\"",phrase];
    column = columnName;
  }
  else
  {
    searchString = keywordWildcard;
    column = @"cards_search_content";
  }

  // Only the column name (one of our own constants) and the integer limit are formatted into the SQL.
  NSString *sql = [NSString stringWithFormat:@"SELECT card_id FROM cards_search_content WHERE "
                   "%@ MATCH ? ORDER BY LENGTH(content) ASC, ptag DESC LIMIT %ld", column, (long)limit];
  return [[LWEDatabase sharedLWEDatabase].dao executeQuery:sql withArgumentsInArray:[NSArray arrayWithObject:searchString]];
}

/**
 * Returns single card from result set - if multiple records, will take the last one
 */ 
+ (Card *) _retrieveCardWithResultSet:(FMResultSet *)rs
{
  Card *tmpCard = nil;
  while ([rs next])
  {
    tmpCard = [CardPeer blankCard];
    [tmpCard hydrateWithResultSet:rs];
  }
  [rs close];
  return tmpCard;
}

/**
 * Looping helper.  Populates an array of cards, either lightweight or full.
 */
+ (NSMutableArray *) _addCardsToList:(NSMutableArray*)cardList fromResultSet:(FMResultSet*)rs hydrate:(BOOL)shouldHydrate
{
  while ([rs next])
  {
    Card *tmpCard = nil;
    if (shouldHydrate)
    {
      tmpCard = [CardPeer blankCard];
      [tmpCard hydrateWithResultSet:rs];
    }
    else
    {
      tmpCard = [CardPeer blankCardWithId:[rs intForColumn:@"card_id"]];
    }
    [cardList addObject:tmpCard];
  }
  [rs close];
  return cardList;
}

// Query different tables depending on the type of the tag
// Get the tablename
+ (NSString *) _tagLinkTableName:(Tag *)tag
{
  NSString *tableName;
  if ([tag isEditable] == YES || tag.tagId == 0)
  {
    tableName = @"card_tag_link";
  }
  else
  {
    tableName = @"system_card_tag_link";
  }
  return tableName;
}


#pragma mark - Convenience Helpers

/**
 * Takes a cardId and returns a hydrated Card from the database
 */
+ (Card *) retrieveCardByPK:(NSInteger)cardId
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = [db.dao executeQuery:@""
     "SELECT c.card_id AS card_id,u.card_level as card_level,u.user_id as user_id,"
     "u.wrong_count as wrong_count,u.right_count as right_count,c.*,ch.meaning "
     "FROM cards c INNER JOIN cards_html ch ON c.card_id = ch.card_id "
     "LEFT OUTER JOIN user_history u ON c.card_id = u.card_id AND u.user_id = ? "
     "WHERE c.card_id = ch.card_id AND c.card_id = ?",[settings objectForKey:@"user_id"],[NSNumber numberWithInt:cardId]];
  return [CardPeer _retrieveCardWithResultSet:rs];
}


/**
 * Returns an array of Card ids for a given tagId
 */
+ (NSMutableArray *) retrieveCardsSortedByLevelForTag:(Tag *)tag
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  NSMutableArray *cardIdList = [NSMutableArray arrayWithCapacity:6];
  for (NSInteger i = 0; i < 6; i++)
  {
    [cardIdList addObject:[NSMutableArray array]];
  }
  
  NSString *linkTableName = [self _tagLinkTableName:tag];
  NSString *sqlQuery = [NSString stringWithFormat:@"SELECT l.card_id AS card_id,u.card_level as card_level "
                        "FROM %@ l LEFT OUTER JOIN user_history u ON u.card_id = l.card_id "
                        "AND u.user_id = ? WHERE l.tag_id = ?", linkTableName];
  FMResultSet *rs = [db.dao executeQuery:sqlQuery,[settings objectForKey:@"user_id"],[NSNumber numberWithInt:tag.tagId]];
  while ([rs next])
  {
    Card *newCard = [CardPeer blankCardWithId:[rs intForColumn:@"card_id"]];
    NSInteger levelId = [rs intForColumn:@"card_level"];
    [[cardIdList objectAtIndex:levelId] addObject:newCard];
  }
  [rs close];
  return cardIdList;
}

/**
 * Returns an array containing cardId integers contained in by the Tag tagId
 */
+ (NSArray *) retrieveFaultedCardsForTag:(Tag *)tag
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  NSString *linkTableName = [self _tagLinkTableName:tag];
  NSString *sqlQuery = [NSString stringWithFormat:@"SELECT card_id FROM %@ WHERE tag_id = ?",linkTableName];
  FMResultSet *rs = [db.dao executeQuery:sqlQuery,[NSNumber numberWithInt:tag.tagId]];
  return (NSArray *)[self _addCardsToList:[NSMutableArray array] fromResultSet:rs hydrate:NO];
}

/**
 * Returns an array containng cardId integers that are linked to the sentence
 * \param sentenceId Primary key of the sentence to look up cards for
 */
+ (NSArray*) retrieveCardSetForExampleSentenceId:(NSInteger)sentenceId
{	
	LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = nil;
  if ([ExampleSentencePeer isNewVersion])
  {
    rs = [db.dao executeQuery:@"SELECT c.* FROM card_sentence_link l, cards c WHERE l.card_id = c.card_id AND sentence_id = ? AND l.should_show = '1'", [NSNumber numberWithInt:sentenceId]];
  }
  else
  {
    rs = [db.dao executeQuery:@"SELECT c.* FROM card_sentence_link l, cards c WHERE l.card_id = c.card_id AND sentence_id = ?", [NSNumber numberWithInt:sentenceId]];
  }
	        
	NSMutableArray *cardList = [NSMutableArray array];
	while ([rs next])
	{
		Card *tmpCard = [CardPeer blankCard];
		[tmpCard hydrateWithResultSet:rs simpleHydrate:YES];
		[cardList addObject:tmpCard];
	}
	[rs close];

	return (NSArray*)cardList; 
}

@end