//
//  ChineseCard.m
//  jFlash
//
//  Created by Mark Makdad on 8/21/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import "ChineseCard.h"
#import "Plugin.h"
#import "PluginManager.h"
#import "ThemeManager.h"

@interface ChineseCard ()
- (NSArray *) _pinyinAudioFilenamesWithPlugin:(Plugin *)pinyinPlugin;
- (NSString *) _fullAudioFilenameWithPlugin:(Plugin *)hskPlugin;
@end

@implementation ChineseCard

@synthesize headword_simp;

- (void) hydrateWithResultSet:(FMResultSet*)rs
{
  [self hydrateWithResultSet:rs simpleHydrate:NO];
  self._headword = [rs stringForColumn:@"headword_trad"];
  self.headword_simp = [rs stringForColumn:@"headword_simp"];
}

- (void) hydrateWithResultSet:(FMResultSet*)rs simpleHydrate:(BOOL)isSimple
{
  [super hydrateWithResultSet:rs simpleHydrate:isSimple];
  self._headword = [rs stringForColumn:@"headword_trad"];
  self.headword_simp = [rs stringForColumn:@"headword_simp"];
}

/**
 * Takes something like "hao3" and converts it to "hǎo".
 * Standard placement: a or e takes the mark; in "ou" the o does; otherwise the last vowel
 * (hui4 -> huì, jiu3 -> jiǔ, cuo4 -> cuò, lüe4 -> lüè).  Syllabic m / n (m2, ng2) take it on the m or n.
 * Tone 5 (neutral) drops the digit.  Strings that don't end in a tone digit 1-5 are returned unchanged.
 */
- (NSString*) _pinyinForNumberedPinyin:(NSString*)numberedPinyin
{
  // Quick return on bad string input/nil input
  if ([numberedPinyin length] == 0)
  {
    return nil;
  }

  // Another quick return if we don't have a valid tone number
  NSInteger toneNumber = [[numberedPinyin substringFromIndex:([numberedPinyin length]-1)] integerValue];
  if (toneNumber == 0 || toneNumber > 5)
  {
    return numberedPinyin;
  }

  // Replace u: and v (the keyboard spelling, lv4 / nv3) with ü (u umlaut); no pinyin syllable has a real v
  numberedPinyin = [numberedPinyin stringByReplacingOccurrencesOfString:@"u:" withString:@"ü"];
  numberedPinyin = [numberedPinyin stringByReplacingOccurrencesOfString:@"U:" withString:@"Ü"];
  numberedPinyin = [numberedPinyin stringByReplacingOccurrencesOfString:@"v" withString:@"ü"];
  numberedPinyin = [numberedPinyin stringByReplacingOccurrencesOfString:@"V" withString:@"Ü"];
  NSString *reading = [numberedPinyin substringToIndex:([numberedPinyin length]-1)];
  if (toneNumber == 5)
  {
    return reading;
  }

  // Find the letter that carries the mark (case-insensitively; ü is one UTF-16 unit, so indexes match)
  NSString *lower = [reading lowercaseString];
  NSRange mark = [lower rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"ae"]];
  if (mark.location == NSNotFound)
  {
    NSRange ou = [lower rangeOfString:@"ou"];
    if (ou.location != NSNotFound) mark = NSMakeRange(ou.location, 1);
  }
  if (mark.location == NSNotFound)
  {
    mark = [lower rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"iouü"] options:NSBackwardsSearch];
  }
  if (mark.location == NSNotFound)
  {
    mark = [lower rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"mn"]];
  }
  if (mark.location == NSNotFound || [lower length] != [reading length])
  {
    return reading;
  }

  // Combining macron / acute / caron / grave after that letter, then compose (u + U+030C -> ǔ, ü + U+0301 -> ǘ)
  static const unichar kToneMarks[4] = {0x0304, 0x0301, 0x030C, 0x0300};
  NSMutableString *marked = [[reading mutableCopy] autorelease];
  [marked insertString:[NSString stringWithCharacters:&kToneMarks[toneNumber - 1] length:1] atIndex:NSMaxRange(mark)];
  return [marked precomposedStringWithCanonicalMapping];
}

- (NSAttributedString *) attributedReading
{
  return [self attributedReadingUsingToneColors:[[self class] pinyinColoringIsOn] themeKey:nil];
}

- (NSAttributedString *) attributedReadingUsingToneColors:(BOOL)useToneColors themeKey:(NSString *)themeKey
{
  NSMutableAttributedString *attrString = [[[[NSAttributedString alloc] init] autorelease] mutableCopy];
  NSArray *readingHashes = [self readingComponentsUsingToneColors:useToneColors themeKey:themeKey];
  for (NSInteger i = 0; i < [readingHashes count]; i++)
  {
    NSDictionary *readingHash = [readingHashes objectAtIndex:i];
    NSString *stringToAppend = nil;
    if (i == ([readingHashes count] - 1))
    {
      // This is the last one, don't append a string
      stringToAppend = [NSString stringWithFormat:@"%@",[readingHash objectForKey:@"pinyin"]];
    }
    else
    {
      // We have more pinyin, so append a string
      stringToAppend = [NSString stringWithFormat:@"%@ ",[readingHash objectForKey:@"pinyin"]];
    }
    NSMutableAttributedString *tmpAttrString = [[[[NSAttributedString alloc] initWithString:stringToAppend] autorelease] mutableCopy];
    NSRange allRange = NSMakeRange(0, [stringToAppend length]);
    // UILabel-compatible attrs (cFlash reading label is a plain UILabel as of themes v2).
    UIColor *toneColor = (UIColor *)[readingHash objectForKey:@"color"];
    [tmpAttrString addAttribute:NSForegroundColorAttributeName value:toneColor range:allRange];
    // 20pt regular (furigana spec §8); CardViewController shrinks or wraps long pinyin to fit the row.
    [tmpAttrString addAttribute:NSFontAttributeName
                          value:[UIFont systemFontOfSize:20 weight:UIFontWeightRegular]
                          range:allRange];
    [attrString appendAttributedString:tmpAttrString];
    [tmpAttrString release];
  }
  
  return [attrString autorelease];
}

+ (NSDictionary *) toneColorsForThemeKey:(NSString *)themeKey cardFill:(UIColor *)cardFill
{
  // The AA-checked tone palettes from the Paper/Fire/Water (#13) and Kimono/Kutani (#14) themes.
  // Light: fire-deep / dark amber / right-ink / water.  Dark: soft red / yellow / mint / sky.
  CGFloat r = 0, g = 0, b = 0, a = 0;
  [cardFill getRed:&r green:&g blue:&b alpha:&a];
  // Relative luminance (sRGB approx). Paper/Kimono are light; Fire/Water/Kutani are dark.
  CGFloat lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  BOOL lightCard = (cardFill == nil) || (lum > 0.45);
  UIColor *tone1, *tone2, *tone3, *tone4;
  if ([themeKey isEqualToString:SET_THEME_KIMONO])
  {
    // Mid kaki #EEA57A: darker tones so all four pass 4.5 at normal size.
    tone1 = [UIColor colorWithRed:0.478 green:0.067 blue:0.000 alpha:1.0]; // #7A1100
    tone2 = [UIColor colorWithRed:0.420 green:0.212 blue:0.000 alpha:1.0]; // #6B3600
    tone3 = [UIColor colorWithRed:0.031 green:0.271 blue:0.122 alpha:1.0]; // #08451F
    tone4 = [UIColor colorWithRed:0.055 green:0.247 blue:0.490 alpha:1.0]; // #0E3F7D
  }
  else if (lightCard)
  {
    tone1 = [UIColor colorWithRed:0.557 green:0.078 blue:0.000 alpha:1.0]; // #8E1400 fire-deep
    tone2 = [UIColor colorWithRed:0.604 green:0.306 blue:0.000 alpha:1.0]; // #9A4E00 dark amber
    tone3 = [UIColor colorWithRed:0.043 green:0.353 blue:0.173 alpha:1.0]; // #0B5A2C right-ink
    tone4 = [UIColor colorWithRed:0.075 green:0.337 blue:0.655 alpha:1.0]; // #1356A7 water
  }
  else
  {
    tone1 = [UIColor colorWithRed:1.000 green:0.635 blue:0.580 alpha:1.0]; // #FFA294 (AA at normal size on dark cards)
    tone2 = [UIColor colorWithRed:1.000 green:0.839 blue:0.039 alpha:1.0]; // #FFD60A yellow
    tone3 = [UIColor colorWithRed:0.490 green:0.871 blue:0.627 alpha:1.0]; // #7DDEA0
    tone4 = [UIColor colorWithRed:0.557 green:0.784 blue:1.000 alpha:1.0]; // #8EC8FF
  }
  return [NSDictionary dictionaryWithObjectsAndKeys:tone1,@"1", tone2,@"2", tone3,@"3", tone4,@"4", nil];
}

+ (NSInteger) toneForPinyinSyllable:(NSString *)syllable
{
  // The tone of one syllable, ignoring trailing punctuation and whitespace ('ma5,' -> 5): the last tone
  // digit (numbered pinyin, xue2) or, failing that, the last tone mark (xué).  0 when there is none.
  NSCharacterSet *toneDigits = [NSCharacterSet characterSetWithCharactersInString:@"12345"];
  NSRange digit = [syllable rangeOfCharacterFromSet:toneDigits options:NSBackwardsSearch];
  if (digit.location != NSNotFound) return [[syllable substringWithRange:digit] integerValue];
  NSString *decomposed = [syllable decomposedStringWithCanonicalMapping];
  for (NSInteger i = (NSInteger)[decomposed length] - 1; i >= 0; i--)
  {
    switch ([decomposed characterAtIndex:i])
    {
      case 0x0304: return 1; // macron
      case 0x0301: return 2; // acute
      case 0x030C: return 3; // caron
      case 0x0300: return 4; // grave
      default: break;
    }
  }
  return 0;
}

+ (BOOL) pinyinColoringIsOn
{
  return [[[NSUserDefaults standardUserDefaults] objectForKey:APP_PINYIN_COLOR] isEqualToString:SET_PINYIN_COLOR_ON];
}

- (NSArray *) readingComponents
{
  return [self readingComponentsUsingToneColors:[[self class] pinyinColoringIsOn] themeKey:nil];
}

- (NSArray *) readingComponentsUsingToneColors:(BOOL)useToneColors themeKey:(NSString *)themeKey
{
  // Pinyin Coloring ON (the default): each syllable in its tone colour, from the theme's palette.
  // OFF: every syllable in the theme's readingInk, the same ink as jFlash's kana.  Neutral-tone (5)
  // syllables use readingInk either way.  Read fresh on every call, so a setting or theme change shows
  // on the next card render (StudyViewController observes both).
  // themeKey nil = the current theme (the card); tests pass a key so they needn't change the setting.
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  if (themeKey == nil) themeKey = [[tm _currentTheme] objectForKey:@"key"];
  UIColor *ink = [tm colorForSlot:@"readingInk" themeKey:themeKey] ?: [UIColor colorWithRed:0.227 green:0.208 blue:0.180 alpha:1.0]; // ink-2 #3A352E
  NSDictionary *toneColors = nil;
  if (useToneColors)
  {
    toneColors = [[self class] toneColorsForThemeKey:themeKey cardFill:[tm colorForSlot:@"cardFill" themeKey:themeKey]];
  }

  NSMutableArray *components = [NSMutableArray array];
  NSArray *pinyinSegments = [self.reading componentsSeparatedByString:@" "];
  for (NSString *pinyinSegment in pinyinSegments)
  {
    UIColor *theColor = ink;
    if (toneColors)
    {
      NSInteger tone = [[self class] toneForPinyinSyllable:pinyinSegment];
      theColor = (tone >= 1 && tone <= 4) ? ([toneColors objectForKey:[NSString stringWithFormat:@"%ld", (long)tone]] ?: ink) : ink;
    }
    // Now pinyin-ify the string
    pinyinSegment = [self _pinyinForNumberedPinyin:pinyinSegment];
    NSDictionary *pinyinHash = [NSDictionary dictionaryWithObjectsAndKeys:theColor,@"color",pinyinSegment,@"pinyin",nil];
    [components addObject:pinyinHash];
  }
  return components;
}

- (NSString *) pinyinReading
{
  NSArray *pinyinSegments = [self.reading componentsSeparatedByString:@" "];
  LWE_ASSERT_EXC([pinyinSegments count] > 0, @"Need at least 1 pinyin segment for this to work");
  NSUInteger resultLength = [self.reading length] - [pinyinSegments count] + 1;
  NSMutableString *result = [NSMutableString stringWithCapacity:resultLength];
                             
  for (NSString *pinyinSegment in pinyinSegments)
  {
    // Now pinyin-ify the string
    pinyinSegment = [self _pinyinForNumberedPinyin:pinyinSegment];
    [result appendFormat:@"%@ ", pinyinSegment];
  }
  
  NSRange lastCharacter = (NSRange){[result length]-1,1};
  [result deleteCharactersInRange:lastCharacter];
  return result;
}

//! The tone digit 1-5 at the end of one numbered-pinyin syllable ("hao3" -> 3); 0 when there is none
static NSInteger LWENumberedPinyinTone(NSString *pinyin)
{
  if ([pinyin length] == 0) return 0;
  NSInteger tone = [[pinyin substringFromIndex:([pinyin length] - 1)] integerValue];
  return (tone >= 1 && tone <= 5) ? tone : 0;
}

/**
 * The reading with Mandarin tone sandhi applied, one syllable per hanzi.  Each rule looks at the
 * dictionary tone of the syllable that follows:
 *  [3] [3]       -> [2] [3]   你好 nǐ hǎo -> ní hǎo (along a run of 3rd tones: 3 3 3 -> 2 2 3)
 *  不/一 [4]     -> [2] [4]   不是 bù shì -> bú shì, 一半 yī bàn -> yí bàn
 *  一 [1|2|3]    -> [4]       一般 yī bān -> yì bān, 一直 yī zhí -> yì zhí, 一起 yī qǐ -> yì qǐ
 * Only a dictionary-tone 不 (bu4) or 一 (yi1) changes: a neutral-tone one (看不见 kan4 bu5 jian4,
 * 看一看 kan4 yi5 kan4) stays neutral.  一 also keeps its 1st tone before a neutral tone, at the end of
 * the word, and when it is a number in a date or ordinal: before 月 (一月 yī yuè) or after 第 (第一天).
 */
- (NSString *) sandhiReading
{
  NSArray *pinyinSegments = [self.reading componentsSeparatedByString:@" "];
  // Use _headword because we *always* want the Chinese character version, no funny stuff
  NSString *headword = self._headword;
  LWE_ASSERT_EXC([headword length] == [pinyinSegments count], @"do i have a bold assumption wrong here?");

  NSMutableArray *sandhiPieces = [NSMutableArray arrayWithCapacity:[pinyinSegments count]];
  NSUInteger count = [pinyinSegments count];
  for (NSUInteger i = 0; i < count; i++)
  {
    NSString *pinyin = [pinyinSegments objectAtIndex:i];
    NSString *hanzi = (i < [headword length]) ? [headword substringWithRange:NSMakeRange(i, 1)] : nil;
    NSInteger tone = LWENumberedPinyinTone(pinyin);
    NSInteger nextTone = (i + 1 < count) ? LWENumberedPinyinTone([pinyinSegments objectAtIndex:(i + 1)]) : 0;
    NSString *prevHanzi = (i > 0 && i - 1 < [headword length]) ? [headword substringWithRange:NSMakeRange(i - 1, 1)] : nil;
    NSString *nextHanzi = (i + 1 < [headword length]) ? [headword substringWithRange:NSMakeRange(i + 1, 1)] : nil;
    BOOL isBu = ([hanzi isEqualToString:@"不"] && tone == 4);
    // 一 as a plain number (一月, 第一天) is read yī whatever follows
    BOOL isYi = ([hanzi isEqualToString:@"一"] && tone == 1 &&
                 ![nextHanzi isEqualToString:@"月"] && ![prevHanzi isEqualToString:@"第"]);

    NSInteger newTone = tone;
    if (tone == 3 && nextTone == 3)
    {
      newTone = 2;
    }
    else if ((isBu || isYi) && nextTone == 4)
    {
      newTone = 2;
    }
    else if (isYi && nextTone >= 1 && nextTone <= 3)
    {
      newTone = 4;
    }

    if (newTone != tone)
    {
      pinyin = [NSString stringWithFormat:@"%@%ld", [pinyin substringToIndex:([pinyin length] - 1)], (long)newTone];
    }
    NSString *marked = [self _pinyinForNumberedPinyin:pinyin];
    if (marked) [sandhiPieces addObject:marked];
  }
  return [[sandhiPieces componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

#pragma mark - Audio Related

- (BOOL) hasAudioWithPluginManager:(PluginManager *)pluginManager
{
  // Quick return if they have pinyin installed, saves us from searching for their card in HSK
  if ([pluginManager pluginKeyIsLoaded:AUDIO_PINYIN_KEY])
  {
    return YES;
  }
  else
  {
    // If have a filename we have audio -- TODO maybe cache this value?
    Plugin *hskPlugin = [pluginManager pluginForKey:AUDIO_HSK_KEY];
    return ([self _fullAudioFilenameWithPlugin:hskPlugin] != nil);
  }
}

- (NSDictionary *) audioFilenamesWithPluginManager:(PluginManager *)mgr
{
  Plugin *pinyinPlugin = [mgr pluginForKey:AUDIO_PINYIN_KEY];
  Plugin *hskPlugin = [mgr pluginForKey:AUDIO_HSK_KEY];
  NSMutableDictionary *audioFilenames = [NSMutableDictionary dictionaryWithCapacity:2];
  [audioFilenames setValue:[self _pinyinAudioFilenamesWithPlugin:pinyinPlugin] forKey:kLWESegmentedReadingKey];
  [audioFilenames setValue:[self _fullAudioFilenameWithPlugin:hskPlugin] forKey:kLWEFullReadingKey];
  return (NSDictionary*)audioFilenames;
}

- (NSString *) _fullAudioFilenameWithPlugin:(Plugin *)hskPlugin
{
  // Quick return if we don't have the full audio plugin
  if (hskPlugin == nil)
  {
    return nil;
  }
  
  // OK, we have it, so search for the file
  NSString *filename = [[hskPlugin fullPath] stringByAppendingFormat:@"%@.mp3",self.headword_simp];
  if ([LWEFile fileExists:filename])
  {
    return filename;
  }
  else
  {
    return nil;
  }
}

- (NSArray *) _pinyinAudioFilenamesWithPlugin:(Plugin *)pinyinPlugin
{
  LWE_ASSERT_EXC(pinyinPlugin, @"We shouldn't be asking for filenames if the plugin isn't loaded");
  NSArray *pinyinSegments = [self.reading componentsSeparatedByString:@" "];
  NSMutableArray *audioArray = [NSMutableArray array];
  for (NSString *pinyin in pinyinSegments)
  {
    // We have a special case for when it is nü(x) tones -- the filenames are "v"
    pinyin = [pinyin stringByReplacingOccurrencesOfString:@"ü" withString:@"v"]; 
    
    // Note there is no checking here for whether the file exists
    NSString *filename = [[pinyinPlugin fullPath] stringByAppendingFormat:@"%@.mp3",[pinyin lowercaseString]];
    [audioArray addObject:filename];
  }
  return (NSArray *)audioArray;
}

#pragma mark -

// -headword will call this automatically with a value of NO
- (NSString *) headwordIgnoringMode:(BOOL)ignoreMode
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSString *type = [settings objectForKey:APP_HEADWORD_TYPE];

  NSString *hw = nil;
  if ([type isEqualToString:SET_HEADWORD_TYPE_TRAD])
  {
    hw = self._headword;
  } 
  else if ([type isEqualToString:SET_HEADWORD_TYPE_SIMP])
  {
    hw = self.headword_simp;
  }
  
  // Only run this code if we're not ignoring
  if (ignoreMode == NO)
  {
    if([[settings objectForKey:APP_HEADWORD] isEqualToString:SET_E_TO_J])
    {
      hw = self.headword_en;
    }
  }
  
  return hw;
}


#pragma mark - Class Plumbing

- (void) dealloc
{
  [headword_simp release];
  [super dealloc];
}


@end
