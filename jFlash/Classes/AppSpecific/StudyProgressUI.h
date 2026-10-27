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

//! How much of the pill sentence to draw. Full is "4 / 626 learned"; compact drops the
//! word; tight is "4/626" with no chevron, used only when compact would cover the page dots.
enum {
  LWELearnedPillTextFull = 0,
  LWELearnedPillTextCompact = 1,
  LWELearnedPillTextTight = 2,
};

//! Counts only, for the compact and tight lines. format is "%ld / %ld" or "%ld/%ld".
static inline NSString *LWELearnedProgressCountsText(NSInteger learned, NSInteger total, NSString *format)
{
  if (learned < 0) learned = 0;
  if (total < 0) total = 0;
  return [NSString stringWithFormat:(format ?: @"%ld / %ld"), (long)learned, (long)total];
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

//! Shorter visible lines for when the full pill would cover the page dots.
//! VoiceOver keeps the full sentence; only the drawn label changes.
static inline NSString *LWELearnedProgressLocalizedPillTextForStyle(NSInteger learned, NSInteger total, NSInteger style)
{
  if (LWELearnedProgressIsComplete(learned, total))
  {
    if (style == LWELearnedPillTextTight) return NSLocalizedString(@"✓", @"StudyProgress.PillTightComplete");
    if (style == LWELearnedPillTextCompact) return NSLocalizedString(@"Learned ✓", @"StudyProgress.PillCompactComplete");
    return NSLocalizedString(@"Set learned ✓", @"StudyProgress.PillComplete");
  }
  if (learned < 0) learned = 0;
  if (total < 0) total = 0;
  if (style == LWELearnedPillTextTight)
  {
    return LWELearnedProgressCountsText(learned, total, NSLocalizedString(@"%ld/%ld", @"StudyProgress.PillTight"));
  }
  if (style == LWELearnedPillTextCompact)
  {
    return LWELearnedProgressCountsText(learned, total, NSLocalizedString(@"%ld / %ld", @"StudyProgress.PillCompact"));
  }
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

//! Width of the pill besides its label. The tight form drops the chevron and a little padding.
static inline CGFloat LWELearnedPillChromeWidth(BOOL includesChevron)
{
  CGFloat ring = 16.0;
  if (includesChevron)
  {
    CGFloat hPad = 10.0;
    CGFloat gap = 5.0;
    CGFloat chevron = 11.0;
    return hPad + ring + gap + gap + chevron + hPad;
  }
  CGFloat hPad = 8.0;
  CGFloat gap = 4.0;
  return hPad + ring + gap + hPad;
}

//! Left edge the pill's hit target must stay to the right of. With the page dots showing,
//! that is the dot's right edge plus gap, so a 44pt-tall pill cannot cover the control.
static inline CGFloat LWEStudyFooterPillMinX(CGFloat rowWidth, BOOL pageDotVisible, CGFloat pageDotHalfWidth, CGFloat gap)
{
  if (rowWidth < 0) rowWidth = 0;
  if (pageDotVisible == NO) return 0;
  if (pageDotHalfWidth < 0) pageDotHalfWidth = 0;
  if (gap < 0) gap = 0;
  CGFloat minX = (rowWidth / 2.0f) + pageDotHalfWidth + gap;
  if (minX < 0) minX = 0;
  if (minX > rowWidth) minX = rowWidth;
  return minX;
}

typedef struct {
  NSInteger index; //!< LWELearnedPillTextFull, Compact, or Tight
  CGFloat pillX;
  CGFloat pillWidth;
} LWEStudyFooterPillFit;

//! Right-align the longest pill that stays at or to the right of minX. widths are full, then
//! compact, then tight, each already including chrome. If even the tight pill cannot, pin it
//! at minX and clip it to the row so the hit target still does not cover the dots.
static inline LWEStudyFooterPillFit LWEStudyFooterFitPill(CGFloat rowWidth, CGFloat rightMargin, CGFloat minX, CGFloat fullWidth, CGFloat compactWidth, CGFloat tightWidth)
{
  LWEStudyFooterPillFit fit;
  fit.index = LWELearnedPillTextTight;
  fit.pillX = 0;
  fit.pillWidth = 0;
  if (rowWidth < 0) rowWidth = 0;
  if (rightMargin < 0) rightMargin = 0;
  if (minX < 0) minX = 0;
  if (minX > rowWidth) minX = rowWidth;
  CGFloat widths[3];
  widths[0] = (fullWidth < 1.0f) ? 1.0f : fullWidth;
  widths[1] = (compactWidth < 1.0f) ? 1.0f : compactWidth;
  widths[2] = (tightWidth < 1.0f) ? 1.0f : tightWidth;
  CGFloat limit = rowWidth - rightMargin;
  if (limit < minX) limit = rowWidth;
  for (NSInteger i = 0; i < 3; i++)
  {
    CGFloat x = limit - widths[i];
    if (x >= minX - 0.5f)
    {
      fit.index = i;
      fit.pillX = x;
      fit.pillWidth = widths[i];
      return fit;
    }
  }
  fit.index = LWELearnedPillTextTight;
  fit.pillX = minX;
  CGFloat room = rowWidth - minX;
  fit.pillWidth = (widths[2] < room) ? widths[2] : room;
  if (fit.pillWidth < 0) fit.pillWidth = 0;
  return fit;
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

//! Drops the spotlight callback so a study screen that is going away is not messaged.
- (void) clearSpotlightProvider;

@end

#pragma mark - Weak target

//! Zeroing weak reference for the progress-tip timer and spotlight callback (the app is MRC).
@interface LWEWeakHolder : NSObject
- (id) initWithObject:(id)object;
- (id) object;
@end

#pragma mark - Pill hit target

//! Not a UIControl. UIScrollView cancels touches in plain views, so a swipe that starts on the
//! pill pages the card; a tap is a separate gesture and is what opens the progress sheet.
@interface LWETapPillView : UIView
@end
