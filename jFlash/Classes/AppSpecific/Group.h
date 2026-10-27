//
//  Group.h
//  jFlash
//
//  Created by Mark Makdad on 10/10/09.
//  Copyright 2009 LONG WEEKEND INC.. All rights reserved.
//

#import "FMResultSet.h"

extern NSInteger const kLWEUninitializedGroupId;

@interface Group : NSObject
{
  NSInteger childGroupCount;
}

- (void) hydrate:(FMResultSet*)rs;
- (NSArray*) childTags;

//! Returns YES if this group is the top level group in a hierarchy.
- (BOOL) isTopLevelGroup;

@property (retain) NSString *groupName;   //! Stored name.  Browse sort uses this.
@property (retain) NSString *groupNameJa; //! Japanese name for a built-in group.  Nil when there is none.

//! Name to show.  Japanese when the app language is Japanese and groupNameJa is set.
- (NSString *)displayName;
@property NSInteger groupId;              //! groupId of the parent Group
@property NSInteger ownerId;
@property NSInteger tagCount;             //! cached number of Tag items in the Group
@property NSInteger recommended;          //! Is a recommended Group?
@property NSInteger childGroupCount;      //! cached number of children Group objects
@property (retain) NSString *groupDescription;

@end
