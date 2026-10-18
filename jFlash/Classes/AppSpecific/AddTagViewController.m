//
//  AddTagViewController.m
//  jFlash
//
//  Created by Mark Makdad on 6/28/09.
//  Copyright 2009 LONG WEEKEND LLC. All rights reserved.
//

#import "AddTagViewController.h"
#import "AddStudySetInputViewController.h"
#import "SettingsViewController.h"
#import "DisplaySearchedSentenceViewController.h"
#import "UpgradeAdViewController.h"

#import "TagPeer.h"
#import "ExampleSentencePeer.h"
#import "GroupPeer.h"

#if defined (LWE_CFLASH)
  #import "ChineseCard.h"
#endif

enum EntrySectionRows
{
  kEntrySectionInfoRow = 0,
  kEntrySectionCount
};

// Private methods & properties
@interface AddTagViewController ()
- (void) _reloadTableData;
- (NSArray*) sectionsArray;
@property (retain) NSMutableArray *membershipCacheArray;
@property (retain) NSArray* _sectionsArray;
@end

@implementation AddTagViewController
@synthesize myTagArray,sysTagArray,membershipCacheArray,sentencesArray,currentCard,showExamplesCell,_sectionsArray;

#pragma mark - Initializer

/**
 * Initializer - automatically loads AddTagView XIB file
 * attaches the Card parameter to the object
 * Also sets up nav bar properties
 */
- (id) initWithCard:(Card*)card
{
  // TODO: iPad customization!
  if ((self = [super initWithNibName:@"AddTagView" bundle:nil]))
  {
    LWE_ASSERT_EXC((card.isFault == NO), @"Card passed to AddTagViewcontroller should not be a fault!");
    self.currentCard = card;
    self.myTagArray = [TagPeer retrieveUserTagList];
    self.sysTagArray = [TagPeer retrieveSysTagListContainingCard:card];
    self.showExamplesCell = NO;
    
    // Add "add" button to nav bar
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addStudySet)];
    self.navigationItem.rightBarButtonItem = addButton;
    [addButton release];

    // For listening for headword direction changes
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:APP_HEADWORD_TYPE options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:APP_THEME options:NSKeyValueObservingOptionNew context:NULL];

    // Cache the tag's membership list
    self.membershipCacheArray = [[[TagPeer faultedTagsForCard:card] mutableCopy] autorelease];

    // Register listener to reload data if modal added a set
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tagContentDidChange:) name:LWETagContentDidChange object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadTableData) name:kSetWasAddedOrUpdated object:nil];
    
    // Set nav bar title
    self.navigationItem.title = NSLocalizedString(@"Add Card To Set",@"AddTagViewController.NavBarTitle");
  }
  return self;
}

- (id) initForExampleSentencesWithCard:(Card *)card
{
  if(self = [self initWithCard:card])
  {
    // Add the sentences for the card
    self.sentencesArray = [ExampleSentencePeer getExampleSentencesByCardId:card.cardId];
    if ([self.sentencesArray count] > 0) 
    {
      self.showExamplesCell = YES;
    }
    // Set nav bar title
    self.navigationItem.title = NSLocalizedString(@"Dictionary Entry",@"AddTagViewController.NavBarTitle");
  }
  return self;
}

#pragma mark - UIViewController methods

- (void) viewDidLoad
{
  [super viewDidLoad];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:APP_HEADWORD_TYPE] && self.tableView)
  {
    [self.tableView reloadData];
  }
  else if ([keyPath isEqualToString:APP_THEME] && self.navigationController.navigationBar)
  {
    self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  }
  else
  {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - Tag Content Did Change Methods

- (void) tagContentDidChange:(NSNotification *)notification
{
  // If the card that changed wasn't what we are currently showing, who cares?
  Card *card = [notification.userInfo objectForKey:LWETagContentDidChangeCardKey];
  if ([self.currentCard isEqual:card] == NO)
  {
    return;
  }
  
  // OK, it is our card, update the tag membership.
  Tag *changedTag = (Tag*)notification.object;
  NSString *type = [notification.userInfo objectForKey:LWETagContentDidChangeTypeKey];
  if ([type isEqualToString:LWETagContentCardAdded])
  {
    [self.membershipCacheArray addObject:changedTag];
  }
  else if ([type isEqualToString:LWETagContentCardRemoved])
  {
    [self.membershipCacheArray removeObject:changedTag];
  }
  [self.tableView reloadData];
}

#pragma mark - IBAction Methods

/** Target action for the Nav Bar "Add" button, launches AddStudySetInputViewController in a modal */
- (IBAction) addStudySet
{
#if defined (LWE_JUNIOR)
  // In JFlash & CFlash Junior we don't let them add their own study sets.  Instead we show the coffee modal.
  UpgradeAdViewController *tmpVC = [[UpgradeAdViewController alloc] initWithNibName:@"UpgradeAdViewController" bundle:nil];
#else
  AddStudySetInputViewController *tmpVC = [[AddStudySetInputViewController alloc] initWithDefaultCard:self.currentCard
                                                                                              inGroup:[GroupPeer topLevelGroup]];
#endif
  UINavigationController *modalNavController = [[UINavigationController alloc] initWithRootViewController:tmpVC];
	[tmpVC release];
  [self.navigationController presentViewController:modalNavController animated:YES completion:nil];
  [modalNavController release];
}

#pragma mark - Private Methods

//! Returns an array of sections for the table to use
- (NSArray*) sectionsArray
{
  if (self._sectionsArray == nil)
  {
    NSMutableArray* sectionsArray = [NSMutableArray arrayWithObject:@"kAddTagEntrySection"];
    if(self.showExamplesCell)
    {
      [sectionsArray addObject:@"kAddTagExampleSentenceSection"];
    }
    [sectionsArray addObjectsFromArray:[NSArray arrayWithObjects:@"kAddTagUserSection", @"kAddTagSystemSection", nil]];
    self._sectionsArray = sectionsArray;
  }
  return self._sectionsArray;
}

/**
 * Recreates tag membership caches and reloads table view, if a table view is loaded.
 * Otherwise (e.g. if this is called after a low-memory warning purges the table), it is a NOOP.
 */
- (void) _reloadTableData
{
  if (self.tableView)
  {
    self.myTagArray = [TagPeer retrieveUserTagList];
    self.membershipCacheArray = [[[TagPeer faultedTagsForCard:self.currentCard] mutableCopy] autorelease];
    [self.tableView reloadData];
  }
}

- (void) _toggleMembershipForTag:(Tag *)tmpTag
{
  // Check whether or not we are ADDING or REMOVING from the selected tag
  if ([self.membershipCacheArray containsObject:tmpTag])
  {
    // Remove tag
    NSError *error = nil;
    BOOL result = [TagPeer cancelMembership:self.currentCard fromTag:tmpTag error:&error];
    if (!result)
    {
      //something wrong, check whether it is the last card.
      if ([error code] == kRemoveLastCardOnATagError)
      {
        NSString *errorMessage = [error localizedDescription];
        [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Last Card in Set", @"AddTagViewController.AlertViewLastCardTitle")
                                           message:errorMessage];
      }
      else 
      {
        LWE_LOG_ERROR(@"[UNKNOWN ERROR]%@", error);
      }
      return;
    }
    [self.membershipCacheArray removeObject:tmpTag];
  }
  else
  {
    [TagPeer subscribeCard:self.currentCard toTag:tmpTag];
    [self.membershipCacheArray addObject:tmpTag];
  }
}

#pragma mark - LWEAudioQueue Delegate Methods

/*- (void)audioQueueBeginInterruption:(LWEAudioQueue *)audioQueue
{
  [audioQueue pause];
  self.pronounceBtn.enabled = YES;
}

- (void)audioQueueFinishInterruption:(LWEAudioQueue *)audioQueue withFlag:(LWEAudioQueueInterruptionFlag)flag
{
  //if the reason of interruption is whether the audio get deallocated
  //or something else happen besides the phone call/other trivia thing which
  //is better to get the audio play again
  if (flag == LWEAudioQueueInterruptionShouldResume)
  {
    [audioQueue play];
    self.pronounceBtn.enabled = NO;
  }
  else
  {
    self.pronounceBtn.enabled = YES;
  }
}

- (void)audioQueueDidFinishPlaying:(LWEAudioQueue *)audioQueue
{
  self.pronounceBtn.enabled = YES;
}

- (void)audioQueueWillStartPlaying:(LWEAudioQueue *)audioQueue
{
  self.pronounceBtn.enabled = NO;
}*/

#pragma mark - UITableViewDataSource Methods

//! Returns the total number of enum values in "Sections" enum
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [self.sectionsArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  NSInteger i = 0;
  if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagUserSection"])
  {
    i = [self.myTagArray count];
  }
  else if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagSystemSection"])
  {
    i = [self.sysTagArray count];  
  }
  else if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagEntrySection"])
  {
    i = kEntrySectionCount;
  }
  else if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagExampleSentenceSection"])
  {
    i = 0;
    if ([self.sentencesArray count] > 0)
    {
      i = 1;
    }
  }
  return i;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagEntrySection"])
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"entry" onTable:tableView usingStyle:UITableViewCellStyleDefault];
  }
  else if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagExampleSentenceSection"])
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"exampleSentence" onTable:tableView usingStyle:UITableViewCellStyleDefault];
  }
  else 
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"cell" onTable:tableView usingStyle:UITableViewCellStyleDefault];
  } 
  
  // setup the cell for the full entry
  if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagEntrySection"])
  {
    // Cell attributes
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // Don't re-add the same label
    UILabel *label = (UILabel*)[cell.contentView viewWithTag:101];
    if (label == nil)
    {
      label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
      label.tag = 101;
      label.lineBreakMode = NSLineBreakByWordWrapping;
      label.font = [UIFont systemFontOfSize:FONT_SIZE_ADD_TAG_VC];
      label.numberOfLines = 0;
      label.backgroundColor = [UIColor clearColor];
      [cell.contentView addSubview:label];
    }
    
    NSString *reading = nil;
#if defined(LWE_CFLASH)
    reading = [(ChineseCard *)currentCard pinyinReading];
#else
    reading = [self.currentCard reading];
#endif  
    label.text = [NSString stringWithFormat:@"[%@]\n%@", reading, [self.currentCard meaningWithoutMarkup]];
    [label adjustFrameWithFontSize:FONT_SIZE_ADD_TAG_VC
                         cellWidth:LWE_UITABLE_CELL_CONTENT_WIDTH
                        cellMargin:LWE_UITABLE_CELL_CONTENT_MARGIN];
  }
  else if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagExampleSentenceSection"])
  {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = NSLocalizedString(@"Example Sentences", @"Cell that displays example sentences");
  }
  // the cells for either tag type look the same
  else
  {        
    // Get the tag arrays
    Tag *tmpTag = nil;
    if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagUserSection"])
    {
      tmpTag = [self.myTagArray objectAtIndex:indexPath.row];
      cell.selectionStyle = UITableViewCellSelectionStyleGray;
      if ([self.membershipCacheArray containsObject:tmpTag])
      {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
      else
      {
        cell.accessoryType = UITableViewCellAccessoryNone;
      }
    }
    else if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagSystemSection"])
    {
      tmpTag = [self.sysTagArray objectAtIndex:indexPath.row];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.textLabel.text = tmpTag.tagName;
  }
  
  return cell;
}


#pragma mark - UITableViewDelegate methods

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagEntrySection"])
  {
    UIView *containingView = [[[UIView alloc] init] autorelease];
    containingView.autoresizesSubviews = NO;
    UILabel *headword = [[[UILabel alloc] initWithFrame:CGRectMake(15, 5, 300, 50)] autorelease];
    headword.text = [self.currentCard headwordIgnoringMode:YES];
    headword.backgroundColor = [UIColor clearColor];
    headword.shadowColor = [UIColor whiteColor];
    headword.shadowOffset = CGSizeMake(0.5f,1.0f);
    headword.textColor = [UIColor colorWithRed:0.3f green:0.3f blue:0.4f alpha:1.0f];
    headword.font = [UIFont boldSystemFontOfSize:24];
#if defined (LWE_CFLASH)
    headword.font = [ChineseCard configureFontForLabel:headword];
#endif
    [containingView addSubview:headword];
    return containingView;
  }
  else
  {
    // Use the method below and let UI kit do the hard work
    return nil;
  }
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagEntrySection"])
  {
    return 50.0f;
  }
  else if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagExampleSentenceSection"])
  {
    if (self.showExamplesCell == YES)
    {
      return 22.0f;
    }
    return 0.0f;
  }
  else
  {
    return 44.0f;
  }
}

-(NSString*) tableView: (UITableView*) tableView titleForHeaderInSection:(NSInteger)section
{
  if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagUserSection"])
  {
    return NSLocalizedString(@"My Sets",@"AddTagViewController.TableHeader_MySets");
  }
  else if ([[self.sectionsArray objectAtIndex:section] isEqualToString:@"kAddTagSystemSection"] && ([self.sysTagArray count] > 0))
  {
    return NSLocalizedString(@"Other Sets with this Card",@"AddTagViewController.TableHeader_AllSets");
  }
  else
  {
    return nil;
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
  if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagEntrySection"])
  {
    NSString *text = [NSString stringWithFormat:@"[%@]\n%@", [self.currentCard reading], [self.currentCard meaningWithoutMarkup]];
    return [LWEUITableUtils autosizeHeightForCellWithText:text];
  }
  else if (self.showExamplesCell == NO && [[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagExampleSentenceSection"])
  {
    return 0.0f;
  }
  else 
  {
    return 44.0f;
  }
}


/**
 * Called when the user selects one of the table rows containing a tag name
 * Calls subscribe or cancel set membership accordingly
 */
- (void)tableView:(UITableView *)lclTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [lclTableView deselectRowAtIndexPath:indexPath animated:NO];
  
  // do nothing for the entry section or system tags
  if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagEntrySection"] || [[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagSystemSection"])
  {
    return;
  }
  
  if ([[self.sectionsArray objectAtIndex:indexPath.section] isEqualToString:@"kAddTagExampleSentenceSection"])
  {
    DisplaySearchedSentenceViewController* sentenceVC = [[DisplaySearchedSentenceViewController alloc] initWithSentences:self.sentencesArray];
    [self.navigationController pushViewController:sentenceVC animated:YES];
    [sentenceVC release];
    return;
  }

  Tag *tmpTag = [self.myTagArray objectAtIndex:indexPath.row];
  [self _toggleMembershipForTag:tmpTag];
  
  // MMA: TODO: we shouldn't reload the whole table, that's really lazy-- we should change the row
  [lclTableView reloadData];
}


#pragma mark - Class plumbing

//! Standard dealloc
- (void)dealloc
{
  // Remove all observers
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:APP_HEADWORD_TYPE];
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:APP_THEME];
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  self.myTagArray = nil;
  self.sysTagArray = nil;
  self.currentCard = nil;
  self.membershipCacheArray = nil;
  self.sentencesArray = nil;
  self._sectionsArray = nil;
  [super dealloc];
}


#pragma mark - Modal dismissal

- (IBAction) dismissModal:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end