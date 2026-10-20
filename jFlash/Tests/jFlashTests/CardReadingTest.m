//
//  CardReadingTest.m
//  jFlash
//
//  The card's furigana reading row (DD furigana spec, option A): reading-visibility state,
//  the kana-only rule, and the long-reading fit rule.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "LWEReadingLayout.h"
#import "CardViewController.h"
#import "PracticeModeCardViewDelegate.h"
#import "JapaneseCard.h"
#import "Constants.h"
#import "MoodIcon.h"
#import "ActionBarViewController.h"
#import "StudyViewController.h"
#import "ProgressBarViewController.h"
#import "ThemeManager.h"
#import "StudySetViewController.h"

//! Stands in for a Group, so the Study Sets screen can load without the database
@interface LWEStudySetStubGroup : NSObject
@property (nonatomic, retain) NSString *groupName;
@property (nonatomic) NSInteger groupId;
@end

@implementation LWEStudySetStubGroup
@synthesize groupName, groupId;
- (NSArray *) childTags { return [NSArray array]; }
- (BOOL) isTopLevelGroup { return NO; }
- (void) dealloc { [groupName release]; [super dealloc]; }
@end

static void LWEStudySetTestNoop(id self, SEL _cmd) {}

/**
 * The host app's StudySetViewController (the test bundle doesn't compile its own copy, so it is looked
 * up at run time), with -reloadSubgroupData stubbed out so the screen loads without the database.
 */
static Class LWEStudySetControllerClassWithoutDatabase(void)
{
  Class base = NSClassFromString(@"StudySetViewController");
  if (base == nil) return nil;
  const char *name = "LWEStudySetViewControllerWithoutDatabase";
  Class cls = objc_getClass(name);
  if (cls == nil)
  {
    cls = objc_allocateClassPair(base, name, 0);
    class_addMethod(cls, @selector(reloadSubgroupData), (IMP)LWEStudySetTestNoop, "v@:");
    objc_registerClassPair(cls);
  }
  return cls;
}

@interface CardReadingTest : XCTestCase
@end

@implementation CardReadingTest
{
  NSString *_savedHeadwordSetting;
  NSString *_savedReadingSetting;
}

- (void)setUp
{
  [super setUp];
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  _savedHeadwordSetting = [[settings objectForKey:APP_HEADWORD] retain];
  _savedReadingSetting = [[settings objectForKey:APP_READING] retain];
  [settings setObject:SET_J_TO_E forKey:APP_HEADWORD];
  [settings setObject:SET_READING_BOTH forKey:APP_READING];
  // Each test starts as a fresh launch: reading hidden
  [CardViewController setSessionReadingVisible:NO];
}

- (void)tearDown
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  if (_savedHeadwordSetting) [settings setObject:_savedHeadwordSetting forKey:APP_HEADWORD];
  else [settings removeObjectForKey:APP_HEADWORD];
  if (_savedReadingSetting) [settings setObject:_savedReadingSetting forKey:APP_READING];
  else [settings removeObjectForKey:APP_READING];
  [_savedHeadwordSetting release];
  _savedHeadwordSetting = nil;
  [_savedReadingSetting release];
  _savedReadingSetting = nil;
  [CardViewController setSessionReadingVisible:NO];
  [super tearDown];
}

#pragma mark - Helpers

//! A J-to-E study card controller with its view loaded at the 17 Pro's card size
- (CardViewController *)_newCardViewWithDelegate:(id<CardViewControllerDelegate>)delegate
{
  CardViewController *cvc = [[[CardViewController alloc] initDisplayMainHeadword:YES] autorelease];
  cvc.delegate = delegate;
  cvc.view.frame = CGRectMake(0, 0, 402, 494);
  return cvc;
}

- (JapaneseCard *)_cardWithHeadword:(NSString *)headword reading:(NSString *)reading romaji:(NSString *)romaji
{
  JapaneseCard *card = [[[JapaneseCard alloc] init] autorelease];
  card._headword = headword;
  card.hw_reading = reading;
  card.romaji = romaji;
  card._meaning = @"study";
  return card;
}

#pragma mark - Reading visibility (spec §1, §7)

- (void)testReadingStartsHidden
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  XCTAssertFalse(cvc.readingVisible, @"A new card view starts with the reading hidden");
  [cvc setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  XCTAssertTrue(cvc.readingScrollContainer.hidden, @"The reading row is hidden at launch");
  XCTAssertFalse(cvc.toggleReadingBtn.hidden, @"The Show Reading toggle is on screen");
  XCTAssertEqualObjects(cvc.toggleReadingBtn.accessibilityLabel, NSLocalizedString(@"Show Reading", nil));
}

- (void)testTapTogglesReadingAndStoresChoice
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];

  [cvc doToggleReadingBtn];
  XCTAssertFalse(cvc.readingScrollContainer.hidden, @"Tapping the pill shows the reading");
  XCTAssertTrue(cvc.readingVisible, @"...and remembers the choice");
  XCTAssertFalse(cvc.toggleReadingBtn.hidden, @"The blank toggle stays over the reading so it can hide it again");
  XCTAssertTrue(cvc.toggleReadingBtn.enabled);
  XCTAssertEqualObjects(cvc.toggleReadingBtn.accessibilityHint, NSLocalizedString(@"Hides the reading", nil));

  [cvc doToggleReadingBtn];
  XCTAssertTrue(cvc.readingScrollContainer.hidden, @"Tapping the reading hides it again");
  XCTAssertFalse(cvc.readingVisible);

  // The choice carries to the next card for the life of this card view
  [cvc doToggleReadingBtn];
  [cvc setupWithCard:[self _cardWithHeadword:@"海" reading:@"うみ" romaji:@"umi"]];
  XCTAssertFalse(cvc.readingScrollContainer.hidden, @"Shown stays shown on the next card");
}

- (void)testRevealShowsReadingWithoutChangingChoice
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];

  [cvc reveal];
  XCTAssertFalse(cvc.readingScrollContainer.hidden, @"Revealing the answer shows this card's reading");
  XCTAssertFalse(cvc.readingVisible, @"...but doesn't change the stored choice");

  [cvc setupWithCard:[self _cardWithHeadword:@"海" reading:@"うみ" romaji:@"umi"]];
  XCTAssertTrue(cvc.readingScrollContainer.hidden, @"The next card starts hidden again");
}

- (void)testSessionStartsHidden
{
  XCTAssertFalse([CardViewController sessionReadingVisible], @"Each launch starts with the reading hidden");
}

- (void)testNewCardViewControllerKeepsSessionChoice
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *first = [self _newCardViewWithDelegate:practice];
  [first setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  [first doToggleReadingBtn];
  XCTAssertTrue(first.readingVisible);
  XCTAssertTrue([CardViewController sessionReadingVisible], @"Tapping sets the session's choice (in memory)");

  // Theme, direction, mode and text-size changes build a new card view: it keeps the choice
  CardViewController *second = [self _newCardViewWithDelegate:practice];
  XCTAssertTrue(second.readingVisible, @"A mid-session theme change doesn't flip the reading back to hidden");
  [second setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  XCTAssertFalse(second.readingScrollContainer.hidden);

  // Hiding it again also carries over
  [second doToggleReadingBtn];
  CardViewController *third = [self _newCardViewWithDelegate:practice];
  [third setupWithCard:[self _cardWithHeadword:@"海" reading:@"うみ" romaji:@"umi"]];
  XCTAssertFalse(third.readingVisible);
  XCTAssertTrue(third.readingScrollContainer.hidden);
}

- (void)testSessionChoiceIsNotSaved
{
  NSDictionary *before = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  [cvc doToggleReadingBtn];
  NSDictionary *after = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
  XCTAssertEqualObjects([before allKeys].count ? [NSSet setWithArray:[before allKeys]] : [NSSet set],
                        [after allKeys].count ? [NSSet setWithArray:[after allKeys]] : [NSSet set],
                        @"Showing the reading writes nothing to NSUserDefaults");
}

- (void)testForcedReadingDoesNotChangeSessionChoice
{
  // Browse mode and English-first cards set readingVisible on their own card view
  // (BrowseModeCardViewDelegate -cardViewDidChangeMode:); that isn't the reader's choice
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *forced = [self _newCardViewWithDelegate:practice];
  forced.readingVisible = YES;
  XCTAssertFalse([CardViewController sessionReadingVisible]);
  CardViewController *next = [self _newCardViewWithDelegate:practice];
  XCTAssertFalse(next.readingVisible, @"Back in practice the reading is still hidden");
}

- (void)testToggleSitsOverReadingRowAboveHeadword
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  [cvc layoutCardSubviews];
  CGRect toggle = cvc.toggleReadingBtn.frame;
  XCTAssertGreaterThanOrEqual(toggle.size.height, 44.0, @"44pt hit area");
  XCTAssertEqualWithAccuracy(CGRectGetMidY(toggle), 58.0 + 14.0, 1.0, @"Centred on the 28pt reading row at the 58pt top padding");
  XCTAssertLessThan(CGRectGetMidY(toggle), CGRectGetMinY(cvc.headwordScrollContainer.frame) + 10.0, @"The reading row is above the headword");
  XCTAssertGreaterThan([cvc revealAreaTop], CGRectGetMaxY(cvc.headwordScrollContainer.frame), @"Tap-to-reveal starts below the headword");
}

- (void)testKanaOnlyHeadwordMovesToggleToRomajiRow
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"ありがとう" reading:@"ありがとう" romaji:@"arigatou"]];
  [cvc layoutCardSubviews];
  XCTAssertFalse(cvc.toggleReadingBtn.hidden, @"Both mode: romaji is still a reading to show");
  XCTAssertEqual([cvc.readingLabel.attributedText length], (NSUInteger)0, @"No kana row repeating the headword");
  XCTAssertGreaterThan(CGRectGetMidY(cvc.toggleReadingBtn.frame), CGRectGetMaxY(cvc.headwordScrollContainer.frame) - 10.0,
                       @"The toggle sits on the romaji row below the headword");
}

- (void)testKanaOnlyHeadwordInKanaModeHidesToggle
{
  [[NSUserDefaults standardUserDefaults] setObject:SET_READING_KANA forKey:APP_READING];
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"これ" reading:@"これ" romaji:@"kore"]];
  XCTAssertTrue(cvc.toggleReadingBtn.hidden, @"Kana mode: nothing to show, so no Show Reading");
}

#pragma mark - Kana-only rule (spec §5)

- (void)testKanaOnlyWhenKanaEqualsHeadword
{
  XCTAssertTrue(LWEReadingIsKanaOnlyHeadword(@"ありがとう", @"ありがとう", 1, NO));
  XCTAssertTrue(LWEReadingIsKanaOnlyHeadword(@"テレビ", @"テレビ", 1, NO));
}

- (void)testKanaReadingEqualToHeadwordIsSkippedWithMoreReadings
{
  // QA: ゴールデンウィーク showed ゴールデンウィーク again above itself (it has a second reading,
  // ゴールデン・ウィーク, which the "+1 reading" pill still offers)
  XCTAssertTrue(LWEReadingIsKanaOnlyHeadword(@"ゴールデンウィーク", @"ゴールデンウィーク", 2, NO));
  XCTAssertTrue(LWEReadingIsKanaOnlyHeadword(@"これ", @"これ", 2, NO));
  NSDictionary *rows = LWEReadingRows(SET_READING_BOTH, @"ゴールデンウィーク", @"go-rudenui-ku", YES);
  XCTAssertNil(rows[LWEReadingRowTopKey], @"No duplicate katakana row above the headword");
  XCTAssertEqualObjects(rows[LWEReadingRowBelowKey], @"go-rudenui-ku");
}

- (void)testNotKanaOnlyWhenReadingDiffersOrListed
{
  XCTAssertFalse(LWEReadingIsKanaOnlyHeadword(@"べんきょう", @"勉強", 1, NO));
  XCTAssertFalse(LWEReadingIsKanaOnlyHeadword(@"これ", @"これ", 1, YES), @"Expanded +N readings list");
  XCTAssertFalse(LWEReadingIsKanaOnlyHeadword(nil, @"これ", 0, NO));
}

- (void)testRowsBothMode
{
  NSDictionary *rows = LWEReadingRows(SET_READING_BOTH, @"べんきょう", @"benkyou", NO);
  XCTAssertEqualObjects(rows[LWEReadingRowTopKey], @"べんきょう");
  XCTAssertEqualObjects(rows[LWEReadingRowBelowKey], @"benkyou", @"Romaji moves to its own row below the headword");
  XCTAssertFalse([rows[LWEReadingRowTopIsLatinKey] boolValue]);
  XCTAssertFalse([rows[LWEReadingRowToggleOnRomajiKey] boolValue]);
}

- (void)testRowsKanaMode
{
  NSDictionary *rows = LWEReadingRows(SET_READING_KANA, @"べんきょう", @"benkyou", NO);
  XCTAssertEqualObjects(rows[LWEReadingRowTopKey], @"べんきょう");
  XCTAssertNil(rows[LWEReadingRowBelowKey]);
}

- (void)testRowsRomajiModeTakesTopRow
{
  NSDictionary *rows = LWEReadingRows(SET_READING_ROMAJI, @"べんきょう", @"benkyou", NO);
  XCTAssertEqualObjects(rows[LWEReadingRowTopKey], @"benkyou");
  XCTAssertNil(rows[LWEReadingRowBelowKey]);
  XCTAssertTrue([rows[LWEReadingRowTopIsLatinKey] boolValue]);
  XCTAssertFalse([rows[LWEReadingRowToggleOnRomajiKey] boolValue]);
}

- (void)testRowsKanaOnlyBothAndRomajiMoveToggleToRomaji
{
  for (NSString *mode in @[SET_READING_BOTH, SET_READING_ROMAJI])
  {
    NSDictionary *rows = LWEReadingRows(mode, @"ありがとう", @"arigatou", YES);
    XCTAssertNil(rows[LWEReadingRowTopKey], @"%@: the kana is dropped", mode);
    XCTAssertEqualObjects(rows[LWEReadingRowBelowKey], @"arigatou", @"%@", mode);
    XCTAssertTrue([rows[LWEReadingRowToggleOnRomajiKey] boolValue], @"%@: toggle on the romaji row", mode);
  }
}

- (void)testRowsKanaOnlyKanaModeHasNothing
{
  NSDictionary *rows = LWEReadingRows(SET_READING_KANA, @"ありがとう", @"arigatou", YES);
  XCTAssertNil(rows[LWEReadingRowTopKey]);
  XCTAssertNil(rows[LWEReadingRowBelowKey]);
  XCTAssertFalse([rows[LWEReadingRowToggleOnRomajiKey] boolValue]);
}

#pragma mark - Long-reading fit (spec §4, §8)

- (void)testMaxWidthKana
{
  XCTAssertEqualWithAccuracy(LWEReadingMaxWidth(112, NO, 354), 136, 0.001, @"headword + 24");
  XCTAssertEqualWithAccuracy(LWEReadingMaxWidth(56, NO, 354), 120, 0.001, @"120pt floor");
  XCTAssertEqualWithAccuracy(LWEReadingMaxWidth(400, NO, 354), 354, 0.001, @"never wider than the card");
}

- (void)testMaxWidthPinyin
{
  XCTAssertEqualWithAccuracy(LWEReadingMaxWidth(76, YES, 382), 160, 0.001, @"160pt floor (学习)");
  XCTAssertEqualWithAccuracy(LWEReadingMaxWidth(200, YES, 382), 248, 0.001, @"headword + 48");
}

- (void)testFitKeeps20WhenItFits
{
  // べんきょう: 102pt at 20pt
  LWEReadingFit fit = LWEReadingFitToWidth(^CGFloat(CGFloat size) { return 102.0 * size / 20.0; }, 20, 15, 136);
  XCTAssertEqualWithAccuracy(fit.size, 20, 0.001);
  XCTAssertEqual(fit.lines, 1);
  XCTAssertEqualWithAccuracy(fit.width, 102, 0.001);
}

- (void)testFitScalesInHalfPointSteps
{
  // 鯱瓦 / しゃちほこがわら: natural 163 vs max 136 -> 16.5pt on one line
  LWEReadingFit fit = LWEReadingFitToWidth(^CGFloat(CGFloat size) { return 163.0 * size / 20.0; }, 20, 15, 136);
  XCTAssertEqualWithAccuracy(fit.size, 16.5, 0.001);
  XCTAssertEqual(fit.lines, 1);
  XCTAssertLessThanOrEqual(fit.width, 136);
}

- (void)testFitWrapsBelowFloor
{
  // 冠鳰 / かんむりかいつぶり: 184 vs 136 would need 14.8pt, under the floor -> 2 lines at 15pt
  LWEReadingFit fit = LWEReadingFitToWidth(^CGFloat(CGFloat size) { return 184.0 * size / 20.0; }, 20, 15, 136);
  XCTAssertEqualWithAccuracy(fit.size, 15, 0.001);
  XCTAssertEqual(fit.lines, 2);
  // 138pt at 15pt -> half + one 15pt glyph
  XCTAssertEqualWithAccuracy(LWEReadingBalancedWrapWidth(138, 15, 136), 84, 0.001);
  XCTAssertEqualWithAccuracy(LWEReadingBalancedWrapWidth(300, 15, 136), 136, 0.001, @"capped at the max width");
}

- (void)testReadingSizesFollowDynamicType
{
  CGFloat base = 0, floorSize = 0;
  LWEReadingSizes(1.0, NO, &base, &floorSize);
  XCTAssertEqualWithAccuracy(base, 20, 0.001);
  XCTAssertEqualWithAccuracy(floorSize, 15, 0.001);
  LWEReadingSizes(1.53, NO, &base, &floorSize);
  XCTAssertEqualWithAccuracy(base, 28, 0.001, @"capped at 28pt (dt 1.4)");
  XCTAssertEqualWithAccuracy(floorSize, 21, 0.001);
  LWEReadingSizes(1.53, YES, &base, &floorSize);
  XCTAssertEqualWithAccuracy(base, 20, 0.001, @"compact cards keep 20pt");
}

- (void)testPinyinWrapsAtSyllableSpaceOnly
{
  NSDictionary *attrs = @{NSFontAttributeName: [UIFont systemFontOfSize:15]};
  NSAttributedString *pinyin = [[[NSAttributedString alloc] initWithString:@"zhōng huá rén mín gòng hé guó" attributes:attrs] autorelease];
  NSString *split = [LWEReadingBalancedSplitAtSpace(pinyin) string];
  NSArray *lines = [split componentsSeparatedByString:@"\n"];
  XCTAssertEqual([lines count], (NSUInteger)2);
  XCTAssertEqualObjects([[lines componentsJoinedByString:@" "] description], @"zhōng huá rén mín gòng hé guó", @"no syllable is cut");
  XCTAssertTrue([lines[0] length] > 6 && [lines[1] length] > 6, @"balanced: %@", lines);
  NSAttributedString *oneSyllable = [[[NSAttributedString alloc] initWithString:@"shachihokogawara" attributes:attrs] autorelease];
  XCTAssertNil(LWEReadingBalancedSplitAtSpace(oneSyllable));
}

- (void)testToneColoursSurvivePinyinSplit
{
  // Per-syllable colours (as with tone colouring) stay on their syllables when the line is split
  UIFont *font = [UIFont systemFontOfSize:15];
  NSArray *syllables = @[@"zhōng", @"huá", @"rén", @"mín", @"gòng", @"hé", @"guó"];
  NSArray *colours = @[[UIColor redColor], [UIColor orangeColor], [UIColor greenColor], [UIColor blueColor],
                       [UIColor purpleColor], [UIColor brownColor], [UIColor cyanColor]];
  NSMutableAttributedString *pinyin = [[[NSMutableAttributedString alloc] init] autorelease];
  for (NSUInteger i = 0; i < [syllables count]; i++)
  {
    NSString *piece = (i + 1 < [syllables count]) ? [syllables[i] stringByAppendingString:@" "] : syllables[i];
    [pinyin appendAttributedString:[[[NSAttributedString alloc] initWithString:piece attributes:@{
      NSFontAttributeName: font, NSForegroundColorAttributeName: colours[i]}] autorelease]];
  }
  NSAttributedString *split = LWEReadingBalancedSplitAtSpace(pinyin);
  XCTAssertNotNil(split);
  NSString *plain = [split string];
  NSUInteger searchFrom = 0;
  for (NSUInteger i = 0; i < [syllables count]; i++)
  {
    NSRange r = [plain rangeOfString:syllables[i] options:0 range:NSMakeRange(searchFrom, [plain length] - searchFrom)];
    XCTAssertNotEqual(r.location, (NSUInteger)NSNotFound);
    for (NSUInteger c = r.location; c < NSMaxRange(r); c++)
    {
      XCTAssertEqualObjects([split attribute:NSForegroundColorAttributeName atIndex:c effectiveRange:NULL], colours[i],
                            @"'%@' keeps its colour after the split", syllables[i]);
    }
    searchFrom = NSMaxRange(r);
  }
}

#pragma mark - Text size, VoiceOver (review of PR #21)

- (void)testOneDynamicTypeCapForReadingText
{
  XCTAssertEqualWithAccuracy(LWEReadingTypeScale(1.0, NO), 1.0, 0.001);
  XCTAssertEqualWithAccuracy(LWEReadingTypeScale(1.35, NO), 1.35, 0.001);
  XCTAssertEqualWithAccuracy(LWEReadingTypeScale(2.35, NO), 1.4, 0.001, @"one cap, 1.4x");
  XCTAssertEqualWithAccuracy(LWEReadingTypeScale(2.35, YES), 1.0, 0.001, @"compact cards stay at 1x");
  XCTAssertEqualWithAccuracy(roundf(13.0 * LWEReadingTypeScale(2.35, NO)), 18.0, 0.001, @"pill label 13 -> 18pt");
  XCTAssertEqualWithAccuracy(17.0 * LWEReadingTypeScale(2.35, NO), 23.8, 0.001, @"romaji 17 -> 23.8pt (was capped at 1.35x)");
}

- (void)testLegacyReadingRowGrowsToFit
{
  XCTAssertEqualWithAccuracy(LWELegacyReadingRowHeightFor(24), 42, 0.001, @"one line: the 42pt row");
  XCTAssertEqualWithAccuracy(LWELegacyReadingRowHeightFor(42), 42, 0.001, @"two 21pt lines at 15pt");
  XCTAssertEqualWithAccuracy(LWELegacyReadingRowHeightFor(58.8), 59, 0.001, @"two lines at 1.4x: grow, don't scroll");
}

- (void)testSpokenReadingHasNoMidReadingPause
{
  XCTAssertEqualObjects(LWEReadingSpokenLabel(@"べんきょう", @"benkyou"), @"べんきょう, benkyou", @"a pause between the rows");
  XCTAssertEqualObjects(LWEReadingSpokenLabel(@"かんむり\nかいつぶり", nil), @"かんむりかいつぶり", @"wrapped kana joined back");
  XCTAssertEqualObjects(LWEReadingSpokenLabel(nil, @"arigatou"), @"arigatou");
  XCTAssertEqualObjects(LWEReadingSpokenLabel(@"", @""), @"");
}

- (void)testShownReadingAccessibilityLabelUsesUnwrappedText
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"冠鳰" reading:@"かんむりかいつぶり" romaji:@"kanmurikaitsuburi"]];
  [cvc layoutCardSubviews];
  [cvc doToggleReadingBtn];
  NSString *label = cvc.toggleReadingBtn.accessibilityLabel;
  XCTAssertEqualObjects(label, @"かんむりかいつぶり, kanmurikaitsuburi");
  XCTAssertEqual([label rangeOfString:@"\n"].location, (NSUInteger)NSNotFound);
}

#pragma mark - Meaning vs the score bubble (DD review of PR #21)

- (void)testShortMeaningWrapsAroundBubbleCorner
{
  CGSize corner = CGSizeMake(56, 44);
  LWEMeaningInsets insets = LWEMeaningInsetsFor(180, 260, corner);
  XCTAssertTrue(insets.wrapCorner, @"Fits: lines next to the bubble wrap short of it");
  XCTAssertFalse(insets.scrolls);
  XCTAssertEqualWithAccuracy(insets.bottomInset, 0, 0.001);
  XCTAssertFalse(LWEMeaningShowsBottomFade(insets, 0, 180, 260));
  // Exactly full still fits
  XCTAssertTrue(LWEMeaningInsetsFor(260, 260, corner).wrapCorner);
}

- (void)testLongMeaningScrollsWithBubbleInset
{
  // 勉強: 4 senses, ~330pt of meaning in a ~250pt area
  CGSize corner = CGSizeMake(56, 44);
  LWEMeaningInsets insets = LWEMeaningInsetsFor(330, 250, corner);
  XCTAssertTrue(insets.scrolls, @"Taller than the area: scroll instead of clipping");
  XCTAssertFalse(insets.wrapCorner);
  XCTAssertEqualWithAccuracy(insets.bottomInset, 44, 0.001, @"The end scrolls clear of the bubble");
  XCTAssertTrue(LWEMeaningShowsBottomFade(insets, 0, 330, 250), @"Fade while more is below");
  XCTAssertTrue(LWEMeaningShowsBottomFade(insets, 80, 330, 250), @"Content ends at 330, but the inset adds 44");
  XCTAssertFalse(LWEMeaningShowsBottomFade(insets, 124, 330, 250), @"No fade at the end");
}

- (void)testScrollingMeaningStopsAboveBubble
{
  LWEMeaningInsets scrolls = LWEMeaningInsetsFor(330, 250, CGSizeMake(56, 44));
  XCTAssertEqualWithAccuracy(LWEMeaningVisibleHeight(scrolls, 250), 206, 0.001, @"nothing runs under the bubble while scrolling");
  LWEMeaningInsets fits = LWEMeaningInsetsFor(180, 250, CGSizeMake(56, 44));
  XCTAssertEqualWithAccuracy(LWEMeaningVisibleHeight(fits, 250), 250, 0.001, @"a meaning that fits uses the whole area (wrapping the corner)");
}

- (void)testCornerFromBubblePosition
{
  // 勉強 on the 17 Pro: the meaning area is 354 x 250; the bubble sits 35pt into it from the right
  // and 70pt up from its bottom
  CGSize corner = LWEMeaningCornerForBubble(CGRectMake(319, 180, 48, 37), CGSizeMake(354, 250));
  XCTAssertEqualWithAccuracy(corner.width, 41, 0.001, @"bubble edge to the right edge, + 6pt");
  XCTAssertEqualWithAccuracy(corner.height, 76, 0.001, @"bubble top to the bottom, + 6pt");
  XCTAssertTrue(CGSizeEqualToSize(LWEMeaningCornerForBubble(CGRectMake(400, 300, 48, 37), CGSizeMake(354, 250)), CGSizeZero),
                @"a bubble outside the area reserves nothing");
  XCTAssertTrue(CGSizeEqualToSize(LWEMeaningCornerForBubble(CGRectZero, CGSizeMake(354, 250)), CGSizeZero));
}

- (void)testNoBubbleNoInset
{
  LWEMeaningInsets fits = LWEMeaningInsetsFor(100, 260, CGSizeZero);
  XCTAssertFalse(fits.wrapCorner, @"Bubble hidden (browse mode): nothing to wrap around");
  LWEMeaningInsets tall = LWEMeaningInsetsFor(400, 260, CGSizeZero);
  XCTAssertTrue(tall.scrolls);
  XCTAssertEqualWithAccuracy(tall.bottomInset, 0, 0.001);
}

- (void)testCornerSizeFollowsBubbleAndNudge
{
  CGSize area = CGSizeMake(354, 250);
  CGSize paper = LWEMeaningCornerSize(YES, 0, area);
  XCTAssertEqualWithAccuracy(paper.width, 56, 0.001);
  XCTAssertEqualWithAccuracy(paper.height, 44, 0.001);
  CGSize kutani = LWEMeaningCornerSize(YES, 4, area);
  XCTAssertEqualWithAccuracy(kutani.width, 60, 0.001, @"Kutani's rim nudges the bubble 4pt up and left");
  XCTAssertEqualWithAccuracy(kutani.height, 48, 0.001);
  XCTAssertTrue(CGSizeEqualToSize(LWEMeaningCornerSize(NO, 0, area), CGSizeZero));
  CGSize tiny = LWEMeaningCornerSize(YES, 0, CGSizeMake(40, 30));
  XCTAssertEqualWithAccuracy(tiny.width, 40, 0.001, @"Clipped to the area");
  XCTAssertEqualWithAccuracy(tiny.height, 30, 0.001);
}

#pragma mark - QA a11y fixes (iPhone SE, VoiceOver, Reduce Motion, contrast)

- (void)testShortMeaningBandKeepsAFade
{
  XCTAssertEqualWithAccuracy(LWEMeaningFadeHeightFor(206), LWEMeaningFadeHeight, 0.001, @"Regular cards keep the 24pt fade");
  XCTAssertEqualWithAccuracy(LWEMeaningFadeHeightFor(48), LWEMeaningFadeHeight, 0.001);
  XCTAssertEqualWithAccuracy(LWEMeaningFadeHeightFor(90), LWEMeaningFadeHeight, 0.001, @"iPhone SE at the default text size");
  // A band under 48pt (iPhone SE at larger text sizes) used to get no fade at all
  CGFloat shortBand = LWEMeaningFadeHeightFor(40);
  XCTAssertGreaterThanOrEqual(shortBand, 12.0);
  XCTAssertLessThan(shortBand, LWEMeaningFadeHeight);
  XCTAssertLessThanOrEqual(LWEMeaningFadeHeightFor(20), 10.0, @"Never more than half the band");
  XCTAssertEqualWithAccuracy(LWEMeaningFadeHeightFor(0), 0, 0.001);
}

- (void)testRegularCardSpacingIsUnchanged
{
  // iPhone 17 Pro's card area is ~507pt: the design spacing, as before
  LWECardSpacing s = LWECardSpacingFor(507);
  XCTAssertFalse(LWECardIsCompact(507));
  XCTAssertEqualWithAccuracy(s.headwordScale, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(s.rowY, 59.0, 0.001, @"MAX(12, round(507 x 0.117))");
  XCTAssertEqualWithAccuracy(s.romajiGap, 8.0, 0.001);
  XCTAssertEqualWithAccuracy(s.moreReadingsGap, 12.0, 0.001);
  XCTAssertEqualWithAccuracy(s.meaningGap, 14.0, 0.001);
}

- (void)testCompactCardSpacingLeavesTheMeaningMoreRoom
{
  // iPhone SE (3rd gen): ~342pt card area
  XCTAssertTrue(LWECardIsCompact(342));
  LWECardSpacing s = LWECardSpacingFor(342);
  XCTAssertLessThan(s.headwordScale, 342.0 / 420.0, @"Smaller headword than the old linear scale");
  XCTAssertGreaterThanOrEqual(s.headwordScale, 0.55);
  XCTAssertLessThan(s.rowY, round(342 * 0.06), @"Reading row nearer the top");
  XCTAssertLessThan(s.romajiGap, 8.0);
  XCTAssertLessThan(s.meaningGap, 10.0);
  XCTAssertEqualWithAccuracy(LWECardSpacingFor(200).headwordScale, 0.55, 0.001, @"Floor");
  XCTAssertFalse(LWECardIsCompact(0), @"Not laid out yet");
}

- (void)testCardTransitionHonoursReduceMotion
{
  XCTAssertEqualObjects(LWECardTransitionType(NO), kCATransitionPush);
  XCTAssertEqualObjects(LWECardTransitionSubtype(NO, kCATransitionFromRight), kCATransitionFromRight);
  XCTAssertEqualObjects(LWECardTransitionType(YES), kCATransitionFade, @"Reduce Motion: cross-fade, no slide");
  XCTAssertNil(LWECardTransitionSubtype(YES, kCATransitionFromRight));
}

- (void)testProgressStripAccessibilitySummary
{
  NSArray *names = @[@"Studying", @"Right 1x", @"Right 2x", @"Right 3x", @"Learned"];
  NSArray *counts = @[@"3", @"15", @"0", @"0", @"2"];
  XCTAssertEqualObjects(LWEProgressAccessibilitySummary(names, counts),
                        @"Studying 3, Right 1x 15, Right 2x 0, Right 3x 0, Learned 2");
  NSArray *jaNames = @[@"学習中", @""];
  NSArray *jaCounts = @[@"3", @"4"];
  XCTAssertEqualObjects(LWEProgressAccessibilitySummary(jaNames, jaCounts), @"学習中 3", @"Unnamed levels are skipped");
  XCTAssertEqualObjects(LWEProgressAccessibilitySummary(@[@"Studying"], @[]), @"Studying");
}

- (void)testScoreBubbleAccessibilityValue
{
  NSString *expected = [NSString stringWithFormat:NSLocalizedString(@"%ld%% right", nil), 100L];
  XCTAssertEqualObjects([MoodIcon accessibilityValueForPercentCorrect:100.0f], expected);
  NSString *v = [MoodIcon accessibilityValueForPercentCorrect:66.6f];
  XCTAssertTrue([v rangeOfString:@"67"].location != NSNotFound, @"Rounded like the bubble: %@", v);
}

- (void)testLearnedButtonLabelMatchesItsTitle
{
  // Voice Control: "Tap Learned" needs the accessibility label to contain the visible title (WCAG 2.5.3)
  ActionBarViewController *bar = [[[ActionBarViewController alloc] initWithNibName:@"ActionBarViewController" bundle:nil] autorelease];
  [bar view];
  UIButton *learned = bar.buryCardBtn;
  XCTAssertNotNil(learned);
  NSString *title = learned.configuration.title ?: learned.configuration.attributedTitle.string ?: learned.currentTitle;
  XCTAssertEqualObjects(title, NSLocalizedString(@"Learned", nil));
  XCTAssertEqualObjects(learned.accessibilityLabel, title);
  XCTAssertEqualObjects(learned.accessibilityHint, NSLocalizedString(@"Mark as learned", nil));
  XCTAssertTrue([learned.accessibilityUserInputLabels containsObject:title]);
}

static CGFloat LWETestRelativeLuminance(UIColor *color)
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

static CGFloat LWETestContrast(UIColor *a, UIColor *b)
{
  CGFloat la = LWETestRelativeLuminance(a), lb = LWETestRelativeLuminance(b);
  return (MAX(la, lb) + 0.05) / (MIN(la, lb) + 0.05);
}

- (void)testListSubtitleInkMeetsAAInEveryTheme
{
  // "4 Sets" / "7546 Words" (Study Sets) and search-result readings use cellValueInk
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  NSArray *keys = [tm themeKeysList];
  XCTAssertEqual([keys count], (NSUInteger)5);
  for (NSString *key in keys)
  {
    UIColor *ink = [tm colorForSlot:@"cellValueInk" themeKey:key];
    XCTAssertNotNil(ink, @"%@", key);
    for (UIColor *fill in @[[UIColor whiteColor], ([tm colorForSlot:@"cellFill" themeKey:key] ?: [UIColor whiteColor])])
    {
      CGFloat ratio = LWETestContrast(ink, fill);
      XCTAssertGreaterThanOrEqual(ratio, 4.5, @"%@: %.2f:1", key, ratio);
    }
  }
  XCTAssertLessThan(LWETestContrast([UIColor grayColor], [UIColor whiteColor]), 4.5, @"The grey it replaces fails AA");
}

#pragma mark - PR #28 review follow-ups

- (void)testScoreBubbleReadsTheScoreInPracticeMode
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  MoodIcon *mood = cvc.moodIcon;
  XCTAssertNotNil(mood.moodIconBtn);
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:100.0f];
  XCTAssertFalse(mood.talkBubble.hidden, @"Practice shows the % bubble");
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityLabel, NSLocalizedString(@"Session score", nil));
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:100.0f]);
  XCTAssertTrue((mood.moodIconBtn.accessibilityTraits & UIAccessibilityTraitButton) != 0);
}

- (void)testBrowseModeScoreBubbleHasNoScoreForVoiceOver
{
  // Review: VoiceOver said "Session score, 100% right" on every Browse card while the % is hidden
  Class browseClass = NSClassFromString(@"BrowseModeCardViewDelegate");
  XCTAssertNotNil(browseClass);
  id<CardViewControllerDelegate> browse = [[[browseClass alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:browse];
  MoodIcon *mood = cvc.moodIcon;
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:100.0f]; // CardViewController seeds 100%; a later update must not bring the value back
  XCTAssertTrue(mood.talkBubble.hidden, @"Browse never shows the %% bubble");
  XCTAssertNil(mood.moodIconBtn.accessibilityValue, @"No score read while none is on screen");
  XCTAssertFalse(mood.moodIconBtn.isAccessibilityElement, @"Not tappable and no score: not a VoiceOver stop");
  [cvc setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  XCTAssertNil(mood.moodIconBtn.accessibilityValue, @"...on the next card too");

  // Back to Practice: the bubble and its value return
  cvc.delegate = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  [cvc studyViewModeDidChange:nil];
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:100.0f]);
}

- (void)testPracticeScoreBubbleHiddenByTapHasNoValue
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  MoodIcon *mood = cvc.moodIcon;
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:67.0f];
  [mood doTogglePercentCorrectBtn];
  XCTAssertTrue(mood.talkBubble.hidden);
  XCTAssertNil(mood.moodIconBtn.accessibilityValue, @"Bubble hidden: no score value");
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement, @"Still a button, to show the score again");
  [mood doTogglePercentCorrectBtn];
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:67.0f]);
  XCTAssertTrue([MoodIcon scoreBubbleIsAccessibilityElementWhenEnabled:YES bubbleHidden:YES]);
  XCTAssertTrue([MoodIcon scoreBubbleIsAccessibilityElementWhenEnabled:NO bubbleHidden:NO]);
  XCTAssertFalse([MoodIcon scoreBubbleIsAccessibilityElementWhenEnabled:NO bubbleHidden:YES]);
}

- (void)testMeaningScrollFlashDoesNotCarryOverToTheNextCard
{
  // Review: a reveal's pending scroll-indicator flash could fire on the next card
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  XCTAssertFalse([cvc meaningScrollFlashPending]);
  [practice cardViewDidReveal:cvc]; // meaning not measured yet: the flash waits for the measurement
  XCTAssertTrue([cvc meaningScrollFlashPending]);
  [cvc setupWithCard:[self _cardWithHeadword:@"海" reading:@"うみ" romaji:@"umi"]];
  XCTAssertFalse([cvc meaningScrollFlashPending], @"The next card starts with no flash pending");
  [cvc flashMeaningScrollIndicatorIfScrollable];
  XCTAssertTrue([cvc meaningScrollFlashPending], @"...and flashes after its own reveal");
}

- (void)testStudySetNavigationBarIsOpaqueInTheThemeColours
{
  // Review: the Study Sets nav bar showed the white window instead of paper #E7E1D6
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  for (NSString *key in [tm themeKeysList])
  {
    UIColor *fill = [tm colorForSlot:@"navBarFill" themeKey:key];
    UIColor *ink = [tm colorForSlot:@"navTitleInk" themeKey:key];
    XCTAssertNotNil(fill, @"%@", key);
    UINavigationItem *item = [[[UINavigationItem alloc] initWithTitle:@"JLPT"] autorelease];
    UIColor *hairline = [tm colorForSlot:@"separator" themeKey:key];
    LWEStudySetApplyNavigationBarAppearance(item, fill, ink, hairline);
    for (UINavigationBarAppearance *a in @[item.standardAppearance, item.scrollEdgeAppearance, item.compactAppearance, item.compactScrollEdgeAppearance])
    {
      XCTAssertEqualObjects(a.backgroundColor, fill, @"%@", key);
      CGFloat red = 0, green = 0, blue = 0, alpha = 0;
      [a.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
      XCTAssertEqualWithAccuracy(alpha, 1.0, 0.001, @"%@: opaque", key);
      XCTAssertEqualObjects(a.titleTextAttributes[NSForegroundColorAttributeName], ink, @"%@", key);
      XCTAssertEqualObjects(a.shadowColor, hairline, @"%@: theme hairline", key);
    }
  }
  CGFloat r = 0, g = 0, b = 0, alpha = 0;
  [[tm colorForSlot:@"navBarFill" themeKey:@"PAPER"] getRed:&r green:&g blue:&b alpha:&alpha];
  XCTAssertEqual((int)lround(r * 255), 0xE7);
  XCTAssertEqual((int)lround(g * 255), 0xE1);
  XCTAssertEqual((int)lround(b * 255), 0xD6);
}

- (void) testStudySetViewControllerAppliesTheNavigationBarAppearance
{
  // Review nit: the screen itself must use the helper (not just the helper being right), on every bar state
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  UIColor *fill = [tm colorForSlot:@"navBarFill"];
  UIColor *ink = [tm colorForSlot:@"navTitleInk"];
  UIColor *hairline = [tm colorForSlot:@"separator"];
  XCTAssertNotNil(fill);
  Class studySetClass = LWEStudySetControllerClassWithoutDatabase();
  XCTAssertNotNil(studySetClass);
  LWEStudySetStubGroup *group = [[[LWEStudySetStubGroup alloc] init] autorelease];
  group.groupName = @"Test Group";
  StudySetViewController *vc = [[[studySetClass alloc] initWithGroup:(Group *)group] autorelease];
  [vc loadViewIfNeeded];
  UINavigationItem *item = vc.navigationItem;
  for (int pass = 0; pass < 2; pass++)
  {
    NSArray *states = @[item.standardAppearance ?: [NSNull null], item.scrollEdgeAppearance ?: [NSNull null],
                        item.compactAppearance ?: [NSNull null], item.compactScrollEdgeAppearance ?: [NSNull null]];
    for (id a in states)
    {
      XCTAssertTrue([a isKindOfClass:[UINavigationBarAppearance class]], @"pass %d: every bar state has the appearance", pass);
      if ([a isKindOfClass:[UINavigationBarAppearance class]] == NO) continue;
      UINavigationBarAppearance *appearance = (UINavigationBarAppearance *)a;
      XCTAssertEqualObjects(appearance.backgroundColor, fill, @"pass %d", pass);
      XCTAssertEqualObjects(appearance.titleTextAttributes[NSForegroundColorAttributeName], ink, @"pass %d", pass);
      XCTAssertEqualObjects(appearance.shadowColor, hairline, @"pass %d: theme hairline", pass);
    }
    // viewWillAppear: puts it back (the theme may have changed in Settings)
    item.standardAppearance = nil;
    item.scrollEdgeAppearance = nil;
    item.compactAppearance = nil;
    item.compactScrollEdgeAppearance = nil;
    [vc viewWillAppear:NO];
  }
  // Paper list behind the rows, not the XIB's system grouped grey
  XCTAssertEqualObjects(vc.tableView.backgroundColor, [tm colorForSlot:@"groupedBackground"]);
  XCTAssertEqualWithAccuracy(vc.tableView.sectionHeaderTopPadding, 0, 0.001);
}

- (void) testStudySetSearchBarScrollRoomLetsAShortListHideTheSearchBar
{
  // Short group (4 sets): 675pt visible + 64pt bar - 723pt content = 16pt more needed
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(675, 64, 723), 16, 0.001);
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(675, 64, 739), 0, 0.001, @"exactly enough");
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(675, 64, 1810), 0, 0.001, @"long list needs nothing");
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(500.25, 56, 500), 57, 0.001, @"rounded up to whole points");
}

@end
