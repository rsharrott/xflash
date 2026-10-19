//
//  TagPeer.m
//  jFlash
//
//  Created by paul on 5/6/09.
//  Copyright 2009 Long Weekend LLC. All rights reserved.
//

#import "TagPeer.h"

NSString * const kTagPeerErrorDomain         = @"kTagPeerErrorDomain";
NSUInteger const kRemoveLastCardOnATagError  = 999;

NSString * const LWETagContentDidChange = @"LWETagContentDidChange";
NSString * const LWETagContentDidChangeTypeKey = @"LWETagContentDidChangeTypeKey";
NSString * const LWETagContentDidChangeCardKey = @"LWETagContentDidChangeCardKey";
NSString * const LWETagContentCardAdded = @"LWETagContentCardAdded";
NSString * const LWETagContentCardRemoved = @"LWETagContentCardRemoved";

@interface TagPeer ()
+ (NSArray *) _tagListWithResultSet:(FMResultSet *)rs;
+ (Tag *) _tagWithResultSet:(FMResultSet *)rs;
@end

//! Handles retrieval, creation, deletion, and updating of Tag objects in database
@implementation TagPeer

#pragma mark - Caching Methods

/** Recaches card counts for user tags */
+ (void) recacheCountsForUserTags
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  
  FMResultSet *userTagsRS = [db executeQuery:@"SELECT tag_id FROM tags WHERE editable = 1"];
  while ([userTagsRS next])
  {
    // Get the number of cards
    NSInteger tagId = [userTagsRS intForColumn:@"tag_id"];
    FMResultSet *cardsInTagRS = [db.dao executeQuery:@"SELECT card_id FROM card_tag_link WHERE tag_id = ?",[NSNumber numberWithInt:tagId]];
    
    NSInteger numCards = 0;
    while ([cardsInTagRS next])
    {
      numCards = numCards + 1;
    }
    [cardsInTagRS close];
    
    // Now do the update
    Tag *tmpTag = [[Tag alloc] init]; // encapsulation is a bitch but one we should heed
    tmpTag.tagId = tagId;
    [TagPeer setCardCount:numCards forTag:tmpTag];
    [tmpTag release];
    LWE_LOG(@"tag id %d has %d cards",tagId,numCards);
  }
  [userTagsRS close];
}

+ (void) setCardCount:(NSInteger)newCount forTag:(Tag*)tag
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  [db.dao executeUpdate:@"UPDATE tags SET count = ? WHERE tag_id = ?",[NSNumber numberWithInt:newCount],[NSNumber numberWithInt:tag.tagId]];
}

#pragma mark - Membership Methods

/**
 * \brief   Removes cardId from Tag indicated by parameter tagId
 * \details This method will also check regarding the last card on the active set. 
 *          and automatically remove that card from the active set card cache.
 *          Note that this method DOES update the tag count cache on the tags table.
 */
+ (BOOL)cancelMembership:(Card*)card fromTag:(Tag*)tag error:(NSError **)theError
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  
  // First check whether the removed card is in the active tag.
  // if the tagId supplied is the active card, check for last card cause we dont
  // want the last card being removed from a tag. 
  CurrentState *currentState = [CurrentState sharedCurrentState];
  if ([tag isEqual:currentState.activeTag])
  {
    LWE_LOG(@"Editing current set tags");

    FMResultSet *rs = [db.dao executeQuery:@"SELECT count(card_id) AS total_card FROM card_tag_link WHERE tag_id = ?",[NSNumber numberWithInt:tag.tagId]];
    NSInteger totalCard = 0;
    while ([rs next])
    {
      totalCard = [rs intForColumn:@"total_card"];
    }
    
    if (totalCard <= 1)
    {
      LWE_LOG(@"Last card in set");
      //this is the last card, abort!
      //Construct the error object to be returned back to its caller.
      NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                NSLocalizedString(@"This set only contains the card you are currently studying.  To delete a set entirely, please change to a different set first.", @"AddTagViewController.AlertViewLastCardMessage"), NSLocalizedDescriptionKey,
                                nil];
      
      if (theError != NULL)
      {
        *theError = [NSError errorWithDomain:kTagPeerErrorDomain code:kRemoveLastCardOnATagError userInfo:userInfo];
      }
      return NO;
    }
  }

  // Now execute the deletion from card_tag_link
  [db.dao executeUpdate:@"DELETE FROM card_tag_link WHERE card_id = ? AND tag_id = ?",[NSNumber numberWithInt:card.cardId],[NSNumber numberWithInt:tag.tagId]];

  // Only update this stuff if not the active set
  if ([tag isEqual:currentState.activeTag] == NO)
  {
    // Update the tag's card count cache
    [db.dao executeUpdate:@"UPDATE tags SET count = (count - 1) WHERE tag_id = ?",[NSNumber numberWithInt:tag.tagId]];
    
    if (db.dao.hadError)
    {
      LWE_LOG(@"Err %d: %@", [db.dao lastErrorCode], [db.dao lastErrorMessage]);
      NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                db.dao.lastErrorMessage,NSLocalizedDescriptionKey,nil];
      
      //put the error information and send it back to whoever calls this function.
      if (theError != NULL)
      {
        *theError = [NSError errorWithDomain:kTagPeerErrorDomain code:db.dao.lastErrorCode userInfo:userInfo];
      }
      return NO;
    }
  }
  
  // Finally, send a system-wide notification that this tag changed. Interested objects can listen.
  NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            LWETagContentCardRemoved,LWETagContentDidChangeTypeKey,
                            card,LWETagContentDidChangeCardKey,
                            nil];
  [[NSNotificationCenter defaultCenter] postNotificationName:LWETagContentDidChange
                                                      object:tag
                                                    userInfo:userInfo];
  return YES;
}

//! Checks if a passed tagId/cardId are matched
+ (BOOL) card:(Card*)card isMemberOfTag:(Tag*)tag
{
  BOOL returnVal = NO;
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = [db.dao executeQuery:@"SELECT * FROM system_card_tag_link WHERE card_id = ? AND tag_id = ?",[NSNumber numberWithInt:card.cardId],[NSNumber numberWithInt:tag.tagId]];
	while ([rs next])
  {
    returnVal = YES;
	}
	[rs close];
  
  // Now check the user sets if we didn't find it in the system
  if (returnVal == NO)
  {
    rs = [db.dao executeQuery:@"SELECT * FROM card_tag_link WHERE card_id = ? AND tag_id = ?",[NSNumber numberWithInt:card.cardId],[NSNumber numberWithInt:tag.tagId]];
    while ([rs next])
    {
      // Older jFlash Users still have the out of date system tags in their card_tag_link table
      // We already checked the real system table, so if this is a user tag, keep it (ignore the system tags)
      Tag* tag = [Tag blankTagWithId:[rs intForColumn:@"tag_id"]];
      [tag hydrate];
      // user tag is defined as editable or "My Starred Words" which is tag 0
      if (tag.tagEditable == 1 || tag.tagId == 0)
      {
        returnVal = YES;
      }
    }
  }
	[rs close];
  return returnVal;
}

//! Returns an array of tag Ids this card is a member of
+ (NSArray *) faultedTagsForCard:(Card *)card
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  NSMutableSet *membershipListSet = [NSMutableSet set];
  NSInteger tmpTagId = 0;
	FMResultSet *rs = [db.dao executeQuery:@"SELECT t.tag_id AS tag_id FROM tags t, card_tag_link c WHERE t.tag_id = c.tag_id AND c.card_id = ?",[NSNumber numberWithInt:card.cardId]];
	while ([rs next])
  {
    tmpTagId = [rs intForColumn:@"tag_id"];
    [membershipListSet addObject:[Tag blankTagWithId:tmpTagId]];
	}
	[rs close];
  
  // Include the system sets, the NSMutableSet will handle removing duplicates for our legacy users
  rs = [db.dao executeQuery:@"SELECT t.tag_id AS tag_id FROM tags t, system_card_tag_link c WHERE t.tag_id = c.tag_id AND c.card_id = ?",[NSNumber numberWithInt:card.cardId]];
	while ([rs next])
  {
    tmpTagId = [rs intForColumn:@"tag_id"];
    [membershipListSet addObject:[Tag blankTagWithId:tmpTagId]];
	}
	[rs close];
  
  return [membershipListSet allObjects];
}



/**
 * Subscribes a Card to a given Tag based on parameter IDs
 * Note that this method DOES NOT update the tag count cache on the tags table
 */
+ (BOOL) subscribeCard:(Card*)card toTag:(Tag*)tag
{
  // Quick return on bad input
  if (tag == nil || card == nil || card.cardId <= 0)
  {
    return NO;
  }
  
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];

  // Insert tag link & update its count
  [db.dao executeUpdate:@"INSERT INTO card_tag_link (card_id,tag_id) VALUES (?,?)",[NSNumber numberWithInt:card.cardId],[NSNumber numberWithInt:tag.tagId]];
  [db.dao executeUpdate:@"UPDATE tags SET count = (count + 1) WHERE tag_id = ?",[NSNumber numberWithInt:tag.tagId]];

  if (db.dao.hadError)
  {
    LWE_LOG(@"Err %d: %@", db.dao.lastErrorCode, db.dao.lastErrorMessage);
    return NO;
  }
  
  // Finally, send a system-wide notification that this tag changed. Interested objects can listen.
  NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            LWETagContentCardAdded,LWETagContentDidChangeTypeKey,
                            card,LWETagContentDidChangeCardKey,
                            nil];
  [[NSNotificationCenter defaultCenter] postNotificationName:LWETagContentDidChange
                                                      object:tag
                                                    userInfo:userInfo];
  return YES;
}

#pragma mark - Private Methods

+ (NSArray *) _tagListWithResultSet:(FMResultSet *)rs
{
	NSMutableArray *tags = [NSMutableArray array];
	while ([rs next])
  {
		Tag *tmpTag = [[Tag alloc] init];
		[tmpTag hydrateWithResultSet:rs];
		[tags addObject:tmpTag];
		[tmpTag release];
	}
	[rs close];
	return (NSArray*)tags;
}

+ (Tag *) _tagWithResultSet:(FMResultSet *)rs
{
  // TODO: it would make more sense to return NIL if there were no tag, not an empty tag object.
  Tag *tmpTag = [[[Tag alloc] init] autorelease];
	while ([rs next])
  {
		[tmpTag hydrateWithResultSet:rs];
	}
	[rs close];
	return tmpTag;
}

#pragma mark - Convenience Methods to Abstract SQL

//! Gets system Tag objects as array
+ (NSArray *) retrieveSysTagList
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
	FMResultSet *rs = [db executeQuery:@"SELECT *, UPPER(tag_name) as utag_name FROM tags WHERE editable = 0 ORDER BY utag_name ASC"];
  return [TagPeer _tagListWithResultSet:rs];
}

//! Gets user Tag objects as array
+ (NSArray *) retrieveUserTagList
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
	FMResultSet *rs = [db executeQuery:@"SELECT *, UPPER(tag_name) as utag_name FROM tags WHERE editable = 1 OR tag_id = 0 ORDER BY utag_name ASC"];
  return [TagPeer _tagListWithResultSet:rs];
}

//! Gets system Tag objects that have card in them - as array
+ (NSArray *) retrieveSysTagListContainingCard:(Card*)card
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = [db.dao executeQuery:@"SELECT *, UPPER(t.tag_name) as utag_name FROM system_card_tag_link l,tags t WHERE l.card_id = ? AND l.tag_id = t.tag_id AND t.editable = 0 ORDER BY utag_name ASC",[NSNumber numberWithInt:card.cardId]];
  return [TagPeer _tagListWithResultSet:rs];
}

//! Returns array of Tag objects based on Group membership
+ (NSArray *) retrieveTagListByGroupId:(NSInteger)groupId
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
	FMResultSet *rs = [db.dao executeQuery:@"SELECT * FROM tags t, group_tag_link l WHERE t.tag_id = l.tag_id AND l.group_id = ? ORDER BY t.tag_name ASC",[NSNumber numberWithInt:groupId]];
	return [TagPeer _tagListWithResultSet:rs];
}

//! Returns a Tag array containing any Tag with a title LIKE '%string%'
+ (NSArray *) retrieveTagListLike:(NSString*)string
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  // This generates "%string%"; we pass the parameter binding the string w/ the like % attached
  NSString *searchString = [NSString stringWithFormat:@"%%%@%%",string];
  FMResultSet *rs = [db.dao executeQuery:@"SELECT * FROM tags WHERE tag_name LIKE ? ORDER BY tag_name ASC",searchString];
	return [TagPeer _tagListWithResultSet:rs];
}

//! Gets a Tag by its id (PK)
+ (Tag *) retrieveTagById:(NSInteger)tagId
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = [db.dao executeQuery:@"SELECT * FROM tags WHERE tag_id = ? LIMIT 1",[NSNumber numberWithInt:tagId]];
  return [TagPeer _tagWithResultSet:rs];
}

//! Gets a Tag by its name
+ (Tag*) retrieveTagByName:(NSString*)tagName
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  FMResultSet *rs = [db.dao executeQuery:@"SELECT * FROM tags WHERE tag_name LIKE ? LIMIT 1",tagName];
  // Unlike -retrieveTagById: (whose callers expect an object), a name that isn't there gives nil,
  // not an empty Tag (tag_id 0 would look like My Starred Words).  Only tests call this today.
  Tag *tag = nil;
  if ([rs next])
  {
    tag = [[[Tag alloc] init] autorelease];
    [tag hydrateWithResultSet:rs];
  }
  [rs close];
  return tag;
}

#pragma mark - Create & Delete

//! adds a new tag to the database, returns new tag object, nil in case of error
+ (Tag *) createTagNamed:(NSString*)tagName inGroup:(Group*)owner
{
  return [[self class] createTagNamed:tagName inGroup:owner withDescription:@""];
}

//! Adds a new tag to the database, returns new tag object, nil if error
+ (Tag *) createTagNamed:(NSString*)tagName inGroup:(Group*)owner withDescription:(NSString*)description;
{
  LWE_ASSERT_EXC([tagName isKindOfClass:[NSString class]],@"You must pass a string as the tag name");
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  [db.dao executeUpdate:@"INSERT INTO tags (tag_name, description) VALUES (?,?)",tagName,description];
  
  NSInteger lastTagId = (NSInteger)db.dao.lastInsertRowId;
  Tag *createdTag = nil;
  if (db.dao.hadError == NO)
  {
    // Link it & then update the tag card count cache
    [db.dao executeUpdate:@"INSERT INTO group_tag_link (tag_id, group_id) VALUES (?,?)",[NSNumber numberWithInt:lastTagId],[NSNumber numberWithInt:owner.groupId]];
    [db.dao executeUpdate:@"UPDATE groups SET tag_count=(tag_count+1) WHERE group_id = ?",[NSNumber numberWithInt:owner.groupId]];
    createdTag = [TagPeer retrieveTagById:lastTagId];
  }
  return createdTag;
}

//! Deletes a tag and all Card links
+ (BOOL) deleteTag:(Tag*)tag
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  
  // First get owner id of a tag
  FMResultSet *rs = [db.dao executeQuery:@"SELECT group_id FROM group_tag_link WHERE tag_id = ?",[NSNumber numberWithInt:tag.tagId]];
  NSInteger groupId = 0;
	while ([rs next])
  {
    groupId = [rs intForColumn:@"group_id"];
	}
  [rs close];
  
  // Now do everything
  [db.dao beginTransaction];
  [db.dao executeUpdate:@"DELETE FROM card_tag_link WHERE tag_id = ?",[NSNumber numberWithInt:tag.tagId]];
  [db.dao executeUpdate:@"DELETE FROM tags WHERE tag_id = ?",[NSNumber numberWithInt:tag.tagId]];
  [db.dao executeUpdate:@"UPDATE groups SET tag_count = (tag_count-1) WHERE group_id = ?",[NSNumber numberWithInt:groupId]];
  [db.dao commit];
  
  if (db.dao.hadError)
  {
    LWE_LOG(@"Err %d: %@", db.dao.lastErrorCode, db.dao.lastErrorMessage);
    return NO;
  }
  return YES;
}

@end