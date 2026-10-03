//
//  StudyViewController.m
//  jFlash
//
//  Created by シャロット ロス on 5/4/09.
//  Copyright LONG WEEKEND INC 2009. All rights reserved.
//

#import "jFlashAppDelegate.h"
#import "CurrentState.h"
#import "SettingsViewController.h"
#import "StudyViewController.h"
#import "LWENetworkUtils.h"
#import "AddTagViewController.h"
#import "UpdateManager.h"
#import "CardViewController.h"

@interface StudyViewController()
//private methods
- (void) _applicationDidEnterBackground:(NSNotification*)notification;
- (void) _contentSizeCategoryDidChange:(NSNotification*)notification;
- (BOOL) _shouldShowExampleViewForCard:(Card*)card;
- (BOOL) _shouldShowSampleAudioButtonForCard:(Card*)card;
- (void) _tagContentDidChange:(NSNotification*)notification;
- (void) _setupScrollView;
- (void)_setupPageControl:(NSInteger)page;
- (void) _setupDelegateForStudyMode:(NSString*)studyMode;
- (void) _setupSubviews;
- (Card*) _getNextCardWithDirection:(NSString*)directionOrNil currentCard:(Card *)theCurrentCard;
@end

@implementation StudyViewController
@synthesize delegate;
@synthesize pluginManager;
@synthesize currentCard, currentCardSet, remainingCardsLabel;
@synthesize progressBarViewController, progressBarView;
@synthesize numRight, numWrong, numViewed, cardSetLabel;
@synthesize practiceBgImage, currentRightStreak, currentWrongStreak, cardViewController, cardView;
@synthesize scrollView, pageControl, exampleSentencesViewController, showProgressModalBtn;
@synthesize actionBarController, actionbarView, revealCardBtn, tapForAnswerImage;
@synthesize progressDetailsViewController;
@synthesize pronounceBtn = pronounceBtn;

#define LWE_EX_SENTENCE_INSTALLER_VIEW_TAG 69

#pragma mark - LWEAudioQueue Delegate Methods

- (void)audioQueueBeginInterruption:(LWEAudioQueue *)audioQueue
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
}

#pragma mark - UIView Delegate Methods

/**
 * On viewDidAppear, show Alert Views if it is first launch
 */
- (void) viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  // Show a UIAlert if this is the first time the user has launched the app.  
  CurrentState *state = [CurrentState sharedCurrentState];
  if (state.isFirstLoad && _alreadyShowedAlertView == NO)
  {
    _alreadyShowedAlertView = YES;
#if defined (LWE_JFLASH)
    [LWEUIAlertView confirmationAlertWithTitle:NSLocalizedString(@"Welcome to Japanese Flash!",@"StudyViewController.WelcomeAlertViewTitle")
                                       message:NSLocalizedString(@"We've loaded our favorite word set to get you started.\n\nTo study other sets, tap the 'Study Sets' tab below.\n\nLike Japanese Flash? Checkout Rikai Browser: Reading Japanese on your iPhone just got easier!",@"RootViewController.WelcomeAlertViewMessage")
                                            ok:NSLocalizedString(@"Later", @"StudyViewController.Later")
                                        cancel:NSLocalizedString(@"Get Rikai", @"WebViewController.RikaiAppStore")
                                      delegate:self];
#elif (LWE_CFLASH)
    [LWEUIAlertView confirmationAlertWithTitle:NSLocalizedString(@"Welcome to Chinese Flash!",@"StudyViewController.WelcomeAlertViewTitle")
                                       message:NSLocalizedString(@"We've loaded our favorite word set to get you started.\n\nIf you want to study other sets, tap the 'Study Sets' tab below.",@"RootViewController.WelcomeAlertViewMessage")
                                            ok:NSLocalizedString(@"OK", @"StudyViewController.OK")
                                        cancel:nil
                                      delegate:nil];
#endif
  }
  else if (state.isFirstLaunchAfterUpdate && _alreadyShowedAlertView == NO)
  {
    // The update manager will handle showing the proper message based on which app & which version
    [UpdateManager showUpgradeAlertView:[NSUserDefaults standardUserDefaults] delegate:self];
    _alreadyShowedAlertView = YES;
  }
}

- (void)viewSafeAreaInsetsDidChange
{
  [super viewSafeAreaInsetsDidChange];
  [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];

  // Position progress bar and scroll view from the live safe area insets so
  // the layout is correct regardless of what triggered this pass (initial load,
  // safe area change, tag change, modal dismiss, etc.).
  if (@available(iOS 11.0, *)) {
    CGFloat top = self.view.safeAreaInsets.top;
    CGFloat progressBottom = top + self.progressBarView.bounds.size.height;

    CGRect pf = self.progressBarView.frame;
    pf.origin.y = top;
    self.progressBarView.frame = pf;
    self.showProgressModalBtn.frame = pf;

    CGFloat svBottom = CGRectGetMinY(self.actionbarView.frame);
    if (svBottom > progressBottom) {
      CGRect sv = self.scrollView.frame;
      sv.origin.y = progressBottom;
      sv.size.height = svBottom - progressBottom;
      self.scrollView.frame = sv;
    }
  }

  // Fix action bar VC view width (autoresizing won't fire if container was already at
  // final width when the view was added), then distribute buttons evenly.
  if (self.actionBarController) {
    CGRect f = self.actionBarController.view.frame;
    f.size.width = self.actionbarView.bounds.size.width;
    self.actionBarController.view.frame = f;
    if ([self.actionBarController respondsToSelector:@selector(distributeButtonsEvenly)]) {
      [(ActionBarViewController *)self.actionBarController distributeButtonsEvenly];
    }
  }

  // Fix progress bar VC view width for the same reason, then redraw.
  if (self.progressBarViewController) {
    CGRect f = self.progressBarViewController.view.frame;
    f.size.width = self.progressBarView.bounds.size.width;
    self.progressBarViewController.view.frame = f;
    if (self.progressBarViewController.tag) {
      [self.progressBarViewController drawProgressBar];
    }
  }

  // Lay out the card content to fill its container vertically.
  // Reading/headword sit near the top; webview fills remaining space to the mood icon.
  if (self.cardViewController && self.cardView.bounds.size.height > 0) {
    CGFloat containerW = self.cardView.bounds.size.width;
    CGFloat containerH = self.cardView.bounds.size.height;

    // Fill the full card area so the layout percentages in layoutCardSubviews
    // resolve to the intended on-screen positions (~30% from screen top for reading).
    self.cardViewController.view.frame = CGRectMake(0, 0, containerW, containerH);

    if ([self.cardViewController isKindOfClass:[CardViewController class]]) {
      CardViewController *cvc = (CardViewController *)self.cardViewController;

      // Apply internal card layout now that the view has its final bounds.
      [cvc layoutCardSubviews];

      // Move mood icon to cardView so it floats at the bottom-right of the red area
      // regardless of how the card VC view is sized.
      UIView *moodView = cvc.moodIcon.view;
      if (moodView && moodView.superview != self.cardView) {
        [[self.cardView viewWithTag:9001] removeFromSuperview];
        moodView.tag = 9001;
        [moodView removeFromSuperview];
        [self.cardView addSubview:moodView];
      }
      if (moodView) {
        CGFloat iconW = moodView.bounds.size.width;
        CGFloat iconH = moodView.bounds.size.height;
        moodView.frame = CGRectMake(
          containerW - iconW + 20.0,
          containerH - iconH - 8.0,
          iconW, iconH
        );
      }

      // Move the reveal button below the reading/headword area so the reading toggle
      // sits above it and can be tapped without triggering the definition reveal.
      if (self.revealCardBtn) {
        // readingY (25% of containerH) + readingH (42) + gap (4) + headwordH (55) + buffer (10)
        CGFloat headwordsBottom = roundf(containerH * 0.25) + 42.0 + 4.0 + 55.0 + 10.0;
        CGFloat revealTop = self.scrollView.frame.origin.y + headwordsBottom;
        CGRect rf = self.revealCardBtn.frame;
        rf.origin.y = revealTop;
        rf.size.height = MAX(100.0, self.view.bounds.size.height - revealTop);
        self.revealCardBtn.frame = rf;
      }
    }
  }

}

/**
 * This method sets up all of the non-nib stuff.
 * Observers are added for settings changes, plugins, etc.
 */
- (void) viewDidLoad
{
  [super viewDidLoad];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  // Setup block callback for when active tag changes or the user settings changed - resets study set
  [center addObserverForName:LWEActiveTagDidChange object:nil queue:nil usingBlock:^(NSNotification *notification)
   {
     [self changeStudySetToTag:(Tag *)notification.object];
   }];
  
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings addObserver:self forKeyPath:APP_MODE options:NSKeyValueObservingOptionNew context:NULL];
  [settings addObserver:self forKeyPath:APP_THEME options:NSKeyValueObservingOptionNew context:NULL];
  [settings addObserver:self forKeyPath:APP_HEADWORD options:NSKeyValueObservingOptionNew context:NULL];
  [settings addObserver:self forKeyPath:APP_HEADWORD_TYPE options:NSKeyValueObservingOptionNew context:NULL];
#if defined (LWE_CFLASH)
  [settings addObserver:self forKeyPath:APP_PINYIN_COLOR options:NSKeyValueObservingOptionNew context:NULL];
#elif defined (LWE_JFLASH)
  [settings addObserver:self forKeyPath:APP_KANA_ONLY options:NSKeyValueObservingOptionNew context:NULL];
  [settings addObserver:self forKeyPath:APP_READING options:NSKeyValueObservingOptionNew context:NULL];
#endif
  
  [center addObserver:self selector:@selector(pluginDidInstall:) name:LWEPluginDidInstall object:nil];
  [center addObserver:self selector:@selector(_tagContentDidChange:) name:LWETagContentDidChange object:nil];
  [center addObserver:self selector:@selector(_applicationDidEnterBackground:) name:UIApplicationWillTerminateNotification object:nil];
  [center addObserver:self selector:@selector(_contentSizeCategoryDidChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
  
  // Initialize the progressBarView
	ProgressBarViewController *tmpPBVC = [[ProgressBarViewController alloc] init];
  [self.progressBarView addSubview:tmpPBVC.view];
  self.progressBarViewController = tmpPBVC;
	[tmpPBVC release];

  // Initialize the scroll view
  [self _setupScrollView];
  
  [self setBackgroundColor_];
  
  // Load the active study set and be done!!
  [self changeStudySetToTag:[[CurrentState sharedCurrentState] activeTag]];
}

#pragma mark - UIAlertView delegate method

/**
 * We prompt users to get Rikai if it is JFlash.
 * This is the delegate method to handle the response of what the user taps.
 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  // not really a cancel button, just button two
  if (buttonIndex == LWE_ALERT_CANCEL_BTN)
  {
    LWENetworkUtils *tmpNet = [[LWENetworkUtils alloc] init];
    [tmpNet followLinkshareURL:@"http://click.linksynergy.com/fs-bin/stat?id=qGx1VSppku4&offerid=146261&type=3&subid=0&tmpid=1826&RD_PARM1=http%253A%252F%252Fitunes.apple.com%252Fus%252Fapp%252Fid380853144%253Fmt%253D8%2526uo%253D4%2526partnerId%253D30&u1=JFLASH_APP_WELCOME_MESSAGE"];
    [tmpNet release];
  }
}

#pragma mark - Public methods

/**
 * \brief   Changes to a new study set
 * \details Gets the active Tag from the CurrentState singleton and
 *          re-initializes the entire StudyViewController to a fresh set.
 *          Responsible for getting the first card out of the set and
 *          refreshing the views accordingly.
 */
- (void) changeStudySetToTag:(Tag *)newTag
{
  // Initialize all variables
  self.currentRightStreak = 0;
  self.currentWrongStreak = 0;
  self.numRight = 0;
  self.numWrong = 0;
  self.numViewed = 0;
  
  // remove the observer from the previous currentCardSet before getting the new one
  if (self.currentCardSet)
  {
    [self.currentCardSet removeObserver:self forKeyPath:@"tagName"];
  }
  
  // Tell the progress bars about this new tag
  self.progressDetailsViewController.tag = newTag;
  self.progressBarViewController.tag = newTag;

  // Get active set/tag & add an observer
  self.currentCardSet = newTag;
  [self.currentCardSet addObserver:self forKeyPath:@"tagName" options:NSKeyValueObservingOptionNew context:NULL];
  
  // Use this to set up delegates, show the card, etc
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSString *studyMode = [settings objectForKey:APP_MODE];
  [self _setupDelegateForStudyMode:studyMode];
  
  // Change to new card, by passing nil, there is no animation
  Card *nextCard = [self.delegate getNextCard:self.currentCardSet afterCard:nil direction:nil];
  [self doChangeCard:nextCard direction:nil];
}

#pragma mark - KVO Observer Method

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"tagName"]) 
  {
    self.cardSetLabel.text = [change objectForKey:NSKeyValueChangeNewKey];
  }
  else if ([keyPath isEqualToString:APP_MODE])
  {
    [self _setupDelegateForStudyMode:[change objectForKey:NSKeyValueChangeNewKey]];
    [self doChangeCard:self.currentCard direction:nil];
  }
  else if ([keyPath isEqualToString:APP_THEME])
  {
    [self setBackgroundColor_];
    [self _setupSubviews];
    [self doChangeCard:self.currentCard direction:nil];
  }
  else if ([keyPath isEqualToString:APP_HEADWORD])
  {
    // We need to setup the card view controller again
    [self _setupSubviews];
    [self doChangeCard:self.currentCard direction:nil];
  }
#if defined (LWE_CFLASH)
  else if ([keyPath isEqualToString:APP_PINYIN_COLOR] || [keyPath isEqualToString:APP_HEADWORD_TYPE])
  {
    [self doChangeCard:self.currentCard direction:nil];
  }
#elif defined (LWE_JFLASH)
  else if ([keyPath isEqualToString:APP_READING])
  {
    [self doChangeCard:self.currentCard direction:nil];
  }
  else if ([keyPath isEqualToString:APP_KANA_ONLY])
  {
    // Reload the current card from the database first so we get the right headword.
    self.currentCard = [CardPeer retrieveCardByPK:self.currentCard.cardId];
    [self doChangeCard:self.currentCard direction:nil];
  }
#endif
  else
  {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - Page Control

- (void)_setupPageControl:(NSInteger)page
{
  if ([self hasExampleSentences] == NO) // can't show the examples if there are none
  {
    page = 0;
    // Page control should be shown when we have example sentences
    self.pageControl.hidden = YES;
    self.scrollView.scrollEnabled = NO;
  }
  else
  {
    self.pageControl.hidden = NO;
    self.scrollView.scrollEnabled = YES;      
  }

  self.pageControl.currentPage = page;
  [self changePage:self.pageControl animated:NO];
  _isChangingPage = NO;
}

/**
 * \brief Basic method to change cards
 * \param card The Card object to move to
 * \param directionOrNil If direction is a CATransition type, animate
 */
- (void) doChangeCard:(Card*)card direction:(NSString*)directionOrNil
{
  if (card == nil)
  {
    return;
  }
  
  // Asks our delegate if it wants to change any of the details of the view (labels, etc)
  // Due to a hack in PracticeModeCardViewDelegate.m, this call MUST be before setupWithCard:.
  LWE_DELEGATE_CALL(@selector(updateStudyViewLabels:), self);

  // Sets up all of the sub-controllers of the study view controller.
  LWE_DELEGATE_CALL(@selector(studyViewWillSetup:),self);
  
  [self.cardViewController setupWithCard:card];
  [self.actionBarController setupWithCard:card];
  [self.exampleSentencesViewController setupWithCard:card];
           
  self.currentCard = card;
  
  // Sets up the page control (incl. determining if we have example sentences)
  [self _setupPageControl:0];

  // Show/Hide pronounce button depending on presence of plugin + sound for this file
  self.pronounceBtn.hidden = ([self _shouldShowSampleAudioButtonForCard:card] == NO);
  
  // If no direction, don't animate transition
  if (directionOrNil != nil)
  {
    [LWEViewAnimationUtils doViewTransition:kCATransitionPush direction:directionOrNil duration:0.15f objectToTransition:self];
  }
  
  // Finally, update the progress bar
  [self.progressBarViewController drawProgressBar];
}

- (IBAction)doCardBtn:(id)sender
{
  NSInteger action = [(UIButton *)sender tag];
  
  // Default to animation from the right.
  NSString *direction = kCATransitionFromRight;
	switch (action)
  {
    // Browse Mode options
    case NEXT_BTN: 
      break;
    case PREV_BTN:
      direction = kCATransitionFromLeft;
      break;
      
    case BURY_BTN:
      self.numRight++;
      self.numViewed++;
      self.currentRightStreak++;
      self.currentWrongStreak = 0;
      [UserHistoryPeer buryCard:self.currentCard inTag:self.currentCardSet];
      break;
      
    case RIGHT_BTN:
      self.numRight++;
      self.numViewed++;
      self.currentRightStreak++;
      self.currentWrongStreak = 0;
      [UserHistoryPeer recordCorrectForCard:self.currentCard inTag:self.currentCardSet];
      break;
      
    case WRONG_BTN:
      self.numWrong++;
      self.numViewed++;
      self.currentWrongStreak++;
      self.currentRightStreak = 0;
      [UserHistoryPeer recordWrongForCard:self.currentCard inTag:self.currentCardSet];
      break;      
  }
  
  // Get the next card and switch to it
  Card *nextCard = [self _getNextCardWithDirection:direction currentCard:self.currentCard];
  [self doChangeCard:nextCard direction:direction];
}


/**
 * Called when the user taps the progress bar at the top of the practice view
 * Launches the progress modal view in ProgressDetailsViewController
 */
- (IBAction)doShowProgressModalBtn
{
  // Bring up the modal dialog for progress view
  // TODO: iPad customization!
  if (self.progressDetailsViewController == nil)
  {
    self.progressDetailsViewController = [[[ProgressDetailsViewController alloc] initWithNibName:@"ProgressView" bundle:nil] autorelease];
  }
  self.progressDetailsViewController.tag = self.currentCardSet;
  self.progressDetailsViewController.rightStreak = self.currentRightStreak;
  self.progressDetailsViewController.wrongStreak = self.currentWrongStreak;
  self.progressDetailsViewController.cardsRightNow.text = [NSString stringWithFormat:@"%i", self.numRight];
  self.progressDetailsViewController.cardsWrongNow.text = [NSString stringWithFormat:@"%i", self.numWrong];
  self.progressDetailsViewController.cardsViewedNow.text = [NSString stringWithFormat:@"%i", self.numViewed];

  self.progressDetailsViewController.view.frame = self.parentViewController.view.frame;
  
  // Tell the modal to update its details
  [self.progressDetailsViewController updateView];
  
  // The parent is a nav bar controller, (tab bar in this case), so it will cover the whole view
  // We could use presentModalViewController, but then we lose the "see-through" ability with the views underneath.
  // There is a call to -removeFromSuperview inside the progress VC on dismiss.
  [self.view addSubview:self.progressDetailsViewController.view];
}


/**
 * Target for UIPageControl - allows us to flip between
 * card view and example sentence view
 */
- (IBAction)changePage:(id)sender animated:(BOOL)animated
{
  CGFloat xOffset = self.scrollView.frame.size.width * self.pageControl.currentPage;
  [self.scrollView setContentOffset:CGPointMake(xOffset, 0) animated:animated];
  
	// When the animated scrolling finishings, scrollViewDidEndDecelerating will turn this off
  _isChangingPage = YES;
}

//! convenience method for have the animated bool defalut to yes for Interface Builder
- (IBAction)changePage:(id)sender
{
  [self changePage:sender animated:YES];
}

/** Shows the meaning/reading */
- (IBAction) revealCard
{
  LWE_DELEGATE_CALL(@selector(studyViewWillReveal:), self);
  [self.cardViewController reveal];
  [self.actionBarController reveal];
}

- (IBAction) pronounceCard:(id)sender
{
#if defined(LWE_CFLASH)
  // We have to pass the plugin manager to each call so that Card knows what plugins (PINYIN, HSK) we have installed.
  if ([self.currentCard hasAudioWithPluginManager:self.pluginManager])
  {
    [self.currentCard pronounceWithDelegate:self pluginManager:self.pluginManager];
  }
  else
  {
    // Audio ships with the app. There is no online plugin to fetch.
  }
#endif
}

#pragma mark - Private methods to setup cards (called every transition)

- (Card*) _getNextCardWithDirection:(NSString*)directionOrNil currentCard:(Card *)theCurrentCard
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(getNextCard:afterCard:direction:)])
  {
    return [self.delegate getNextCard:self.currentCardSet afterCard:theCurrentCard direction:(NSString*)directionOrNil];
  }
  return theCurrentCard; // just keep the same card if the delegate cannot help us
}

/** 
 * Both page controller visibility setter and scroll view
 * enabler call this.  In the future, we don't want to 
 * hit the DB twice like we are now for the same card.
 */
- (BOOL) _shouldShowExampleViewForCard:(Card*)card
{
  // Default value is YES because if no plugin, we want to show the installer
  BOOL returnVal = YES;
  if ([self.pluginManager pluginKeyIsLoaded:EXAMPLE_DB_KEY])
  {
    returnVal = [card hasExampleSentencesWithPluginManager:self.pluginManager];
  }
  return returnVal;
}

/** 
 * Show the audio button if there plugin enabled and card has audio sample
 * Cards may have a "pieced together" sample, but Card class will take care of this
 */
- (BOOL) _shouldShowSampleAudioButtonForCard:(Card*)card
{
#if defined (LWE_CFLASH)
  BOOL returnVal = YES;
  if ([self.pluginManager pluginKeyIsLoaded:AUDIO_PINYIN_KEY] || [self.pluginManager pluginKeyIsLoaded:AUDIO_HSK_KEY])
  {
    returnVal = [card hasAudioWithPluginManager:self.pluginManager];
  }
  return returnVal;
#else
  return NO;
#endif
}

- (void) _tagContentDidChange:(NSNotification*)notification
{
  // First of all, we don't care if we're not talking about the active set, so quick return otherwise.
  if ([self.currentCardSet isEqual:(Tag*)notification.object] == NO)
  {
    return;
  }
  
  // Next check that we have a valid card to deal with
  Card *theCard = [notification.userInfo objectForKey:LWETagContentDidChangeCardKey];
  if (theCard == nil)
  {
    return;
  }
  // Unfortunately, this new setup isn't perfect yet.  We have a card, but it does NOT have a
  // levelId associated with it, because we retrieved it in a different, far off place that doesn't
  // care about level Ids.  So we need to re-get the card, sadly.  This should still be faster
  // than any other way around the problem... MMA - 18.Oct.2011
  [theCard hydrate];
  
  NSString *changeType = [notification.userInfo objectForKey:LWETagContentDidChangeTypeKey];
  if ([changeType isEqualToString:LWETagContentCardAdded])
  {
    [self.currentCardSet addCardToActiveSet:theCard];
    LWE_DELEGATE_CALL(@selector(updateStudyViewLabels:), self);
  }
  else if ([changeType isEqualToString:LWETagContentCardRemoved])
  {
    [self.currentCardSet removeCardFromActiveSet:theCard];
    if ([theCard isEqual:self.currentCard])
    {
      // Get a new card & change to it
      Card *nextCard = [self _getNextCardWithDirection:nil currentCard:self.currentCard];
      [self doChangeCard:nextCard direction:nil];
    }
    else
    {
      //It is smoother to just update the percentage, rather than the need to update the
      //whole view of the cards (the state will be changed as well like meaning label is hidden, etc)
      LWE_DELEGATE_CALL(@selector(updateStudyViewLabels:), self);
    }
  }
}

- (void) _setupDelegateForStudyMode:(NSString*)studyMode
{
  // TODO: Ideally this code wouldn't be part of the SVC, then it wouldn't need to (a) retain
  // its delegate, or (b) have specific knowledge of the name of every class/mode that it could be in.
  //=====================================
  // Set up our delegate based on mode
  if ([studyMode isEqualToString:SET_MODE_BROWSE])
  {
		self.delegate = [[[BrowseModeCardViewDelegate alloc] init] autorelease];
  }
  else
  {
		self.delegate = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  }
  
  // Now that we have a new delegate, re-init the subviews asking the delegate for VCs
  [self _setupSubviews];
  
  // Now send our new subcontrollers a message telling it we are using it
  [self.cardViewController studyViewModeDidChange:self];
  [self.actionBarController studyViewModeDidChange:self];  
}

- (void) _setupSubviews
{
  // Add the CardView to the View -- ask the delegate what controller we want
  if (self.delegate && [self.delegate respondsToSelector:@selector(cardViewControllerForStudyView:)])
  {
    // Remove any old view before setting a new one
    if (self.cardViewController)
    {
      [self.cardViewController.view removeFromSuperview];
    }
    
    // Set the new VC — keep natural XIB height; width fills container.
    // viewDidLayoutSubviews will center it vertically.
    self.cardViewController = [self.delegate cardViewControllerForStudyView:self];
    self.cardViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.cardView addSubview:self.cardViewController.view];
  }
  
  // Add the Action Bar View -- ask the delegate what controller we want
  if (self.delegate && [self.delegate respondsToSelector:@selector(actionBarViewControllerForStudyView:)])
  {
    if (self.actionBarController)
    {
      [self.actionBarController.view removeFromSuperview];
    }

    UIViewController<StudyViewSubcontrollerProtocol> *actionVC = [self.delegate actionBarViewControllerForStudyView:self];
    actionVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.actionbarView addSubview:actionVC.view];
    self.actionBarController = actionVC;
  }

  // New subcontrollers have just been swapped in at their NIB sizes.
  // Mark self.view as needing layout so viewDidLayoutSubviews runs and
  // resizes them to fill their containers correctly.
  [self.view setNeedsLayout];
}

#pragma mark - Plugin-Related

- (BOOL) hasExampleSentences
{
#if defined (LWE_JFLASH)
  // JFlash is currently the only code base with example sentences
  return [self _shouldShowExampleViewForCard:self.currentCard];
#else
  return NO;
#endif
}

/**
 * Connects the "Download Example Sentences" button to actually launch the installer
 * Kind of just a convenience method
 */
- (IBAction) launchExampleInstaller
{
  // Example sentences ship with the app; nothing is downloaded.
}

/**
 * Connects the "Play Audio" button to actually launch the installer
 * Kind of just a convenience method
 */
- (IBAction) launchAudioInstaller
{
  // Audio ships with the app; nothing is downloaded.
}

/** Called by notification when a plugin is installed - if it is Example sentences, handle that */
- (void)pluginDidInstall:(NSNotification *)aNotification
{
  Plugin *installedPlugin = (Plugin *)aNotification.object;
  if ([installedPlugin.pluginId isEqualToString:EXAMPLE_DB_KEY])
  {
    // Get rid of the old example sentences guy & re-setup the scroll view
    [[self.scrollView viewWithTag:LWE_EX_SENTENCE_INSTALLER_VIEW_TAG] removeFromSuperview];
    [self _setupScrollView];
    
    // Reset the page control (this will automatically call the code to determine if this card has ex sentences)
    [self _setupPageControl:1];
    [self.exampleSentencesViewController setupWithCard:self.currentCard]; // finally setup the example view for the current card
  }
#if defined (LWE_CFLASH)
  else if ([installedPlugin.pluginId isEqualToString:AUDIO_PINYIN_KEY])
  {
    // Reset the current card
    [self doChangeCard:self.currentCard direction:nil];
  }
#endif
}

#pragma mark - ScrollView Delegate & Page Control stuff

/**
 * Called when a major thing happens (JFlash startup or EX_DB plugin installation)
 * when the fundamental workings of the scroll view may change.
 */
- (void) _setupScrollView
{
  UIViewController *vc = nil;
  Plugin *exPlugin = [self.pluginManager pluginForKey:EXAMPLE_DB_KEY];
  if (exPlugin)
  {
    // We have EX db installed
    self.exampleSentencesViewController = [[[ExampleSentencesViewController alloc] initWithExamplesPlugin:exPlugin] autorelease];
    vc = self.exampleSentencesViewController;
  }
  else
  {
    // No example sentence plugin loaded, so show "please download me" view instead
    // TODO: iPad customization
    vc = [[[UIViewController alloc] initWithNibName:@"ExamplesUnavailable" bundle:nil] autorelease];
    vc.view.tag = LWE_EX_SENTENCE_INSTALLER_VIEW_TAG;
  }
  
  // Resize our second view to fill the second page of the scroll view
	CGFloat cx = self.scrollView.frame.size.width;
	CGRect rect = CGRectMake(cx, 0, cx, self.scrollView.frame.size.height);
	vc.view.frame = rect;
  
  // Set the content size for the width * the number of views
	NSInteger numViews = 2;
	self.pageControl.numberOfPages = numViews;
  // Here we are setting contentSize to the frame's height because this scroll view never scrolls vertically.
  self.scrollView.contentSize = CGSizeMake(cx * numViews, self.scrollView.contentSize.height);
  
  // add the new view as a subview for the scroll view to handle
	[self.scrollView addSubview:vc.view];
}


/**
 * Called whenever the user scrolls; if it is horizontally,
 * determine if it is 50% across, if so, swap the page
 */
- (void)scrollViewDidScroll:(UIScrollView *)_scrollView
{
  // This will be called if we mess with the page control, but we're only interested in swipes so return here
  if (_isChangingPage) 
  {
    return;
  }
  
  //	We switch page at 50% across
  CGFloat pageWidth = _scrollView.frame.size.width;
  NSInteger page = floor((_scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
  self.pageControl.currentPage = page;
}

/**
 * Resets the pageControlIsChangingPage property to NO
 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)_scrollView 
{
  _isChangingPage = NO;
}

/** 
 * Choose the background based on the current theme
 */
-(void)setBackgroundColor_
{
  self.practiceBgImage.backgroundColor = [[ThemeManager sharedThemeManager] currentThemeTintColor:0.9];
  self.view.backgroundColor = [UIColor colorWithWhite:0.902 alpha:1.0];
}

#pragma mark - Class plumbing

- (void) _contentSizeCategoryDidChange:(NSNotification *)notification
{
  [self _setupSubviews];
  [self doChangeCard:self.currentCard direction:nil];
}

/*
* We ask Tag to freeze its current state to a plist so if the app is killed
* while in the background, we can get it back!
*/
- (void) _applicationDidEnterBackground:(NSNotification*)notification
{
  // Only freeze if we have a database
  if ([[[LWEDatabase sharedLWEDatabase] dao] goodConnection])
  {
    // Save current tag id & location
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    [settings setInteger:self.currentCardSet.tagId forKey:@"tag_id"];
    [settings setInteger:self.currentCardSet.currentIndex forKey:@"current_index"];
    [settings synchronize];
    [self.currentCardSet freezeCardIds];
  }
}

- (void) viewDidUnload
{
  self.progressDetailsViewController = nil;
	self.progressBarViewController = nil;
	self.exampleSentencesViewController = nil;
	self.cardViewController = nil;
	self.actionBarController = nil;
  
	self.scrollView = nil;
	self.pageControl = nil;
	self.cardView = nil;
	self.actionbarView = nil;
	self.cardSetLabel = nil;
	self.revealCardBtn = nil;
	self.tapForAnswerImage = nil;
	self.practiceBgImage = nil;
	self.progressBarView = nil;
	self.remainingCardsLabel = nil;
	self.showProgressModalBtn = nil;
  self.pronounceBtn = nil;
  [super viewDidUnload];
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings removeObserver:self forKeyPath:APP_MODE];
  [settings removeObserver:self forKeyPath:APP_THEME];
  [settings removeObserver:self forKeyPath:APP_HEADWORD];
  [settings removeObserver:self forKeyPath:APP_HEADWORD_TYPE];
#if defined (LWE_CFLASH)
  [settings removeObserver:self forKeyPath:APP_PINYIN_COLOR];
#elif defined (LWE_JFLASH)
  [settings removeObserver:self forKeyPath:APP_READING];
  [settings removeObserver:self forKeyPath:APP_KANA_ONLY];
#endif

  [delegate release];

  [pronounceBtn release];

  //theme
  [practiceBgImage release];
  
  //kept on this view for now - refactor this too
  [cardSetLabel release];
  
  //progress stuff
  [progressDetailsViewController release];
  [progressBarViewController release];
  [progressBarView release];
  
  //card view stuff
  [cardViewController release];
  [cardView release];
  
  //action bar
  [actionBarController release];
  [actionbarView release];
  [revealCardBtn release];
  [tapForAnswerImage release];
  
  //state
  [currentCardSet removeObserver:self forKeyPath:@"tagName"];
  [currentCardSet release];
  [currentCard release];
  
  [pluginManager release];
  
  //scrollView
  [scrollView release];
  [pageControl release];
  [exampleSentencesViewController release];
  
	[super dealloc];
}

@end