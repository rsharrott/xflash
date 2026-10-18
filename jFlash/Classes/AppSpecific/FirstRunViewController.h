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

@interface FirstRunWelcomeViewController : UIViewController <UIAdaptivePresentationControllerDelegate>

//! YES on a fresh install (same condition as the old welcome alert) until the sheet has been shown once.
+ (BOOL) shouldShowWelcome;

//! Records that the sheet was shown so it never appears again.
+ (void) markWelcomeShown;

//! Called after the sheet is dismissed (by "Start studying" or by swiping it away).
@property (nonatomic, copy) dispatch_block_t finishedHandler;

- (IBAction) startStudying:(id)sender;

@end


@interface FirstRunCoachHintView : UIView

//! YES until the user has tapped "Got it" once.
+ (BOOL) shouldShowHint;

//! Dims hostView, outlines spotlightRect (the card) and points a tip bubble at tapPoint.
//! Both rects/points are in hostView's coordinate space.
+ (FirstRunCoachHintView *) showInView:(UIView *)hostView spotlightRect:(CGRect)spotlightRect tapPoint:(CGPoint)tapPoint;

@end

#endif
