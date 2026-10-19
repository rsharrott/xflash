//
//  StudySetViewController.h
//  jFlash
//
//  Created by Paul Chapman on 6/26/09.
//  Copyright 2009 LONG WEEKEND INC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Group.h"
#import "TagPeer.h"
#import "GroupPeer.h"

/**
 * VoiceOver value for a drawn Starred / Recommended row badge: localizedWord, or nil when the row's
 * title already contains the word (English or localized, case-insensitive), so "My Starred Words"
 * isn't read as "My Starred Words, Starred".  Inline in the header so the unit tests can use it
 * (the test bundle compiles its own copies of the code under test).
 */
static inline NSString *LWEStudySetBadgeAccessibilityValue(NSString *title, NSString *englishWord, NSString *localizedWord)
{
  NSStringCompareOptions opts = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
  if (title && ((englishWord.length && [title rangeOfString:englishWord options:opts].location != NSNotFound) ||
                (localizedWord.length && [title rangeOfString:localizedWord options:opts].location != NSNotFound)))
  {
    return nil;
  }
  return localizedWord;
}

//! Sets the row's VoiceOver badge value, or clears it when hasBadge is NO (cells are reused)
static inline void LWEStudySetApplyBadgeAccessibility(UITableViewCell *cell, BOOL hasBadge, NSString *title, NSString *englishWord, NSString *localizedWord)
{
  cell.accessibilityValue = hasBadge ? LWEStudySetBadgeAccessibilityValue(title, englishWord, localizedWord) : nil;
}

@interface StudySetViewController : UITableViewController <UISearchBarDelegate>
{
  UIBarButtonItem *_addButton;
  UIButton *searchOverlayBtn;
  UIView *_searchOverlay;
	BOOL searching;
}

- (id) initWithGroup:(Group*)aGroup;
- (void) activateTag: (Tag*) tag;
- (IBAction)addStudySet:(id)sender;
- (void) reloadTableData;
- (void) reloadSubgroupData;
- (void) doDoneSearching;
- (void) hideSearchBar;

@property NSInteger selectedTagId;
@property (nonatomic, retain) IBOutlet UISearchBar *searchBar;

@property (nonatomic, retain) Group *group;
@property (nonatomic, retain) NSMutableArray *tagArray;
@property (nonatomic, retain) NSArray *subgroupArray;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;

@end