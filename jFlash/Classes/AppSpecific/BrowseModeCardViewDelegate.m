//
//  BrowseModeCardViewDelegate.m
//  jFlash
//
//  Created by シャロット ロス on 6/1/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "BrowseModeCardViewDelegate.h"

#import "CardViewController.h"
#import "ActionBarViewController.h"
#import "StudyViewController.h"

//! The id's bucket is the level a later move has to find. A missed user_history read leaves 0.
static void LWECarryLevelForCard(Tag *tag, Card *card)
{
  if (card == nil)
  {
    return;
  }
  NSNumber *cardId = [NSNumber numberWithInteger:card.cardId];
  NSInteger count = (NSInteger)[tag.cardsByLevel count];
  for (NSInteger level = 0; level < count; level++)
  {
    if ([[tag.cardsByLevel objectAtIndex:level] containsObject:cardId])
    {
      card.levelId = level;
      return;
    }
  }
}

//! Browse stores card ids. Load the full card only for the one about to be shown.
static Card *LWECardForBrowseEntry(Tag *tag, id entry)
{
  Card *card = nil;
  if ([entry isKindOfClass:[NSNumber class]])
  {
    card = [CardPeer hydratedCardWithId:[entry integerValue]];
  }
  else
  {
    card = entry;
    if (card.isFault)
    {
      [card hydrate];
    }
  }
  LWECarryLevelForCard(tag, card);
  return card;
}

@implementation BrowseModeCardViewDelegate

#pragma mark - CardViewControllerDelegate Methods

//! This method will be called when the cardViewController enters browse mode.
- (void) cardViewDidChangeMode:(CardViewController*)cardViewController
{
  // You can't tap the HH in browse mode.
  [cardViewController.moodIcon setButtonEnabled:NO];
  
  // We never want to see "% correct" in browse mode
  [cardViewController.moodIcon turnPercentCorrectOff];
  
  // Reading should start as "on" in browse mode no matter what
  cardViewController.readingVisible = YES;
}

//! This method will be called when the cardViewController will set up a new card.
- (void)cardViewWillSetup:(CardViewController*)cardViewController
{
  [cardViewController resetReadingVisibility];
}

#pragma mark StudyViewControllerDelegate Methods

- (UIViewController<StudyViewSubcontrollerProtocol> *)cardViewControllerForStudyView:(StudyViewController *)svc
{
  BOOL useMainHeadword = [[[NSUserDefaults standardUserDefaults] objectForKey:APP_HEADWORD] isEqualToString:SET_J_TO_E];
	CardViewController *tmpCVC = [[CardViewController alloc] initDisplayMainHeadword:useMainHeadword];
  // This class isn't just a delegate for SVC, it's also the card view controller's delegate!
  tmpCVC.delegate = self;
  return [tmpCVC autorelease];
}

- (UIViewController<StudyViewSubcontrollerProtocol> *)actionBarViewControllerForStudyView:(StudyViewController *)svc
{
  ActionBarViewController *tmpABVC = [[ActionBarViewController alloc] initWithNibName:@"ActionBarViewController-Browse" bundle:nil];
  tmpABVC.delegate = self;
  return [tmpABVC autorelease];
}

//! This method will be called when StudyViewController will set up a new card.
- (void) studyViewWillSetup:(StudyViewController*)svc
{
  // TODO: Note that our delegate here is making decisions about example sentences
  // even though ex sentences have nothing to do with the card view controller (and only have to
  // do with SVC because of the scrollView & pageControl (MMA - 11.14.2011)
  
	// In browse mode, scroll view should be enabled if the example sentences view is available
  BOOL hasExampleSentences = [svc hasExampleSentences];
  svc.scrollView.pagingEnabled = hasExampleSentences; 
  svc.scrollView.scrollEnabled = hasExampleSentences;
}

//! This method will be called when StudyViewController needs its labels updated
- (void) updateStudyViewLabels:(StudyViewController *)svc
{
  // Set the remainingCardsLabel based on the currentIndex (browse mode)
  NSInteger currIndex = svc.currentCardSet.currentIndex + 1;
  NSInteger total = svc.currentCardSet.cardCount;
  svc.remainingCardsLabel.text = [NSString stringWithFormat:@"%d / %d",currIndex,total];
  svc.cardSetLabel.text = [svc.currentCardSet displayName];
  
  // These buttons should be hidden at all times in browse mode.
  svc.tapForAnswerImage.hidden = YES;
  svc.revealCardBtn.hidden = YES;
}

- (Card *)getNextCard:(Tag*)cardSet afterCard:(Card*)currentCard direction:(NSString*)directionOrNil
{
  Card *nextCard = nil;
  if (currentCard == nil)
  {
    // If currentCard == nil, this is the "first card" -- use whatever the value of currentIndex is
    LWE_ASSERT_EXC((cardSet.currentIndex < [cardSet.flattenedCardIdArray count]), @"the currentIndex is out of bounds?");
    nextCard = LWECardForBrowseEntry(cardSet, [cardSet.flattenedCardIdArray objectAtIndex:cardSet.currentIndex]);
  }
  else
  {
    // We already have a card, so get the next card based on the current index
    if (directionOrNil == kCATransitionFromLeft) // if we are coming from the left, get the previous card
    {
      if (cardSet.currentIndex == 0)
      {
        cardSet.currentIndex = ([cardSet.flattenedCardIdArray count] - 1);
      }
      else
      {
        cardSet.currentIndex--;
      }
    }
    else // if we are coming from the right or don't know, get the next card
    {
      if (cardSet.currentIndex >= ([cardSet.flattenedCardIdArray count] - 1))
      {
        cardSet.currentIndex = 0;
      }
      else 
      {
        cardSet.currentIndex++;
      }
    }
    
    // OK, we've updated currentIndex, get the new card
    nextCard = LWECardForBrowseEntry(cardSet, [cardSet.flattenedCardIdArray objectAtIndex:cardSet.currentIndex]);
  }
  return nextCard;
}

#pragma mark - ActionBarViewControllerDelegate Methods

- (void) actionBarDidChangeMode:(ActionBarViewController *)avc
{
}

@end