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

//! Spec §7: the reading's size and floor for a Dynamic Type multiplier: min(20 x dt, 28), and 15 x dt;
//! dt is capped at 1.4, and compact cards keep the base size.  Both in 0.5pt steps.
static inline void LWEReadingSizes(CGFloat dynamicTypeMultiplier, BOOL compact, CGFloat *baseSize, CGFloat *minSize)
{
  CGFloat dt = compact ? 1.0 : MIN(dynamicTypeMultiplier, 1.4);
  CGFloat base = MIN(28.0, round(20.0 * dt * 2.0) / 2.0);
  if (baseSize) *baseSize = base;
  if (minSize) *minSize = MIN(base, round(15.0 * dt * 2.0) / 2.0);
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
