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

- (void) test2Becomes1WhenPrecededBy1Or2AndFollowedByOther
{
  /**
   6. A 2nd tone preceded by a 1st or 2nd tone and followed by another tone becomes a 1st tone
   This one will probably start to feel natural after a lot of listening practice and exposure.
   Written down, however, it looks fairly crazy.
   
   As symbols:
   [1 | 2] [2] [*] ⇒ [1 | 2] [1] [*]
   (here the | represents ‘or’, and the * represents any tone)
   
   Examples:
   三年级 (third grade): sān niánjí ⇒ ‘sān niānjí’
   谁来吃？ (who’s coming to eat?): shéi lái chī? ⇒ shéi lāi chī?
   特别难看 (especially ugly): tèbié nánkàn ⇒ tèbié nānkàn
   */
//  ChineseCard *card = [self _cardForKeyword:@"三年级"];
//  XCTAssertNotNil(card, @"Card could not be found: 三年级");
//  XCTAssertEqualObjects(@"bu4 shi4", card.reading, @"Regular reading should not change"); 
//  XCTAssertEqualObjects(@"bù shì", card.attributedReading.string, @"Regular reading should not change"); 
//  XCTAssertEqualObjects(@"bú shì", card.sandhiReading, @"Tone sandhi reading should change");
  
  ChineseCard *card = [self _cardForKeyword:@"不会"];
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


#pragma mark - Pinyin ink (furigana spec, DD review of PR #21)

static BOOL LWESameRGBA(UIColor *a, UIColor *b)
{
  CGFloat r1 = 0, g1 = 0, b1 = 0, a1 = 0, r2 = 0, g2 = 0, b2 = 0, a2 = 0;
  if (![a getRed:&r1 green:&g1 blue:&b1 alpha:&a1] || ![b getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) return NO;
  return fabs(r1 - r2) < 0.002 && fabs(g1 - g2) < 0.002 && fabs(b1 - b2) < 0.002 && fabs(a1 - a2) < 0.002;
}

//! Writes a setting for this test.  The host app's StudyViewController observes these keys and rebuilds
//! its card view; in cFlash that can throw from the stale English-first nib (a pre-existing bug, see
//! PR #21), which isn't what this test checks.
static void LWESetTestSetting(id value, NSString *key)
{
  @try
  {
    if (value) [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    else [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
  }
  @catch (NSException *exception)
  {
    NSLog(@"Host app threw while observing %@: %@", key, exception);
  }
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
  NSUInteger i = 0;
  while (i < [plain length])
  {
    NSRange space = [plain rangeOfString:@" " options:0 range:NSMakeRange(i, [plain length] - i)];
    NSUInteger end = (space.location == NSNotFound) ? [plain length] : space.location;
    if (end > i) [colours addObject:[pinyin attribute:NSForegroundColorAttributeName atIndex:i effectiveRange:NULL]];
    i = end + 1;
  }
  return colours;
}

//! Saves and restores the theme and Pinyin Coloring settings around a test
- (void) _withSavedSettings:(void (^)(void))block
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  id savedTheme = [[settings objectForKey:APP_THEME] retain];
  id savedColor = [[settings objectForKey:APP_PINYIN_COLOR] retain];
  block();
  LWESetTestSetting(savedTheme, APP_THEME);
  LWESetTestSetting(savedColor, APP_PINYIN_COLOR);
  [savedTheme release];
  [savedColor release];
}

- (ChineseCard *) _allTonesCard
{
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  card.hw_reading = @"ma1 ma2 ma3 ma4 ma5";
  return card;
}

- (void) testPinyinUsesThemeToneColoursWhenColoringIsOn
{
  [self _withSavedSettings:^{
    LWESetTestSetting(SET_PINYIN_COLOR_ON, APP_PINYIN_COLOR);
    ThemeManager *tm = [ThemeManager sharedThemeManager];
    NSArray *themeKeys = [tm themeKeysList];
    XCTAssertTrue([themeKeys count] >= 5, @"All five themes");
    for (NSString *themeKey in themeKeys)
    {
      LWESetTestSetting(themeKey, APP_THEME);
      NSDictionary *palette = [ChineseCard toneColorsForThemeKey:themeKey cardFill:[tm colorForSlot:@"cardFill"]];
      NSArray *colours = LWESyllableColours([[self _allTonesCard] attributedReading]);
      XCTAssertEqual([colours count], (NSUInteger)5, @"%@", themeKey);
      for (NSUInteger tone = 1; tone <= 4; tone++)
      {
        UIColor *expected = palette[[NSString stringWithFormat:@"%lu", (unsigned long)tone]];
        XCTAssertTrue(LWESameRGBA(colours[tone - 1], expected), @"%@ tone %lu: %@, expected %@", themeKey, (unsigned long)tone, colours[tone - 1], expected);
        XCTAssertFalse(LWESameRGBA(colours[tone - 1], [tm colorForSlot:@"readingInk"]), @"%@ tone %lu is coloured", themeKey, (unsigned long)tone);
      }
      XCTAssertTrue(LWESameRGBA(colours[4], [tm colorForSlot:@"readingInk"]), @"%@: neutral tone in readingInk", themeKey);
    }
  }];
}

- (void) testTonePalettesAreTheAACheckedOnes
{
  // Light (Paper, #13), dark (Fire/Water #13, Kutani #14) and Kimono (#14) palettes
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  [self _withSavedSettings:^{
    NSDictionary *expected = @{
      SET_THEME_PAPER:  @[LWEHex(0x8E1400), LWEHex(0x9A4E00), LWEHex(0x0B5A2C), LWEHex(0x1356A7)],
      SET_THEME_FIRE:   @[LWEHex(0xFFA294), LWEHex(0xFFD60A), LWEHex(0x7DDEA0), LWEHex(0x8EC8FF)],
      SET_THEME_KIMONO: @[LWEHex(0x7A1100), LWEHex(0x6B3600), LWEHex(0x08451F), LWEHex(0x0E3F7D)],
    };
    for (NSString *themeKey in expected)
    {
      LWESetTestSetting(themeKey, APP_THEME);
      NSDictionary *palette = [ChineseCard toneColorsForThemeKey:themeKey cardFill:[tm colorForSlot:@"cardFill"]];
      for (NSUInteger tone = 1; tone <= 4; tone++)
      {
        XCTAssertTrue(LWESameRGBA(palette[[NSString stringWithFormat:@"%lu", (unsigned long)tone]], expected[themeKey][tone - 1]),
                      @"%@ tone %lu", themeKey, (unsigned long)tone);
      }
    }
  }];
}

- (void) testPinyinUsesReadingInkWhenColoringIsOff
{
  [self _withSavedSettings:^{
    LWESetTestSetting(SET_PINYIN_COLOR_OFF, APP_PINYIN_COLOR);
    ThemeManager *tm = [ThemeManager sharedThemeManager];
    for (NSString *themeKey in [tm themeKeysList])
    {
      LWESetTestSetting(themeKey, APP_THEME);
      UIColor *ink = [tm colorForSlot:@"readingInk"];
      ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
      card.hw_reading = @"xue2 xi2";
      NSAttributedString *pinyin = [card attributedReading];
      XCTAssertEqualObjects([pinyin string], @"xué xí");
      for (UIColor *colour in LWESyllableColours(pinyin))
      {
        XCTAssertTrue(LWESameRGBA(colour, ink), @"%@: %@ should be readingInk %@", themeKey, colour, ink);
      }
      for (UIColor *colour in LWESyllableColours([[self _allTonesCard] attributedReading]))
      {
        XCTAssertTrue(LWESameRGBA(colour, ink), @"%@: every tone in readingInk when off", themeKey);
      }
    }
    // Paper's readingInk is ink-2 #3A352E
    LWESetTestSetting(SET_THEME_PAPER, APP_THEME);
    XCTAssertTrue(LWESameRGBA([tm colorForSlot:@"readingInk"], LWEHex(0x3A352E)));
  }];
}

- (void) testPinyinFollowsTheSettingWhenItChanges
{
  // The same card re-renders with the new setting (nothing is cached), as StudyViewController does on a change
  [self _withSavedSettings:^{
    LWESetTestSetting(SET_THEME_PAPER, APP_THEME);
    ThemeManager *tm = [ThemeManager sharedThemeManager];
    UIColor *ink = [tm colorForSlot:@"readingInk"];
    ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
    card.hw_reading = @"xue2 xi2";
    LWESetTestSetting(SET_PINYIN_COLOR_ON, APP_PINYIN_COLOR);
    XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReading])[0], LWEHex(0x9A4E00)), @"on: tone 2 dark amber");
    LWESetTestSetting(SET_PINYIN_COLOR_OFF, APP_PINYIN_COLOR);
    XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReading])[0], ink), @"off: readingInk");
    LWESetTestSetting(SET_PINYIN_COLOR_ON, APP_PINYIN_COLOR);
    XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReading])[0], LWEHex(0x9A4E00)), @"on again");
    // and a theme change while on picks that theme's palette
    LWESetTestSetting(SET_THEME_FIRE, APP_THEME);
    XCTAssertTrue(LWESameRGBA(LWESyllableColours([card attributedReading])[0], LWEHex(0xFFD60A)), @"Fire: tone 2 yellow");
  }];
}

- (void) testToneColoursSurviveTheLongPinyinSplit
{
  // A long reading wrapped onto two lines (the card's fit rule) keeps each syllable's tone colour
  [self _withSavedSettings:^{
    LWESetTestSetting(SET_PINYIN_COLOR_ON, APP_PINYIN_COLOR);
    LWESetTestSetting(SET_THEME_PAPER, APP_THEME);
    ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
    card.hw_reading = @"zhong1 hua2 ren2 min2 gong4 he2 guo2";
    NSAttributedString *pinyin = [card attributedReading];
    NSArray *before = LWESyllableColours(pinyin);
    NSAttributedString *split = LWEReadingBalancedSplitAtSpace(pinyin);
    XCTAssertNotNil(split);
    NSMutableArray *after = [NSMutableArray array];
    NSString *plain = [split string];
    NSUInteger i = 0;
    while (i < [plain length])
    {
      NSRange sep = [plain rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:0 range:NSMakeRange(i, [plain length] - i)];
      NSUInteger end = (sep.location == NSNotFound) ? [plain length] : sep.location;
      if (end > i) [after addObject:[split attribute:NSForegroundColorAttributeName atIndex:i effectiveRange:NULL]];
      i = end + 1;
    }
    XCTAssertEqual([after count], [before count]);
    for (NSUInteger s = 0; s < MIN([after count], [before count]); s++)
    {
      XCTAssertTrue(LWESameRGBA(after[s], before[s]), @"syllable %lu keeps its tone colour", (unsigned long)s);
    }
    XCTAssertTrue(LWESameRGBA(before[4], LWEHex(0x1356A7)), @"gòng is tone 4 water");
  }];
}

@end
