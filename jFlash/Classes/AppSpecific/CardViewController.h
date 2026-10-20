//
//  WordCardViewController.h
//  jFlash
//
//  Created by シャロット ロス on 6/3/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "Card.h"
#import "MoodIcon.h"
#import "StudyViewProtocols.h"

// These strings define the HTML that expresses how the card's meeting will be 
// displayed in each study direction.
extern NSString * const LWECardHTMLTemplate;
extern NSString * const LWECardHTMLTemplate_EtoJ;

@class CardViewController;

@protocol CardViewControllerDelegate <NSObject>
@optional
- (void) cardViewDidChangeMode:(CardViewController*)cardViewController;
- (void)cardViewWillSetup:(CardViewController*)cardViewController;
- (void)cardViewDidSetup:(CardViewController*)cardViewController;
- (void)cardViewWillReveal:(CardViewController*)cardViewController;
- (void)cardViewDidReveal:(CardViewController*)cardViewController;
- (BOOL)shouldRevealCardView:(CardViewController*)cvc;
@end

@interface CardViewController : UIViewController <StudyViewSubcontrollerProtocol, WKNavigationDelegate>
{
  //! Holds a reference to the current meaning's string-replacement javascript
  NSString *_tmpJavascript;
  //! WKWebView created programmatically inside meaningWebViewContainer.
  WKWebView *_meaningWebView;
}

//! Designated initializer.  Passing "NO" to displayMainHeadword shows alt headword (e.g. English)
- (id) initDisplayMainHeadword:(BOOL)displayMainHeadword;

- (IBAction) doToggleReadingBtn;

#if defined(LWE_JFLASH)
//! Speaks the current headword using AVSpeechSynthesizer.
- (IBAction) doSpeakHeadword;
#endif

//! Use when you want to show the reading (w/o persisting that state)
- (void) turnReadingOn;

//! Use when you want to stop the reading from showing (w/o persisting that state)
- (void) turnReadingOff;

//! Whatever the value of readingVisible is, this will reset it to that state.
- (void) resetReadingVisibility;

//! Lays out reading, headword, and webview based on current bounds.
//! Call from StudyViewController.viewDidLayoutSubviews (child VC containment is informal).
- (void) layoutCardSubviews;

//! The study view placed the score bubble: re-fit the meaning around it.
- (void) scoreBubbleDidMove;

//! The answer was just revealed: briefly flash the meaning's scroll indicator when it is longer than
//! the card shows (on an iPhone SE often only the first sense fits), once its height is known.
- (void) flashMeaningScrollIndicatorIfScrollable;

//! YES while a reveal's scroll-indicator flash waits for the meaning to be measured.  Cleared when
//! the next card is set up, so it never carries over to another card.
- (BOOL) meaningScrollFlashPending;

//! Y (in this controller's view) below which a tap on the card should reveal the answer.
//! Everything above it (headword, speaker, reading toggle, "+N readings") stays tappable.
- (CGFloat) revealAreaTop;

//! Implement this delegate to control how the card is displayed in a mode.
@property (assign) IBOutlet id<CardViewControllerDelegate> delegate;

//! Our little guy.
@property (nonatomic, retain) IBOutlet MoodIcon *moodIcon;

//! The label holding the reading for this card
@property (nonatomic, retain) IBOutlet UILabel *readingLabel;

//! If yes, the reading is visible.  Separate variable than label.hidden because we preserve state across cards.
//! A new card view starts from the session's choice (+sessionReadingVisible).
@property BOOL readingVisible;

//! The reader's show/hide choice for this run of the app: hidden at launch, kept in memory only (never
//! saved), and picked up by every new card view (theme, direction, mode or text-size changes).
//! Tapping the reading toggle sets it; delegates that force the reading on or off (browse mode,
//! English-first cards) change only that card view's readingVisible.
+ (BOOL) sessionReadingVisible;
+ (void) setSessionReadingVisible:(BOOL)visible;

//! Toggles the visibility of the reading off and on.  Will persist state to readingVisible
@property (nonatomic, retain) IBOutlet UIButton *toggleReadingBtn;

//! Scroll view containing the reading label.  If the reading doesn't fit, we can scroll it.
@property (nonatomic, retain) IBOutlet UIScrollView *readingScrollContainer;

//! If the reading is scrollable, the "more icon" will show to help the user understand
@property (nonatomic, retain) IBOutlet UIImageView *readingMoreIcon;

//! The label holding the card's main headword
@property (nonatomic, retain) IBOutlet UILabel *headwordLabel;

//! Scroll view containing the headword label.  If the headword doesn't fit, we can scroll it.
@property (nonatomic, retain) IBOutlet UIScrollView *headwordScrollContainer;

//! If the headword is scrollable, the "more icon" will show to help the user understand
@property (nonatomic, retain) IBOutlet UIImageView *headwordMoreIcon;

#if defined(LWE_JFLASH)
//! Speaker button that triggers TTS for the current headword.
@property (nonatomic, retain) UIButton *speakBtn;
#endif

//! Container view (XIB-instantiated UIView) into which the WKWebView is added in viewDidLoad.
@property (nonatomic, retain) IBOutlet UIView *meaningWebViewContainer;

@property (nonatomic, retain) NSString *baseHtml;
@end
