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
  XCTAssertEqualObjects(LWELearnedProgressPillText(1, 1, @"覚えた", @"全部覚えた ✓"), @"1 / 1 覚えた");
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
