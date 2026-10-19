//
//  ChineseCard.h
//  jFlash
//
//  Created by Mark Makdad on 8/21/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Card.h"

@interface ChineseCard : Card

typedef enum
{
  noToneState = 0,
  toneIsOther = 1,
  toneIsSecondAfterOther = 2,
  toneIsThird = 3,
  toneIsFourth = 4,
} ToneStates;

//! Tone 1-4 colours for a theme (AA on its card): Kimono, light cards (Paper) or dark cards (Fire/Water/Kutani)
+ (NSDictionary *) toneColorsForThemeKey:(NSString *)themeKey cardFill:(UIColor *)cardFill;
//! Tone 1-5 of one syllable from its last tone digit or tone mark, ignoring trailing punctuation; 0 if none
+ (NSInteger) toneForPinyinSyllable:(NSString *)syllable;
//! Per-syllable {pinyin, color}: tone colours when the Pinyin Coloring setting is ON, else readingInk
- (NSArray *) readingComponents;
//! YES when the Pinyin Coloring setting is ON (read fresh on every call)
+ (BOOL) pinyinColoringIsOn;
//! As readingComponents / attributedReading, for an explicit setting and theme key (nil = the current theme)
- (NSArray *) readingComponentsUsingToneColors:(BOOL)useToneColors themeKey:(NSString *)themeKey;
- (NSAttributedString *) attributedReadingUsingToneColors:(BOOL)useToneColors themeKey:(NSString *)themeKey;
//! As above with the current theme passed in (tests): a nil or unknown themeKey uses currentThemeKey's palette, ink and card fill
- (NSArray *) readingComponentsUsingToneColors:(BOOL)useToneColors themeKey:(NSString *)themeKey currentThemeKey:(NSString *)currentThemeKey;
- (NSString *) pinyinReading;
- (NSString *) sandhiReading;

@property (nonatomic, retain) NSString *headword_simp;

@end
