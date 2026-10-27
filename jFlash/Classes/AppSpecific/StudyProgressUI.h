//
//  StudyProgressUI.h
//  jFlash
//
//  Direction B: the learned-progress pill, the one-time strip tip, and the footer
//  layout rule (the set name truncates; the pill does not). Pure functions so the
//  formatting and the "shown once" flag can be tested without the study screen.
//

#import <UIKit/UIKit.h>

//! Learned is card level 5 (kLWELearnedCardLevel). A literal so this header does not
//! import Tag.h, which has no include guard and is already in the prefix header.
enum { LWELearnedProgressLevel = 5 };

//! NSUserDefaults flag: YES once the "Your progress lives here" tip has been dismissed.
static NSString * const LWEStudyProgressTipShownKey = @"study_progress_tip_shown";

//! YES until the learner has dismissed the tip (a nil defaults object counts as not yet shown).
static inline BOOL LWEStudyProgressTipShouldShow(NSUserDefaults *defaults)
{
  if (defaults == nil) return YES;
  return ([defaults boolForKey:LWEStudyProgressTipShownKey] == NO);
}

static inline void LWEStudyProgressTipMarkShown(NSUserDefaults *defaults)
{
  if (defaults == nil) return;
  [defaults setBool:YES forKey:LWEStudyProgressTipShownKey];
}

//! cardLevelCounts[Learned], or 0 when the tag has not loaded its counts yet.
static inline NSInteger LWELearnedCountFromLevelCounts(NSArray *counts)
{
  if ([counts count] <= (NSUInteger)LWELearnedProgressLevel) return 0;
  return [[counts objectAtIndex:LWELearnedProgressLevel] integerValue];
}

//! 0 when nothing is learned (or the set is empty); 1 when every card is learned.
static inline CGFloat LWELearnedProgressFraction(NSInteger learned, NSInteger total)
{
  if (total <= 0 || learned <= 0) return 0.0f;
  if (learned >= total) return 1.0f;
  return (CGFloat)learned / (CGFloat)total;
}

//! Every card in the set is Learned. An empty set is not "done".
static inline BOOL LWELearnedProgressIsComplete(NSInteger learned, NSInteger total)
{
  return (total > 0 && learned >= total);
}

//! Visible pill text. The trailing › is drawn separately. completePhrase is the
//! all-learned line ("Set learned ✓"); learnedWord is the word after the counts.
static inline NSString *LWELearnedProgressPillText(NSInteger learned, NSInteger total, NSString *learnedWord, NSString *completePhrase)
{
  if (LWELearnedProgressIsComplete(learned, total)) return completePhrase ?: @"";
  if (learned < 0) learned = 0;
  if (total < 0) total = 0;
  return [NSString stringWithFormat:@"%ld / %ld %@", (long)learned, (long)total, learnedWord ?: @""];
}

//! What VoiceOver reads for the pill. inProgressFormat takes learned, then total
//! (use %1$ld / %2$ld when the translation names the total first).
static inline NSString *LWELearnedProgressAccessibilityLabel(NSInteger learned, NSInteger total, NSString *inProgressFormat, NSString *completePhrase)
{
  if (LWELearnedProgressIsComplete(learned, total)) return completePhrase ?: @"";
  if (learned < 0) learned = 0;
  if (total < 0) total = 0;
  return [NSString stringWithFormat:(inProgressFormat ?: @"%1$ld / %2$ld"), (long)learned, (long)total];
}

//! Visible pill, localized. The format is its own key so it does not reuse the
//! action-bar caption "learned" (Japanese "もう覚えた" is too long for the pill).
static inline NSString *LWELearnedProgressLocalizedPillText(NSInteger learned, NSInteger total)
{
  if (LWELearnedProgressIsComplete(learned, total))
  {
    return NSLocalizedString(@"Set learned ✓", @"StudyProgress.PillComplete");
  }
  if (learned < 0) learned = 0;
  if (total < 0) total = 0;
  return [NSString stringWithFormat:NSLocalizedString(@"%ld / %ld learned", @"StudyProgress.Pill"), (long)learned, (long)total];
}

static inline NSString *LWELearnedProgressLocalizedAccessibilityLabel(NSInteger learned, NSInteger total)
{
  return LWELearnedProgressAccessibilityLabel(learned, total,
                                              NSLocalizedString(@"%ld of %ld learned", @"StudyProgress.PillAccessibility"),
                                              NSLocalizedString(@"Set learned", @"StudyProgress.PillCompleteAccessibility"));
}

//! Width left for the set name. pillWidth is never reduced: a long name truncates,
//! and a pill that fills the row leaves the name at 0. pageDotHalfWidth is how far
//! the dot (when visible) reaches left of the row's centre.
static inline CGFloat LWEStudyFooterNameWidth(CGFloat rowWidth, CGFloat nameX, CGFloat pillWidth, CGFloat pillRightMargin, CGFloat gap, BOOL pageDotVisible, CGFloat pageDotHalfWidth)
{
  if (rowWidth < 0) rowWidth = 0;
  if (nameX < 0) nameX = 0;
  if (pillWidth < 0) pillWidth = 0;
  if (pillRightMargin < 0) pillRightMargin = 0;
  if (gap < 0) gap = 0;
  CGFloat pillX = rowWidth - pillRightMargin - pillWidth;
  CGFloat nameMax = pillX - gap - nameX;
  if (pageDotVisible)
  {
    CGFloat dotLeft = (rowWidth / 2.0f) - pageDotHalfWidth;
    CGFloat beforeDot = dotLeft - gap - nameX;
    if (beforeDot < nameMax) nameMax = beforeDot;
  }
  if (nameMax < 0) nameMax = 0;
  return nameMax;
}

#pragma mark - Ring

//! Small ring for the learned pill. Track and progress colours come from theme slots.
@interface LWEProgressRingView : UIView
@property (nonatomic, assign) CGFloat fraction;
- (void) applyTrackColor:(UIColor *)track fillColor:(UIColor *)fill;
@end

#pragma mark - One-time tip

typedef void (^LWEProgressTipSpotlightProvider)(CGRect *spotlightRect);

//! "Your progress lives here", pointing at the level strip. "Got it" (or a tap outside
//! the bubble, or VoiceOver escape) dismisses it and sets LWEStudyProgressTipShownKey.
@interface StudyProgressTipView : UIView

+ (StudyProgressTipView *) showInView:(UIView *)hostView spotlightProvider:(LWEProgressTipSpotlightProvider)provider;
+ (void) setNeedsLayoutInView:(UIView *)hostView;
+ (StudyProgressTipView *) tipInView:(UIView *)hostView;

@end
