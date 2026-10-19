//
//  LWEReadingLayout.h
//  jFlash
//
//  Pure helpers for the card's furigana reading row (DD furigana spec, option A): which rows a
//  reading mode shows, the kana-only rule, and the long-reading fit rule.  Header-only so that
//  CardViewController and the unit tests share one copy.
//

#import <UIKit/UIKit.h>

// Keys of the dictionary LWEReadingRows() returns
#define LWEReadingRowTopKey           @"top"           // NSString: the row above the headword (or absent)
#define LWEReadingRowBelowKey         @"below"         // NSString: the romaji row under the headword (or absent)
#define LWEReadingRowTopIsLatinKey    @"topIsLatin"    // NSNumber BOOL: the top row holds romaji (Romaji mode)
#define LWEReadingRowToggleOnRomajiKey @"toggleOnRomaji" // NSNumber BOOL: the toggle sits on the romaji row

//! Spec §5: a kana-only headword (e.g. これ, or ありがとう with Prefer Kana) whose single kana reading
//! is the headword itself.  Its kana would only repeat the headword, so it is dropped.
static inline BOOL LWEReadingIsKanaOnlyHeadword(NSString *kanaText, NSString *headword, NSUInteger kanaCount, BOOL expanded)
{
  return (expanded == NO && kanaCount <= 1 && [kanaText length] > 0 && [kanaText isEqualToString:headword]);
}

//! What the reading rows say for APP_READING mode (KANA / ROMAJI / BOTH):
//!  - Kana or Both: kana above the headword; romaji (Both) in its own row below it.
//!  - Romaji: romaji is the only reading, so it takes the top row.
//!  - Kana-only headword: no top row; in Both or Romaji mode the romaji stays below the headword
//!    and the toggle moves onto that row.  In Kana mode nothing is left (the toggle hides).
static inline NSDictionary *LWEReadingRows(NSString *mode, NSString *kanaText, NSString *romajiText, BOOL kanaOnlyHeadword)
{
  BOOL showKana = ([mode isEqualToString:@"ROMAJI"] == NO);
  BOOL showRomaji = ([mode isEqualToString:@"KANA"] == NO);
  NSString *top = nil;
  NSString *below = nil;
  BOOL topIsLatin = NO;
  if (kanaOnlyHeadword)
  {
    below = showRomaji ? romajiText : nil;
  }
  else if (showKana)
  {
    top = kanaText;
    below = showRomaji ? romajiText : nil;
  }
  else
  {
    top = romajiText;
    topIsLatin = YES;
  }
  if ([top length] == 0) top = nil;
  if ([below length] == 0) below = nil;
  NSMutableDictionary *rows = [NSMutableDictionary dictionaryWithCapacity:4];
  if (top) [rows setObject:top forKey:LWEReadingRowTopKey];
  if (below) [rows setObject:below forKey:LWEReadingRowBelowKey];
  [rows setObject:[NSNumber numberWithBool:topIsLatin] forKey:LWEReadingRowTopIsLatinKey];
  [rows setObject:[NSNumber numberWithBool:(top == nil && below != nil)] forKey:LWEReadingRowToggleOnRomajiKey];
  return rows;
}

//! Spec §4 / §8: the widest a reading may be before it shrinks.  Kana: headword + 24, at least 120.
//! Latin (pinyin, or romaji on the top row): headword + 48, at least 160.  Never wider than the card.
static inline CGFloat LWEReadingMaxWidth(CGFloat headwordInkWidth, BOOL latin, CGFloat contentWidth)
{
  CGFloat maxW = latin ? MAX(headwordInkWidth + 48.0, 160.0) : MAX(headwordInkWidth + 24.0, 120.0);
  return (contentWidth > 0) ? MIN(maxW, contentWidth) : maxW;
}

//! A reading fitted to its row: the point size, the line count (1, or 2 = wrap), and the width.
typedef struct
{
  CGFloat size;
  NSInteger lines;
  CGFloat width;
} LWEReadingFit;

//! Shrink in 0.5pt steps from baseSize down to minSize until naturalWidth(size) fits in maxW; if it
//! still doesn't, use minSize on 2 lines (width = maxW; see LWEReadingBalancedWrapWidth for kana).
static inline LWEReadingFit LWEReadingFitToWidth(CGFloat (^naturalWidth)(CGFloat size), CGFloat baseSize, CGFloat minSize, CGFloat maxW)
{
  LWEReadingFit fit = { baseSize, 1, maxW };
  for (CGFloat size = baseSize; size >= minSize - 0.01; size -= 0.5)
  {
    CGFloat natural = ceil(naturalWidth(size));
    if (natural <= maxW)
    {
      fit.size = size;
      fit.width = natural;
      return fit;
    }
  }
  fit.size = minSize;
  fit.lines = 2;
  return fit;
}

//! Spec §4: a wrapped kana reading's width, for 2 balanced lines: min(maxW, ceil(full / 2) + one glyph).
static inline CGFloat LWEReadingBalancedWrapWidth(CGFloat fullWidth, CGFloat glyphWidth, CGFloat maxW)
{
  return MIN(maxW, ceil(fullWidth / 2.0) + glyphWidth);
}

//! One Dynamic Type rule for all of the card's reading text -- the kana/pinyin row, the romaji row
//! and the Show Reading pill: they follow the text size up to 1.4x (spec §7's cap: 20pt -> 28pt
//! reading, 17 -> 24pt romaji, 13 -> 18pt pill label), and compact cards stay at 1x.
static const CGFloat LWEReadingDynamicTypeCap = 1.4;
static inline CGFloat LWEReadingTypeScale(CGFloat dynamicTypeMultiplier, BOOL compact)
{
  return compact ? 1.0 : MIN(dynamicTypeMultiplier, LWEReadingDynamicTypeCap);
}

//! Spec §7: the reading's size and floor for a Dynamic Type multiplier: min(20 x dt, 28), and 15 x dt,
//! with dt from LWEReadingTypeScale().  Both in 0.5pt steps.
static inline void LWEReadingSizes(CGFloat dynamicTypeMultiplier, BOOL compact, CGFloat *baseSize, CGFloat *minSize)
{
  CGFloat dt = LWEReadingTypeScale(dynamicTypeMultiplier, compact);
  CGFloat base = MIN(28.0, round(20.0 * dt * 2.0) / 2.0);
  if (baseSize) *baseSize = base;
  if (minSize) *minSize = MIN(base, round(15.0 * dt * 2.0) / 2.0);
}

//! The legacy (cFlash) reading row's height: 42pt (two 21pt lines at 15pt), grown to fit the fitted
//! pinyin -- two lines at a larger text size need more (2 x 21 x 1.4 = ~59pt).
static const CGFloat LWELegacyReadingRowHeight = 42.0;
static inline CGFloat LWELegacyReadingRowHeightFor(CGFloat fittedTextHeight)
{
  return MAX(LWELegacyReadingRowHeight, ceil(fittedTextHeight));
}

//! What VoiceOver says for a shown reading: the reading row, then the romaji row, with a pause
//! between the rows only.  A wrapped line is joined back with no separator (no comma mid-reading).
static inline NSString *LWEReadingSpokenLabel(NSString *top, NSString *below)
{
  NSMutableArray *parts = [NSMutableArray array];
  for (NSString *row in [NSArray arrayWithObjects:(top ?: @""), (below ?: @""), nil])
  {
    NSString *joined = [[row componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
    joined = [joined stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([joined length] > 0) [parts addObject:joined];
  }
  return [parts componentsJoinedByString:@", "];
}

//! Inserts a line break at the space that splits text into the two most even lines (pinyin and
//! romaji wrap at syllable spaces only, never inside a syllable).  Returns nil if there is no space.
static inline NSAttributedString *LWEReadingBalancedSplitAtSpace(NSAttributedString *text)
{
  NSString *plain = [text string];
  NSInteger best = NSNotFound;
  CGFloat bestWidth = CGFLOAT_MAX;
  for (NSUInteger i = 1; i + 1 < [plain length]; i++)
  {
    if ([plain characterAtIndex:i] != ' ') continue;
    CGFloat left = [[text attributedSubstringFromRange:NSMakeRange(0, i)] size].width;
    CGFloat right = [[text attributedSubstringFromRange:NSMakeRange(i + 1, [plain length] - i - 1)] size].width;
    CGFloat widest = MAX(left, right);
    if (widest < bestWidth)
    {
      bestWidth = widest;
      best = (NSInteger)i;
    }
  }
  if (best == NSNotFound) return nil;
  NSMutableAttributedString *split = [[NSMutableAttributedString alloc] initWithAttributedString:text];
#if !__has_feature(objc_arc)
  [split autorelease];
#endif
  [split replaceCharactersInRange:NSMakeRange((NSUInteger)best, 1) withString:@"\n"];
  return split;
}

#pragma mark - Meaning area vs the score bubble (DD review of PR #21)

//! The score bubble's corner, reserved at the bottom right of the meaning area (about 56 x 44pt)
static const CGFloat LWEMeaningBubbleCornerWidth  = 56.0;
static const CGFloat LWEMeaningBubbleCornerHeight = 44.0;
//! Height of the bottom fade shown while more meaning is below
static const CGFloat LWEMeaningFadeHeight = 24.0;

//! How the meaning area keeps clear of the score bubble.
//!  wrapCorner:  the meaning fits; its lines wrap around the bubble's corner (nothing scrolls).
//!  scrolls:     the meaning is taller than the area; it scrolls, with bottomInset of extra room at the
//!               end so the last lines can be scrolled clear of the bubble (no corner wrap).
typedef struct {
  BOOL wrapCorner;
  BOOL scrolls;
  CGFloat bottomInset;
} LWEMeaningInsets;

//! contentHeight is the meaning's height with its lines wrapped around the corner; corner is the
//! bubble's part of the area (CGSizeZero when the bubble is hidden).
static inline LWEMeaningInsets LWEMeaningInsetsFor(CGFloat contentHeight, CGFloat viewportHeight, CGSize corner)
{
  LWEMeaningInsets insets = {NO, NO, 0.0};
  BOOL hasCorner = (corner.width > 0.0 && corner.height > 0.0);
  if (contentHeight <= viewportHeight + 0.5)
  {
    insets.wrapCorner = hasCorner;
    return insets;
  }
  insets.scrolls = YES;
  insets.bottomInset = hasCorner ? corner.height : 0.0;
  return insets;
}

//! The bottom fade shows while a scrolling meaning has more below the visible area.
static inline BOOL LWEMeaningShowsBottomFade(LWEMeaningInsets insets, CGFloat offsetY, CGFloat contentHeight, CGFloat viewportHeight)
{
  if (insets.scrolls == NO) return NO;
  return (offsetY + viewportHeight < contentHeight + insets.bottomInset - 1.0);
}

//! A scrolling meaning is masked off above the bubble: it shows down to the bubble's top (the band
//! beside the bubble stays empty), so nothing ever runs under the bubble while it scrolls.
static inline CGFloat LWEMeaningVisibleHeight(LWEMeaningInsets insets, CGFloat viewportHeight)
{
  return insets.scrolls ? MAX(0.0, viewportHeight - insets.bottomInset) : viewportHeight;
}

//! Clear space kept around the bubble
static const CGFloat LWEMeaningBubbleMargin = 6.0;

//! The bubble's corner of a meaning area from where the bubble actually is (in the area's coordinates):
//! from its left edge to the area's right edge, and from its top to the area's bottom, plus a margin.
//! CGSizeZero when the bubble doesn't overlap the area.
static inline CGSize LWEMeaningCornerForBubble(CGRect bubbleInArea, CGSize area)
{
  CGRect bounds = CGRectMake(0, 0, area.width, area.height);
  if (CGRectIsEmpty(bubbleInArea) || !CGRectIntersectsRect(CGRectInset(bubbleInArea, -LWEMeaningBubbleMargin, -LWEMeaningBubbleMargin), bounds)) return CGSizeZero;
  CGFloat w = area.width - (CGRectGetMinX(bubbleInArea) - LWEMeaningBubbleMargin);
  CGFloat h = area.height - (CGRectGetMinY(bubbleInArea) - LWEMeaningBubbleMargin);
  return CGSizeMake(MAX(0.0, MIN(area.width, w)), MAX(0.0, MIN(area.height, h)));
}

//! The bubble's corner inside a meaning area: the reserved 56 x 44pt grown by the theme's bubble nudge
//! (Kutani's rim moves the bubble up and left), clipped to the area.
static inline CGSize LWEMeaningCornerSize(BOOL bubbleVisible, CGFloat nudge, CGSize area)
{
  if (bubbleVisible == NO) return CGSizeZero;
  return CGSizeMake(MIN(area.width, LWEMeaningBubbleCornerWidth + nudge), MIN(area.height, LWEMeaningBubbleCornerHeight + nudge));
}

