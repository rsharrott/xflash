//
//  Created by Mark Makdad on 5/31/10.
//  Copyright 2010 Long Weekend Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString * const SET_THEME_PAPER;
extern NSString * const SET_THEME_FIRE;
extern NSString * const SET_THEME_WATER;
extern NSString * const SET_THEME_KIMONO;
extern NSString * const SET_THEME_KUTANI;
extern NSString * const DEFAULT_THEME;

//! Study card shape, shared by every theme (themes v2: inset 12pt, radius-3xl 28)
extern const CGFloat kLWECardInset;
extern const CGFloat kLWECardCornerRadius;

@interface ThemeManager : NSObject

+ (ThemeManager*) sharedThemeManager;
- (UIColor*) currentThemeTintColor;
- (UIColor*) currentThemeTintColor:(float)customAlpha;
//! The shared paper screen colour (paper-2, #E7E1D6); the same in every theme
- (UIColor*) backgroundColor;
- (NSString*) currentThemeFileName;
- (NSString*) currentThemeName;
- (NSString*) currentThemeCSS;
//! CSS for the example-sentences web view (SENTENCES_CSS)
- (NSString*) sentencesCSS;
- (NSString*) currentThemeWebSelectionColor;
- (NSString*) elementWithCurrentTheme:(NSString*)element;
//! The current theme's dictionary; an unknown or missing stored key falls back to DEFAULT_THEME (never nil)
- (NSDictionary*) _currentTheme;
- (NSArray*) _themeListWithKey:(NSString*)key;

/**
 * Colour for a named slot of the current theme (themes v2 slot table), e.g. @"cardFill",
 * @"headwordInk", @"showAnswerBorder".  Shared paper-screen slots (cellFill, tabBarFill, ...)
 * resolve to the same value in every theme.  Absent optional slots return nil; a present but
 * unparseable value asserts in debug and falls back to a grey.
 */
- (UIColor*) colorForSlot:(NSString*)slot;

//! Paints `layer` as the current theme's study card: cardFill, radius 28, ring and shadow (cardStyle)
- (void) applyCardStyleToLayer:(CALayer*)layer;

//! Optional card face decorations (Kimono seigaiha band, Kutani double rim).  `includePattern`
//! is YES only for the study card face — example-sentence web views never get the pattern.
//! Pass the card view; a tagged host subview holds the layers so the card's shadow stays unclipped.
- (void) applyCardDecorationsToView:(UIView*)view includePattern:(BOOL)includePattern;

//! Points to nudge the 67% mood bubble up+left when a cardRim is present (0 otherwise)
- (CGFloat) cardRimBubbleNudge;

//! Provide list of names of all available themes, in display order (Paper, Fire, Water, Kimono, Kutani)
- (NSArray*) themeNameList;

//! Provide dictionary-safe key reference names for all available themes, in display order
- (NSArray*) themeKeysList;

//! The theme key that follows `themeKey` in display order (wraps; unknown keys give the first theme)
- (NSString*) themeKeyAfter:(NSString*)themeKey;

//! Holds themes dictionary, keyed on the theme key
@property (nonatomic, retain) NSDictionary *themes;

//! Theme dictionaries in display order (Settings cycle, themeNameList, themeKeysList)
@property (nonatomic, retain) NSArray *orderedThemes;

@end
