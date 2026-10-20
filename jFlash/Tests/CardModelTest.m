//
//  CardModelTest.m
//  jFlash
//
//  Copyright (c) 2026 Long Weekend LLC. All rights reserved.
//

#import "CardModelTest.h"
#import "Card.h"
#import "Constants.h"

@implementation CardModelTest
{
  NSString *_savedHeadwordSetting;
}

- (void)setUp
{
  [super setUp];
  _savedHeadwordSetting = [[[NSUserDefaults standardUserDefaults] objectForKey:APP_HEADWORD] retain];
}

- (void)tearDown
{
  if (_savedHeadwordSetting)
    [[NSUserDefaults standardUserDefaults] setObject:_savedHeadwordSetting forKey:APP_HEADWORD];
  else
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:APP_HEADWORD];
  [_savedHeadwordSetting release];
  _savedHeadwordSetting = nil;
  [super tearDown];
}

#pragma mark - meaningWithoutMarkup

- (void)testMeaningWithoutMarkupPlainTextIsUnchanged
{
  Card *card = [[Card alloc] init];
  card._meaning = @"hello";
  XCTAssertEqualObjects(@"hello", [card meaningWithoutMarkup], @"Plain text meaning should pass through unchanged");
  [card release];
}

- (void)testMeaningWithoutMarkupStripsDfnTags
{
  Card *card = [[Card alloc] init];
  card._meaning = @"<dfn>noun</dfn>";
  XCTAssertEqualObjects(@"(noun)", [card meaningWithoutMarkup], @"<dfn>...</dfn> should become (...)");
  [card release];
}

- (void)testMeaningWithoutMarkupJoinsAdjacentDfnsWithComma
{
  Card *card = [[Card alloc] init];
  card._meaning = @"<dfn>cat</dfn><dfn>kitten</dfn>";
  NSString *result = [card meaningWithoutMarkup];
  XCTAssertTrue([result rangeOfString:@"cat, kitten"].location != NSNotFound, @"Adjacent dfn tags should be joined with a comma and a space, got: %@", result);
  [card release];
}

- (void)testMeaningWithoutMarkupStripsListTags
{
  Card *card = [[Card alloc] init];
  card._meaning = @"<ol><li>first</li><li>second</li></ol>";
  NSString *result = [card meaningWithoutMarkup];
  XCTAssertTrue([result rangeOfString:@"first"].location != NSNotFound, @"List item text should be preserved, got: %@", result);
  XCTAssertTrue([result rangeOfString:@"<ol>"].location == NSNotFound, @"<ol> should be stripped");
  XCTAssertTrue([result rangeOfString:@"<li>"].location == NSNotFound, @"<li> should be stripped");
  [card release];
}

- (void)testMeaningWithoutMarkupSpacesPartsOfSpeechLikeProse
{
  // QA (search results): "study(noun,~する verb reg,verb trans); diligence..." read as one run-on word
  Card *card = [[Card alloc] init];
  card._meaning = @"<ol><li>study<dfn>noun</dfn><dfn>~する verb reg</dfn><dfn>verb trans</dfn></li><li>diligence / working hard<dfn>noun</dfn></li></ol>";
  XCTAssertEqualObjects([card meaningWithoutMarkup], @"study (noun, ~する verb reg, verb trans); diligence / working hard (noun)");
  [card release];
}

- (void)testMeaningWithoutMarkupKeepsOneSpaceBeforeParenthesis
{
  Card *card = [[Card alloc] init];
  card._meaning = @"<ol><li>study <dfn>noun</dfn></li></ol>";
  XCTAssertEqualObjects([card meaningWithoutMarkup], @"study (noun)");
  [card release];
}

- (void)testMeaningWithoutMarkupHasNoTrailingSeparator
{
  Card *card = [[Card alloc] init];
  card._meaning = @"<ol><li>first</li><li>second</li></ol>";
  XCTAssertEqualObjects([card meaningWithoutMarkup], @"first; second");
  [card release];
}

- (void)testMeaningWithoutMarkupPlainChineseMeaningIsUnchanged
{
  Card *card = [[Card alloc] init];
  card._meaning = @"component in Chinese character 殷[yin1]";
  XCTAssertEqualObjects([card meaningWithoutMarkup], @"component in Chinese character 殷[yin1]");
  [card release];
}

- (void)testMeaningWithoutMarkupNormalizesTrailingSpaceBeforeSemicolon
{
  Card *card = [[Card alloc] init];
  card._meaning = @"<ol><li>item</li></ol>";
  NSString *result = [card meaningWithoutMarkup];
  XCTAssertTrue([result rangeOfString:@" ; "].location == NSNotFound, @"' ; ' should be normalized to '; ', got: %@", result);
  [card release];
}

#pragma mark - headwordIgnoringMode:

- (void)testHeadwordIgnoringModeYESReturnsRawHeadword
{
  Card *card = [[Card alloc] init];
  card._headword = @"猫";
  card.headword_en = @"cat";
  [[NSUserDefaults standardUserDefaults] setObject:SET_E_TO_J forKey:APP_HEADWORD];

  NSString *result = [card headwordIgnoringMode:YES];
  XCTAssertEqualObjects(@"猫", result, @"ignoreMode:YES must return _headword regardless of APP_HEADWORD setting");
  [card release];
}

- (void)testHeadwordIgnoringModeNOWithJToESettingReturnsJapaneseHeadword
{
  Card *card = [[Card alloc] init];
  card._headword = @"猫";
  card.headword_en = @"cat";
  [[NSUserDefaults standardUserDefaults] setObject:SET_J_TO_E forKey:APP_HEADWORD];

  NSString *result = [card headwordIgnoringMode:NO];
  XCTAssertEqualObjects(@"猫", result, @"J→E mode should show Japanese headword");
  [card release];
}

- (void)testHeadwordIgnoringModeNOWithEToJSettingReturnsEnglishHeadword
{
  Card *card = [[Card alloc] init];
  card._headword = @"猫";
  card.headword_en = @"cat";
  [[NSUserDefaults standardUserDefaults] setObject:SET_E_TO_J forKey:APP_HEADWORD];

  NSString *result = [card headwordIgnoringMode:NO];
  XCTAssertEqualObjects(@"cat", result, @"E→J mode should show English headword");
  [card release];
}

@end
