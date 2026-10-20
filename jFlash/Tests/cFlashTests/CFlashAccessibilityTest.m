//
//  CFlashAccessibilityTest.m
//  xFlash
//
//  Chinese Flash versions of the PR #28 accessibility tests (jFlash: CardReadingTest.m): the score
//  bubble (including Browse mode), the study progress strip, Reduce Motion, list contrast, the Study
//  Sets nav bar and the reveal's scroll-indicator flash.  The practice bar's "Learned" label is not
//  covered: Chinese Flash keeps the original icon bar (ActionBarViewController -viewDidLoad).
//

#import <XCTest/XCTest.h>
#import "CardViewController.h"
#import "PracticeModeCardViewDelegate.h"
#import "ChineseCard.h"
#import "MoodIcon.h"
#import "StudyViewController.h"
#import "ProgressBarViewController.h"
#import "StudySetViewController.h"
#import "ThemeManager.h"

@interface CFlashAccessibilityTest : XCTestCase
@end

@implementation CFlashAccessibilityTest

#pragma mark - Helpers

- (CardViewController *) _newCardViewWithDelegate:(id<CardViewControllerDelegate>)delegate
{
  CardViewController *cvc = [[[CardViewController alloc] initDisplayMainHeadword:YES] autorelease];
  cvc.delegate = delegate;
  cvc.view.frame = CGRectMake(0, 0, 402, 494);
  return cvc;
}

- (ChineseCard *) _cardWithHeadword:(NSString *)headword reading:(NSString *)reading meaning:(NSString *)meaning
{
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  card._headword = headword;
  card.headword_simp = headword;
  card.hw_reading = reading;
  card._meaning = meaning;
  return card;
}

static CGFloat LWECFTestRelativeLuminance(UIColor *color)
{
  CGFloat rgb[4] = {0, 0, 0, 1};
  [color getRed:&rgb[0] green:&rgb[1] blue:&rgb[2] alpha:&rgb[3]];
  CGFloat lin[3];
  for (int i = 0; i < 3; i++)
  {
    lin[i] = (rgb[i] <= 0.03928) ? rgb[i] / 12.92 : pow((rgb[i] + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}

static CGFloat LWECFTestContrast(UIColor *a, UIColor *b)
{
  CGFloat la = LWECFTestRelativeLuminance(a), lb = LWECFTestRelativeLuminance(b);
  return (MAX(la, lb) + 0.05) / (MIN(la, lb) + 0.05);
}

#pragma mark - Score bubble

- (void) testScoreBubbleAccessibilityValue
{
  NSString *expected = [NSString stringWithFormat:NSLocalizedString(@"%ld%% right", nil), 100L];
  XCTAssertEqualObjects([MoodIcon accessibilityValueForPercentCorrect:100.0f], expected);
  NSString *v = [MoodIcon accessibilityValueForPercentCorrect:66.6f];
  XCTAssertTrue([v rangeOfString:@"67"].location != NSNotFound, @"Rounded like the bubble: %@", v);
}

- (void) testScoreBubbleReadsTheScoreInPracticeMode
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  MoodIcon *mood = cvc.moodIcon;
  XCTAssertNotNil(mood.moodIconBtn);
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:100.0f];
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityLabel, NSLocalizedString(@"Session score", nil));
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:100.0f]);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityHint, NSLocalizedString(@"Shows or hides the score", nil));
  XCTAssertFalse(mood.percentCorrectLabel.isAccessibilityElement, @"The bubble's \"100%%\" is not read twice");
}

- (void) testBrowseModeScoreBubbleHasNoScoreForVoiceOver
{
  Class browseClass = NSClassFromString(@"BrowseModeCardViewDelegate");
  XCTAssertNotNil(browseClass);
  id<CardViewControllerDelegate> browse = [[[browseClass alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:browse];
  MoodIcon *mood = cvc.moodIcon;
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:100.0f];
  XCTAssertTrue(mood.talkBubble.hidden);
  XCTAssertNil(mood.moodIconBtn.accessibilityValue, @"No score read while none is on screen");
  XCTAssertFalse(mood.moodIconBtn.isAccessibilityElement);
  [cvc setupWithCard:[self _cardWithHeadword:@"你好" reading:@"ni3 hao3" meaning:@"hello"]];
  XCTAssertNil(mood.moodIconBtn.accessibilityValue, @"...on the next card too");

  cvc.delegate = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  [cvc studyViewModeDidChange:nil];
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:100.0f]);
}

- (void) testPracticeScoreBubbleHiddenByTapHasNoValue
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  MoodIcon *mood = cvc.moodIcon;
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:67.0f];
  [mood doTogglePercentCorrectBtn];
  XCTAssertNil(mood.moodIconBtn.accessibilityValue);
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement, @"Still a button, to show the score again");
  [mood doTogglePercentCorrectBtn];
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:67.0f]);
}

#pragma mark - Scroll-indicator flash

- (void) testMeaningScrollFlashDoesNotCarryOverToTheNextCard
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"你好" reading:@"ni3 hao3" meaning:@"hello"]];
  XCTAssertFalse([cvc meaningScrollFlashPending]);
  [practice cardViewDidReveal:cvc];
  XCTAssertTrue([cvc meaningScrollFlashPending]);
  [cvc setupWithCard:[self _cardWithHeadword:@"一半" reading:@"yi1 ban4" meaning:@"half"]];
  XCTAssertFalse([cvc meaningScrollFlashPending], @"The next card starts with no flash pending");
}

#pragma mark - Study screen

- (void) testProgressStripAccessibilitySummary
{
  NSArray *names = @[@"Studying", @"Right 1x", @"Right 2x", @"Right 3x", @"Learned"];
  NSArray *counts = @[@"3", @"15", @"0", @"0", @"2"];
  XCTAssertEqualObjects(LWEProgressAccessibilitySummary(names, counts),
                        @"Studying 3, Right 1x 15, Right 2x 0, Right 3x 0, Learned 2");
  XCTAssertEqualObjects(LWEProgressAccessibilitySummary(@[@"Studying", @""], @[@"3", @"4"]), @"Studying 3", @"Unnamed levels are skipped");
}

- (void) testCardTransitionHonoursReduceMotion
{
  XCTAssertEqualObjects(LWECardTransitionType(NO), kCATransitionPush);
  XCTAssertEqualObjects(LWECardTransitionSubtype(NO, kCATransitionFromLeft), kCATransitionFromLeft);
  XCTAssertEqualObjects(LWECardTransitionType(YES), kCATransitionFade);
  XCTAssertNil(LWECardTransitionSubtype(YES, kCATransitionFromLeft));
}

#pragma mark - Study Sets

- (void) testListSubtitleInkMeetsAAInEveryTheme
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  for (NSString *key in [tm themeKeysList])
  {
    UIColor *ink = [tm colorForSlot:@"cellValueInk" themeKey:key];
    XCTAssertNotNil(ink, @"%@", key);
    for (UIColor *fill in @[[UIColor whiteColor], ([tm colorForSlot:@"cellFill" themeKey:key] ?: [UIColor whiteColor])])
    {
      CGFloat ratio = LWECFTestContrast(ink, fill);
      XCTAssertGreaterThanOrEqual(ratio, 4.5, @"%@: %.2f:1", key, ratio);
    }
  }
}

- (void) testStudySetNavigationBarIsOpaqueInTheThemeColours
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  for (NSString *key in [tm themeKeysList])
  {
    UIColor *fill = [tm colorForSlot:@"navBarFill" themeKey:key];
    UIColor *ink = [tm colorForSlot:@"navTitleInk" themeKey:key];
    XCTAssertNotNil(fill, @"%@", key);
    UINavigationItem *item = [[[UINavigationItem alloc] initWithTitle:@"HSK"] autorelease];
    LWEStudySetApplyNavigationBarAppearance(item, fill, ink);
    for (UINavigationBarAppearance *a in @[item.standardAppearance, item.scrollEdgeAppearance, item.compactAppearance, item.compactScrollEdgeAppearance])
    {
      XCTAssertEqualObjects(a.backgroundColor, fill, @"%@", key);
      CGFloat red = 0, green = 0, blue = 0, alpha = 0;
      [a.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
      XCTAssertEqualWithAccuracy(alpha, 1.0, 0.001, @"%@: opaque", key);
      XCTAssertEqualObjects(a.titleTextAttributes[NSForegroundColorAttributeName], ink, @"%@", key);
    }
  }
}

@end
