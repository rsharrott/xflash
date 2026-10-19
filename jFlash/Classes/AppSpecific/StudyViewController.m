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
#import "AddTagViewController.h"
#import "UpdateManager.h"
#import "CardViewController.h"
#import "ActionBarViewController.h"
#import "FirstRunViewController.h"
#import "LWEDesignTokens.h"

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
- (void) _applyCardChrome;
- (Card*) _getNextCardWithDirection:(NSString*)directionOrNil currentCard:(Card *)theCurrentCard;
#if defined (LWE_JFLASH)
- (void) _showWelcomeSheet;
- (void) _showFirstCardHint;
- (void) _coachHintSpotlight:(CGRect *)spot tapPoint:(CGPoint *)tap inView:(UIView *)host;
#endif
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
    // First launch: the welcome sheet (starter set + reading mode) replaces the old UIAlert.
    if ([FirstRunWelcomeViewController shouldShowWelcome])
    {
      [self _showWelcomeSheet];
    }
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

#if defined (LWE_DEBUG)
  // Screenshot hooks for Debug builds (the simulator can't be tapped from scripts):
  //   simctl launch <udid> <bundle> -LWEDebugShowCardHint YES   -> show the coach hint
  //   simctl launch <udid> <bundle> -LWEDebugAutoReveal YES     -> reveal the first card
  static BOOL debugHooksRan = NO;
  if (debugHooksRan == NO)
  {
    debugHooksRan = YES;
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    //   simctl launch <udid> <bundle> -LWEDebugCardId 116148     -> show a specific card first
    NSInteger debugCardId = [settings integerForKey:@"LWEDebugCardId"];
    if (debugCardId > 0)
    {
      Card *debugCard = [CardPeer retrieveCardByPK:debugCardId];
      if (debugCard) [self doChangeCard:debugCard direction:nil];
    }
#if defined (LWE_JFLASH)
    // The coach hint only exists in Japanese in a Flash.
    if ([settings boolForKey:@"LWEDebugShowCardHint"])
    {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self _showFirstCardHint]; });
    }
#endif
    if ([settings boolForKey:@"LWEDebugAutoReveal"])
    {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self revealCard]; });
    }
    //   simctl launch --console <udid> <bundle> -LWEDebugCheckRevealTapGuard YES
    //     -> reveal, then log what a tap on the Right button's spot would hit (UIKit hit-testing, which
    //        honours userInteractionEnabled / hidden / alpha) during and after the Show answer fade.
    if ([settings boolForKey:@"LWEDebugCheckRevealTapGuard"] &&
        [self.actionBarController isKindOfClass:[ActionBarViewController class]])
    {
      ActionBarViewController *bar = (ActionBarViewController *)self.actionBarController;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self revealCard];
        NSArray *delays = @[@0.02, @0.1, @0.2, @0.28, @0.4, @0.6];
        for (NSNumber *delay in delays)
        {
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([delay doubleValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGPoint p = CGPointMake(CGRectGetMidX(bar.rightBtn.frame), CGRectGetMidY(bar.rightBtn.frame));
            UIView *hit = [bar.view hitTest:p withEvent:nil];
            NSString *what = (hit == bar.rightBtn) ? @"RIGHT BUTTON (answer would be recorded)"
                           : (hit == bar.showAnswerBtn) ? @"Show answer" : NSStringFromClass([hit class]);
            NSLog(@"LWEDebugCheckRevealTapGuard t+%.2fs: tap at Right hits %@", [delay doubleValue], what);
          });
        }
      });
    }
    //   simctl launch <udid> <bundle> -LWEDebugAnswerCards RRWRW  -> answer cards Right (R) / Wrong (W) / Bury (B)
    //     through the normal button path (records history, updates counts), one every 0.3s
    NSString *debugAnswers = [settings stringForKey:@"LWEDebugAnswerCards"];
    NSTimeInterval answerTime = 0.3 * [debugAnswers length];
    for (NSUInteger i = 0; i < [debugAnswers length]; i++)
    {
      unichar answer = [debugAnswers characterAtIndex:i];
      NSInteger buttonTag = (answer == 'W') ? WRONG_BTN : (answer == 'B') ? BURY_BTN : RIGHT_BTN;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.2 + 0.3 * i) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIButton *fake = [UIButton buttonWithType:UIButtonTypeCustom];
        fake.tag = buttonTag;
        [self doCardBtn:fake];
      });
    }
    //   simctl launch <udid> <bundle> -LWEDebugShowProgress YES  -> open the progress sheet (after any debug answers)
    if ([settings boolForKey:@"LWEDebugShowProgress"])
    {
#if defined (LWE_JFLASH)
      [settings setBool:YES forKey:LWEFirstRunCardHintShownKey]; // never cover it with the coach hint
#endif
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.5 + answerTime) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self doShowProgressModalBtn];
        //   -LWEDebugProgressDetent large  -> open the sheet at the large detent
        if ([[settings stringForKey:@"LWEDebugProgressDetent"] isEqualToString:@"large"])
        {
          [self.progressDetailsViewController.sheetPresentationController animateChanges:^{
            self.progressDetailsViewController.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
          }];
        }
      });
    }
    //   simctl launch --console <udid> <bundle> -LWEDebugProgressCycles 10  -> open and close the progress sheet
    //     N times (2s apart), logging when each sheet is presented and when it has gone (leak check)
    NSInteger cycles = [settings integerForKey:@"LWEDebugProgressCycles"];
    for (NSInteger i = 0; i < cycles; i++)
    {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.0 + 2.0 * i) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self doShowProgressModalBtn];
        NSLog(@"LWEDebugProgressCycles open %ld: %@", (long)(i + 1), self.progressDetailsViewController);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [self.progressDetailsViewController dismiss];
          if (i == cycles - 1) NSLog(@"LWEDebugProgressCycles done");
        });
      });
    }
    //   simctl launch <udid> <bundle> -LWEDebugShowExamples YES  -> reveal, then open the example sentences page
    if ([settings boolForKey:@"LWEDebugShowExamples"])
    {
#if defined (LWE_JFLASH)
      [settings setBool:YES forKey:LWEFirstRunCardHintShownKey]; // never cover it with the coach hint
#endif
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([settings boolForKey:@"LWEDebugAutoReveal"] == NO) [self revealCard];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          if (self.pageControl.numberOfPages > 1)
          {
            self.pageControl.currentPage = 1;
            [self changePage:self.pageControl animated:NO];
            _isChangingPage = NO;
          }
        });
      });
    }
  }
#endif
}

#if defined (LWE_JFLASH)
- (void) _showWelcomeSheet
{
  // Something else (an alert, the upgrade notice, a plugin prompt...) may already be up; a second
  // present would be dropped, so try again shortly instead -- for up to ~30 seconds.
  static NSInteger retries = 0;
  UIViewController *presenter = self.tabBarController ?: self;
  if (presenter.presentedViewController != nil || presenter.view.window == nil)
  {
    if (retries++ < 60)
    {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([FirstRunWelcomeViewController shouldShowWelcome]) [self _showWelcomeSheet];
      });
    }
    return;
  }

  FirstRunWelcomeViewController *welcome = [[[FirstRunWelcomeViewController alloc] init] autorelease];
  welcome.finishedHandler = ^{
    // Then, once, point at the first card.
    if ([FirstRunCoachHintView shouldShowHint])
    {
      [self _showFirstCardHint];
    }
  };
  [presenter presentViewController:welcome animated:YES completion:nil];
}

- (void) _showFirstCardHint
{
  UIView *host = self.tabBarController.view ?: self.view;
  [self.view layoutIfNeeded];
  // MRC: __block keeps the block from retaining self (the hint goes away long before we do).
  __block StudyViewController *blockSelf = self;
  [FirstRunCoachHintView showInView:host spotlightProvider:^(CGRect *spot, CGPoint *tap) {
    [blockSelf _coachHintSpotlight:spot tapPoint:tap inView:host];
  }];
}

//! The card's current spotlight rect and tap point, in host's coordinates.
- (void) _coachHintSpotlight:(CGRect *)spot tapPoint:(CGPoint *)tap inView:(UIView *)host
{
  // Spotlight the card: the red area between the progress strip and the answer bar.
  CGFloat top = CGRectGetMinY(self.scrollView.frame) + 8.0;
  CGFloat bottom = CGRectGetMinY(self.actionbarView.frame) - 8.0;
  CGRect rect = CGRectMake(14.0, top, self.view.bounds.size.width - 28.0, MAX(120.0, bottom - top));
  *spot = [self.view convertRect:rect toView:host];

  // Tap target: just below the headword, where tapping reveals the answer.
  CGFloat revealTop = CGRectGetMinY(self.revealCardBtn.frame);
  if ([self.cardViewController isKindOfClass:[CardViewController class]])
  {
    revealTop = CGRectGetMinY(self.scrollView.frame) + [(CardViewController *)self.cardViewController revealAreaTop];
  }
  // Keep the ring inside the card even when large text pushes the reveal area down.
  CGFloat tapY = MIN(revealTop + 44.0, bottom - 48.0);
  *tap = [self.view convertPoint:CGPointMake(CGRectGetMidX(self.view.bounds), tapY) toView:host];
}
#endif

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

#if defined (LWE_JFLASH)
    // Give the action bar the height it asks for (the practice answer bar is two rows and grows
    // with Dynamic Type), pinned to the bottom of the safe area.
    if ([self.actionBarController respondsToSelector:@selector(preferredBarHeight)]) {
      CGFloat barH = [(ActionBarViewController *)self.actionBarController preferredBarHeight];
      CGFloat bottomInset = self.view.safeAreaInsets.bottom;
      CGFloat viewH = self.view.bounds.size.height;
      if (barH > 0 && viewH > barH) {
        self.actionbarView.frame = CGRectMake(0, viewH - bottomInset - barH, self.view.bounds.size.width, barH + bottomInset);
        self.actionBarController.view.frame = self.actionbarView.bounds;
      }
    }
    // The card colour runs behind the answer bar's rounded top corners.
    self.practiceBgImage.frame = self.view.bounds;

    // Keep the example-sentence page dot on the card's bottom line (between the set name and
    // the count), not over the taller answer bar.
    if (self.pageControl) {
      CGPoint pc = self.pageControl.center;
      pc.x = roundf(self.view.bounds.size.width / 2.0);
      pc.y = CGRectGetMinY(self.actionbarView.frame) - 17.0;
      self.pageControl.center = pc;
    }
#endif

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

#if defined (LWE_JFLASH)
  // Keep the inset card + footer colours in sync with the live scroll bounds
  [self _applyCardChrome];
#endif

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
#if defined (LWE_JFLASH)
        // Starts below the headword / reading toggle / "+N readings" (still tappable) and
        // stops at the answer bar.
        CGFloat revealTop = self.scrollView.frame.origin.y + [cvc revealAreaTop];
        CGFloat revealBottom = CGRectGetMinY(self.actionbarView.frame);
        CGRect rf = self.revealCardBtn.frame;
        rf.origin.x = 0;
        rf.size.width = self.view.bounds.size.width;
        rf.origin.y = revealTop;
        rf.size.height = MAX(100.0, revealBottom - revealTop);
        self.revealCardBtn.frame = rf;
        // The answer bar's "Show answer" button is the VoiceOver element for revealing; this
        // invisible tap area would only be a second, duplicate "Show answer".
        BOOL barHasShowAnswer = [self.actionBarController isKindOfClass:[ActionBarViewController class]] &&
                                ((ActionBarViewController *)self.actionBarController).showAnswerBtn != nil;
        self.revealCardBtn.isAccessibilityElement = (barHasShowAnswer == NO);
        self.revealCardBtn.accessibilityLabel = NSLocalizedString(@"Show answer", @"StudyViewController.ShowAnswerAccessibility");
#else
        // readingY (25% of containerH) + readingH (42) + gap (4) + headwordH (55) + buffer (10)
        CGFloat headwordsBottom = roundf(containerH * 0.25) + 42.0 + 4.0 + 55.0 + 10.0;
        CGFloat revealTop = self.scrollView.frame.origin.y + headwordsBottom;
        CGRect rf = self.revealCardBtn.frame;
        rf.origin.y = revealTop;
        rf.size.height = MAX(100.0, self.view.bounds.size.height - revealTop);
        self.revealCardBtn.frame = rf;
#endif
      }
    }
  }

#if defined (LWE_JFLASH)
  // A coach hint on screen follows the card.
  [FirstRunCoachHintView setNeedsLayoutInView:(self.tabBarController.view ?: self.view)];
#endif
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
  // A suspended app is killed without -applicationWillTerminate:, so also save the session when we
  // go to the background. Coming back without being killed deletes the plist again
  // (-applicationWillEnterForeground:); after a kill, the next cold launch restores it.
  [center addObserver:self selector:@selector(_applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
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
 * Handles the button tap on the legacy (pre-1.7) upgrade alerts shown by
 * UpdateManager showUpgradeAlertView:delegate:. The first-launch welcome alert
 * no longer uses this delegate.
 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  // The legacy alerts' second button linked to Rikai Browser, which is no longer
  // on the App Store, so both buttons now just dismiss.
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
  
  // Tell the progress bars (and an open progress sheet) about this new tag
  ProgressDetailsViewController *openSheet = self.progressDetailsViewController;
  if (openSheet)
  {
    openSheet.tag = newTag;
    openSheet.rightCount = 0;
    openSheet.wrongCount = 0;
    openSheet.rightStreak = 0;
    openSheet.wrongStreak = 0;
    [openSheet updateView];
  }
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
    if ([self.actionBarController respondsToSelector:@selector(applyTheme)])
    {
      [(ActionBarViewController *)self.actionBarController applyTheme];
    }
    if (self.progressBarViewController.tag)
    {
      [self.progressBarViewController drawProgressBar];
    }
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
  else if ([keyPath isEqualToString:APP_HEADWORD_TYPE])
  {
    // Observed in every build (see -viewDidLoad) but only matters for cFlash's simplified/traditional
    // headwords. Handle and ignore it here so a write never reaches NSObject, which raises on
    // unhandled KVO notifications.
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

  // The card's headword size varies per card, so the reveal area moves too.
  [self.view setNeedsLayout];
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
  // Already showing it (or something else) -- don't stack sheets.
  if (self.presentedViewController != nil || self.currentCardSet == nil)
  {
    return;
  }
  // Pass everything in up front; the sheet builds its views from these in -viewDidLoad.
  // (The old XIB overlay set label text before its view was loaded, so the first open showed
  // the XIB's placeholder numbers.)
  ProgressDetailsViewController *progressVC = [[[ProgressDetailsViewController alloc] initWithTag:self.currentCardSet
                                                                                     rightCount:self.numRight
                                                                                     wrongCount:self.numWrong
                                                                                    rightStreak:self.currentRightStreak
                                                                                    wrongStreak:self.currentWrongStreak] autorelease];
  // A page sheet: content-sized + large detents (see ProgressDetailsViewController -init). The
  // presentation retains it, so it's released as soon as it's dismissed.
  [self presentViewController:progressVC animated:YES completion:nil];
}


- (ProgressDetailsViewController *) progressDetailsViewController
{
  UIViewController *presented = self.presentedViewController;
  if ([presented isKindOfClass:[ProgressDetailsViewController class]] && presented.isBeingDismissed == NO)
  {
    return (ProgressDetailsViewController *)presented;
  }
  return nil;
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
    // Assume we haven't installed the plugin yet
    Plugin *pinyinPlugin = [self.pluginManager.downloadablePlugins objectForKey:AUDIO_PINYIN_KEY];
    [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldShowDownloadModal object:pinyinPlugin userInfo:nil];
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
  Plugin *exPlugin = [self.pluginManager.downloadablePlugins objectForKey:EXAMPLE_DB_KEY];
  [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldShowDownloadModal object:exPlugin userInfo:nil];
}

/**
 * Connects the "Play Audio" button to actually launch the installer
 * Kind of just a convenience method
 */
- (IBAction) launchAudioInstaller
{
#if defined (LWE_CFLASH)
  Plugin *exPlugin = [self.pluginManager.downloadablePlugins objectForKey:AUDIO_PINYIN_KEY];
  [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldShowDownloadModal object:exPlugin userInfo:nil];
#endif
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
  
  // Resize our second view to fill the second page of the scroll view (inset like page 1's card)
	CGFloat cx = self.scrollView.frame.size.width;
  CGFloat inset = kLWECardInset;
  CGFloat footerReserve = 28.0;
  CGFloat cardH = MAX(0, self.scrollView.frame.size.height - footerReserve - inset);
	CGRect rect = CGRectMake(cx + inset, inset, MAX(0, cx - 2.0 * inset), cardH);
	vc.view.frame = rect;
  [[ThemeManager sharedThemeManager] applyCardStyleToLayer:vc.view.layer];
  vc.view.layer.masksToBounds = NO;
  vc.view.backgroundColor = [UIColor clearColor];
  
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
/**
 * Themes v2: every theme shares the paper-2 screen; only the study card (cardView) takes cardFill.
 * practiceBgImage is cleared (no practice-bg image) and sits behind the card as the screen colour.
 */
-(void)setBackgroundColor_
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  UIColor *screen = [tm colorForSlot:@"screenBackground"] ?: [tm backgroundColor];
  self.view.backgroundColor = screen;
  // practiceBgImage used to be the full-bleed theme colour; it is now the paper screen behind the card.
  self.practiceBgImage.image = nil;
  self.practiceBgImage.backgroundColor = screen;
  [self _applyCardChrome];
}

//! Paints cardView as the inset study card (fill, radius, shadow) and colours the footer / page dots
- (void) _applyCardChrome
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  UIView *card = self.cardView;
  if (card)
  {
    // Inset the card inside the scroll area so paper shows around it (themes v2: 12pt)
    UIView *host = card.superview; // scrollView
    CGFloat inset = kLWECardInset;
    if (host)
    {
      CGRect bounds = host.bounds;
      // Keep the footer labels (cardSetLabel / remainingCardsLabel) on the paper below the card:
      // the card fills the scroll area above them (~21pt labels near the bottom).
      CGFloat footerReserve = 28.0;
      CGFloat cardH = MAX(0, bounds.size.height - footerReserve - inset);
      card.frame = CGRectMake(inset, inset, MAX(0, bounds.size.width - 2.0 * inset), cardH);
    }
    // Shadow + fill on cardView; clipsToBounds stays NO so the shadow is visible.  Content that
    // reaches the edge is rare (the card VC pads), and the mood icon sits inset from the corner.
    card.backgroundColor = [UIColor clearColor];
    [tm applyCardStyleToLayer:card.layer];
    card.layer.masksToBounds = NO;
    // Bounds are final here (frame was just set); keep the shadow cheap and matching the rounded card
    card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:kLWECardCornerRadius].CGPath;
    if (self.cardViewController)
    {
      self.cardViewController.view.backgroundColor = [UIColor clearColor];
    }
  }
  // Keep page 2 (examples) on the same card chrome
  if (self.exampleSentencesViewController.view.superview == self.scrollView)
  {
    UIView *ex = self.exampleSentencesViewController.view;
    CGFloat inset = kLWECardInset;
    CGFloat footerReserve = 28.0;
    CGFloat cx = self.scrollView.bounds.size.width;
    CGFloat cardH = MAX(0, self.scrollView.bounds.size.height - footerReserve - inset);
    ex.frame = CGRectMake(cx + inset, inset, MAX(0, cx - 2.0 * inset), cardH);
    [tm applyCardStyleToLayer:ex.layer];
    ex.layer.masksToBounds = NO;
    ex.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:ex.bounds cornerRadius:kLWECardCornerRadius].CGPath;
    ex.backgroundColor = [UIColor clearColor];
  }

  UIColor *foot = [tm colorForSlot:@"footInk"];
  self.cardSetLabel.textColor = foot;
  self.remainingCardsLabel.textColor = foot;
  if (@available(iOS 14.0, *))
  {
    self.pageControl.currentPageIndicatorTintColor = [tm colorForSlot:@"pageDotOn"];
    self.pageControl.pageIndicatorTintColor = [tm colorForSlot:@"pageDotOff"];
  }
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