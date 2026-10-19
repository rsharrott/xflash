//
//  ChineseCardTest.m
//  xFlash
//
//  Created by Mark Makdad on 2/28/12.
//  Copyright (c) 2012 Long Weekend LLC. All rights reserved.
//

#import "ChineseCardTest.h"
#import "ChineseCard.h"
#import "CardPeer.h"
#import "SetupDatabaseHelper.h"
#import "ThemeManager.h"
#import "Constants.h"
#import "LWEReadingLayout.h"

@interface ChineseCardTest ()
- (ChineseCard *) _cardForKeyword:(NSString *)keyword;
@end

@implementation ChineseCardTest

#pragma mark - Accent on wrong mark tests

- (void) testCorrectPinyinization
{
  // This should put the accent mark over the "i", not the "u".
  ChineseCard *card = [[ChineseCard alloc] init];
  card.hw_reading = @"hui2";
  XCTAssertEqualObjects(card.pinyinReading,@"huí",@"Card reading should be the same");
  [card release];
}

- (void) testToneMarkPlacement
{
  // a / e take the mark; in "ou" the o; otherwise the last vowel (ui -> i, iu -> u, uo -> o)
  NSDictionary *expected = @{
    @"hao3": @"hǎo", @"xie4": @"xiè", @"lüe4": @"lüè", @"lu:e4": @"lüè", @"xue2": @"xué",
    @"gou3": @"gǒu", @"zhou1": @"zhōu", @"ou1": @"ōu",
    @"hui4": @"huì", @"gui4": @"guì", @"dui4": @"duì", @"shui3": @"shuǐ",
    @"liu2": @"liú", @"jiu3": @"jiǔ", @"cuo4": @"cuò", @"guo2": @"guó", @"zuo4": @"zuò",
    @"nü3": @"nǚ", @"nu:3": @"nǚ", @"lü4": @"lǜ", @"zhong1": @"zhōng", @"er2": @"ér", @"yi1": @"yī",
    @"Zhong1": @"Zhōng", @"An1": @"Ān", @"Ou1": @"Ōu",
    @"ng2": @"ńg", @"m2": @"ḿ",
    // v is the keyboard spelling of ü
    @"lv4": @"lǜ", @"nv3": @"nǚ", @"lve4": @"lüè", @"nve4": @"nüè", @"Lv3": @"Lǚ",
    @"ma5": @"ma", @"r5": @"r", @"de5": @"de",
  };
  for (NSString *numbered in expected)
  {
    ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
    card.hw_reading = numbered;
    XCTAssertEqualObjects(card.pinyinReading, expected[numbered], @"%@", numbered);
  }
  // A whole reading, syllable by syllable
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  card.hw_reading = @"dui4 bu5 qi3";
  XCTAssertEqualObjects(card.pinyinReading, @"duì bu qǐ");
  // Not numbered pinyin: unchanged
  card.hw_reading = @"ma";
  XCTAssertEqualObjects(card.pinyinReading, @"ma");
  card.hw_reading = @"ni3,";
  XCTAssertEqualObjects(card.pinyinReading, @"ni3,", @"Trailing punctuation is left alone (pre-existing)");
}

#pragma mark - Tone Change Tests

#pragma mark 3rd Tone Tests

- (void) testTone3Repeated
{
  /**
   1. A 3rd tone followed by another 3rd tone becomes a 2nd tone
   [3] [3] ⇒ [2] [3]
   你好 (hello): nǐhǎo ⇒ ‘níhǎo’
   很远 (very far): hěnyuǎn ⇒ ‘hényuǎn’
   好久 (a long time): hǎojiǔ ⇒ ‘háojiǔ’
   */

  ChineseCard *card = [self _cardForKeyword:@"你好"];
  XCTAssertNotNil(card, @"Card could not be found: 你好");
  XCTAssertEqualObjects(@"ni3 hao3", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"nǐ hǎo", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"ní hǎo", card.sandhiReading, @"Tone sandhi reading should change"); 

  card = [self _cardForKeyword:@"好久"];
  XCTAssertNotNil(card, @"Card could not be found: 好久");
  XCTAssertEqualObjects(@"hao3 jiu3", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"hǎo jiǔ", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"háo jiǔ", card.sandhiReading, @"Tone sandhi reading should change"); 
}

- (void) testTone3FollowedByNonTone3
{
  /**
   
   2. A 3rd tone becomes a ‘low tone’ if followed by any other tone
   Again, this is confusing at first. It’s probably easier to approach these two rules as “if a third tone isn’t on its own, it changes”. This ‘low tone’ is a low-pitch tone that falls slightly.
   As symbols:
   [3] [!3] ⇒ [low tone] [3]
   (here the ! represents ‘not’)
   Examples:
   
   考试 (exam): kǎoshì ⇒ kaoshì
   语言 (language): yǔyán ⇒ yuyán
   马车 (cart): mǎchē ⇒ machē
   */
}

#pragma mark Rules for "一" (one)

- (void) testYi1BecomesYi2WhenFollowedByTone4
{
  /**
   3. 一 is 2nd tone when followed by a 4th tone
   As symbols:
   [一] [4] ⇒ [一2] [4]
   Examples:
   一个 (one …): yī gè ⇒ ‘yí gè’
   一半 (one half): yī bàn ⇒ ‘yí bàn’
   一步 (one step): yī bù ⇒ ‘yí bù’
   */

//  ChineseCard *card = [self _cardForKeyword:@"一个"];
//  XCTAssertNotNil(card, @"Card could not be found: 一个");
//  XCTAssertEqualObjects(@"yi1 ge4", card.reading, @"Regular reading should not change"); 
//  XCTAssertEqualObjects(@"yī gè", card.attributedReading.string, @"Regular reading should not change"); 
//  XCTAssertEqualObjects(@"yí gè", card.sandhiReading, @"Tone sandhi reading should change"); 

  ChineseCard *card = [self _cardForKeyword:@"一半"];
  XCTAssertNotNil(card, @"Card could not be found: 一半");
  XCTAssertEqualObjects(@"yi1 ban4", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yī bàn", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yí bàn", card.sandhiReading, @"Tone sandhi reading should change"); 
  
  card = [self _cardForKeyword:@"一步"];
  XCTAssertNotNil(card, @"Card could not be found: 一步");
  XCTAssertEqualObjects(@"yi1 bu4", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yī bù", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yí bù", card.sandhiReading, @"Tone sandhi reading should change"); 
}

- (void) testYi1BecomesYi4WhenFollowedByNonTone4
{
  /**
   4. 一 is 4th tone when followed by a 1st, 2nd or 3rd tone
   As symbols:
   [一] [1 | 2 | 3] ⇒ [一4] [1 | 2 | 3]
   (here the | represents ‘or’)
   Examples
   一般 (normally): yībān ⇒ ‘yìbān’
   一直 (continuously): yīzhí ⇒ ‘yìzhí’
   一起 (together): yīqǐ ⇒ ‘yìqǐ’
   */
  ChineseCard *card = [self _cardForKeyword:@"一般"];
  XCTAssertNotNil(card, @"Card could not be found: 一般");
  XCTAssertEqualObjects(@"yi1 ban1", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yī bān", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yì bān", card.sandhiReading, @"Tone sandhi reading should change");

  card = [self _cardForKeyword:@"一直"];
  XCTAssertNotNil(card, @"Card could not be found: 一直");
  XCTAssertEqualObjects(@"yi1 zhi2", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yī zhí", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yì zhí", card.sandhiReading, @"Tone sandhi reading should change"); 
  
  card = [self _cardForKeyword:@"一起"];
  XCTAssertNotNil(card, @"Card could not be found: 一起");
  XCTAssertEqualObjects(@"yi1 qi3", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yī qǐ", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"yì qǐ", card.sandhiReading, @"Tone sandhi reading should change"); 
}

#pragma mark Rules for "不" (non-, no)

- (void) testBu4BecomesBu2WhenFollowedByTone4
{
  /**
   不 is normally 4th tone (bù), but there is one situation where this changes.
   5. 不 is 2nd tone when followed by a 4th tone
   As symbols:
   [不] [4] ⇒ [不2] [4]
   Examples:
   不是 (is not): bù shì ⇒ ‘bú shì
   ’
   不会 (will not, cannot): bù huì ⇒ ‘bú huì’
   不错 (not bad): bù cuò ⇒ ‘bú cuò’
   */
  ChineseCard *card = [self _cardForKeyword:@"不是"];
  XCTAssertNotNil(card, @"Card could not be found: 不是");
  XCTAssertEqualObjects(@"bu4 shi4", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"bù shì", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"bú shì", card.sandhiReading, @"Tone sandhi reading should change");
  
  card = [self _cardForKeyword:@"不会"];
  XCTAssertNotNil(card, @"Card could not be found: 不会");
  XCTAssertEqualObjects(@"bu4 hui4", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"bù huì", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"bú huì", card.sandhiReading, @"Tone sandhi reading should change"); 
  
  card = [self _cardForKeyword:@"不错"];
  XCTAssertNotNil(card, @"Card could not be found: 不错");
  XCTAssertEqualObjects(@"bu4 cuo4", card.reading, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"bù cuò", card.attributedReading.string, @"Regular reading should not change"); 
  XCTAssertEqualObjects(@"bú cuò", card.sandhiReading, @"Tone sandhi reading should change");
}

#pragma mark Rules for 2nd Tone

- (void) testSecondToneBetweenTonesIsNotChanged
{
  /**
   6. A 2nd tone preceded by a 1st or 2nd tone and followed by another tone becomes a 1st tone
   [1 | 2] [2] [*] => [1 | 2] [1] [*]
   三年级 (third grade): sān niánjí => 'sān niānjí'

   This is a fast-speech tendency, not a rule dictionaries or textbooks write, so sandhiReading
   deliberately doesn't apply it.  (This test used to be a copy of testBu4BecomesBu2WhenFollowedByTone4
   under this name; it now pins the intended behaviour instead.)
   */
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  card._headword = @"三年级";
  card.hw_reading = @"san1 nian2 ji2";
  XCTAssertEqualObjects(card.sandhiReading, @"sān nián jí", @"Rule 6 is not applied");
  card._headword = @"谁来吃";
  card.hw_reading = @"shei2 lai2 chi1";
  XCTAssertEqualObjects(card.sandhiReading, @"shéi lái chī", @"Rule 6 is not applied");
}

- (void) testYiAndBuEdgeCases
{
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  // 一 at the end of a word (第一) and before a neutral tone keeps tone 1
  card._headword = @"第一";
  card.hw_reading = @"di4 yi1";
  XCTAssertEqualObjects(card.sandhiReading, @"dì yī");
  card._headword = @"一个";
  card.hw_reading = @"yi1 ge5";
  XCTAssertEqualObjects(card.sandhiReading, @"yī ge");
  // 不一定: 一 changes before the 4th tone; 不 is followed by 一's dictionary tone 1, so it stays bù
  card._headword = @"不一定";
  card.hw_reading = @"bu4 yi1 ding4";
  XCTAssertEqualObjects(card.sandhiReading, @"bù yí dìng");
  // A run of 3rd tones: 3 3 3 -> 2 2 3
  card._headword = @"我很好";
  card.hw_reading = @"wo3 hen3 hao3";
  XCTAssertEqualObjects(card.sandhiReading, @"wó hén hǎo");
  // Other characters before a 4th tone don't change
  card._headword = @"他是";
  card.hw_reading = @"ta1 shi4";
  XCTAssertEqualObjects(card.sandhiReading, @"tā shì");
}

- (void) testNeutralToneBuAndYiAreNotChanged
{
  // Only a dictionary-tone 不 (bu4) / 一 (yi1) changes; a neutral-tone one stays neutral
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  card._headword = @"看不见";
  card.hw_reading = @"kan4 bu5 jian4";
  XCTAssertEqualObjects(card.sandhiReading, @"kàn bu jiàn");
  card._headword = @"看一看";
  card.hw_reading = @"kan4 yi5 kan4";
  XCTAssertEqualObjects(card.sandhiReading, @"kàn yi kàn");
  card._headword = @"想一想";
  card.hw_reading = @"xiang3 yi5 xiang3";
  XCTAssertEqualObjects(card.sandhiReading, @"xiǎng yi xiǎng");
  // Some dictionaries write the reduplication with yi1; sandhi then applies as usual
  card._headword = @"看一看";
  card.hw_reading = @"kan4 yi1 kan4";
  XCTAssertEqualObjects(card.sandhiReading, @"kàn yí kàn");
}

- (void) testYiAsANumberInDatesAndOrdinalsKeepsTone1
{
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  // Before 月 (a month name)
  card._headword = @"一月";
  card.hw_reading = @"yi1 yue4";
  XCTAssertEqualObjects(card.sandhiReading, @"yī yuè");
  card._headword = @"十一月";
  card.hw_reading = @"shi2 yi1 yue4";
  XCTAssertEqualObjects(card.sandhiReading, @"shí yī yuè");
  // After 第 (an ordinal)
  card._headword = @"第一天";
  card.hw_reading = @"di4 yi1 tian1";
  XCTAssertEqualObjects(card.sandhiReading, @"dì yī tiān");
  card._headword = @"第一次";
  card.hw_reading = @"di4 yi1 ci4";
  XCTAssertEqualObjects(card.sandhiReading, @"dì yī cì");
  // Other 一 still change
  card._headword = @"一样";
  card.hw_reading = @"yi1 yang4";
  XCTAssertEqualObjects(card.sandhiReading, @"yí yàng");
}

#pragma mark - Helpers

- (ChineseCard *) _cardForKeyword:(NSString *)keyword
{
  // TECHNICALLY we shouldn't be using CardPeer to search for a UNIT test, but it's SO DAMN CONVENIENT.
  NSArray *cards = [CardPeer searchCardsForKeyword:keyword];
  if ([cards count] > 0)
  {
    ChineseCard *card = [cards objectAtIndex:0];
    [card hydrate];
    return card;
  }
  return nil;
}

#pragma mark - Setup & Teardown

- (void)setUp
{
  //get the cloned database as a test database.
  NSError *error = nil;
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  BOOL result = [db setupTestDatabaseAndOpenConnectionWithError:&error];
  XCTAssertTrue(result, @"Failed in setup the test database with error: %@", [error localizedDescription]);
  
  //Setup FTS
  result = [db setupAttachedDatabase:CURRENT_FTS_TEST_DATABASE asName:@"fts"];
  XCTAssertTrue(result, @"Failed to setup search database");
  
  //Setup Cards
  result = [db setupAttachedDatabase:CURRENT_CARD_TEST_DATABASE asName:@"cards"];
  XCTAssertTrue(result, @"Failed to setup cards database");
}

- (void)tearDown
{
  JFlashDatabase *db = [JFlashDatabase sharedJFlashDatabase];
  NSError *error = nil;
  BOOL result = [db removeTestDatabaseWithError:&error];
  XCTAssertTrue(result, @"Test database cannot be removed for some reason.\nError: %@", [error localizedDescription]);
}


#pragma mark - Pinyin colour (furigana spec; Pinyin Coloring on = tone colours, off = readingInk)

// These tests pass the setting and theme explicitly instead of writing them to NSUserDefaults: the host
// app's StudyViewController observes both keys and re-renders its card on a change, which in cFlashTest
// can reach a card view left half-built by the pre-existing English-first nib exception (separate PR).

static BOOL LWESameRGBA(UIColor *a, UIColor *b)
{
  CGFloat r1 = 0, g1 = 0, b1 = 0, a1 = 0, r2 = 0, g2 = 0, b2 = 0, a2 = 0;
  if (![a getRed:&r1 green:&g1 blue:&b1 alpha:&a1] || ![b getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) return NO;
  return fabs(r1 - r2) < 0.002 && fabs(g1 - g2) < 0.002 && fabs(b1 - b2) < 0.002 && fabs(a1 - a2) < 0.002;
}

static UIColor *LWEHex(unsigned rgb)
{
  return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0 green:((rgb >> 8) & 0xFF) / 255.0 blue:(rgb & 0xFF) / 255.0 alpha:1.0];
}

//! Colour of each syllable of the card's revealed (attributed) pinyin, in order
static NSArray *LWESyllableColours(NSAttributedString *pinyin)
{
  NSMutableArray *colours = [NSMutableArray array];
  NSString *plain = [pinyin string];
  NSCharacterSet *breaks = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSUInteger i = 0;
  while (i < [plain length])
  {
    NSRange sep = [plain rangeOfCharacterFromSet:breaks options:0 range:NSMakeRange(i, [plain length] - i)];
    NSUInteger end = (sep.location == NSNotFound) ? [plain length] : sep.location;
    if (end > i) [colours addObject:[pinyin attribute:NSForegroundColorAttributeName atIndex:i effectiveRange:NULL]];
    i = end + 1;
  }
  return colours;
}

static UIColor *LWEInk(NSString *themeKey)
{
  return [[ThemeManager sharedThemeManager] colorForSlot:@"readingInk" themeKey:themeKey];
}

static NSDictionary *LWEPalette(NSString *themeKey)
{
  return [ChineseCard toneColorsForThemeKey:themeKey cardFill:[[ThemeManager sharedThemeManager] colorForSlot:@"cardFill" themeKey:themeKey]];
}

- (ChineseCard *) _cardWithReading:(NSString *)reading
{
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  card.hw_reading = reading;
  return card;
}

- (void) testPinyinUsesThemeToneColoursWhenColoringIsOn
{
  NSArray *themeKeys = [[ThemeManager sharedThemeManager] themeKeysList];
  XCTAssertTrue([themeKeys count] >= 5, @"All five themes");
  ChineseCard *card = [self _cardWithReading:@"ma1 ma2 ma3 ma4 ma5"];
  for (NSString *themeKey in themeKeys)
  {
    NSDictionary *palette = LWEPalette(themeKey);
    NSArray *colours = LWESyllableColours([card attributedReadingUsingToneColors:YES themeKey:themeKey]);
    XCTAssertEqual([colours count], (NSUInteger)5, @"%@", themeKey);
    for (NSUInteger tone = 1; tone <= 4 && tone <= [colours count]; tone++)
    {
      UIColor *expected = palette[[NSString stringWithFormat:@"%lu", (unsigned long)tone]];
      XCTAssertTrue(LWESameRGBA(colours[tone - 1], expected), @"%@ tone %lu: %@, expected %@", themeKey, (unsigned long)tone, colours[tone - 1], expected);
      XCTAssertFalse(LWESameRGBA(colours[tone - 1], LWEInk(themeKey)), @"%@ tone %lu is coloured", themeKey, (unsigned long)tone);
    }
    if ([colours count] == 5) XCTAssertTrue(LWESameRGBA(colours[4], LWEInk(themeKey)), @"%@: neutral tone in readingInk", themeKey);
  }
}

- (void) testTonePalettesAreTheAACheckedOnes
{
  // Light (Paper, #13), dark (Fire/Water #13, Kutani #14) and Kimono (#14) palettes: all five themes
  NSArray *dark = @[LWEHex(0xFFA294), LWEHex(0xFFD60A), LWEHex(0x7DDEA0), LWEHex(0x8EC8FF)];
  NSDictionary *expected = @{
    SET_THEME_PAPER:  @[LWEHex(0x8E1400), LWEHex(0x9A4E00), LWEHex(0x0B5A2C), LWEHex(0x1356A7)],
    SET_THEME_FIRE:   dark,
    SET_THEME_WATER:  dark,
    SET_THEME_KIMONO: @[LWEHex(0x7A1100), LWEHex(0x6B3600), LWEHex(0x08451F), LWEHex(0x0E3F7D)],
    SET_THEME_KUTANI: dark,
  };
  XCTAssertEqualObjects([NSSet setWithArray:[expected allKeys]], [NSSet setWithArray:[[ThemeManager sharedThemeManager] themeKeysList]], @"every theme has a row");
  for (NSString *themeKey in expected)
  {
    NSDictionary *palette = LWEPalette(themeKey);
    for (NSUInteger tone = 1; tone <= 4; tone++)
    {
      XCTAssertTrue(LWESameRGBA(palette[[NSString stringWithFormat:@"%lu", (unsigned long)tone]], expected[themeKey][tone - 1]),
                    @"%@ tone %lu", themeKey, (unsigned long)tone);
    }
  }
}

- (void) testToneIgnoresTrailingPunctuation
{
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"ma5,"], (NSInteger)5);
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"hao3,"], (NSInteger)3);
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"xue2 "], (NSInteger)2);
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"ma1."], (NSInteger)1);
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"shi4)\n"], (NSInteger)4);
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"lü4"], (NSInteger)4);
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"xué,"], (NSInteger)2, @"tone mark");
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"hǎo!"], (NSInteger)3, @"tone mark");
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@"ma"], (NSInteger)0);
  XCTAssertEqual([ChineseCard toneForPinyinSyllable:@","], (NSInteger)0);

  // On the card: a syllable with trailing punctuation keeps its tone colour (not readingInk)
  NSArray *colours = LWESyllableColours([[self _cardWithReading:@"ni3, hao3!"] attributedReadingUsingToneColors:YES themeKey:SET_THEME_PAPER]);
  XCTAssertEqual([colours count], (NSUInteger)2);
  if ([colours count] == 2)
  {
    XCTAssertTrue(LWESameRGBA(colours[0], LWEHex(0x0B5A2C)), @"'ni3,' keeps tone 3");
    XCTAssertTrue(LWESameRGBA(colours[1], LWEHex(0x0B5A2C)), @"'hao3!' keeps tone 3");
  }
  colours = LWESyllableColours([[self _cardWithReading:@"ma4, ma5,"] attributedReadingUsingToneColors:YES themeKey:SET_THEME_FIRE]);
  if ([colours count] == 2)
  {
    XCTAssertTrue(LWESameRGBA(colours[0], LWEHex(0x8EC8FF)), @"'ma4,' tone 4 on Fire");
    XCTAssertTrue(LWESameRGBA(colours[1], LWEInk(SET_THEME_FIRE)), @"'ma5,' neutral tone in ink");
  }
}

- (void) testPinyinUsesReadingInkWhenColoringIsOff
{
  for (NSString *themeKey in [[ThemeManager sharedThemeManager] themeKeysList])
  {
    UIColor *ink = LWEInk(themeKey);
    NSAttributedString *pinyin = [[self _cardWithReading:@"xue2 xi2"] attributedReadingUsingToneColors:NO themeKey:themeKey];
    XCTAssertEqualObjects([pinyin string], @"xué xí");
    for (UIColor *colour in LWESyllableColours(pinyin))
    {
      XCTAssertTrue(LWESameRGBA(colour, ink), @"%@: %@ should be readingInk %@", themeKey, colour, ink);
    }
    for (UIColor *colour in LWESyllableColours([[self _cardWithReading:@"ma1 ma2 ma3 ma4 ma5"] attributedReadingUsingToneColors:NO themeKey:themeKey]))
    {
      XCTAssertTrue(LWESameRGBA(colour, ink), @"%@: every tone in readingInk when off", themeKey);
    }
  }
  XCTAssertTrue(LWESameRGBA(LWEInk(SET_THEME_PAPER), LWEHex(0x3A352E)), @"Paper readingInk is ink-2 #3A352E");
}

- (void) testPinyinFollowsTheSetting
{
  // The card's own render reads the current setting and theme each time (nothing cached), so the
  // re-render StudyViewController does on a Pinyin Coloring change shows the new colours.
  ChineseCard *card = [self _cardWithReading:@"xue2 xi2"];
  NSString *current = [[[ThemeManager sharedThemeManager] _currentTheme] objectForKey:@"key"];
  NSAttributedString *expected = [card attributedReadingUsingToneColors:[ChineseCard pinyinColoringIsOn] themeKey:current];
  XCTAssertEqualObjects([card attributedReading], expected, @"attributedReading = the current setting and theme");
  XCTAssertEqual([ChineseCard pinyinColoringIsOn],
                 [[[NSUserDefaults standardUserDefaults] objectForKey:APP_PINYIN_COLOR] isEqualToString:SET_PINYIN_COLOR_ON]);
  // the same card object, on -> off -> on
  XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReadingUsingToneColors:YES themeKey:SET_THEME_PAPER])[0], LWEHex(0x9A4E00)), @"on: tone 2 dark amber");
  XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReadingUsingToneColors:NO themeKey:SET_THEME_PAPER])[0], LWEInk(SET_THEME_PAPER)), @"off: readingInk");
  XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReadingUsingToneColors:YES themeKey:SET_THEME_PAPER])[0], LWEHex(0x9A4E00)), @"on again");
  XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReadingUsingToneColors:YES themeKey:SET_THEME_FIRE])[0], LWEHex(0xFFD60A)), @"Fire: tone 2 yellow");
}

- (void) testToneColoursSurviveTheLongPinyinSplit
{
  // A long reading wrapped onto two lines (the card's fit rule) keeps each syllable's tone colour
  NSAttributedString *pinyin = [[self _cardWithReading:@"zhong1 hua2 ren2 min2 gong4 he2 guo2"] attributedReadingUsingToneColors:YES themeKey:SET_THEME_PAPER];
  NSArray *before = LWESyllableColours(pinyin);
  NSAttributedString *split = LWEReadingBalancedSplitAtSpace(pinyin);
  XCTAssertNotNil(split);
  XCTAssertTrue([[split string] rangeOfString:@"\n"].location != NSNotFound, @"split onto two lines");
  NSArray *after = LWESyllableColours(split);
  XCTAssertEqual([after count], [before count]);
  for (NSUInteger i = 0; i < MIN([after count], [before count]); i++)
  {
    XCTAssertTrue(LWESameRGBA(after[i], before[i]), @"syllable %lu keeps its tone colour", (unsigned long)i);
  }
  if ([before count] == 7) XCTAssertTrue(LWESameRGBA(before[4], LWEHex(0x1356A7)), @"gòng is tone 4 water");
}

@end
