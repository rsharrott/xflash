//
//  CardReadingTest.m
//  jFlash
//
//  The card's furigana reading row (DD furigana spec, option A): reading-visibility state,
//  the kana-only rule, and the long-reading fit rule.
//

#import <XCTest/XCTest.h>
#import "LWEReadingLayout.h"
#import "CardViewController.h"
#import "PracticeModeCardViewDelegate.h"
#import "JapaneseCard.h"
#import "Constants.h"

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

- (void)testNewCardViewControllerResetsChoice
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *first = [self _newCardViewWithDelegate:practice];
  [first setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  [first doToggleReadingBtn];
  XCTAssertTrue(first.readingVisible);

  // Theme, direction, mode and text-size changes build a new card view: it starts hidden (not saved)
  CardViewController *second = [self _newCardViewWithDelegate:practice];
  XCTAssertFalse(second.readingVisible);
  [second setupWithCard:[self _cardWithHeadword:@"勉強" reading:@"べんきょう" romaji:@"benkyou"]];
  XCTAssertTrue(second.readingScrollContainer.hidden);
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

- (void)testNotKanaOnlyWhenReadingDiffersOrListed
{
  XCTAssertFalse(LWEReadingIsKanaOnlyHeadword(@"べんきょう", @"勉強", 1, NO));
  XCTAssertFalse(LWEReadingIsKanaOnlyHeadword(@"これ", @"これ", 2, NO), @"Several readings: the list still shows");
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

@end
