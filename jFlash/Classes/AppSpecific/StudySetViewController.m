//
//  StudySetViewController.m
//  jFlash
//
//  Created by Paul Chapman on 6/26/09.
//  Copyright 2009 LONG WEEKEND INC. All rights reserved.
//

#import "StudySetViewController.h"
#import "StudySetWordsViewController.h"
#import "AddStudySetInputViewController.h"

#import "CustomCellBackgroundView.h"
#import "SettingsViewController.h"
#import "Constants.h"

enum Sections {
  kLWEGroupsSection = 0,
  kLWETagsSection = 1,
  NUM_SECTIONS
};

@interface StudySetViewController ()
- (void) _commonInit;
@end

//! Row icons are SF Symbols; ~28pt like the old art
static UIImage *LWEStudySetRowSymbol(NSString *name)
{
  UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
  return [[UIImage systemImageNamed:name withConfiguration:cfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

/**
 * The Starred Words set and recommended groups show the tag / folder symbol with a small star on it
 * (there is no starred tag or folder SF Symbol).  starCenter is where the star goes, as a fraction of
 * the symbol's size; a bold filled star is drawn on top of the outline so it reads at small sizes.
 * The badge is also announced to VoiceOver (accessibilityValue "Starred" / "Recommended"), unless
 * the row's title already says it (see LWEStudySetBadgeAccessibilityValue).
 */
static UIImage *LWEStudySetStarredRowSymbol(NSString *name, CGPoint starCenter)
{
  UIImage *base = LWEStudySetRowSymbol(name);
  UIImageSymbolConfiguration *starCfg = [UIImageSymbolConfiguration configurationWithPointSize:9 weight:UIImageSymbolWeightBold];
  UIImage *star = [UIImage systemImageNamed:@"star.fill" withConfiguration:starCfg];
  if (base == nil || star == nil)
  {
    return base;
  }
  CGSize size = base.size;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
  UIImage *composite = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    [base drawInRect:CGRectMake(0, 0, size.width, size.height)];
    CGSize starSize = star.size;
    CGRect starRect = CGRectMake(roundf(size.width * starCenter.x - starSize.width / 2.0),
                                 roundf(size.height * starCenter.y - starSize.height / 2.0),
                                 starSize.width, starSize.height);
    [star drawInRect:starRect];
  }];
  [renderer release];
  return [composite imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@implementation StudySetViewController
@synthesize subgroupArray,tagArray,selectedTagId,group,activityIndicator,searchBar;
/** 
 * Customized initializer - returns UITableView group as self.view
 * Also creates tab bar image and sets nav bar title
 */

- (id) initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self)
  {
    [self _commonInit];
  }
  return self;
}

- (id) initWithGroup:(Group*)aGroup
{
  self = [self initWithNibName:@"StudySetView" bundle:nil];
  if (self)
  {
    self.group = aGroup;
    self.title = aGroup.groupName;
    [self _commonInit];
  }
  return self;
}

- (void) _commonInit
{
  self.selectedTagId = kLWEUninitializedTagId;

  // Register observers to reload table data on other events
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:APP_HEADWORD_TYPE options:NSKeyValueObservingOptionNew context:NULL];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableData) name:kSetWasAddedOrUpdated object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableData) name:LWETagContentDidChange object:nil];
}

#pragma mark - UIViewController Methods

- (void) viewDidLoad
{
  [super viewDidLoad];
  if (self.group == nil)
  {
    self.group = [GroupPeer topLevelGroup];
  }
  
  [self reloadSubgroupData];
  
  // Add add button to nav bar
  _addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addStudySet:)];
  self.navigationItem.rightBarButtonItem = _addButton;
  
  self.tagArray = [[self.group.childTags mutableCopy] autorelease];
  self.activityIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium] autorelease];

  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 60;
  // The table starts under the navigation bar, not behind it: the scrolled-off "Search Sets By Name"
  // bar would otherwise sit behind the translucent bar and show through it (pushed group screens).
  self.edgesForExtendedLayout = UIRectEdgeNone;
  [self _applyNavigationBarAppearance];

  // Shared paper screen, like Settings: paper-2 behind paper cells, hairline separators (the XIB's
  // system grouped grey showed as a light band between the paper nav bar and the first row)
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  self.tableView.backgroundColor = [tm colorForSlot:@"groupedBackground"];
  self.tableView.separatorColor = [tm colorForSlot:@"separator"];
  self.tableView.sectionHeaderTopPadding = 0; // deployment target ≥ 15
}

//! Opaque paper nav bar (theme navBarFill), so the bar over the table isn't the white window
- (void) _applyNavigationBarAppearance
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  LWEStudySetApplyNavigationBarAppearance(self.navigationItem, [tm colorForSlot:@"navBarFill"], [tm colorForSlot:@"navTitleInk"], [tm colorForSlot:@"separator"]);
}

- (void) viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self updateSearchBarScrollRoom];
}

/**
 * Keeps enough bottom inset that the search bar can scroll off the top of a short list (see
 * LWEStudySetSearchBarScrollRoom).  Only our own share of contentInset.bottom is changed.
 */
- (void) updateSearchBarScrollRoom
{
  if (self.isViewLoaded == NO || searching)
  {
    return;
  }
  UITableView *tv = self.tableView;
  UIEdgeInsets inset = tv.contentInset;
  UIEdgeInsets adjusted = tv.adjustedContentInset;
  CGFloat visibleHeight = tv.bounds.size.height - adjusted.top - (adjusted.bottom - _searchBarScrollRoom);
  CGFloat room = LWEStudySetSearchBarScrollRoom(visibleHeight, self.searchBar.frame.size.height, tv.contentSize.height);
  if (fabs(room - _searchBarScrollRoom) >= 0.5)
  {
    inset.bottom = MAX(0, inset.bottom - _searchBarScrollRoom + room);
    _searchBarScrollRoom = room;
    tv.contentInset = inset;
  }
  // The rows can settle after -hideSearchBar (first layout in the window); if the shorter content
  // clamped the offset, the search bar peeks out again, so put it back off the top
  CGFloat hiddenOffsetY = -tv.adjustedContentInset.top + self.searchBar.frame.size.height;
  if (_keepSearchBarHidden && tv.isDragging == NO && tv.contentOffset.y < hiddenOffsetY - 0.5)
  {
    [tv setContentOffset:CGPointMake(tv.contentOffset.x, hiddenOffsetY) animated:NO];
  }
}

//! The user scrolls the list themselves from here on (e.g. pulls the search bar down)
- (void) scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  _keepSearchBarHidden = NO;
}

- (void) viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self _applyNavigationBarAppearance]; // the theme may have changed in Settings
  self.searchBar.placeholder = NSLocalizedString(@"Search Sets By Name",@"StudySetViewController.SearchPlaceholder");
  // Reload first: a reload re-clamps the offset to the (new) content size
  [self reloadTableData];
  if (searching == NO)
  {
    [self hideSearchBar];
  }
}

- (void) viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
#if defined (LWE_DEBUG)
  // Screenshot hook (Debug builds only): `-LWEDebugSelectTab 1 -LWEDebugOpenGroup 1` opens the Study Sets
  // tab and pushes its first group (1-based row in the groups section), once per launch.
  static BOOL sLWEDebugOpenedGroup = NO;
  NSInteger row = [[NSUserDefaults standardUserDefaults] integerForKey:@"LWEDebugOpenGroup"];
  if (sLWEDebugOpenedGroup == NO && row > 0 && [self.group isTopLevelGroup] && row <= (NSInteger)[self.subgroupArray count])
  {
    sLWEDebugOpenedGroup = YES;
    StudySetViewController *subgroupController = [[StudySetViewController alloc] initWithGroup:[self.subgroupArray objectAtIndex:(row - 1)]];
    [self.navigationController pushViewController:subgroupController animated:NO];
    [subgroupController release];
  }
#endif
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:APP_HEADWORD_TYPE])
  {
    [self reloadTableData];
  }
  else
  {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark -

- (void) reloadSubgroupData
{
  // Get subgroups
  self.subgroupArray = [GroupPeer retrieveGroupsByOwner:self.group.groupId];
  for (Group *subGroup in self.subgroupArray)
  {
    [subGroup childGroupCount];
  }
}

- (void) reloadTableData
{
  // No need to do anything if we don't have a table view (low memory, etc)
  if (self.isViewLoaded == NO)
  {
    return;
  }
  
	if (searching)
  {
    self.tagArray = [[[TagPeer retrieveTagListLike:self.searchBar.text] mutableCopy] autorelease];
  }
  else
  {
    self.tagArray = [[[self.group childTags] mutableCopy] autorelease];
    
    // Do something special for starred words - re-sort so starred shows up on top.
    if ([self.group isTopLevelGroup])
    {
      NSMutableArray *tmpTagArray = [NSMutableArray array];
      Tag *starredTag = [Tag starredWordsTag];
      for (Tag *tmpTag in self.tagArray)
      {
        if ([tmpTag isEqual:starredTag])
        {
          // Put it at the beginning
          [tmpTagArray insertObject:tmpTag atIndex:0];
        }
        else
        {
          [tmpTagArray addObject:tmpTag];
        }
      }
      self.tagArray = tmpTagArray;
    }
  }
  [self.tableView reloadData];
}

/**
 * Slides the search bar off of the visible space by setting the content offset of the table view
 */
- (void) hideSearchBar
{
  // Lay out the rows first, so the content size (and the room a short list needs) is real
  [self.tableView layoutIfNeeded];
  [self updateSearchBarScrollRoom];
  // Measured from the top of the content area, whatever inset the table has
  self.tableView.contentOffset = CGPointMake(0, -self.tableView.adjustedContentInset.top + self.searchBar.frame.size.height);
  _keepSearchBarHidden = YES;
}

/**
 * Changes the user's active study set
 * \param tag Is a Tag object pointing to the tag to begin studying
 */
- (void) activateTag:(Tag*) tag
{
  [self.activityIndicator startAnimating];
  
  // Put this on a queue so we are updating the UI
  CurrentState *appSettings = [CurrentState sharedCurrentState];
  [appSettings setActiveTag:tag completionHandler:^{
    // Tell the tab bar to switch to the SVC
    NSNumber *index = [NSNumber numberWithInt:STUDY_VIEW_CONTROLLER_TAB_INDEX];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:index forKey:@"index"];
    [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldSwitchTab object:nil userInfo:userInfo];
    
    // Stop the animator & reset the table
    self.selectedTagId = kLWEUninitializedTagId;
    [self.activityIndicator stopAnimating];
    [self.tableView reloadData];
  }];
}

/** Pops up AddStudySetInputViewController modal to create a new set */
- (IBAction)addStudySet:(id)sender
{
  // TODO: iPad customization?
  AddStudySetInputViewController *tmpVC = [[AddStudySetInputViewController alloc] initWithDefaultCard:nil inGroup:self.group];
  UINavigationController *modalNavController = [[UINavigationController alloc] initWithRootViewController:tmpVC];
  [self.navigationController presentViewController:modalNavController animated:YES completion:nil];
  [modalNavController release];
	[tmpVC release];
}


#pragma mark - UITableViewDataSource Methods

/**
 * If we are searching, there is only one section (returns 1)
 * If we are not searching, there are groups & tags (returns 2)
 * In either case, if we are at the "top of the stack", show 3 (including backup/restore)
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)lclTableView
{
	if (searching)
  {
    // Tags only
		return 1;
  }
  else if ([self.group isTopLevelGroup])
  {
    // Full list defined in enum at top of file
    return NUM_SECTIONS;
  }
  else
  {
    // Groups + Tags
    return 2;
  }
}


/**
 * If searching, returns the number of search results.  If no results, returns 1 (no results cell)
 * If not searching, returns number of tags or groups, depending on section
 */
- (NSInteger)tableView:(UITableView *)lclTableView numberOfRowsInSection:(NSInteger)section
{
	if (searching)
  {
    if ([self.tagArray count] > 0)
    {
      return [self.tagArray count];
    }
    else
    {
      return 1; // show no results message
    }
  }
  else
  {
    if (section == kLWETagsSection)
    {
      return [self.tagArray count];
    }
    else
    {
      return [self.subgroupArray count];
    }
  }
}


/**
 * Generates cells for table view depending on section & whether or not we are searching
 */
- (UITableViewCell *)tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  // Get theme manager so we can get elements from it
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  
  // Study Set Cells (ie. a tag)
  if (indexPath.section == kLWETagsSection || searching)
  {
    
    // No search results msg
    if (searching && [self.tagArray count] == 0)
    {
      cell = [LWEUITableUtils reuseCellForIdentifier:@"result" onTable:lclTableView usingStyle:UITableViewCellStyleSubtitle];
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12];
      cell.detailTextLabel.textColor = [tm colorForSlot:@"cellValueInk"]; // "4 Sets" / "7546 Words": 4.5:1+ (WCAG AA)
      cell.selectionStyle = UITableViewCellSelectionStyleGray;
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.text = NSLocalizedString(@"No Results Found",@"StudySetViewController.SearchedButNoResults");
      cell.detailTextLabel.numberOfLines = 0;
    }
    // Normal cell display
    else
    {
      cell = [LWEUITableUtils reuseCellForIdentifier:@"normal" onTable:lclTableView usingStyle:UITableViewCellStyleSubtitle];
      
      Tag *tmpTag = [self.tagArray objectAtIndex:indexPath.row];
      
      // Set up the image
      UIImageView *tmpView = cell.imageView;
      tmpView.tintColor = [tm currentThemeTintColor];
      BOOL starred = (tmpTag.tagId == STARRED_TAG_ID);
      if (starred)
      {
        tmpView.image = LWEStudySetStarredRowSymbol(@"tag", CGPointMake(0.43f, 0.57f));
      }
      else
      {
        tmpView.image = LWEStudySetRowSymbol(@"tag");
      }
      // VoiceOver: the star badge is only drawn, so say it too (cleared on rows without it)
      LWEStudySetApplyBadgeAccessibility(cell, starred, tmpTag.tagName, @"Starred",
                                         NSLocalizedString(@"Starred", @"StudySetViewController.StarredBadgeAccessibility"));
      
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.text = tmpTag.tagName;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      NSString *tmpDetailText = [NSString stringWithFormat:NSLocalizedString(@"%d Words",@"StudySetViewController.WordCount"), [tmpTag cardCount]];
      cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12];
      cell.detailTextLabel.textColor = [tm colorForSlot:@"cellValueInk"]; // "4 Sets" / "7546 Words": 4.5:1+ (WCAG AA)
      cell.detailTextLabel.text = tmpDetailText;
      cell.accessoryView = nil;
      if (tmpTag.cardCount == 0)
      {
        cell.accessoryType = UITableViewCellAccessoryNone;
      }
      else
      {
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
      }
      
      // Special behavior if we are loading the set
      if (self.selectedTagId == indexPath.row)
      {
        cell.accessoryView = self.activityIndicator;
        cell.detailTextLabel.text = NSLocalizedString(@"Loading cards...",@"StudySetViewController.LoadingCards");
      }
    }
  }
  // Group Cells
  else
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"group" onTable:lclTableView usingStyle:UITableViewCellStyleSubtitle];
    
    // Folders should display the theme color when pressed!
    CustomCellBackgroundView *bgView = [[CustomCellBackgroundView alloc] initWithFrame:CGRectZero];
    [bgView setCellIndexPath:indexPath tableLength:[self.subgroupArray count]];
    [bgView setBorderColor:[self.tableView separatorColor]];
    [bgView setFillColor:[[ThemeManager sharedThemeManager] currentThemeTintColor]];
    cell.selectedBackgroundView = bgView;
    [bgView release];
    
    // This is for groups?
    Group *tmpGroup = [self.subgroupArray objectAtIndex:indexPath.row];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = tmpGroup.groupName;
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    NSMutableArray *descItems = [NSMutableArray arrayWithCapacity:2];
    if (tmpGroup.childGroupCount > 0)
    {
      [descItems addObject:[NSString stringWithFormat:NSLocalizedString(@"%d Groups",@"StudySetViewController.GroupCount"),tmpGroup.childGroupCount]]; 
    }
    if (tmpGroup.tagCount > 0)  // note that this is *not* else if, these are additive
    {
      [descItems addObject:[NSString stringWithFormat:NSLocalizedString(@"%d Sets",@"StudySetViewController.TagCount"),tmpGroup.tagCount]];
    }
    NSString *tmpDetailText = [descItems componentsJoinedByString:@"; "];
    
    // Set up the image
    UIImageView *tmpView = (UIImageView*)cell.imageView;
    // TODO: iPad customization?
    if(tmpGroup.recommended)
    {
      tmpView.tintColor = [tm currentThemeTintColor];
      tmpView.image = LWEStudySetStarredRowSymbol(@"folder", CGPointMake(0.5f, 0.58f));
    }
    else
    {
      tmpView.tintColor = [tm currentThemeTintColor];
      tmpView.image = LWEStudySetRowSymbol(@"folder");
    }
    // VoiceOver: the star badge is only drawn, so say it too (cleared on rows without it)
    LWEStudySetApplyBadgeAccessibility(cell, (tmpGroup.recommended != 0), tmpGroup.groupName, @"Recommended",
                                       NSLocalizedString(@"Recommended", @"StudySetViewController.RecommendedBadgeAccessibility"));
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12];
    cell.detailTextLabel.textColor = [tm colorForSlot:@"cellValueInk"]; // "4 Sets" / "7546 Words": 4.5:1+ (WCAG AA)
    cell.detailTextLabel.text = tmpDetailText;
  }
  return cell;
}

#pragma mark - UITableViewDelegate Methods

/**
 * A group screen with no subgroups still has an (empty) groups section; its footer and the sets
 * section's header left a 20pt band between the nav bar and the first set.  Empty sections take no
 * space, and the first section with rows starts right under the search bar, as on the top level.
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  BOOL firstWithRows = YES;
  for (NSInteger i = 0; i < section; i++)
  {
    if ([self tableView:tableView numberOfRowsInSection:i] > 0)
    {
      firstWithRows = NO;
      break;
    }
  }
  if (firstWithRows || [self tableView:tableView numberOfRowsInSection:section] == 0)
  {
    return CGFLOAT_MIN;
  }
  return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
  return ([self tableView:tableView numberOfRowsInSection:section] == 0) ? CGFLOAT_MIN : UITableViewAutomaticDimension;
}

//! Paper cells on the paper list, like Settings (the detail ink is set per row in cellForRowAtIndexPath)
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  cell.backgroundColor = [tm colorForSlot:@"cellFill"];
  cell.textLabel.textColor = [tm colorForSlot:@"cellLabelInk"];
}

/**
 * Allows user to delete the selected tag
 * Note that this does not accept responsibility for IF the tag SHOULD be deleted
 */ 
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete)
  {
    // Delete the row from the data source
    Tag *tmpTag = [self.tagArray objectAtIndex:indexPath.row];
    [TagPeer deleteTag:tmpTag];
    [self.tagArray removeObjectAtIndex:indexPath.row];
    [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    [self reloadSubgroupData];
  }
}

/*- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  // No group description if we are at the top level or searching
  if ([self.group isTopLevelGroup] || searching || section != kLWEGroupsSection)
  {
    return nil;
  }
  
  CGFloat topPadding = 5.0f;
  CGRect rect = CGRectMake(8, topPadding, 304, 50);
  UILabel *groupDescription = [[[UILabel alloc] initWithFrame:rect] autorelease];
  groupDescription.text = self.group.groupDescription;
  groupDescription.font = [UIFont systemFontOfSize:14.0f];
  groupDescription.backgroundColor = [UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1.0f];
  groupDescription.numberOfLines = 0;
  groupDescription.lineBreakMode = NSLineBreakByWordWrapping;
  groupDescription.layer.borderWidth = 1.0f;
  groupDescription.layer.cornerRadius = 7.0f;
  groupDescription.layer.borderColor = [[UIColor lightGrayColor] CGColor];
  
  CGRect labelRect = [LWEUILabelUtils makeFrameForText:self.group.groupDescription fontSize:12 cellWidth:320 cellMargin:10];
  CGRect viewRect = CGRectMake(0, 0, 320, labelRect.size.height + (topPadding * 2));
  UIView *holdingView = [[UIView alloc] initWithFrame:viewRect];
  [holdingView addSubview:groupDescription];
  return [holdingView autorelease];
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  if ([self.group isTopLevelGroup] == NO && section == kLWEGroupsSection)
  {
    CGRect labelRect = [LWEUILabelUtils makeFrameForText:self.group.groupDescription fontSize:12 cellWidth:320 cellMargin:10];
    return labelRect.size.height + 10;
  }
  else
  {
    return 44.0f;
  }
}*/

/** UI Table View delegate - when a user selects a cell, either start that set, or navigate to the group (if a group) */
- (void)tableView:(UITableView *)lclTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == kLWETagsSection || searching)
  {
    if ([self.tagArray count] > 0)
    {
      NSInteger numCards = [[self.tagArray objectAtIndex:indexPath.row] cardCount];
      if (numCards > 0)
      {
        self.selectedTagId = indexPath.row;
        NSString *tagName = [[self.tagArray objectAtIndex:indexPath.row] tagName];
        [LWEUIAlertView confirmationAlertWithTitle:tagName
                                           message:NSLocalizedString(@"Do you want to start this set?  Progress on your last set will be saved.",@"StudySetViewController.StartStudy_AlertViewMessage")
                                          delegate:self];
      }
      else
      {
        [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"No Words In Set",@"StudySetViewController.NoWords_AlertViewTitle")
                                           message:NSLocalizedString(@"To add words to this set, you can use Search.",@"StudySetViewController.NoWords_AlertViewMessage")];
      }
    }
    else
    {
      // deselect "no results" msg
      [lclTableView deselectRowAtIndexPath:indexPath animated:NO];    
    }
  }
  else
  {
    [lclTableView deselectRowAtIndexPath:indexPath animated:NO];

    // If they selected a group
    Group *childGroup = [self.subgroupArray objectAtIndex:indexPath.row];
    StudySetViewController *subgroupController = [[StudySetViewController alloc] initWithGroup:childGroup];
    [self.navigationController pushViewController:subgroupController animated:YES];
    [subgroupController release];
  }
}


/**
 * If tag section OR in searching mode (where it becomes another section)
 * Show the study set words view controller for that tag
 */
- (void)tableView:(UITableView *)lclTableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
  [lclTableView deselectRowAtIndexPath:indexPath animated:NO];
  if (indexPath.section == kLWETagsSection || searching)
  {
    Tag *tmpTag = [self.tagArray objectAtIndex:indexPath.row];
    StudySetWordsViewController *wordsController = [[StudySetWordsViewController alloc] initWithTag:tmpTag]; 
    [self.navigationController pushViewController:wordsController animated:YES];
    [wordsController release];
  }
}


/**
 * If the tag's "tagEditable" flag is set to 1, return YES
 * Returns NO in any case if the tag is the active tag
 * Always returns NO for groups
 */
- (BOOL)tableView:(UITableView *)lclTableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
  // Only can edit tags, and user tags at that
  if (indexPath.section == kLWETagsSection)
  {
    Tag *activeTag = [[CurrentState sharedCurrentState] activeTag];
    Tag *tmpTag = [self.tagArray objectAtIndex:indexPath.row];
    if (tmpTag.isEditable && ([tmpTag isEqual:activeTag] == NO))
    {
      return YES;
    }
  }
  return NO;
}

#pragma mark - UIAlertViewDelegate Methods

/** Alert view delegate - initiates the "study set change" if they pressed OK */
- (void) alertView: (UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  // Quick return on anything but OK
  if (buttonIndex != LWE_ALERT_OK_BTN)
  {
    self.selectedTagId = kLWEUninitializedTagId;
    return;
  }
  
  {
    // This is the alert view that warns users they are about to start a new tag.
    
    // Cache this value and re-set it, the animation messes it up by resetting it to zero
    CGPoint offset = self.tableView.contentOffset;
    
    // We want to reload the selected row because it will now say "loading cards"
    [self.tableView beginUpdates];
    NSInteger section = kLWETagsSection;
    if (searching)
    {
      // If we are searching, the section is always 0.
      section = 0;
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.selectedTagId inSection:section];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
    
    // For some unknown reason, the above calls (but not -reloadData) reset the table offset.  We don't want that.
    self.tableView.contentOffset = offset;

    // Activate the tag!
    [self activateTag:[self.tagArray objectAtIndex:self.selectedTagId]]; 
  }
}

#pragma mark - Search Bar delegate methods

/**
 * Sets up the controller for searching mode
 * Creates an 50% alpha overlay to hide the study sets when nothing is entered in the 
 * search box
 */
- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar
{	
	//When the user clicks back from teh detail view
	if (searching) return;
	
  //Add the overlay view.
  if (_searchOverlay == nil)
  {
    _searchOverlay = [[UIView alloc] init];
    searchOverlayBtn = [[UIButton alloc] init];
    [_searchOverlay insertSubview:searchOverlayBtn atIndex:0];
    [searchOverlayBtn addTarget:self action:@selector(doDoneSearching) forControlEvents:UIControlEventTouchDown];
  }

  _searchOverlay.userInteractionEnabled = YES;
	CGFloat yaxis = self.navigationController.navigationBar.frame.size.height;
	CGFloat width = self.view.frame.size.width;
	CGFloat height = self.view.frame.size.height;
  CGRect frame = CGRectMake(0, yaxis, width, height);
	_searchOverlay.frame = frame;	
  searchOverlayBtn.frame = frame;
	_searchOverlay.alpha = 0.5;
	[self.tableView insertSubview:_searchOverlay aboveSubview:self.parentViewController.view];
	
	searching = YES;
  self.tagArray = [[[TagPeer retrieveTagListLike:self.searchBar.text] mutableCopy] autorelease];
  self.tableView.scrollEnabled = NO;
	
	//Add the done button.
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doDoneSearching)] autorelease];
}


/**
 * Run search if the user typed something into the search bar
 */
- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	// Remove all objects first.
  [self.tagArray removeAllObjects];
	
	if([searchText length] > 0)
  {
    [_searchOverlay removeFromSuperview];
		searching = YES;
    self.tableView.scrollEnabled = YES;
	}
	else
  {
		[self.tableView insertSubview:_searchOverlay aboveSubview:self.parentViewController.view];
		searching = NO;
    self.tableView.scrollEnabled = NO;
	}
  [self reloadTableData];
}

// Called when the user finally presses "Search" on the keyboard
- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar
{
  self.tagArray = [[[TagPeer retrieveTagListLike:self.searchBar.text] mutableCopy] autorelease];
  [self.searchBar resignFirstResponder];
}

/** 
 * Cleanup after searching finished
 * Hides keyboard, nulls out searchBar text, and re-adds add button to nav bar
 */
- (void) doDoneSearching
{
	self.searchBar.text = @"";
	[self.searchBar resignFirstResponder];
	searching = NO;
  
  self.tableView.scrollEnabled = YES;

  // Replace the done button w/ the add button again
	self.navigationItem.rightBarButtonItem = _addButton;
  [self reloadTableData];
  [self hideSearchBar];
  
  // Kill search overlay
  [_searchOverlay removeFromSuperview];
	[_searchOverlay release];
	_searchOverlay = nil;
}

//! Standard dealloc, removes observers
- (void)dealloc
{
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:APP_HEADWORD_TYPE];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  
  [_addButton release];
  [tagArray release];
  [subgroupArray release];
  [group release];
  [activityIndicator release];
  [searchBar release];
  [super dealloc];
}

@end