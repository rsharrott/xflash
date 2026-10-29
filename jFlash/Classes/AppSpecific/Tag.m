//
//  Tag.m
//  jFlash
//
//  Created by Paul Chapman on 5/6/09.
//  Copyright 2009 LONG WEEKEND LLC. All rights reserved.
//

#import "Tag.h"

NSString * const kTagErrorDomain           = @"kTagErrorDomain";
NSString * const LWETagDidSave             = @"kTagDidSave";
NSUInteger const kAllBuriedAndHiddenError  = 999;
NSUInteger const kLWETagUnknownError       = 998;
NSInteger const kLWEUninitializedTagId     = -1;
NSInteger const kLWEUninitializedCardCount = -1;
NSInteger const kLWEUnseenCardLevel        = 0;
NSInteger const kLWELearnedCardLevel       = 5;

static NSString *sLWEBuiltInCatalogLanguageOverride = nil;

@interface Tag ()
- (NSNumber *)_cardIdCarriedFromRetiredNounSession:(BOOL *)resetIndex;
@end

BOOL LWEBuiltInCatalogUsesJapanese(void)
{
#if defined(LWE_JFLASH)
  NSString *language = sLWEBuiltInCatalogLanguageOverride;
  if (language == nil)
  {
    language = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
  }
  return [language hasPrefix:@"ja"];
#else
  return NO;
#endif
}

void LWESetBuiltInCatalogLanguageOverride(NSString *languageOrNil)
{
  if (sLWEBuiltInCatalogLanguageOverride != languageOrNil)
  {
    [sLWEBuiltInCatalogLanguageOverride release];
    sLWEBuiltInCatalogLanguageOverride = [languageOrNil copy];
  }
}

@implementation Tag

@synthesize tagId, tagName, tagEditable, tagDescription, tagNameJa, tagDescriptionJa, isFault = _isFault;
@synthesize cardCount, currentIndex, cardsByLevel, cardLevelCounts, flattenedCardIdArray;

#pragma mark - Class Plumbing

- (id) init
{
  if ((self = [super init]))
  {
    _isFault = YES;
    self.tagId = kLWEUninitializedTagId;
    cardCount = kLWEUninitializedCardCount; // don't use setter here, has special behavior of updating DB 
  }
	return self;
}

- (void) dealloc
{
  if (self.isFault == NO)
  {
    // When we hydrate a card, we also add an observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  }
  [tagName release];
  [tagDescription release];
  [tagNameJa release];
  [tagDescriptionJa release];
  [flattenedCardIdArray release];
  [cardLevelCounts release];
  [cardsByLevel release];
	[super dealloc];
}

#pragma mark - NSObject Protocol

- (BOOL)isEqual:(id)object
{
  if ([object isKindOfClass:[self class]])
  {
    Tag *anotherTag = (Tag *)object;
    return (anotherTag.tagId == self.tagId);
  }
  return NO;
}

#pragma mark - Factory Helpers

+ (Tag *) starredWordsTag
{
  return [TagPeer retrieveTagById:STARRED_TAG_ID];
}

+ (Tag *) blankTagWithId:(NSInteger)tagId
{
  Tag *tag = [[[[self class] alloc] init] autorelease];
  tag.tagId = tagId;
  return tag;
}

#pragma mark - Getters & Setters

/**
 * Gets the group for this tag and returns the id
 */
- (NSInteger) groupId
{
  // TODO: all of this makes the assumption that tags are 1-1 with groups.  that was not the 
  // original design, but are we moving that direction?  MMA - Oct 19 2011
  return [GroupPeer parentGroupIdOfTag:self];
}

- (NSString *)displayName
{
#if defined(LWE_JFLASH)
  // Only a stored Japanese column is shown, and only for a system row.  Editable
  // sets (including one the user renamed) keep the name in tag_name.  Long Weekend
  // Favorites is editable; its Japanese name is shown until a save clears the column.
  if (LWEBuiltInCatalogUsesJapanese() && [self.tagNameJa length] > 0)
  {
    return self.tagNameJa;
  }
#endif
  return self.tagName;
}

- (NSString *)displayDescription
{
#if defined(LWE_JFLASH)
  if (LWEBuiltInCatalogUsesJapanese() && [self.tagDescriptionJa length] > 0)
  {
    return self.tagDescriptionJa;
  }
#endif
  return self.tagDescription;
}

- (BOOL) isEditable
{
  // "My Starred Words" (STARRED_TAG_ID) is a system set in both apps: it can't be renamed, deleted or
  // have its word list edited, whatever its row says (cFlash's bundled cFlash.db has editable = 1 for it,
  // jFlash's has 0). Code that treats it as a user set checks tagId == STARRED_TAG_ID explicitly.
  return (self.tagEditable == 1 && self.tagId != STARRED_TAG_ID);
}

- (NSInteger) seenCardCount
{
  return (self.cardCount - [[self.cardLevelCounts objectAtIndex:kLWEUnseenCardLevel] integerValue]);
}

- (NSInteger) cardCount
{
  return cardCount;
}

//! Setter for cardCount; updates the database cache automatically
- (void) setCardCount:(NSInteger)newCount
{
  NSInteger currentCount = cardCount;
  if (currentCount == newCount)
  {
    // do nothing if its the same
    return;
  }
  
  // update the count in the database if not first load (e.g. cardCount = -1)
  if (currentCount >= 0)
  {
    [TagPeer setCardCount:newCount forTag:self];
  }
  
  // set the variable to the new count - do this directly to bypass this setter!
  cardCount = newCount; 
}


#pragma mark - Prep Card Ids, Deal with Card Ids

//! Create a cache of the number of Card objects in each level
- (void) recacheCardCountForEachLevel
{
  LWE_ASSERT_EXC(([self.cardsByLevel count] == 6),@"Must be six card level arrays");

  NSNumber *count = nil;
  NSInteger totalCount = 0;
  NSMutableArray *cardLevelCountsTmp = [NSMutableArray array];
  for (NSInteger i = 0; i < 6; i++)
  {
    count = [NSNumber numberWithInt:[[self.cardsByLevel objectAtIndex:i] count]];
    [cardLevelCountsTmp addObject:count];
    totalCount = totalCount + [count intValue];
  }
  self.cardLevelCounts = cardLevelCountsTmp;
  self.cardCount = totalCount;
}

//! Keys of the saved-session plist (ids.plist)
static NSString * const kLWEFrozenTagIdKey  = @"tagId";
static NSString * const kLWEFrozenUserIdKey = @"userId";
static NSString * const kLWEFrozenLevelsKey = @"levels";

//! Deletes the saved-session plist if there is one (LWEFile +deleteFile: logs an error when there isn't)
static void LWEDeleteFrozenCardIds(void)
{
  NSString *path = [LWEFile createCachesPathWithFilename:@"ids.plist"];
  if ([[NSFileManager defaultManager] fileExistsAtPath:path])
  {
    [LWEFile deleteFile:path];
  }
}

/**
 * Unarchive plist file containing the user's last session data.
 * The plist is a dictionary: the tag and user it was saved for, and six arrays (one per level) of
 * card ids (NSNumbers), the same way CardPeer +retrieveCardsSortedByLevelForTag: returns them.
 * Returns nil if there is no plist, it is not in that shape, it was saved for another tag or user,
 * or its card total doesn't match this tag's card count. Does not delete the file (-populateCardIds does).
 */
- (NSMutableArray *) thawCardIds
{
  NSString *path = [LWEFile createCachesPathWithFilename:@"ids.plist"];
  NSDictionary *frozen = [NSDictionary dictionaryWithContentsOfFile:path];
  if (frozen == nil)
  {
    return nil;   // no file, or an old-format (array) file
  }
  
  id frozenTagId = [frozen objectForKey:kLWEFrozenTagIdKey];
  id frozenUserId = [frozen objectForKey:kLWEFrozenUserIdKey];
  NSArray *frozenLevels = [frozen objectForKey:kLWEFrozenLevelsKey];
  NSInteger userId = [[NSUserDefaults standardUserDefaults] integerForKey:APP_USER];
  if ([frozenTagId isKindOfClass:[NSNumber class]] == NO || [frozenTagId integerValue] != self.tagId ||
      [frozenUserId isKindOfClass:[NSNumber class]] == NO || [frozenUserId integerValue] != userId ||
      [frozenLevels isKindOfClass:[NSArray class]] == NO || [frozenLevels count] != 6)
  {
    return nil;
  }
  
  NSInteger total = 0;
  NSMutableArray *cardsByLevelTmp = [NSMutableArray arrayWithCapacity:6];
  for (id frozenLevel in frozenLevels)
  {
    if ([frozenLevel isKindOfClass:[NSArray class]] == NO)
    {
      return nil;
    }
    NSMutableArray *levelCards = [NSMutableArray arrayWithCapacity:[frozenLevel count]];
    for (id cardId in frozenLevel)
    {
      if ([cardId isKindOfClass:[NSNumber class]] == NO)
      {
        return nil;
      }
      [levelCards addObject:cardId];
    }
    total += [levelCards count];
    [cardsByLevelTmp addObject:levelCards];
  }
  
  // The tag's cached card count (from the tags table). An uninitialized count can't be checked,
  // so don't trust the file then either.
  if (self.cardCount < 0 || total != self.cardCount)
  {
    return nil;
  }
  return cardsByLevelTmp;
}


/**
 * Archive current session data to a plist so we can re-start at same place in next session.
 * cardsByLevel holds card-id NSNumbers (see -thawCardIds). A Card left in the array is written
 * by its id as well.
 */
- (void) freezeCardIds
{
  NSString *path = [LWEFile createCachesPathWithFilename:@"ids.plist"];
  if ([self.cardsByLevel count] != 6)
  {
    // Nothing loaded to save; make sure no older session is left behind either
    LWEDeleteFrozenCardIds();
    return;
  }
  
  NSMutableArray *frozenLevels = [NSMutableArray arrayWithCapacity:6];
  for (NSArray *levelCards in self.cardsByLevel)
  {
    NSMutableArray *cardIds = [NSMutableArray arrayWithCapacity:[levelCards count]];
    for (id entry in levelCards)
    {
      if ([entry isKindOfClass:[NSNumber class]])
      {
        [cardIds addObject:entry];
      }
      else
      {
        [cardIds addObject:[NSNumber numberWithInteger:[(Card *)entry cardId]]];
      }
    }
    [frozenLevels addObject:cardIds];
  }
  NSInteger userId = [[NSUserDefaults standardUserDefaults] integerForKey:APP_USER];
  NSDictionary *frozen = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInteger:self.tagId], kLWEFrozenTagIdKey,
                          [NSNumber numberWithInteger:userId], kLWEFrozenUserIdKey,
                          frozenLevels, kLWEFrozenLevelsKey,
                          nil];
  [frozen writeToFile:path atomically:YES];
}


/**
 * Card id at the saved browse index when this load is Common Nouns Full Set and
 * the session file still belongs to the removed Nouns list (tag 133) or Nouns
 * 02–13. Those ids are not this set. The caller looks the card up in Common
 * Nouns, and keeps the index only when the card is in it.
 * Returns nil when there is nothing to carry.
 */
- (NSNumber *)_cardIdCarriedFromRetiredNounSession:(BOOL *)resetIndex
{
  if (resetIndex != NULL)
  {
    *resetIndex = NO;
  }
#if !defined(LWE_JFLASH)
  return nil;
#else
  // Common Nouns Full Set (tag 2346) is what an old Nouns session opens now.
  static NSInteger const kLWECommonNounsFullSetTagId = 2346;
  static NSInteger const kLWERetiredGiantNounsTagId = 133;
  static NSInteger const kLWERetiredNounsTagMin = 620;
  static NSInteger const kLWERetiredNounsTagMax = 631;
  if (self.tagId != kLWECommonNounsFullSetTagId)
  {
    return nil;
  }
  NSString *path = [LWEFile createCachesPathWithFilename:@"ids.plist"];
  NSDictionary *frozen = [NSDictionary dictionaryWithContentsOfFile:path];
  if (frozen == nil)
  {
    return nil;
  }
  id frozenTagId = [frozen objectForKey:kLWEFrozenTagIdKey];
  id frozenUserId = [frozen objectForKey:kLWEFrozenUserIdKey];
  NSArray *frozenLevels = [frozen objectForKey:kLWEFrozenLevelsKey];
  NSInteger userId = [[NSUserDefaults standardUserDefaults] integerForKey:APP_USER];
  if ([frozenTagId isKindOfClass:[NSNumber class]] == NO ||
      [frozenUserId isKindOfClass:[NSNumber class]] == NO ||
      [frozenUserId integerValue] != userId ||
      [frozenLevels isKindOfClass:[NSArray class]] == NO ||
      [frozenLevels count] != 6)
  {
    return nil;
  }
  NSInteger retiredTag = [frozenTagId integerValue];
  BOOL retiredSlice = (retiredTag >= kLWERetiredNounsTagMin && retiredTag <= kLWERetiredNounsTagMax);
  if (retiredTag != kLWERetiredGiantNounsTagId && retiredSlice == NO)
  {
    return nil;
  }
  // The saved index is a position in the old list.  It is not a position in
  // Common Nouns, so the caller replaces it after this read.
  if (resetIndex != NULL)
  {
    *resetIndex = YES;
  }
  NSMutableArray *cardIds = [NSMutableArray array];
  for (id frozenLevel in frozenLevels)
  {
    if ([frozenLevel isKindOfClass:[NSArray class]] == NO)
    {
      return nil;
    }
    for (id cardId in (NSArray *)frozenLevel)
    {
      if ([cardId isKindOfClass:[NSNumber class]] == NO)
      {
        return nil;
      }
      [cardIds addObject:cardId];
    }
  }
  // Browse walks the ids sorted by card id, the same order -flattenCardArrays uses.
  [cardIds sortUsingSelector:@selector(compare:)];
  NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"current_index"];
  if (index < 0 || index >= (NSInteger)[cardIds count])
  {
    return nil;
  }
  return [cardIds objectAtIndex:index];
#endif
}

/** Executed when loading a new set on app load */
- (void) populateCardIds
{
  // Read a removed Nouns session before the file is deleted. It does not match
  // Common Nouns Full Set, so -thawCardIds will not use it as this set's cards.
  // resetIndex means the saved browse index belonged to that old list.
  BOOL resetIndex = NO;
  NSNumber *carriedCardId = [self _cardIdCarriedFromRetiredNounSession:&resetIndex];
  NSMutableArray *tmpCardIdsArray = [self thawCardIds];
  // The saved session is good for one load only: delete it whether it matched this tag or not,
  // so a leftover file can never be loaded into a later set.
  LWEDeleteFrozenCardIds();
  if (tmpCardIdsArray == nil)
  {
    // No usable saved session: get the card ids (and their levels) from the database
    tmpCardIdsArray = [CardPeer retrieveCardsSortedByLevelForTag:self];
  }
  
  self.cardsByLevel = tmpCardIdsArray;
  self.flattenedCardIdArray = [self flattenCardArrays];

  // populate the card level counts
	[self recacheCardCountForEachLevel];

  BOOL placed = NO;
  if (carriedCardId != nil)
  {
    NSUInteger index = [self.flattenedCardIdArray indexOfObject:carriedCardId];
    if (index != NSNotFound)
    {
      self.currentIndex = (NSInteger)index;
      // -activeTag applies current_index from settings after this load.
      [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)index forKey:@"current_index"];
      placed = YES;
    }
  }
  if (resetIndex && placed == NO)
  {
    self.currentIndex = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"current_index"];
  }
}

//! Concatenate cardId arrays for browse mode
- (NSMutableArray *)flattenCardArrays
{
  NSMutableArray *allCards = [NSMutableArray arrayWithCapacity:self.cardCount];
  for (NSArray *cardsInLevel in self.cardsByLevel) 
  {
    [allCards addObjectsFromArray:cardsInLevel];
  }
  [allCards sortUsingSelector:@selector(compare:)];
  return allCards;
}


/**
 * Update level counts cache - (kept in memory how many cards are in each level)
 */
- (void) moveCard:(Card*)card toLevel:(NSInteger) nextLevel
{
  LWE_ASSERT_EXC(([self.cardsByLevel count] == 6),@"Must be 6 arrays in cardIds");
  
  // update the cardIds if necessary
  if (nextLevel != card.levelId)
  {
    NSMutableArray *thisLevelCards = [self.cardsByLevel objectAtIndex:card.levelId];
    NSMutableArray *nextLevelCards = [self.cardsByLevel objectAtIndex:nextLevel];
    
    NSInteger countBeforeRemove = [thisLevelCards count];
    NSInteger countBeforeAdd = [nextLevelCards count];

    // Now do the remove. Levels store card ids, matched the same way Card -isEqual: matches.
    NSNumber *cardId = [NSNumber numberWithInteger:card.cardId];
    LWE_ASSERT_EXC([thisLevelCards containsObject:cardId], @"Can't remove the card, it's no longer there!");
    [thisLevelCards removeObject:cardId];
    NSInteger countAfterRemove = [thisLevelCards count];

    // Only do the add if remove was successful
    if (countBeforeRemove == (countAfterRemove + 1))
    {
      [nextLevelCards addObject:cardId];
      
      // And now update its level ID so it stays accurate
      card.levelId = nextLevel;
      
      // Now confirm the add
      NSInteger countAfterAdd = [[self.cardsByLevel objectAtIndex:nextLevel] count];
      LWE_ASSERT_EXC(((countAfterAdd-1) == countBeforeAdd),@"The number after add (%d) should be 1 more than the count before add (%d)",countAfterAdd,countBeforeAdd);

      [self recacheCardCountForEachLevel];
    }
  }
}

#pragma mark - Add & Remove Cards From the Tag

/**
 * Removes card from tag's memory arrays so they are out of the set
 */
- (void) removeCardFromActiveSet:(Card *)card
{
  NSNumber *cardId = [NSNumber numberWithInteger:card.cardId];
  NSMutableArray *cardLevel = [self.cardsByLevel objectAtIndex:card.levelId];
  [cardLevel removeObject:cardId];
  [self.flattenedCardIdArray removeObject:cardId];
  [self recacheCardCountForEachLevel];
}

/**
 * Add card to tag's memory arrays
 */
- (void) addCardToActiveSet:(Card *)card
{
  NSNumber *cardId = [NSNumber numberWithInteger:card.cardId];
  NSMutableArray *cardLevel = [self.cardsByLevel objectAtIndex:card.levelId];
  [cardLevel addObject:cardId];
  [self.flattenedCardIdArray addObject:cardId];
  [self recacheCardCountForEachLevel];
}

#pragma mark - Database Related

//! Saves the tag to the DB. WARNING: this only updates the tags basic info, creation is handled in TagPeer for historical reasons.
// TODO: Should likely be refactored to work as a save method instead of TagPeer creation.
- (void) save
{
  LWE_ASSERT_EXC((self.tagId != kLWEUninitializedTagId),@"The tag must already exist to be saved, use createTagNamed in TagPeer to create a tag");
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  BOOL success = NO;
#if defined(LWE_JFLASH)
  if ([self isEditable])
  {
    // Saving a name the user typed drops the shipped Japanese columns, so the
    // set keeps the name they wrote when the app is in Japanese.
    success = [db.dao executeUpdate:@"UPDATE tags SET tag_name = ?, description = ?, tag_name_ja = NULL, description_ja = NULL WHERE tag_id = ?",self.tagName,self.tagDescription,[NSNumber numberWithInt:self.tagId]];
    if (success)
    {
      self.tagNameJa = nil;
      self.tagDescriptionJa = nil;
    }
  }
  else
  {
    success = [db.dao executeUpdate:@"UPDATE tags SET tag_name = ?, description = ? WHERE tag_id = ?",self.tagName,self.tagDescription,[NSNumber numberWithInt:self.tagId]];
  }
#else
  success = [db.dao executeUpdate:@"UPDATE tags SET tag_name = ?, description = ? WHERE tag_id = ?",self.tagName,self.tagDescription,[NSNumber numberWithInt:self.tagId]];
#endif
  if (success)
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:LWETagDidSave object:self];
  }
}

//! Refreshes self from the DB if a didSave notification is called
- (void)tagDidSave:(NSNotification *)notification
{
  if ([self isEqual:notification.object] && (self.isFault == NO)) // we only care if it's us & this isn't a faulted entry
  {
    [self hydrate];
  }
}

//! gets a tags info from the db and hydrates
- (void) hydrate
{
  LWE_ASSERT_EXC(self.tagId != kLWEUninitializedTagId, @"Hydrate called with uninitialized tag ID");
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
	FMResultSet *rs = [db.dao executeQuery:@"SELECT * FROM tags WHERE tag_id = ? LIMIT 1",[NSNumber numberWithInt:self.tagId]];
	while ([rs next])
  {
		[self hydrateWithResultSet:rs];
	}
	[rs close];
}

//! takes a sqlite result set and populates the properties of Tag
- (void) hydrateWithResultSet: (FMResultSet *) rs
{
  self.tagId = [rs intForColumn:@"tag_id"];
  self.tagDescription = [rs stringForColumn:@"description"];
  self.tagName = [rs stringForColumn:@"tag_name"];
  self.tagEditable = [rs intForColumn:@"editable"];
  self.cardCount = [rs intForColumn:@"count"];
#if defined(LWE_JFLASH)
  self.tagNameJa = [rs stringForColumn:@"tag_name_ja"];
  self.tagDescriptionJa = [rs stringForColumn:@"description_ja"];
#endif
  
  // We only care about getting new updates on data if we had data to begin with.
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tagDidSave:) name:LWETagDidSave object:nil];
  _isFault = NO;
}

#pragma mark - Description

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@:\n\
          Editable: %d\n\
          Name: %@\n\
          Description: %@\n\
          Tag Id: %d\n\
          Current Index: %d\n\
          CardIds: %@",
          NSStringFromClass([self class]),
          [self tagEditable],
          [self tagName],
          [self tagDescription],
          [self tagId],
          [self currentIndex],
          [self cardsByLevel]];
}


@end