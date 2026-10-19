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
 * Takes something like "gao4" and converts it to "gáo"
 */
- (NSString*) _pinyinForNumberedPinyin:(NSString*)numberedPinyin
{
  // Quick return on bad string input/nil input
  if ([numberedPinyin length] == 0)
  {
    return nil;
  }

  // Another quick return if we don't have a valid tone number - we will use toneNumber later too
  NSInteger toneNumber = [[numberedPinyin substringFromIndex:([numberedPinyin length]-1)] integerValue];
  if (toneNumber == 0 || toneNumber > 5)
  {
    return numberedPinyin;
  }
  
  //Replace the u: with ü (u umlaud)
  numberedPinyin = [numberedPinyin stringByReplacingOccurrencesOfString:@"u:" withString:@"ü"];
  
  // Define some regexes that are going to help us
  NSError *error = NULL;
  NSRegularExpression *vocalRegex = [NSRegularExpression regularExpressionWithPattern:@"[aeiouü]" options:NSRegularExpressionCaseInsensitive error:&error];
  NSRegularExpression *diacriticRegex1 = [NSRegularExpression regularExpressionWithPattern:@"[ae]" options:NSRegularExpressionCaseInsensitive error:&error];
  NSRegularExpression *diacriticRegex2 = [NSRegularExpression regularExpressionWithPattern:@"[ou]" options:NSRegularExpressionCaseInsensitive error:&error];
  
  // Now get the number of vowels in the reading to determine where the diacritic mark goes
  NSString *reading = [numberedPinyin substringToIndex:([numberedPinyin length]-1)];
  NSRange readingRange = NSMakeRange(0,[reading length]);
  NSString *vowel = nil;
  NSArray *vowels = [vocalRegex matchesInString:reading options:0 range:readingRange];
  if ([vowels count] == 1)
  {
    vowel = [reading substringWithRange:[[vowels objectAtIndex:0] range]];
  }
  else if ([vowels count] > 1)
  {
    // OK, so there is more than one vowel, so we need to figure out which one to add the diacritic
    NSArray *patternVowels = [diacriticRegex1 matchesInString:reading options:0 range:readingRange];
    if ([patternVowels count] > 0)
    {
      // OK, we matched the first diacritic Regex
      vowel = [reading substringWithRange:[[patternVowels objectAtIndex:0] range]];
    }
    else
    {
      // Nope, let's try the second one.
      patternVowels = [diacriticRegex2 matchesInString:reading options:0 range:readingRange];
      if ([patternVowels count] > 0)
      {
        vowel = [reading substringWithRange:[[patternVowels objectAtIndex:0] range]];
      }
    }
    
    // Assuming we have a vowel now, get the first letter.
    if (vowel)
    {
      vowel = [vowel substringToIndex:1];
    }
    else
    {
      vowel = [vowels objectAtIndex:1];
    }
  }
  
  // OK, now swap the vowel if we have one.
  if (vowel)
  {
    // TODO: consider caching this dictionary, it's probably expensive.
    NSDictionary *diacriticDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"ā",@"a1",@"ē",@"e1",@"ī",@"i1",@"ō",@"o1",@"ū",@"u1",@"ǖ",@"ü1",
                                   @"á",@"a2",@"é",@"e2",@"í",@"i2",@"ó",@"o2",@"ú",@"u2",@"ǘ",@"ü2",
                                   @"ǎ",@"a3",@"ě",@"e3",@"ǐ",@"i3",@"ǒ",@"o3",@"ǔ",@"u3",@"ǚ",@"ü3",
                                   @"à",@"a4",@"è",@"e4",@"ì",@"i4",@"ò",@"o4",@"ù",@"u4",@"ǜ",@"ü4",
                                   nil];
    if (toneNumber < 5)
    {
      NSString *key = [NSString stringWithFormat:@"%@%d",[vowel lowercaseString],toneNumber];
      NSString *newVowel = [diacriticDict objectForKey:key];
      reading = [reading stringByReplacingOccurrencesOfString:vowel withString:newVowel];
    }
  }
  return reading;
}

- (NSAttributedString *) attributedReading
{
  NSMutableAttributedString *attrString = [[[[NSAttributedString alloc] init] autorelease] mutableCopy];
  NSArray *readingHashes = [self readingComponents];
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
    [tmpAttrString addAttribute:NSFontAttributeName
                          value:[UIFont systemFontOfSize:20 weight:UIFontWeightBold]
                          range:allRange];
    [attrString appendAttributedString:tmpAttrString];
    [tmpAttrString release];
  }
  
  return [attrString autorelease];
}

- (NSArray *) readingComponents
{
  NSMutableArray *components = [NSMutableArray array];
  // Tone colours are theme-aware so they stay AA on light (Paper) and dark (Fire/Water) cards.
  // Light: fire-deep / dark amber / right-ink / water.  Dark: soft red / yellow / mint / sky.
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  UIColor *cardFill = [tm colorForSlot:@"cardFill"];
  CGFloat r = 0, g = 0, b = 0, a = 0;
  [cardFill getRed:&r green:&g blue:&b alpha:&a];
  // Relative luminance (sRGB approx). Paper/Kimono are light; Fire/Water/Kutani are dark.
  CGFloat lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  BOOL lightCard = (lum > 0.45);
  UIColor *tone1, *tone2, *tone3, *tone4, *toneDefault;
  if (lightCard)
  {
    tone1 = [UIColor colorWithRed:0.557 green:0.078 blue:0.000 alpha:1.0]; // #8E1400 fire-deep
    tone2 = [UIColor colorWithRed:0.604 green:0.306 blue:0.000 alpha:1.0]; // #9A4E00 dark amber
    tone3 = [UIColor colorWithRed:0.043 green:0.353 blue:0.173 alpha:1.0]; // #0B5A2C right-ink
    tone4 = [UIColor colorWithRed:0.075 green:0.337 blue:0.655 alpha:1.0]; // #1356A7 water
    toneDefault = [tm colorForSlot:@"readingInk"] ?: [UIColor colorWithRed:0.114 green:0.102 blue:0.086 alpha:1.0]; // ink
  }
  else
  {
    tone1 = [UIColor colorWithRed:1.000 green:0.635 blue:0.580 alpha:1.0]; // #FFA294 (AA at normal size on dark cards)
    tone2 = [UIColor colorWithRed:1.000 green:0.839 blue:0.039 alpha:1.0]; // #FFD60A yellow
    tone3 = [UIColor colorWithRed:0.490 green:0.871 blue:0.627 alpha:1.0]; // #7DDEA0
    tone4 = [UIColor colorWithRed:0.557 green:0.784 blue:1.000 alpha:1.0]; // #8EC8FF
    toneDefault = [tm colorForSlot:@"readingInk"] ?: [UIColor whiteColor];
  }
  NSDictionary *colorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                             tone1,@"1", tone2,@"2", tone3,@"3", tone4,@"4", nil];

  NSArray *pinyinSegments = [self.reading componentsSeparatedByString:@" "];
  for (NSString *pinyinSegment in pinyinSegments)
  {
    UIColor *theColor = toneDefault;
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    BOOL useColor = [[settings objectForKey:APP_PINYIN_COLOR] isEqualToString:SET_PINYIN_COLOR_ON];

    if (useColor)
    {
      for (NSString *toneNumber in colorDict)
      {
        NSRange range = [pinyinSegment rangeOfString:toneNumber];
        if (range.location != NSNotFound)
        {
          theColor = (UIColor*)[colorDict objectForKey:toneNumber];
          break;
        }
      }
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

- (NSString *) sandhiReading
{
  // Tone state variable - we'll soon assign to last pinyin #
  ToneStates lastState = noToneState;
  
  // Hold the temp reading string
  NSMutableString *sandhiString = [NSMutableString stringWithCapacity:self.reading.length];
  NSMutableArray *sandhiArray = [NSMutableArray arrayWithCapacity:self._headword.length];
  
  // Create headword array - each character in a separate element.  Use _headword because we *always* want
  // the Chinese character version, no funny stuff
  NSInteger numChars = [self._headword length];
  NSMutableArray *headwordPieces = [NSMutableArray arrayWithCapacity:numChars];
  for (NSInteger i = 0; i < numChars; i++)
  {
    unichar headwordPiece = [self._headword characterAtIndex:i];
    [headwordPieces addObject:[NSString stringWithFormat:@"%C",headwordPiece]];
  }
  
  NSArray *pinyinSegments = [self.reading componentsSeparatedByString:@" "];
  LWE_ASSERT_EXC([headwordPieces count] == [pinyinSegments count], @"do i have a bold assumption wrong here?");
  for (NSInteger i = ([pinyinSegments count]-1); i >= 0; i--)
  {
    NSString *pinyin = [pinyinSegments objectAtIndex:i];
    NSString *hanzi = [headwordPieces objectAtIndex:i];
    NSInteger toneNumber = [[pinyin substringFromIndex:([pinyin length]-1)] integerValue];
    
    // By default, mark that no rules have been triggered with this pass.
    BOOL ruleTriggered = NO;
    
    // If we have no state, this is the first (er, last) pinyin.
    if (lastState == noToneState)
    {
      // In this case, we note if it is 3rd or 4th tone, otherwise just change the state to "other".
      if (toneNumber == toneIsThird || toneNumber == toneIsFourth)
      {
        lastState = toneNumber;
      }
      else
      {
        // Note we always assign "other" -- even if it is tone 2 (for starting state)
        lastState = toneIsOther;
      }
    }
    else if (lastState == toneIsThird)
    {
      // Just change the state to the current tone number
      lastState = toneNumber;

      // 2 thirds in a row triggers the rule
      if (toneNumber == toneIsThird)
      {
        ruleTriggered = YES;
        toneNumber = 2;
      }
    }
    else if (lastState == toneIsFourth)
    {
      // Just remember the state
      lastState = toneNumber;

      // The 2 special headwords trigger the rule
      if ([hanzi isEqualToString:@"一"] || [hanzi isEqualToString:@"不"])
      {
        ruleTriggered = YES;
        toneNumber = 2;
      }
    }
    // Previously the state was other, now see if will catch any rules
    else if (lastState == toneIsOther)
    {
      lastState = toneNumber;
    }
    // If the state matched this pattern, we have a hit if the tone is 
    else if (lastState == toneIsSecondAfterOther)
    {
      lastState = toneNumber;
    }

    // Now, if we triggered a rule, replace it
    if (ruleTriggered)
    {
      pinyin = [NSString stringWithFormat:@"%@%d",[pinyin substringToIndex:(pinyin.length-1)],toneNumber];
    }
    [sandhiArray addObject:pinyin];
  }
  
  // Now reverse the sandhi array to get it back normal again
  NSArray *finalArray = [[sandhiArray reverseObjectEnumerator] allObjects];
  for (NSString *sandhiPiece in finalArray)
  {
    sandhiPiece = [self _pinyinForNumberedPinyin:sandhiPiece];
    [sandhiString appendFormat:@"%@ ",sandhiPiece];
  }
  return [sandhiString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  
  /*  noToneState,
  toneIsSecondAfterOther,
  toneIsThird,
  toneIsFourth,*/
  
  
  // Reset the state machine to the last tone value
  
  // Iterate backwards to the next-to-last tone.  
  
  // Run state transition logic
  
  // Set current state to next-to-last tone and iterate until finished
  
  // Then update the numbers and run it through the normal processor
  //return [self _pinyinForNumberedPinyin:finalString];
  //  return [self pinyinReading];
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
