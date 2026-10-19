//
//  ActionBarViewController.h
//  jFlash
//
//  Created by シャロット ロス on 6/4/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AddTagViewController.h"
#import "Constants.h"
#import "jFlashAppDelegate.h"
#import <MessageUI/MessageUI.h>
#import "StudyViewProtocols.h"

@class ActionBarViewController;

@protocol ActionBarViewControllerDelegate <NSObject>
@optional
- (void)actionBarDidChangeMode:(ActionBarViewController*)avc;

// setup card to unrevealed state
- (void)actionBarWillSetup:(ActionBarViewController*)avc;
- (void)actionBarDidSetup:(ActionBarViewController*)avc;

// reveal card
- (void)actionBarWillReveal:(ActionBarViewController*)avc;
- (void)actionBarDidReveal:(ActionBarViewController*)avc;
- (BOOL)actionBarShouldReveal:(ActionBarViewController*)avc;
@end

@interface ActionBarViewController : UIViewController <MFMailComposeViewControllerDelegate,
                                                       StudyViewSubcontrollerProtocol>

// action sheet
- (IBAction)showCardActionSheet;

- (void)distributeButtonsEvenly;

//! Height the study view should give the action bar (excluding any safe-area inset).
//! Practice mode uses the two-row paper panel; browse mode keeps its NIB height.
- (CGFloat)preferredBarHeight;

//! Re-colours the theme-dependent parts (Show answer) after the theme changes
- (void)applyTheme;

@property (assign) IBOutlet id<ActionBarViewControllerDelegate> delegate;

@property (nonatomic, retain) Card *currentCard;

@property (nonatomic, retain) IBOutlet UIButton *addBtn;
@property (nonatomic, retain) IBOutlet UIButton *buryCardBtn;
@property (nonatomic, retain) IBOutlet UIButton *nextCardBtn;
@property (nonatomic, retain) IBOutlet UIButton *prevCardBtn;
@property (nonatomic, retain) IBOutlet UIButton *rightBtn;
@property (nonatomic, retain) IBOutlet UIButton *wrongBtn;

@property (nonatomic, retain) IBOutlet UIView *cardMeaningBtnHint;

//! Practice mode only: full-width "Show answer" button shown until the card is revealed.
@property (nonatomic, retain) UIButton *showAnswerBtn;

@end