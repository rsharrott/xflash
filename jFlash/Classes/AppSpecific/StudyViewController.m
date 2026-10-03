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
