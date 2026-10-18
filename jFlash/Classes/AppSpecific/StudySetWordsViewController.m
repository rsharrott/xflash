//
//  StudySetWordsViewController.m
//  jFlash
//
//  Created by Ross Sharrott on 6/28/09.
//  Copyright 2009 LONG WEEKEND LLC. All rights reserved.
//

#import "StudySetWordsViewController.h"
#import "AddTagViewController.h"
#import "AddStudySetInputViewController.h"
#import "SettingsViewController.h"

@interface StudySetWordsViewController ()
- (void) _loadWordListInBackground;
- (void) _tagContentDidChange:(NSNotification*)notification;
@end

/**
 * Grouped UITableViewController subclass - shows all words in a given set
 * Some sets may be large, so this controller will not lock the interface
 * by loading all cards into memory at first.  It will load first and then
 * put the cards onto the screen when loaded.
 */
@implementation StudySetWordsViewController

@synthesize tag, cards, activityIndicator;

#pragma mark - Initializer

/**
 * Customized initializer taking a Tag as a single parameter
 * Sets the title of the nav bar to the tag name
 * Also kicks off loadWordListInBackground selector in.. background
 */ 
- (id) initWithTag:(Tag*)initTag
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self)
  {
    LWE_ASSERT_EXC((initTag.tagId >= 0), @"You can't launch this VC with an uninitialized tag");
    self.tag = initTag;
    [self performSelectorInBackground:@selector(_loadWordListInBackground) withObject:nil];
    
    UIActivityIndicatorView *av = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator = av;
    [av release];

    // When the headword type changes, reload the table
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    [settings addObserver:self forKeyPath:APP_HEADWORD_TYPE options:NSKeyValueObservingOptionNew context:NULL];
    
    // Ideally, I could set the object: to self.tag, but there's no guarantee that the MEMORY ADDY of
    // the self.tag is the same as the memory address of the tag object sending the notification, even
    // if they have the same tagId ... sadface. (MMA - 18.10.2011) ... Or is this OK?  Think about it.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_tagContentDidChange:)
                                                 name:LWETagContentDidChange
                                               object:nil];
  }
  return self;
}

#pragma mark - UIViewController Methods

- (void) viewWillAppear: (BOOL)animated
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  
  // We do this on viewWillAppear instead of viewDidLoad because the tagName could change
  // when the user edits it after tapping "Edit" on this VC
  self.navigationItem.title = self.tag.tagName;
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:APP_HEADWORD_TYPE] && self.tableView)
  {
    [self.tableView reloadData];
  }
  else
  {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - Private Methods

- (void) _tagContentDidChange:(NSNotification*)notification
{
  // First, quick return if this tagId isn't relevant to us.
  if ([self.tag isEqual:(Tag*)notification.object] == NO)
  {
    return;
  }
  
  // Next, make sure we have a card.
  Card *theCard = [notification.userInfo objectForKey:LWETagContentDidChangeCardKey];
  if (theCard == nil)
  {
    return;
  }
  
  [self.tableView beginUpdates];
  // OK, now determine what type of update it is - if we don't know, do nothing
  NSString *changeType = [notification.userInfo objectForKey:LWETagContentDidChangeTypeKey];
  if ([changeType isEqualToString:LWETagContentCardAdded])
  {
    [self.cards addObject:theCard];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self.cards indexOfObject:theCard] inSection:kWordSetListSections];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                          withRowAnimation:UITableViewRowAnimationRight];
  }
  else if ([changeType isEqualToString:LWETagContentCardRemoved])
  {
    NSInteger index = [self.cards indexOfObject:theCard];
    if (index != NSNotFound)
    {
      //remove the card, reload the table
      [self.cards removeObjectAtIndex:index];
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:kWordSetListSections];
      [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                            withRowAnimation:UITableViewRowAnimationRight];

    }
  }
  [self.tableView endUpdates];
}

/** Run in background on init to load the word list */
- (void) _loadWordListInBackground
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  self.cards = [[[CardPeer retrieveFaultedCardsForTag:self.tag] mutableCopy] autorelease];
  [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
  [pool release];
}

#pragma mark - UITableViewDataSource Methods

/** Returns the number of enums in wordsSections enum */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return wordsSectionsLength;
}

/**
 * If we are in "header" section with "start this set" button, return 1
 * If we are in the cards section, return # cards, or 1 if still loading
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  int returnCount = 0;
  if (section == kWordSetListSections)
  {
    if ([self cards])
    {
      // Show cards & stop the animator
      [self.activityIndicator stopAnimating];
      returnCount = [self.cards count];
    }
    else
    {
      // No cards yet, show "loading" cell
      returnCount = 1;
    }
  }
  else
  {
    if (self.tag.isEditable)
    {
      // editable tags can be edited and eventually shared
      returnCount = settingsRowsLength;
    }
    else
    {
      // non-editable tags can only be studied
      returnCount = 1;
    }
  }
  return returnCount;
}

/** Customize the appearance of table view cells */
- (UITableViewCell *)tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *cellIdentifier = @"StudySetWordsCell";
  static NSString *headerIdentifier = @"Header";
  UITableViewCell *cell = nil;
  if (indexPath.section == kWordSetListSections)
  {
    if (self.cards == nil)
    {
      // "Loading words..." pre-display cell
      cell = [LWEUITableUtils reuseCellForIdentifier:headerIdentifier onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
      cell.textLabel.text = NSLocalizedString(@"Loading words...",@"StudySetWordsViewController.LoadingWords");
      cell.accessoryView = self.activityIndicator;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      [self.activityIndicator startAnimating];
    }
    else
    {
      // The actual words, once loaded
      cell = [LWEUITableUtils reuseCellForIdentifier:cellIdentifier onTable:lclTableView usingStyle:UITableViewCellStyleSubtitle];
      cell.selectionStyle = UITableViewCellSelectionStyleGray;
      Card *tmpCard = [self.cards objectAtIndex:indexPath.row];
      if (tmpCard.isFault)
      {
        // Lazy load & update our array
        [tmpCard hydrate];
      }
      cell.detailTextLabel.text = [tmpCard meaningWithoutMarkup];
      // Ignore = YES means we get the target language HW no matter what, no headword_en
      cell.textLabel.text = [tmpCard headwordIgnoringMode:YES];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      cell.textLabel.font = [Card configureFontForLabel:cell.textLabel];
    }
  }
  else
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:headerIdentifier onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (indexPath.row == kWordSetOptionsStart)
    {
      cell.textLabel.text = NSLocalizedString(@"Begin Studying These",@"StudySetWordsViewController.BeginStudyingThese");
    }
    if (indexPath.row == kWordSetOptionsEditSet)
    {
      cell.textLabel.text = NSLocalizedString(@"Edit Set Details",@"StudySetWordsViewController.EditSetDetails");
    }
  }
  return cell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)lclTableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete)
  {
    NSError *error = nil;
    Card *card = [self.cards objectAtIndex:indexPath.row];
    
    // Set this to signal to the notification callback that we don't need to do anything
    BOOL result = [TagPeer cancelMembership:card fromTag:self.tag error:&error];

    if (result == NO)
    {
      if (error.code == kRemoveLastCardOnATagError)
      {
        NSString *errorMessage = [error localizedDescription];
        [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Last Card in Set", @"AddTagViewController.AlertViewLastCardTitle")
                                           message:errorMessage];
      }
      else
      {
        LWE_LOG_ERROR(@"[UNKNOWN ERROR]%@", error);
      }
    } // else error
  } // editing style is delete
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
  BOOL returnVal = NO;
  // Only let the user edit the word list, and only if the tag is editable
  if (self.tag.isEditable && indexPath.section == kWordSetListSections)
  {
    returnVal = YES;
  }
  return returnVal;
}


/** If the user selected the "header" row, start the set.  If the user selected a card, push an AddTagViewController at them. */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
  if (indexPath.section == kWordSetOptionsSection)
  {
    if (indexPath.row == kWordSetOptionsStart)
    {
      // one final check to make sure they do not empty out the set prior to running it - reload the card
      [self.tag hydrate];
      if (self.tag.cardCount > 0)
      {
        CurrentState *appSettings = [CurrentState sharedCurrentState];
        [appSettings setActiveTag:self.tag];
        
        // Now switch to the main tab.
        NSNumber *index = [NSNumber numberWithInt:STUDY_VIEW_CONTROLLER_TAB_INDEX];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:index forKey:@"index"];
        [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldSwitchTab object:self userInfo:userInfo];
      }
      else
      {
        [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"No Words In Set",@"StudySetViewController.NoWords_AlertViewTitle")
                                           message:NSLocalizedString(@"To add words to this set, you can use Search.",@"StudySetViewController.NoWords_AlertViewMessage")];
      }
    }
    else if(indexPath.row == kWordSetOptionsEditSet)
    {
      AddStudySetInputViewController *tmpVC = [[AddStudySetInputViewController alloc] initWithTag:self.tag];
      self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel",@"Global.Cancel")
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:nil
                                                                               action:nil] autorelease];
      [self.navigationController pushViewController:tmpVC animated:YES];
      [tmpVC release];
    }
  }
  // If they pressed a card, show the add to set list
  else if (indexPath.section == kWordSetListSections)
  {
    AddTagViewController *tmpVC = [[AddTagViewController alloc] initForExampleSentencesWithCard:[self.cards objectAtIndex:indexPath.row]];
    [self.navigationController pushViewController:tmpVC animated:YES];
    [tmpVC release];
  }
}

#pragma mark - Class Plumbing

//! Standard dealloc
- (void)dealloc
{
  // Remove observers for headword & tag content did change
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:APP_HEADWORD_TYPE];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [tag release]; 
  [cards release];
  [activityIndicator release];
  [super dealloc];
}

@end

