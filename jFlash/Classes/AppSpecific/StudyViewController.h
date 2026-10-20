//
//  StudyViewController.h
//  jFlash
//
//  Created by シャロット ロス on 5/4/09.
//  Copyright LONG WEEKEND INC 2009. All rights reserved.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "Constants.h"
#import "ProgressDetailsViewController.h"
#import "ProgressBarViewController.h"

#import "PluginManager.h"

#import "StudyViewProtocols.h"
#import "PracticeModeCardViewDelegate.h"
#import "BrowseModeCardViewDelegate.h"
#import "ExampleSentencesViewController.h"

#import "ActionBarViewController.h"
#import "CardViewController.h"

#import "LWEAudioQueue.h"

#define STUDY_SET_HAS_FINISHED_ALERT_TAG  777
#define STUDY_SET_SHOW_BURIED_IDX         1
#define STUDY_SET_CHANGE_SET_IDX          0

//! The card-to-card transition: a short push, or (Reduce Motion) a cross-fade with no direction.
static inline NSString *LWECardTransitionType(BOOL reduceMotion)
{
  return reduceMotion ? kCATransitionFade : kCATransitionPush;
}
static inline NSString *LWECardTransitionSubtype(BOOL reduceMotion, NSString *direction)
{
  return reduceMotion ? nil : direction;
}

@interface StudyViewController : UIViewController <UIScrollViewDelegate,
                                                   UIActionSheetDelegate,
                                                   UIAlertViewDelegate,
                                                   LWEAudioQueueDelegate>
{
  //! Used to remember if the user has already seen the alert view for first run
  BOOL _alreadyShowedAlertView;
  BOOL _isChangingPage;  // page control state
}

- (BOOL) hasExampleSentences;

- (IBAction)doShowProgressModalBtn;
- (IBAction)revealCard;
- (IBAction)pronounceCard:(id)sender;

- (void)changeStudySetToTag:(Tag*)newTag;

- (IBAction)doCardBtn:(id)sender;
- (void)doChangeCard: (Card*) card direction:(NSString*)directionOrNil;

//! Gets notification from plugin manager
- (void)pluginDidInstall: (NSNotification *)aNotification;

/* for pageControl */
- (IBAction) changePage:(id)sender;
- (IBAction) changePage:(id)sender animated:(BOOL)animated;
- (IBAction) launchExampleInstaller;

// This delegate is retained -- not the best solution.  Someone (probably CurrentState) needs to own him.
@property (retain) id<StudyViewControllerDelegate> delegate;

@property (nonatomic, retain) IBOutlet UIButton *pronounceBtn;

// scroll view
@property (nonatomic, retain) IBOutlet UIScrollView *scrollView;
@property (nonatomic, retain) IBOutlet UIPageControl *pageControl;

@property (nonatomic, retain) IBOutlet UIViewController<StudyViewSubcontrollerProtocol> *cardViewController;
@property (nonatomic, retain) IBOutlet UIViewController<StudyViewSubcontrollerProtocol> *actionBarController;
@property (nonatomic, retain) ExampleSentencesViewController *exampleSentencesViewController;
@property (nonatomic, retain) IBOutlet UIView *cardView;
@property (nonatomic, retain) IBOutlet UIView *actionbarView;

@property (nonatomic, retain) IBOutlet UILabel *cardSetLabel;
@property (nonatomic, retain) IBOutlet UILabel *remainingCardsLabel;

@property (nonatomic, retain) IBOutlet UIButton *revealCardBtn;
@property (nonatomic, retain) IBOutlet UIImageView *tapForAnswerImage;

@property (nonatomic, retain) IBOutlet UIImageView *practiceBgImage;

// The progress bar
@property (nonatomic, retain) ProgressBarViewController *progressBarViewController; 
@property (nonatomic, retain) IBOutlet UIView *progressBarView;
@property (nonatomic, retain) IBOutlet UIButton *showProgressModalBtn;

// The progress sheet while it's presented, otherwise nil (not retained: the presentation owns it)
@property (nonatomic, readonly) ProgressDetailsViewController *progressDetailsViewController;

// Plugin related
@property (nonatomic, retain) IBOutlet PluginManager *pluginManager;


// scroll view
@property (nonatomic, retain) Tag *currentCardSet;
@property (nonatomic, retain) Card *currentCard;

// stats for progress modal
@property NSInteger numRight;
@property NSInteger numWrong;
@property NSInteger numViewed;
@property NSInteger currentRightStreak;
@property NSInteger currentWrongStreak;

@end