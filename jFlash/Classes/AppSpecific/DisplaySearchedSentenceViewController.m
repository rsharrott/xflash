//
//  DisplaySearchedSentenceViewController.m
//  jFlash
//
//  Created by Mark Makdad on 6/13/10.
//  Copyright 2010 Long Weekend Inc. All rights reserved.
//

#import "DisplaySearchedSentenceViewController.h"


/**
 * Basic View Controller that loads a nib and shows a sentence in that display
 */
@implementation DisplaySearchedSentenceViewController

@synthesize cards, sentenceArray;

- (id) initWithSentences:(NSArray*) sentences
{
  // TODO: iPad customization!
  if ((self = [super initWithNibName:@"SentenceView" bundle:nil]))
  {
    self.sentenceArray = sentences;
    self.cards = [NSMutableArray array];

    // get the related cards
    for (ExampleSentence *sentence in self.sentenceArray)
    {
      NSArray *relatedCards = [CardPeer retrieveCardSetForExampleSentenceId:[sentence sentenceId]];
      [self.cards addObject:relatedCards];
    }
    [self setTitle:NSLocalizedString(@"Examples",@"DisplaySearchedSentenceViewController.NavBarTitle")];
  }
  return self;
}


/** Handles theming the nav bar */
- (void)viewWillAppear:(BOOL)animated
{
  // View related stuff
  [super viewWillAppear:animated];
  // TODO: iPad customization!
  self.navigationController.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:LWETableBackgroundImage]];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  self.tableView.backgroundColor = [UIColor clearColor];
}

#pragma mark - UITableView delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [self.sentenceArray count];
}

// Show number of cards + 1 row for the sentence itself
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[self.cards objectAtIndex:section] count] + 1;
}


//! Returns title based on section - if sentence section, none, if cards, show "Linked Cards" or something similar
-(NSString*) tableView: (UITableView*) tableView titleForHeaderInSection:(NSInteger)section
{
  // TODO: Determine if this method implementation is even necessary - MMA - 6/7/2012
  return @"";
}


//! Returns custom height for sentence, otherwise fixed for cards (44px)
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
  if (indexPath.row == SENTENCE_ROW)
  {
    ExampleSentence *sentence = [self.sentenceArray objectAtIndex:indexPath.section];
    NSString *text = [NSString stringWithFormat:@"%@\n%@", [sentence sentenceJa], [sentence sentenceEn]];
    return [LWEUITableUtils autosizeHeightForCellWithText:text];
  }
  else
  {
    return 44.0f;
  }
}

//! Gets the cells for each section - static cell for sentence section
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  if(indexPath.row == SENTENCE_ROW)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"sentence" onTable:tableView usingStyle:UITableViewCellStyleDefault];
  }
  else
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"card" onTable:tableView usingStyle:UITableViewCellStyleSubtitle];
  } 
  
  // setup the cell for the full entry
  if(indexPath.row == SENTENCE_ROW)
  {
    ExampleSentence* sentence = [self.sentenceArray objectAtIndex:indexPath.section];
    NSString* text = [NSString stringWithFormat:@"%@\n%@", [sentence sentenceJa], [sentence sentenceEn]];

    // Don't re-add the same label
    UILabel *label = (UILabel*)[cell.contentView viewWithTag:101];
    if (label == nil)
    {
      label = [[UILabel alloc] initWithFrame:CGRectZero];
      label.tag = 101;
      [label setLineBreakMode:NSLineBreakByWordWrapping];
      [label setMinimumFontSize:LWE_UITABLE_CELL_FONT_SIZE];
      [label setNumberOfLines:0];
      label.backgroundColor = [UIColor clearColor];
      [label setFont:[UIFont systemFontOfSize:LWE_UITABLE_CELL_FONT_SIZE]];
      [[cell contentView] addSubview:label];
      [label release];
    }
    [label setText:text];
    [label adjustFrameWithFontSize:LWE_UITABLE_CELL_FONT_SIZE
                         cellWidth:LWE_UITABLE_CELL_CONTENT_WIDTH
                        cellMargin:LWE_UITABLE_CELL_CONTENT_MARGIN];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
  }
  // the cells for either tag type look the same
  else
  {
    Card *card = nil;
    NSArray *cardArray = [self.cards objectAtIndex:indexPath.section];
    card = [cardArray objectAtIndex:indexPath.row - 1];
    // Is a search result record
    cell.textLabel.text = [card headwordIgnoringMode:YES];
    cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    NSString *readingStr = [card reading];
    
    if (readingStr.length > 0)
    {
      cell.detailTextLabel.text = readingStr;
    }
  }
  return cell;
}


//! Loads AddTagViewController for any card (not sentence)     
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row == SENTENCE_ROW)
  {
    return; // do nothing for the entry
  }
  
  // Launch AddTagViewController for this card
  Card *card = [[self.cards objectAtIndex:indexPath.section] objectAtIndex:indexPath.row - 1];
  [card hydrate]; // need to fill the meaning field
  AddTagViewController *tagController = [[AddTagViewController alloc] initForExampleSentencesWithCard:card];
  [self.navigationController pushViewController:tagController animated:YES];
  [tagController release];
}

#pragma mark - Class plumbing

//! Standard dealloc
- (void)dealloc
{
  self.sentenceArray = nil;
  [self setCards:nil];
  [super dealloc];
}


@end
