//
//  FirstRunViewController.h
//  jFlash
//
//  First-launch welcome sheet (replaces the old "Welcome to Japanese in a Flash!"
//  UIAlert) and the one-time coach hint shown on the first card afterwards.
//

#import <UIKit/UIKit.h>

//! NSUserDefaults flag: YES once the welcome sheet has been shown.
extern NSString * const LWEFirstRunWelcomeShownKey;
//! NSUserDefaults flag: YES once the first-card coach hint has been dismissed.
extern NSString * const LWEFirstRunCardHintShownKey;

#if defined(LWE_JFLASH)

//! Welcome-sheet starter sets, in display order.  Each pair is group_id, tag_id.
NSInteger LWEStarterSetCount(void);
void LWEStarterSetAtIndex(NSInteger index, NSInteger *groupId, NSInteger *tagId);

@interface FirstRunWelcomeViewController : UIViewController <UIAdaptivePresentationControllerDelegate>

//! YES on a fresh install (same condition as the old welcome alert) until the sheet has been shown once.
+ (BOOL) shouldShowWelcome;

//! Records that the sheet was shown so it never appears again.
+ (void) markWelcomeShown;

//! Called after the sheet is dismissed (by "Start studying" or by swiping it away).
@property (nonatomic, copy) dispatch_block_t finishedHandler;

- (IBAction) startStudying:(id)sender;

@end


typedef void (^LWECoachHintSpotlightProvider)(CGRect *spotlightRect, CGPoint *tapPoint);

@interface FirstRunCoachHintView : UIView

//! YES until the user has tapped "Got it" once.
+ (BOOL) shouldShowHint;

//! Dims hostView, outlines the spotlight rect (the card) and points a tip bubble at the tap
//! point.  The provider is asked for both (in hostView's coordinate space) on every layout pass,
//! so the hint follows the card when it moves; the bubble stays inside the safe area, flipping
//! above the tap point when there's no room below.  "Got it", or a tap outside the bubble, dismisses.
+ (FirstRunCoachHintView *) showInView:(UIView *)hostView spotlightProvider:(LWECoachHintSpotlightProvider)provider;

//! Asks any coach hint in hostView to re-run its layout (call when the card's layout changes).
+ (void) setNeedsLayoutInView:(UIView *)hostView;

@end

#endif
