//
//  PracticeModeCardViewDelegate.m
//  jFlash
//
//  Created by シャロット ロス on 6/1/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "PracticeModeCardViewDelegate.h"

#import "CardViewController.h"
#import "ActionBarViewController.h"
#import "StudyViewController.h"

#define kLWETimesToRetryForNonRecentCardId 3

@interface PracticeModeCardViewDelegate()
@property (nonatomic, assign) BOOL alreadyShowedLearnedAlert;
- (Card *) _randomCardInTag:(Tag *)tag currentCard:(Card *)currentCard error:(NSError **)error;
@end

@implementation PracticeModeCardViewDelegate

@synthesize currentPercentageCorrect;
@synthesize alreadyShowedLearnedAlert;
@synthesize lastFiveCards, cardSelector;

#pragma mark - Plumbing

- (id) init
{
  self = [super init];
  if (self)
  {
    self.currentPercentageCorrect = 100.0f;
    self.lastFiveCards = [NSMutableArray array];
    self.cardSelector = [[[PracticeCardSelector alloc] init] autorelease];
  }
  return self;
}

- (void) dealloc
{
  [cardSelector release];
  [lastFiveCards release];
  [super dealloc];
}

#pragma mark - Card View Controller Delegate

- (void) cardViewDidChangeMode:(CardViewController *)cardViewController
{
  // You can tap the HH in practice mode.
  [cardViewController.moodIcon setButtonEnabled:YES];
  
  // Show the percent correct when in practice mode
  [cardViewController.moodIcon turnPercentCorrectOn];
}

- (void)cardViewWillSetup:(CardViewController*)cardViewController
{
  // always start with the meaning hidden, reset the reading to whatever state it should be
  cardViewController.meaningWebViewContainer.hidden = YES;
  [cardViewController resetReadingVisibility];

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  BOOL useMainHeadword = [[settings objectForKey:APP_HEADWORD] isEqualToString:SET_J_TO_E];
  if (useMainHeadword == NO)
  {
    cardViewController.toggleReadingBtn.hidden = YES;
    cardViewController.readingScrollContainer.hidden = YES;
    cardViewController.readingVisible = NO;
  }
  else
  {
    // set the toggleReadingBtn to not hidden for other modes,
    // if this is not here the button can be missing in practice mode
    cardViewController.toggleReadingBtn.hidden = NO;
  }
  
  [cardViewController.moodIcon updateMoodIcon:self.currentPercentageCorrect];
  [cardViewController.moodIcon turnPercentCorrectOn];
}

- (BOOL)shouldRevealCardView:(CardViewController *)cvc
{
  // We always want to reveal in practice mode
  return YES;
}

- (void)cardViewDidReveal:(CardViewController*)cardViewController
{
  cardViewController.meaningWebViewContainer.hidden = NO;
  [cardViewController turnReadingOn];
}


#pragma mark - StudyViewControllerDelegate Methods

- (Card *) getNextCard:(Tag*)cardSet afterCard:(Card*)currentCard direction:(NSString*)directionOrNil
{
  NSError *error = nil;
  Card *nextCard = [self _randomCardInTag:cardSet currentCard:currentCard error:&error];
  
  // If necessary, tell the user they've learned this set
  if ((nextCard.levelId == kLWELearnedCardLevel) && (error.code == kAllBuriedAndHiddenError))
  {
    if (self.alreadyShowedLearnedAlert == NO)
    {
      [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Study Set Learned", @"Study Set Learned")
                                         message:NSLocalizedString(@"Congratulations! You've already learned this set. We will show cards that would usually be hidden.",@"Congratulations! You've already learned this set. We will show cards that would usually be hidden.")
                                        delegate:self];
      self.alreadyShowedLearnedAlert = YES;
    }
  }
  else if (self.alreadyShowedLearnedAlert)
  {
    // This is used to "reset" the alert in the case that they had them all learned, and then got one wrong.
    self.alreadyShowedLearnedAlert = NO;
  }
  return nextCard;
}

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
  ActionBarViewController *tmpABVC = [[ActionBarViewController alloc] initWithNibName:@"ActionBarViewController" bundle:nil];
  tmpABVC.delegate = self;
  return [tmpABVC autorelease];
}

- (void) studyViewWillSetup:(StudyViewController*)svc
{
  // If practice mode, show the quiz stuff.  The faint "TAP FOR ANSWER" image in the middle
  // of the card is no longer shown -- the answer bar has a "Show answer" button instead.
#if defined(LWE_JFLASH)
  svc.tapForAnswerImage.hidden = YES;
#else
  svc.tapForAnswerImage.hidden = NO;
#endif
  svc.revealCardBtn.hidden = NO;

	// In practice mode, scroll view should always start disabled!
  svc.scrollView.pagingEnabled = NO;
  svc.scrollView.scrollEnabled = NO;
}

- (void) studyViewWillReveal:(StudyViewController *)svc
{
  svc.revealCardBtn.hidden = YES;
  svc.tapForAnswerImage.hidden = YES;
  
  // Now update scrollability (page control doesn't change)
  BOOL hasExampleSentences = [svc hasExampleSentences];
  svc.scrollView.pagingEnabled = hasExampleSentences; 
  svc.scrollView.scrollEnabled = hasExampleSentences;
}

- (void) updateStudyViewLabels:(StudyViewController*)svc
{
  NSInteger unseen = [[svc.currentCardSet.cardLevelCounts objectAtIndex:0] intValue];
  NSInteger total = svc.currentCardSet.cardCount;
  svc.remainingCardsLabel.text = [NSString stringWithFormat:@"%d / %d",unseen,total];
  svc.cardSetLabel.text = svc.currentCardSet.tagName;
  
  // Update mood icon percentage (TODO: this is a hack, we have it as a 
  // local property and then update it when cardViewWillSetup: is called)
  // The problem here is that SVC has "knowledge" of right & wrong counts, even
  // though it should be mode agnostic.
  CGFloat tmpRatio = 100;
  if (svc.numViewed > 0)
  {
    tmpRatio = 100*((CGFloat)svc.numRight / (CGFloat)svc.numViewed);
  }
  self.currentPercentageCorrect = tmpRatio;
}

#pragma mark - Action Bar Delegate Methods

- (void)actionBarDidChangeMode:(ActionBarViewController *)avc
{
}

-(void) actionBarWillSetup:(ActionBarViewController*)avc
{
  avc.rightBtn.hidden = YES;
  avc.wrongBtn.hidden = YES;
  if (avc.showAnswerBtn)
  {
    // New answer bar, before reveal: one "Show answer" button covering the area of the
    // Actions / Bury / Wrong / Right grid it is replaced by, so nothing moves on reveal.
    // Hidden buttons are also hidden from VoiceOver.
    for (UIView *v in @[avc.showAnswerBtn, avc.rightBtn, avc.wrongBtn, avc.buryCardBtn, avc.addBtn])
    {
      [v.layer removeAllAnimations];
      v.alpha = 1.0;
    }
    avc.showAnswerBtn.hidden = NO;
    avc.showAnswerBtn.userInteractionEnabled = YES;
    avc.showAnswerBtn.accessibilityElementsHidden = NO;
    avc.buryCardBtn.hidden = YES;
    avc.addBtn.hidden = YES;
    avc.cardMeaningBtnHint.hidden = YES;
  }
  else
  {
    avc.buryCardBtn.hidden = YES;
    avc.addBtn.hidden = YES;
    avc.cardMeaningBtnHint.hidden = NO;
  }
}

-(void) actionBarWillReveal:(ActionBarViewController*)avc
{
  if (avc.showAnswerBtn && avc.showAnswerBtn.hidden == NO)
  {
    // Short cross-fade from "Show answer" to the 2x2 grid (same frame, so nothing moves).
    UIButton *show = avc.showAnswerBtn;
    NSArray *grid = @[avc.rightBtn, avc.wrongBtn, avc.buryCardBtn, avc.addBtn];
    show.userInteractionEnabled = NO;
    show.accessibilityElementsHidden = YES;
    for (UIView *v in grid) { v.alpha = 0.0; v.hidden = NO; }
    avc.cardMeaningBtnHint.hidden = YES;
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
      for (UIView *v in grid) v.alpha = 1.0;
      show.alpha = 0.0;
    } completion:^(BOOL finished) {
      // Only finish the hand-over if the next card hasn't set up "Show answer" again meanwhile.
      if (show.accessibilityElementsHidden)
      {
        show.hidden = YES;
        show.alpha = 1.0;
      }
    }];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, avc.wrongBtn);
    return;
  }
  avc.rightBtn.hidden = NO;
  avc.wrongBtn.hidden = NO;
  avc.buryCardBtn.hidden = NO;
  avc.addBtn.hidden = NO;
  avc.showAnswerBtn.hidden = YES;
  avc.cardMeaningBtnHint.hidden = YES;
  if (avc.showAnswerBtn)
  {
    // Show answer was replaced by Wrong / Right (and Actions / Bury appeared): move VoiceOver to Wrong.
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, avc.wrongBtn);
  }
}

#pragma mark - Get Random Card

/**
 * Returns a Card object from the database randomly
 * Accepts current cardId in an attempt to not return the last card again
 */
- (Card*) _randomCardInTag:(Tag *)tag currentCard:(Card *)currentCard error:(NSError **)error
{
  LWE_ASSERT_EXC(([tag.cardsByLevel count] == 6),@"Card IDs must have 6 array levels");
  
  Card *randomCard = nil;
  
  // determine the next level
  NSError *theError = nil;
  NSInteger nextLevelId = [self.cardSelector calculateNextCardLevelForTag:tag error:&theError];
  if ((nextLevelId == kLWELearnedCardLevel) &&
      (theError.domain == kTagErrorDomain) &&
      (theError.code == kAllBuriedAndHiddenError))
  {
    if (error != NULL)
    {
      *error = theError;
    }
  }
  
  // Get a random card offset
  NSMutableArray *cardArray = [tag.cardsByLevel objectAtIndex:nextLevelId];
  NSInteger numCardsAtLevel = [cardArray count];
  LWE_ASSERT_EXC((numCardsAtLevel > 0),@"We've been asked for cards at level %d but there aren't any.",nextLevelId);
  NSInteger randomOffset = arc4random() % numCardsAtLevel;
  randomCard = [cardArray objectAtIndex:randomOffset];
  
  // this is a simple queue of the last five cards
  if (currentCard)
  {
    [self.lastFiveCards addObject:currentCard];
  }
  
  if ([self.lastFiveCards count] == NUM_CARDS_IN_NOT_NEXT_QUEUE)
  {
    [self.lastFiveCards removeObjectAtIndex:0];
  }
  
  // prevent getting the same card twice.
  NSInteger i = 0; // counts how many times we whiled against the array
  NSInteger j = 0; // second iterator to count tries that return the same card as before
  while ([self.lastFiveCards containsObject:randomCard])
  {
    LWE_LOG(@"Got the same card as last time");
    // If there is only one card left (this card) in the level, let's get a different level
    
    if (numCardsAtLevel == 1)
    {
      LWE_LOG(@"Only one card left in this level, getting a new level");
      // Try up five times to get a different level
      NSInteger lastNextLevel = nextLevelId;
      for (NSInteger j = 0; j < 5; j++)
      {
        nextLevelId = [self.cardSelector calculateNextCardLevelForTag:tag error:NULL];
        if (nextLevelId != lastNextLevel)
        {
          break;
        }
      }
    }

    // now get a different card randomly
    cardArray = [tag.cardsByLevel objectAtIndex:nextLevelId];
    NSInteger numCardsAtLevel2 = [cardArray count];
    LWE_ASSERT_EXC((numCardsAtLevel2 > 0),@"We've been asked for cards at level %d but there aren't any.",nextLevelId);
    randomOffset = arc4random() % numCardsAtLevel2;
    randomCard = [cardArray objectAtIndex:randomOffset];      
    
    i++;
    if (i > kLWETimesToRetryForNonRecentCardId)
    {
      // the same card is worse than a card that was twice ago, so we check again that it's not that
      if (j == kLWETimesToRetryForNonRecentCardId || ([currentCard isEqual:randomCard] == NO))
      {
        break; //we tried 3 times, fuck it
      }
      j++;
    }
  }
  
  if (randomCard.isFault)
  {
    [randomCard hydrate];
  }
  return randomCard;
}

@end