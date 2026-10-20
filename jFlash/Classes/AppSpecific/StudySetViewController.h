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

/**
 * Opaque nav bar for the Study Sets screens, in the theme's navBarFill / navTitleInk.  The table starts
 * under the bar (edgesForExtendedLayout = none), so the default transparent scroll-edge bar would show
 * the white window instead of the paper screen.  Autoreleased; same appearance for every bar state.
 */
static inline UINavigationBarAppearance *LWEStudySetNavigationBarAppearance(UIColor *fill, UIColor *titleInk, UIColor *shadow)
{
  UINavigationBarAppearance *appearance = [[[UINavigationBarAppearance alloc] init] autorelease];
  [appearance configureWithOpaqueBackground];
  if (fill) appearance.backgroundColor = fill;
  if (shadow) appearance.shadowColor = shadow; // theme hairline instead of the darker system one
  if (titleInk)
  {
    NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithDictionary:appearance.titleTextAttributes];
    [attrs setObject:titleInk forKey:NSForegroundColorAttributeName];
    appearance.titleTextAttributes = attrs;
    NSMutableDictionary *largeAttrs = [NSMutableDictionary dictionaryWithDictionary:appearance.largeTitleTextAttributes];
    [largeAttrs setObject:titleInk forKey:NSForegroundColorAttributeName];
    appearance.largeTitleTextAttributes = largeAttrs;
  }
  return appearance;
}

//! Puts the appearance on this screen's navigation item (pushed group screens get their own), for every bar state
static inline void LWEStudySetApplyNavigationBarAppearance(UINavigationItem *item, UIColor *fill, UIColor *titleInk, UIColor *shadow)
{
  UINavigationBarAppearance *appearance = LWEStudySetNavigationBarAppearance(fill, titleInk, shadow);
  item.standardAppearance = appearance;
  item.scrollEdgeAppearance = appearance;
  item.compactAppearance = appearance;
  item.compactScrollEdgeAppearance = appearance;
}

/**
 * Extra bottom inset a list needs so its table-header search bar can still scroll off the top.  A short
 * list (a group with a few sets) is shorter than the screen plus the bar, and UIScrollView clamps the
 * offset to the content, so part of the "hidden" search bar stayed visible under the nav bar.
 * visibleHeight is the table's height inside its insets; 0 when the content is already tall enough.
 */
static inline CGFloat LWEStudySetSearchBarScrollRoom(CGFloat visibleHeight, CGFloat searchBarHeight, CGFloat contentHeight)
{
  CGFloat room = visibleHeight + searchBarHeight - contentHeight;
  return (room > 0) ? ceil(room) : 0;
}

@interface StudySetViewController : UITableViewController <UISearchBarDelegate>
{
  UIBarButtonItem *_addButton;
  UIButton *searchOverlayBtn;
  UIView *_searchOverlay;
	BOOL searching;
  CGFloat _searchBarScrollRoom; //!< bottom inset added by -updateSearchBarScrollRoom (see LWEStudySetSearchBarScrollRoom)
  BOOL _keepSearchBarHidden;    //!< -hideSearchBar ran and the user hasn't scrolled since: keep it off the top
}

- (id) initWithGroup:(Group*)aGroup;
- (void) activateTag: (Tag*) tag;
- (IBAction)addStudySet:(id)sender;
- (void) reloadTableData;
- (void) reloadSubgroupData;
- (void) doDoneSearching;
- (void) hideSearchBar;
- (void) updateSearchBarScrollRoom;

@property NSInteger selectedTagId;
@property (nonatomic, retain) IBOutlet UISearchBar *searchBar;

@property (nonatomic, retain) Group *group;
@property (nonatomic, retain) NSMutableArray *tagArray;
@property (nonatomic, retain) NSArray *subgroupArray;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;

@end