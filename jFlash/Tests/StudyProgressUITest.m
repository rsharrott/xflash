//
//  StudyProgressUITest.m
//  jFlash
//
//  Learned-pill text (including the all-learned case) and the one-time progress tip flag.
//

#import <XCTest/XCTest.h>
#import "StudyProgressUI.h"

@interface StudyProgressUITest : XCTestCase
@end

@implementation StudyProgressUITest

#pragma mark - Pill text

- (void) testPillShowsLearnedOverTotal
{
  XCTAssertEqualObjects(LWELearnedProgressPillText(4, 626, @"learned", @"Set learned ✓"), @"4 / 626 learned");
  XCTAssertEqualObjects(LWELearnedProgressPillText(0, 626, @"learned", @"Set learned ✓"), @"0 / 626 learned");
  // 1 of 2 is still in progress, so the localized word is used. 1 of 1 is the all-learned line.
  XCTAssertEqualObjects(LWELearnedProgressPillText(1, 2, @"覚えた", @"全部覚えた ✓"), @"1 / 2 覚えた");
}

- (void) testPillShowsSetLearnedWhenEveryCardIsLearned
{
  XCTAssertEqualObjects(LWELearnedProgressPillText(626, 626, @"learned", @"Set learned ✓"), @"Set learned ✓");
  XCTAssertEqualObjects(LWELearnedProgressPillText(14, 14, @"learned", @"Set learned ✓"), @"Set learned ✓");
  // A count past the total (stale cache) still reads as finished, not "700 / 626 learned".
  XCTAssertEqualObjects(LWELearnedProgressPillText(700, 626, @"learned", @"Set learned ✓"), @"Set learned ✓");
}

- (void) testEmptySetIsNotSetLearned
{
  XCTAssertFalse(LWELearnedProgressIsComplete(0, 0));
  XCTAssertEqualObjects(LWELearnedProgressPillText(0, 0, @"learned", @"Set learned ✓"), @"0 / 0 learned");
  XCTAssertEqualWithAccuracy(LWELearnedProgressFraction(0, 0), 0.0, 0.0001);
}

- (void) testNegativeCountsAreClamped
{
  XCTAssertEqualObjects(LWELearnedProgressPillText(-3, 10, @"learned", @"Set learned ✓"), @"0 / 10 learned");
  XCTAssertEqualObjects(LWELearnedProgressPillText(2, -5, @"learned", @"Set learned ✓"), @"2 / 0 learned");
}

- (void) testFractionMatchesLearnedOverTotal
{
  XCTAssertEqualWithAccuracy(LWELearnedProgressFraction(0, 626), 0.0, 0.0001);
  XCTAssertEqualWithAccuracy(LWELearnedProgressFraction(4, 626), 4.0 / 626.0, 0.0001);
  XCTAssertEqualWithAccuracy(LWELearnedProgressFraction(626, 626), 1.0, 0.0001);
  XCTAssertEqualWithAccuracy(LWELearnedProgressFraction(-1, 10), 0.0, 0.0001);
}

- (void) testLearnedCountReadsLevelFive
{
  XCTAssertEqual(kLWELearnedCardLevel, (NSInteger)LWELearnedProgressLevel);
  NSArray *counts = @[ @600, @4, @15, @3, @0, @4 ];
  XCTAssertEqual(LWELearnedCountFromLevelCounts(counts), 4);
  XCTAssertEqual(LWELearnedCountFromLevelCounts(@[ @1, @2 ]), 0);
  XCTAssertEqual(LWELearnedCountFromLevelCounts(nil), 0);
}

#pragma mark - VoiceOver

- (void) testAccessibilityLabelSpeaksLearnedOfTotal
{
  XCTAssertEqualObjects(LWELearnedProgressAccessibilityLabel(4, 626, @"%ld of %ld learned", @"Set learned"),
                        @"4 of 626 learned");
  XCTAssertEqualObjects(LWELearnedProgressAccessibilityLabel(626, 626, @"%ld of %ld learned", @"Set learned"),
                        @"Set learned");
}

- (void) testAccessibilityLabelHonoursPositionalJapanese
{
  NSString *fmt = @"%2$ld枚中%1$ld枚を覚えました";
  XCTAssertEqualObjects(LWELearnedProgressAccessibilityLabel(4, 626, fmt, @"このセットは全部覚えました"),
                        @"626枚中4枚を覚えました");
  XCTAssertEqualObjects(LWELearnedProgressAccessibilityLabel(626, 626, fmt, @"このセットは全部覚えました"),
                        @"このセットは全部覚えました");
}

#pragma mark - Compact pill text

- (void) testCountsTextDropsTheWordAndThenTheSpaces
{
  XCTAssertEqualObjects(LWELearnedProgressCountsText(2999, 3000, @"%ld / %ld"), @"2999 / 3000");
  XCTAssertEqualObjects(LWELearnedProgressCountsText(2999, 3000, @"%ld / %ld語"), @"2999 / 3000語");
  XCTAssertEqualObjects(LWELearnedProgressCountsText(2999, 3000, @"%ld/%ld"), @"2999/3000");
  XCTAssertEqualObjects(LWELearnedProgressCountsText(4, 626, @"%ld / %ld 覚えた"), @"4 / 626 覚えた");
}

#pragma mark - Footer: the pill stays clear of the page dots

- (CGFloat) _textWidth:(NSString *)text size:(CGFloat)size
{
  UIFont *font = [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
  CGSize measured = [text sizeWithAttributes:@{ NSFontAttributeName: font }];
  return ceil(measured.width);
}

- (void) _assertPillClearsDots:(LWEStudyFooterPillFit)fit row:(CGFloat)row minX:(CGFloat)minX half:(CGFloat)half
{
  XCTAssertGreaterThanOrEqual(fit.pillX, minX - 0.01);
  XCTAssertLessThanOrEqual(fit.pillX + fit.pillWidth, row + 0.01);
  // The hit target is the pill's frame, 44pt tall, on the same row as the dots.
  CGRect pill = CGRectMake(fit.pillX, 0, fit.pillWidth, 44);
  CGRect dots = CGRectMake(row / 2.0 - half, 4, half * 2.0, 36);
  XCTAssertFalse(CGRectIntersectsRect(pill, dots));
}

- (void) testFourDigitPillClearsDotsOnA375PointScreen
{
  CGFloat row = 375;
  CGFloat minX = LWEStudyFooterPillMinX(row, YES, 18, 8);
  // The reviewer's estimate: a 4-digit full pill is about 180pt and would start on the dots.
  LWEStudyFooterPillFit estimated = LWEStudyFooterFitPill(row, 12, minX, 180, 140, 110);
  XCTAssertNotEqual(estimated.index, (NSInteger)LWELearnedPillTextFull);
  [self _assertPillClearsDots:estimated row:row minX:minX half:18];

  // 18pt is the reserved half-width; 19pt is half of the 38pt control in StudyView.xib.
  CGFloat halves[2] = { 18.0, 19.0 };
  CGFloat sizes[2] = { 13.0, 20.0 };
  NSArray *fulls = @[ @"2999 / 3000 learned", @"2999 / 3000 覚えた", @"Set learned ✓", @"全部覚えた ✓" ];
  NSArray *compacts = @[ @"2999 / 3000", @"2999 / 3000語", @"Learned ✓", @"覚えた ✓" ];
  NSArray *tights = @[ @"2999/3000", @"2999/3000", @"✓", @"✓" ];
  for (NSInteger h = 0; h < 2; h++)
  {
    CGFloat half = halves[h];
    CGFloat edge = LWEStudyFooterPillMinX(row, YES, half, 8);
    for (NSUInteger i = 0; i < [fulls count]; i++)
    {
      for (NSInteger s = 0; s < 2; s++)
      {
        CGFloat size = sizes[s];
        CGFloat fullW = LWELearnedPillChromeWidth(YES) + [self _textWidth:[fulls objectAtIndex:i] size:size];
        CGFloat compactW = LWELearnedPillChromeWidth(YES) + [self _textWidth:[compacts objectAtIndex:i] size:size];
        CGFloat tightW = LWELearnedPillChromeWidth(NO) + [self _textWidth:[tights objectAtIndex:i] size:size];
        LWEStudyFooterPillFit fit = LWEStudyFooterFitPill(row, 12, edge, fullW, compactW, tightW);
        if (fullW > row - 12.0 - edge) XCTAssertNotEqual(fit.index, (NSInteger)LWELearnedPillTextFull);
        [self _assertPillClearsDots:fit row:row minX:edge half:half];
      }
    }
  }
}

- (void) testPillPinsBesideTheDotsWhenNothingFits
{
  CGFloat row = 375;
  CGFloat minX = LWEStudyFooterPillMinX(row, YES, 18, 8);
  LWEStudyFooterPillFit fit = LWEStudyFooterFitPill(row, 12, minX, 400, 400, 400);
  XCTAssertEqual(fit.index, (NSInteger)LWELearnedPillTextTight);
  [self _assertPillClearsDots:fit row:row minX:minX half:18];
}

- (void) testPillHitTargetIsNotAControlSoASwipeCanPage
{
  XCTAssertFalse([LWETapPillView isSubclassOfClass:[UIControl class]]);
}

#pragma mark - Footer: the set name truncates, the pill does not

- (void) testNameStopsBeforeThePill
{
  // 390pt row, 12pt margins, 160pt pill: the name gets the leftover, not a share of the pill.
  CGFloat name = LWEStudyFooterNameWidth(390, 12, 160, 12, 8, NO, 18);
  XCTAssertEqualWithAccuracy(name, 198, 0.01);
}

- (void) testNameStopsBeforeThePageDotWhenThePillIsFurtherRight
{
  CGFloat withDot = LWEStudyFooterNameWidth(390, 12, 120, 12, 8, YES, 18);
  CGFloat noDot = LWEStudyFooterNameWidth(390, 12, 120, 12, 8, NO, 18);
  XCTAssertLessThan(withDot, noDot);
  // Dot centre 195, half-width 18, gap 8, name x 12 → 195 - 18 - 8 - 12 = 157.
  XCTAssertEqualWithAccuracy(withDot, 157, 0.01);
}

- (void) testNameGivesWayWhenThePillFillsTheRow
{
  CGFloat name = LWEStudyFooterNameWidth(320, 12, 400, 12, 8, NO, 18);
  XCTAssertEqualWithAccuracy(name, 0, 0.01);
}

#pragma mark - Tip flag

- (NSUserDefaults *) _tipDefaults
{
  NSString *suite = @"LWEStudyProgressTipTest";
  NSUserDefaults *defs = [[[NSUserDefaults alloc] initWithSuiteName:suite] autorelease];
  [defs removePersistentDomainForName:suite];
  return defs;
}

- (void) testTipShowsUntilDismissedAndThenStaysHidden
{
  NSUserDefaults *defs = [self _tipDefaults];
  XCTAssertTrue(LWEStudyProgressTipShouldShow(defs));
  XCTAssertTrue(LWEStudyProgressTipShouldShow(defs), @"reading the flag does not consume it");
  LWEStudyProgressTipMarkShown(defs);
  XCTAssertFalse(LWEStudyProgressTipShouldShow(defs));
  LWEStudyProgressTipMarkShown(defs);
  XCTAssertFalse(LWEStudyProgressTipShouldShow(defs), @"a second dismiss keeps it hidden");
}

- (void) testNilDefaultsStillOffersTheTip
{
  XCTAssertTrue(LWEStudyProgressTipShouldShow(nil));
  LWEStudyProgressTipMarkShown(nil);
}

- (void) testWeakHolderZeroesWhenTheTargetIsReleased
{
  LWEWeakHolder *holder = nil;
  @autoreleasepool {
    NSObject *target = [[NSObject alloc] init];
    holder = [[LWEWeakHolder alloc] initWithObject:target];
    // objc_loadWeak retains and autoreleases, so that hold has to drain
    // before the last release is the one that deallocates.
    XCTAssertEqual([holder object], target);
    [target release];
  }
  XCTAssertNil([holder object]);
  [holder release];
}

#pragma mark - Strings (jFlash ships en and ja)

#if defined(LWE_JFLASH)
- (NSDictionary *) _stringsForLocalization:(NSString *)localization
{
  NSString *path = [[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings" inDirectory:nil forLocalization:localization];
  XCTAssertNotNil(path, @"host app should ship %@.lproj/Localizable.strings", localization);
  return path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
}

- (void) testPillAndTipStringsAreLocalizedInEnglishAndJapanese
{
  NSDictionary *en = [self _stringsForLocalization:@"en"];
  NSDictionary *ja = [self _stringsForLocalization:@"ja"];
  XCTAssertEqualObjects([en objectForKey:@"%ld / %ld learned"], @"%ld / %ld learned");
  XCTAssertEqualObjects([ja objectForKey:@"%ld / %ld learned"], @"%ld / %ld 覚えた");
  XCTAssertEqualObjects([en objectForKey:@"%ld / %ld"], @"%ld / %ld");
  XCTAssertEqualObjects([ja objectForKey:@"%ld / %ld"], @"%ld / %ld語");
  XCTAssertEqualObjects([en objectForKey:@"%ld/%ld"], @"%ld/%ld");
  XCTAssertEqualObjects([ja objectForKey:@"%ld/%ld"], @"%ld/%ld");
  XCTAssertEqualObjects([en objectForKey:@"Learned ✓"], @"Learned ✓");
  XCTAssertEqualObjects([ja objectForKey:@"Learned ✓"], @"覚えた ✓");
  XCTAssertEqualObjects([en objectForKey:@"Set learned ✓"], @"Set learned ✓");
  XCTAssertEqualObjects([ja objectForKey:@"Set learned ✓"], @"全部覚えた ✓");
  XCTAssertEqualObjects([en objectForKey:@"%ld of %ld learned"], @"%ld of %ld learned");
  XCTAssertEqualObjects([ja objectForKey:@"%ld of %ld learned"], @"%2$ld枚中%1$ld枚を覚えました");
  XCTAssertEqualObjects([en objectForKey:@"Set learned"], @"Set learned");
  XCTAssertEqualObjects([ja objectForKey:@"Set learned"], @"このセットは全部覚えました");
  XCTAssertEqualObjects([en objectForKey:@"Your progress lives here"], @"Your progress lives here");
  XCTAssertEqualObjects([ja objectForKey:@"Your progress lives here"], @"進み具合はここです");
  NSString *body = @"Tap the level bars, or the count under the card, to see how far along you are in this set.";
  XCTAssertEqualObjects([en objectForKey:body], body);
  XCTAssertEqualObjects([ja objectForKey:body], @"上のレベルバーか、カードの下の枚数をタップすると、このセットの進み具合が見られます。");
  XCTAssertGreaterThan([[ja objectForKey:@"Got it"] length], 0u);
}
#endif

@end
