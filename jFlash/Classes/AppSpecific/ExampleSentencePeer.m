//
//  ExampleSentencePeer.m
//  jFlash
//
//  Created by シャロット ロス on 6/6/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "ExampleSentencePeer.h"
#import "CardPeer.h"
#import "jFlashAppDelegate.h"

NSInteger const kLWESentenceSearchLimit = 100;

/*!
    @class ExampleSentencePeer
    @abstract    Handles getting ExampleSentence objects from LWEDatabase
 */
@implementation ExampleSentencePeer

+ (BOOL) isNewVersion
{
#if defined (LWE_JFLASH)
  // "New" example databases (EX 1.2 and later, including the 2.0 Tatoeba refresh) have
  // card_sentence_link.should_show; EX 1.1 didn't.  Ask the attached database for the column
  // instead of guessing from its version string.  A YES is kept until the loaded version changes; a NO
  // is checked again next time (one PRAGMA), so asking before EX_DB is attached to the current
  // connection (the unit tests reopen the database) can't stick.
  static NSString *checkedVersion = nil;
  static BOOL hasShouldShow = NO;
  jFlashAppDelegate *appDelegate = (jFlashAppDelegate*)[[UIApplication sharedApplication] delegate];
  NSString *exVersion = [appDelegate.pluginManager versionForLoadedPlugin:EXAMPLE_DB_KEY];
  if (exVersion == nil)
  {
    return NO;
  }
  if (hasShouldShow == NO || checkedVersion == nil || [checkedVersion isEqualToString:exVersion] == NO)
  {
    hasShouldShow = NO;
    // The plugin is attached under its pluginId (EX_DB), one of our own constants.
    NSString *sql = [NSString stringWithFormat:@"PRAGMA %@.table_info(card_sentence_link)", EXAMPLE_DB_KEY];
    FMResultSet *rs = [[[LWEDatabase sharedLWEDatabase] dao] executeQuery:sql];
    while ([rs next])
    {
      if ([[rs stringForColumn:@"name"] isEqualToString:@"should_show"])
      {
        hasShouldShow = YES;
      }
    }
    [rs close];
    [checkedVersion release];
    checkedVersion = [exVersion copy];
  }
  return hasShouldShow;
#else
  return YES;
#endif
}


/**
 * Returns a mutable array of ExampleSentence objects based on custom SQL
 * \param sql SQL string used to return the ExampleSentence objects
 * \param hydrate If YES, the -hydrate:rs method will be called on each ExampleSentence
 */
+ (NSMutableArray*) retrieveSentencesWithSQL:(NSString*)sql hydrate:(BOOL)hydrate arguments:(NSArray *)arguments
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = [[db dao] executeQuery:sql withArgumentsInArray:arguments];
  ExampleSentence* tmpSentence;
  NSMutableArray *sentenceList = [[[NSMutableArray alloc] init] autorelease];
  while ([rs next])
  {
    tmpSentence = [[ExampleSentence alloc] init];
    if (hydrate)
    {
      [tmpSentence hydrate:rs];
    }
    else
    {
      [tmpSentence setSentenceId:[rs intForColumn:@"sentence_id"]];
    }
    [sentenceList addObject: tmpSentence];
    [tmpSentence release];
  }
  [rs close];
  return sentenceList;
}

+ (NSMutableArray*) retrieveSentencesWithSQL:(NSString*)sql hydrate:(BOOL)hydrate
{
  return [self retrieveSentencesWithSQL:sql hydrate:hydrate arguments:[NSArray array]];
}


/**
 * Returns a single hydrated ExampleSentence object
 * \param sentenceId primary key of the Sentence to be retrieved from the DB
 */
+ (ExampleSentence*) retrieveExampleSentenceByPK: (NSInteger)sentenceId;
{
  NSMutableArray* tmpSentences = [ExampleSentencePeer retrieveSentencesWithSQL:@"SELECT * FROM sentences WHERE sentence_id = ?"
                                                                       hydrate:YES
                                                                     arguments:[NSArray arrayWithObject:[NSNumber numberWithInteger:sentenceId]]];
  if ([tmpSentences count] == 0)
  {
    return nil;
  }
  return [tmpSentences objectAtIndex:0];
}


/**
 * Returns all linked ExampleSentence objects for a given card
 * \param cardId Primary key of the Card object for which to retrieve ExampleSentences
 */
+ (NSMutableArray*) getExampleSentencesByCardId: (NSInteger)cardId
{
  NSString *sql = nil;
  if ([ExampleSentencePeer isNewVersion])
  {
    sql = @"SELECT s.* FROM sentences s, card_sentence_link l WHERE l.card_id = ? AND s.sentence_id = l.sentence_id AND l.should_show = 1 LIMIT 10";
  }
  else
  {
    sql = @"SELECT s.* FROM sentences s, card_sentence_link l WHERE l.card_id = ? AND s.sentence_id = l.sentence_id LIMIT 10";
  }
  return [ExampleSentencePeer retrieveSentencesWithSQL:sql
                                               hydrate:YES
                                             arguments:[NSArray arrayWithObject:[NSNumber numberWithInteger:cardId]]];
}

/**
 * Returns a boolean YES if example sentences exist for a given card id. NO if none exist/
 * If a card_sentence_link table record's should_show value is 0, this will return NO even if there is a link
 */
+ (BOOL) sentencesExistForCardId: (NSInteger)cardId
{
  NSString *sql = nil;

  if ([ExampleSentencePeer isNewVersion])
  {
    // Version 1.2 example sentences DB
    sql = @"SELECT sentence_id FROM card_sentence_link WHERE card_id = ? AND should_show = '1' LIMIT 1";
  }
  else
  {
    // Version 1.1 example sentences DB
    sql = @"SELECT sentence_id FROM card_sentence_link WHERE card_id = ? LIMIT 1";
  }
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = [[db dao] executeQuery:sql withArgumentsInArray:[NSArray arrayWithObject:[NSNumber numberWithInteger:cardId]]];
  BOOL exists = [rs next];
  [rs close];
  return exists;
}


/**
 * Returns an array of Sentence objects after searching keyword - for search
 */
+ (NSArray*) searchSentencesForKeyword: (NSString*)keyword
{
  NSArray *cardList = [CardPeer searchCardsForKeyword:keyword];
  if ([cardList count] == 0)
  {
    return [NSArray array];
  }

  // Build the IN-list of placeholders ("?,?,?,...") and a parallel arguments array.
  // cardIds come from a previous DB query, but we still parameterize for hygiene.
  NSMutableArray *placeholders = [NSMutableArray arrayWithCapacity:[cardList count]];
  NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[cardList count]];
  for (Card *card in cardList)
  {
    [placeholders addObject:@"?"];
    [arguments addObject:[NSNumber numberWithInteger:[card cardId]]];
  }
  NSString *inList = [placeholders componentsJoinedByString:@","];

  // Every shipped sentence links to all of its words (EX 2.0), so a common word can match
  // hundreds of sentences.  Cap the result like the word search (+[CardPeer searchCardsForKeyword:],
  // 100 cards), whose results the Search tab shows as one unpaged list.  (The Search tab no longer
  // has a sentences mode, so nothing calls this today.)  Sentences a card shows come first.
  NSString *order = [ExampleSentencePeer isNewVersion] ? @"MAX(c.should_show) DESC, s.sentence_id ASC" : @"s.sentence_id ASC";
  NSString *sql = [NSString stringWithFormat:@"SELECT s.sentence_id, s.sentence_ja, s.sentence_en, s.checked FROM sentences s, card_sentence_link c "
                   "WHERE s.sentence_id = c.sentence_id AND c.card_id IN (%@) GROUP BY s.sentence_id ORDER BY %@ LIMIT %ld",
                   inList, order, (long)kLWESentenceSearchLimit];
  return [ExampleSentencePeer retrieveSentencesWithSQL:sql hydrate:YES arguments:arguments];
}

@end
