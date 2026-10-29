//
//  Group.m
//  jFlash
//
//  Created by Mark Makdad on 10/10/09.
//  Copyright 2009 LONG WEEKEND INC.. All rights reserved.
//

#import "Group.h"
#import "Tag.h"

NSInteger const kLWEUninitializedGroupId = -99;

#define LWE_TOP_LEVEL_GROUP_ID -1

//! Group contains Tag objects for display to the user in categorical hierarchies
@implementation Group
@synthesize groupId, groupName, groupNameJa, ownerId, tagCount, recommended, groupDescription;

- (id) init
{
  self = [super init];
  if (self)
  {
    self.groupId = kLWEUninitializedGroupId;
    self.tagCount = -1;
    self.childGroupCount = -1;
  }
  return self;
}

//!takes a sqlite result set and populates the properties of tag
- (void) hydrate: (FMResultSet*) rs
{
  self.groupId = [rs intForColumn:@"group_id"];
  self.groupName = [rs stringForColumn:@"group_name"];
  self.ownerId = [rs intForColumn:@"owner_id"];
  self.tagCount = [rs intForColumn:@"tag_count"];
  self.recommended = [rs intForColumn:@"recommended"];
  self.groupDescription = [rs stringForColumn:@"description"];
#if defined(LWE_JFLASH)
  self.groupNameJa = [rs stringForColumn:@"group_name_ja"];
#endif
}

- (NSString *)displayName
{
#if defined(LWE_JFLASH)
  if (LWEBuiltInCatalogUsesJapanese() && [self.groupNameJa length] > 0)
  {
    return self.groupNameJa;
  }
#endif
  return self.groupName;
}

- (BOOL) isTopLevelGroup
{
  return (self.ownerId == LWE_TOP_LEVEL_GROUP_ID);
}

//! Retrieves out a list of Tag objects based on this Group ID (direct children)
- (NSArray *) childTags
{
  if (self.groupId != kLWEUninitializedGroupId)
  {
    return [TagPeer retrieveTagListByGroupId:self.groupId];
  }
  else
  {
    return nil;
  }
}

- (void) setChildGroupCount:(NSInteger)newChildGroupCount
{
  childGroupCount = newChildGroupCount;
}

//! Gets a number of children group objects
- (NSInteger) childGroupCount
{
  if (childGroupCount < 0)
  {
    NSArray *groups = [GroupPeer retrieveGroupsByOwner:self.groupId];
    childGroupCount = [groups count];
  }
  return childGroupCount;
}

#pragma mark -

- (void) dealloc
{
  [groupName release];
  [groupNameJa release];
  [groupDescription release];
	[super dealloc];
}

@end
