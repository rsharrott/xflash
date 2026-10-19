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

@implementation Tag

@synthesize tagId, tagName, tagEditable, tagDescription, isFault = _isFault;
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

- (BOOL) isEditable
{
  return (self.tagEditable == 1);
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
 * card ids. The ids come back as blank cards, the same way CardPeer +retrieveCardsSortedByLevelForTag:
 * returns them.
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
      [levelCards addObject:[CardPeer blankCardWithId:[cardId integerValue]]];
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
 * cardsByLevel holds Card objects, which a plist cannot store, so write their ids, along with the
 * tag and user they belong to (see -thawCardIds).
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
    for (Card *card in levelCards)
    {
      [cardIds addObject:[NSNumber numberWithInteger:card.cardId]];
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


/** Executed when loading a new set on app load */
- (void) populateCardIds
{
  NSMutableArray *tmpCardIdsArray = [self thawCardIds];
  // The saved session is good for one load only: delete it whether it matched this tag or not,
  // so a leftover file can never be loaded into a later set.
  LWEDeleteFrozenCardIds();
  if (tmpCardIdsArray == nil)
  {
    // No usable saved session: get the cards (and their levels) from the database
    tmpCardIdsArray = [CardPeer retrieveCardsSortedByLevelForTag:self];
  }
  
  self.cardsByLevel = tmpCardIdsArray;
  self.flattenedCardIdArray = [self flattenCardArrays];

  // populate the card level counts
	[self recacheCardCountForEachLevel];
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

    // Now do the remove
    LWE_ASSERT_EXC([thisLevelCards containsObject:card], @"Can't remove the card, it's no longer there!");
    [thisLevelCards removeObject:card];
    NSInteger countAfterRemove = [thisLevelCards count];

    // Only do the add if remove was successful
    if (countBeforeRemove == (countAfterRemove + 1))
    {
      [nextLevelCards addObject:card];
      
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
  NSMutableArray *cardLevel = [self.cardsByLevel objectAtIndex:card.levelId];
  [cardLevel removeObject:card];
  [self.flattenedCardIdArray removeObject:card];
  [self recacheCardCountForEachLevel];
}

/**
 * Add card to tag's memory arrays
 */
- (void) addCardToActiveSet:(Card *)card
{
  NSMutableArray *cardLevel = [self.cardsByLevel objectAtIndex:card.levelId];
  [cardLevel addObject:card];
  [self.flattenedCardIdArray addObject:card];
  [self recacheCardCountForEachLevel];
}

#pragma mark - Database Related

//! Saves the tag to the DB. WARNING: this only updates the tags basic info, creation is handled in TagPeer for historical reasons.
// TODO: Should likely be refactored to work as a save method instead of TagPeer creation.
- (void) save
{
  LWE_ASSERT_EXC((self.tagId != kLWEUninitializedTagId),@"The tag must already exist to be saved, use createTagNamed in TagPeer to create a tag");
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  BOOL success = [db.dao executeUpdate:@"UPDATE tags SET tag_name = ?, description = ? WHERE tag_id = ?",self.tagName,self.tagDescription,[NSNumber numberWithInt:self.tagId]];
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