//
//  SearchViewController.m
//  jFlash
//
//  Created by Mark Makdad on 8/2/09.
//  Copyright 2009 LONG WEEKEND INC.. All rights reserved.
//

#import "SearchViewController.h"
#import "ChineseCard.h"
#import "SettingsViewController.h"
#import "LWEChineseSearchBar.h"
#import "jFlashAppDelegate.h"
#import "UIColor+LWEUtilities.h"

const NSInteger KSegmentedTableHeader = 100;

// Private method declarations
@interface SearchViewController ()
- (BOOL) _checkMembershipCacheForCard:(Card*)card;
- (void) _toggleMembership:(id)sender event:(id)event;
//! Callback from the above runSearchForString: async call
- (void) _receivedSearchResults:(NSArray *)results;
- (UITableViewCell*) _setupTableCell:(UITableViewCell*)cell forCard:(Card*) card;

//! Contains the returned search results (array of Card objects, may be flywheeled (faulted) objects)
@property (nonatomic, retain) NSArray *cardResultsArray;

//! Array to contain cache of starred words membership (so we don't have to hit the DB EVERY time)
@property (nonatomic, retain) NSMutableArray *membershipCacheArray;
@end

@implementation SearchViewController
@synthesize externalAppManager, externalAppBtn, returnToExternalAppView;
@synthesize activityIndicator, searchingCell, searchBar;
@synthesize cardResultsArray, membershipCacheArray;
@synthesize pluginManager;

#pragma mark - Initializer

- (void) _initClass
{
  // Default state
  _searchState = kSearchNoSearch;

  // Notification for when the card headword stlye changes
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:APP_HEADWORD_TYPE options:NSKeyValueObservingOptionNew context:NULL];

  // Register for notification when tag content changes (might be starred words.. in which case we want to know)
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tagContentDidChange:) name:LWETagContentDidChange object:nil];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
  if ((self = [super initWithCoder:aDecoder]))
  {
    [self _initClass];
  }
  return self;
}

/** Initializer to set up a table view, sets title & tab bar controller icon to "search" */
- (id) init
{
  if ((self = [super init]))
  {
    [self _initClass];
  }
  return self;
}

#pragma mark - UIViewController Methods

/** Programmatically create a UISearchBar & UISegmentedControl for search */
- (void) viewDidLoad
{
  [super viewDidLoad];
  
  // Is a little bit ghetto for now.  We could consider updating this class.
  self.externalAppBtn.layer.borderWidth = 2.0f;
  self.externalAppBtn.layer.cornerRadius = 9.0f;
  
  // Set YELLOW, not RED
  NSMutableArray *colors = [NSMutableArray arrayWithCapacity:4];
  UIColor *color = nil;
  //#e4ce9f, 228,206,159 - top of top
  color = [UIColor colorWithRed:0.891 green:0.805 blue:0.621 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  //#efcd64, 239,205,100 - bottom of top
  color = [UIColor colorWithRed:0.933 green:0.8 blue:0.39 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  //#efbc22, 239,188,34 - top of bottom
  color = [UIColor colorWithRed:0.933 green:0.734 blue:0.133 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  //#f6dc24, 246,220,36 - bottom of bottom
  color = [UIColor colorWithRed:0.960 green:0.859 blue:0.141 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  self.externalAppBtn.normalGradientColors = colors;
  self.externalAppBtn.normalGradientLocations = [NSArray arrayWithObjects:
                                                 [NSNumber numberWithFloat:1.0f],
                                                 [NSNumber numberWithFloat:0.5001f],
                                                 [NSNumber numberWithFloat:0.5f],
                                                 [NSNumber numberWithFloat:0.0f],
                                                 nil];

  
  [[NSBundle mainBundle] loadNibNamed:@"SearchingTableCell" owner:self options:nil];
  
  // Programmatically make UISearchBar
  // TODO: iPad customization!
#if defined(LWE_CFLASH)
  // For Chinese Flash, add a custom accessory input to the search keyboard
  LWEChineseSearchBar *tmpSearchBar = [[LWEChineseSearchBar alloc] initWithFrame:CGRectMake(0,0,320,45)];
  self.searchBar = tmpSearchBar;
#endif

  self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
  self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
  
  // If we are loading the view AFTER running a search, make sure to set the search bar appropriately.
  self.searchBar.text = self.externalAppManager.searchTerm;
}

- (void) viewDidUnload
{
  [super viewDidUnload];
  self.externalAppBtn = nil;
  self.searchBar = nil;
  self.returnToExternalAppView = nil;
  self.searchingCell = nil;
  self.activityIndicator = nil;
}

/** 
 * Delegate view method - pops up the keyboard if no search results, also resets the search variables, makes sure title bar theme is correct 
 * If search is not installed, will call shouldShowDownloaderModal notification to stop user from using this screen
 */
- (void) viewWillAppear:(BOOL)animated
{
  // View related
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  self.searchBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  
  // Fire off a notification to bring up the downloader?  If we are on the old data version, let them use search!
  BOOL hasFTS = [self.pluginManager pluginKeyIsLoaded:FTS_DB_KEY];
  if (!hasFTS)
  {
    self.searchBar.placeholder = NSLocalizedString(@"Search unavailable",@"SearchViewController.SearchBarPlaceholder_Unavailable");
  }
  else
  {
    self.searchBar.placeholder = NSLocalizedString(@"Enter search keyword",@"SearchViewController.SearchBarPlaceholder_douzo");
    if (_searchState == kSearchNoSearch)
    {
      // Show keyboard if no results
      [self.searchBar becomeFirstResponder];
    }
  }
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  // If you call "self.tableView" to ask if it's nil, that would launch the loading of the view.. not what we want, so we use isViewLoaded
  if ([keyPath isEqualToString:APP_HEADWORD_TYPE] && self.isViewLoaded)
  {
    [self.tableView reloadData];
  }
  else
  {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - Public Methods

- (IBAction) returnToExternalApp:(id)sender
{
  // Since the app manager isn't part of the responder chain, just fwd this for us
  [self.externalAppManager returnToExternalApp:sender];
}

/**
 * runs a search and sets the text of the searchBar -- used with external apps (Rikai, etc)
 */
- (void) runSearchAndSetSearchBarForString:(NSString*) text
{
  // Set up the view as if the user had searched for the term
  [self.searchBar resignFirstResponder];
  self.searchBar.text = text;
  
  // Now double-check that we actually have the search plugin installed.  If not, don't run the search!
  if ([self.pluginManager pluginKeyIsLoaded:FTS_DB_KEY])
  {
    // Now do the actual search as if the user had done it
    [self runSearchForString:text];
  }
}

/** Execute actual search with \param text */
- (void) runSearchForString:(NSString*) text
{
  _searchState = kSearchSearching;
  
  // Show the searching cell
  [self.tableView reloadData];
  [self.activityIndicator startAnimating];
  
  dispatch_queue_t queue = dispatch_queue_create("com.longweekendmobile.ftssearch",NULL);
  dispatch_async(queue,^
                 {
                   // Run the regular search
                   NSArray *tmpResults = [CardPeer searchCardsForKeyword:text];
                   
                   // If we had no results from the first search and there was no "deep" search, do it automatically
                   if ([tmpResults count] == 0 && ([text hasSuffix:@"?"] == NO))
                   {
                     tmpResults = [CardPeer searchCardsForKeyword:[text stringByAppendingString:@"?"]];
                   }
                   
                   // Report the results back to the view controller on the main thread
                   dispatch_async(dispatch_get_main_queue(), ^{ [self _receivedSearchResults:tmpResults]; });
                 });
  dispatch_release(queue);
}

#pragma mark - TagContentDidChange Methods

- (void) tagContentDidChange:(NSNotification *)aNotification
{
  // Foremost, if the tag isn't starred words, we don't care -- quick return
  if ([aNotification.object isEqual:[Tag starredWordsTag]] == NO)
  {
    return;
  }
  
  // OK, now let's see to add a star or take it away.
  Card *card = [aNotification.userInfo objectForKey:LWETagContentDidChangeCardKey];
  NSString *changeType = [aNotification.userInfo objectForKey:LWETagContentDidChangeTypeKey];
  if ([changeType isEqualToString:LWETagContentCardAdded])
  {
    if ([self.cardResultsArray containsObject:card])
    {
      // Add to the cache & reload so the star appears
      [self.membershipCacheArray addObject:card];
      if (self.isViewLoaded)
      {
        [self.tableView reloadData];
      }
    }
  }
  else if ([changeType isEqualToString:LWETagContentCardRemoved])
  {
    // Only react if this card is listed in the search results
    BOOL cardInSearchResults = [self _checkMembershipCacheForCard:card];
    if (cardInSearchResults)
    {
      [self.membershipCacheArray removeObject:card];
      if (self.isViewLoaded)
      {
        [self.tableView reloadData];
      }
    }
  }
}

#pragma mark - UISearchBarDelegate methods

/**
 * Check if the plugin installed, returns NO if not, and launches modal via notification
 * If plugin is loaded always returns YES
 */
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
  BOOL hasFTS = [self.pluginManager pluginKeyIsLoaded:FTS_DB_KEY];
  
  if (hasFTS)
  {
    return YES;
  }
  else
  {
    return NO;
  }
}

/** Only show the cancel button when the keyboard is displayed */
- (void) searchBarTextDidBeginEditing:(UISearchBar*) lclSearchBar
{
  lclSearchBar.showsCancelButton = YES;
}

/** Hide the cancel button when user finishes */
- (void) searchBarTextDidEndEditing:(UISearchBar *)lclSearchBar
{  
  lclSearchBar.showsCancelButton = NO;
}

/** Run the search and resign the keyboard */
- (void) searchBarSearchButtonClicked:(UISearchBar *)lclSearchBar
{
  // Reset the state machine
  _searchState = kSearchNoSearch;
  
  // Clear the cache of favorites
  self.membershipCacheArray = nil;

  [self runSearchForString:lclSearchBar.text];
  [lclSearchBar resignFirstResponder];
}

/** Cancel the keyboard only */
- (void) searchBarCancelButtonClicked:(UISearchBar*)lclSearchBar
{
  [lclSearchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

/** Returns 1 row ("no results") if there are no search results, otherwise returns number of results **/
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (_searchState == kSearchHasNoResults || _searchState == kSearchSearching)
  {
    return 1;
  }
  else
  {
    if (_currentResultArray)
    {
      // Some results
      return [_currentResultArray count];
    }
    else
    {
      // Nothing searched for
      return 0;
    }
  }
}

/** Delegate for table, returns cells */
- (UITableViewCell *)tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  // Get different kinds of cells depending on the state
  UITableViewCell *cell = nil;
  switch (_searchState)
  {
      // Default to the same behavior if we have NO search results as well as having them
    case kSearchNoSearch:
      cell = [LWEUITableUtils reuseCellForIdentifier:@"NoSearch" onTable:lclTableView usingStyle:UITableViewCellStyleSubtitle];
      break;
      
    case kSearchHasResults:
      // These cards be flywheeled, see if we need to hydrate it
      cell = [LWEUITableUtils reuseCellForIdentifier:@"card" onTable:lclTableView usingStyle:UITableViewCellStyleSubtitle];
      Card *searchResult = [self.cardResultsArray objectAtIndex:indexPath.row];
      if (searchResult.isFault)
      {
        [searchResult hydrate];
      }
      cell = [self _setupTableCell:cell forCard:searchResult];
      break;
      
    case kSearchSearching:
      cell = self.searchingCell;
      break;
      
      // Regular search had no results
    case kSearchHasNoResults:
      cell = [LWEUITableUtils reuseCellForIdentifier:@"NoResults" onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
      cell.textLabel.text = NSLocalizedString(@"No Results Found",@"SearchViewController.NoResults");
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.accessoryType = UITableViewCellAccessoryNone;
      break;
  }
  return cell;
}

#pragma mark - UITableViewDelegate Methods

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  // Quick return if we are not using the Rikai header
  if ([self.externalAppManager externalAppWantsReturn])
  {
    NSString *appName = [self.externalAppManager nameForBundleId:self.externalAppManager.externalBundleId];
    self.externalAppBtn.titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Return to %@", @"ExternalAppReturnButtonFormat"),appName];
    return self.returnToExternalAppView;
  }
  
  return nil;
}

- (CGFloat)tableView:(UITableView *)lclTableView heightForRowAtIndexPath:(NSIndexPath*)indexPath
{
  CGFloat bodySize = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize;
  CGFloat scale = bodySize / 17.0f;
  return floorf(64.0f * bodySize / 17.0f);
}

/** Returns 75px if _showSearchTargetControl is YES, otherwise returns UITableView standard 0 (no headers) */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  if ([self.externalAppManager externalAppWantsReturn])
  {
    return self.returnToExternalAppView.frame.size.height;
  }
  else
  {
    return 0.0f;
  }
}

/**
 * IF there are search results and the user pressed one, push an appropriate view controller onto the view stack
 * (AddTagViewController = card search)
 */
- (void)tableView:(UITableView *)lclTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  // Deselect the row
  [lclTableView deselectRowAtIndexPath:indexPath animated:NO];

  if (_searchState == kSearchHasResults)
  {
    AddTagViewController *tagController = [[AddTagViewController alloc] initForExampleSentencesWithCard:[self.cardResultsArray objectAtIndex:indexPath.row]];
    [self.navigationController pushViewController:tagController animated:YES];
    [tagController release];
  }
}

#pragma mark - Private methods

/**
 * Callback when search is complete
 */
- (void) _receivedSearchResults:(NSArray *)results
{
  // No need to spin anymore!
  [self.activityIndicator stopAnimating];
  
  self.cardResultsArray = _currentResultArray = results;
  
  // Change state based on results (move us through state diagram --> has results -> no results -> no deep results)
  if ([results count] > 0)
  {
    _searchState = kSearchHasResults;
    [self.tableView reloadData];
  }
  else
  {
    // TODO: add bit about wether it is still searching or not.
    _searchState = kSearchHasNoResults;
    [self.tableView reloadData];
  }
  
  // reset the user to the top of the tableview for new searches
  self.tableView.contentOffset = CGPointMake(0, 0);
}


/** Checks the membership cache to see if we are in - FYI similar methods are used by AddTagViewController as well */
- (BOOL) _checkMembershipCacheForCard:(Card*)theCard
{
  BOOL returnVal = NO;
  if (self.membershipCacheArray)
  {
    return [self.membershipCacheArray containsObject:theCard];
  }
  else
  {
    // Rebuild cache and fail over to manual function
    Tag *starredTag = [[CurrentState sharedCurrentState] starredTag];
    self.membershipCacheArray = [[[CardPeer retrieveFaultedCardsForTag:starredTag] mutableCopy] autorelease];
    returnVal = [TagPeer card:theCard isMemberOfTag:starredTag];
  }
  return returnVal;
}


/**
 * Adds a card to a favorites tag, or removes it, depending on its current
 */
- (void) _toggleMembership:(id)sender event:(id)event
{
  // Get the card ID
  NSSet *touches = [event allTouches];
  UITouch *touch = [touches anyObject];
  CGPoint currentTouchPosition = [touch locationInView:self.tableView];
  NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint: currentTouchPosition];
  if (indexPath != nil)
  {
    Card *theCard = [self.cardResultsArray objectAtIndex:indexPath.row];
    Tag *starredTag = [[CurrentState sharedCurrentState] starredTag];
    
    // Use cache for toggling status if we have it
    BOOL isMember = NO;
    if (self.membershipCacheArray && [self.membershipCacheArray count] > 0)
    {
      isMember = [self _checkMembershipCacheForCard:theCard];
    }
    else
    {
      isMember = [TagPeer card:theCard isMemberOfTag:starredTag];
    }
    
    if (isMember == NO)
    {
      [TagPeer subscribeCard:theCard toTag:starredTag];
      
      // Now add the new ID onto the end of the search cache
      [self.membershipCacheArray addObject:theCard];
    }
    else
    {
      NSError *error = nil;
      if ([TagPeer cancelMembership:theCard fromTag:starredTag error:&error] == NO)
      {
        NSString *title = NSLocalizedString(@"Remove From Set Error",@"Remove from Set Error");
        if (error.code == kRemoveLastCardOnATagError)
        {
          // We know about this error, we can give slightly better detail
          title = NSLocalizedString(@"Last Card in Set", @"AddTagViewController.AlertViewLastCardTitle");
        }
        [LWEUIAlertView notificationAlertWithTitle:title message:[error localizedDescription]];
        return;
      }
      
      [self.membershipCacheArray removeObject:theCard];
    }

    NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }
}

/** Helper method - makes a cell for cellForIndexPath for a Card */
- (UITableViewCell*) _setupTableCell:(UITableViewCell*)cell forCard:(Card*) card
{
  CGFloat bodySize = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize;
  CGFloat scale = bodySize / 17.0f;
  CGFloat rowH = floorf(64.0f * scale);

  // Get the headword (or make a new one)
  UILabel *searchResult = (UILabel*)[cell viewWithTag:SEARCH_CELL_HEADWORD];
  if (searchResult == nil)
  {
    searchResult = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    searchResult.tag = SEARCH_CELL_HEADWORD;
    searchResult.lineBreakMode = UILineBreakModeTailTruncation;
    [cell.contentView addSubview:searchResult];
  }
  searchResult.frame = CGRectMake(43, floorf(3 * scale), 240, floorf(25 * scale));
  searchResult.font = [UIFont boldSystemFontOfSize:floorf(18 * scale)];
  searchResult.backgroundColor = [UIColor whiteColor];
  // Ignore == YES means we will always get the target language's headword
  searchResult.text = [card headwordIgnoringMode:YES];

  // Update the glyph based on settings, if necessary
  searchResult.font = [Card configureFontForLabel:searchResult];
  
  // Now make the button
  UIButton *starButton = (UIButton*)[cell viewWithTag:SEARCH_CELL_BUTTON];
  if (starButton == nil)
  {
    starButton = [[[UIButton alloc] initWithFrame:CGRectZero] autorelease];
    starButton.tag = SEARCH_CELL_BUTTON;
    [starButton addTarget:self action:@selector(_toggleMembership:event:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:starButton];
  }
  CGFloat btnH = floorf(rowH * 0.6f);
  CGFloat btnY = floorf((rowH - btnH) / 2.0f);
  starButton.frame = CGRectMake(7, btnY, floorf(29 * scale), btnH);

  UIImage *image = [UIImage imageNamed:@"star.png"];
  image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  [starButton setImage:image forState:UIControlStateNormal];
  // Now set its state
  if ([self _checkMembershipCacheForCard:card])
  {
    [starButton setTintColor:[UIColor colorWithHex:[NSNumber numberWithInt:0xFFD700]]];
  }
  else
  {
    [starButton setTintColor:[UIColor lightGrayColor]];
  }
  
  // Get the meaning
  UILabel *meaningLabel = (UILabel*)[cell viewWithTag:SEARCH_CELL_MEANING];
  if (meaningLabel == nil)
  {
    meaningLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    meaningLabel.tag = SEARCH_CELL_MEANING;
    [cell.contentView addSubview:meaningLabel];
  }
  meaningLabel.frame = CGRectMake(44, floorf(41 * scale), 250, floorf(20 * scale));
  meaningLabel.font = [UIFont systemFontOfSize:floorf(13 * scale)];
  meaningLabel.text = [card meaningWithoutMarkup];

  // And the reading
  UILabel *readingLabel = (UILabel*)[cell viewWithTag:SEARCH_CELL_READING];
  if (readingLabel == nil)
  {
    readingLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    readingLabel.textColor = [UIColor grayColor];
    readingLabel.tag = SEARCH_CELL_READING;
    [cell.contentView addSubview:readingLabel];
  }
  readingLabel.frame = CGRectMake(43, floorf(27 * scale), 250, floorf(16 * scale));
  readingLabel.font = [UIFont systemFontOfSize:floorf(13 * scale)];
  
#if defined(LWE_CFLASH)
  readingLabel.text = [(ChineseCard *)card pinyinReading];
#else
  readingLabel.text = [card reading];
#endif  
  
  // Default cell properties
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  cell.selectionStyle = UITableViewCellSelectionStyleGray;
  return cell;
}

#pragma mark - Class plumbing

//! Standard dealloc
- (void)dealloc
{
  // Plugin did install observer
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // Stop observing headword changes
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:APP_HEADWORD_TYPE];
  
  [pluginManager release];
  [externalAppManager release];
  [returnToExternalAppView release];
  [searchBar release];
  [cardResultsArray release];
  [activityIndicator release];
  [searchingCell release];
  [externalAppBtn release];
  [super dealloc];
}


@end
