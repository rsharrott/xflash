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
//! Per-syllable {pinyin, color}: tone colours when the Pinyin Coloring setting is ON, else readingInk
- (NSArray *) readingComponents;
- (NSArray *) readingComponentsUsingToneColors:(BOOL)useToneColors;
- (NSString *) pinyinReading;
- (NSString *) sandhiReading;

@property (nonatomic, retain) NSString *headword_simp;

@end
