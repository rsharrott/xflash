//
//  LWEDesignTokens.h
//  jFlash
//
//  Colour tokens for the 2026 refresh (first-run sheet, study card, answer bar).
//  Values come from the design mocks (design-review/src/base.css).
//

#import <UIKit/UIKit.h>

static inline UIColor *LWEDesignColorHex(uint32_t hex, CGFloat alpha)
{
  return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                         green:((hex >> 8) & 0xFF) / 255.0
                          blue:(hex & 0xFF) / 255.0
                         alpha:alpha];
}

//! Card background ("fire"), #C01B00 -- replaces the old blended #C42F17
static inline UIColor *LWEDesignFire(void)      { return LWEDesignColorHex(0xC01B00, 1.0); }
//! Deep red ("fire-deep"), #8E1400 -- Paper theme accent, Fire theme card
static inline UIColor *LWEDesignFireDeep(void)  { return LWEDesignColorHex(0x8E1400, 1.0); }
//! Muted fire (Show answer sub-line), #A3341C
static inline UIColor *LWEDesignFireMuted(void) { return LWEDesignColorHex(0xA3341C, 1.0); }
//! Fire wash (pressed Show answer, 67% bubble), #F6E7E1
static inline UIColor *LWEDesignFireWash(void)  { return LWEDesignColorHex(0xF6E7E1, 1.0); }
//! Water theme accent ("water"), #1356A7
static inline UIColor *LWEDesignWater(void)     { return LWEDesignColorHex(0x1356A7, 1.0); }
//! Water theme card ("water-deep"), #134685
static inline UIColor *LWEDesignWaterDeep(void) { return LWEDesignColorHex(0x134685, 1.0); }
//! Headword yellow, #FFD60A
static inline UIColor *LWEDesignYellow(void)    { return LWEDesignColorHex(0xFFD60A, 1.0); }
//! Warm paper background, #FBF8F3
static inline UIColor *LWEDesignPaper(void)     { return LWEDesignColorHex(0xFBF8F3, 1.0); }
//! Darker paper (the shared screen background in every theme; segmented control track), #E7E1D6
static inline UIColor *LWEDesignPaper2(void)    { return LWEDesignColorHex(0xE7E1D6, 1.0); }
//! Raised paper (Show answer fill), #FFFDF9
static inline UIColor *LWEDesignPaperRaised(void) { return LWEDesignColorHex(0xFFFDF9, 1.0); }
//! Line on paper (level-strip track, page dot off), #CFC6B8
static inline UIColor *LWEDesignLine(void)      { return LWEDesignColorHex(0xCFC6B8, 1.0); }
//! Secondary button fill on paper, #EDE6DA
static inline UIColor *LWEDesignPaperButton(void) { return LWEDesignColorHex(0xEDE6DA, 1.0); }
//! Primary ink, #1D1A16
static inline UIColor *LWEDesignInk(void)       { return LWEDesignColorHex(0x1D1A16, 1.0); }
//! Secondary ink (body text on paper), #3A352E
static inline UIColor *LWEDesignInk2(void)      { return LWEDesignColorHex(0x3A352E, 1.0); }
//! Hairline rule on paper, rgba(60,40,20,0.08)
static inline UIColor *LWEDesignHairline(void)  { return [UIColor colorWithRed:60/255.0 green:40/255.0 blue:20/255.0 alpha:0.08]; }
//! Muted ink, #6F665B
static inline UIColor *LWEDesignMuted(void)     { return LWEDesignColorHex(0x6F665B, 1.0); }
//! Wrong button, #F9DCD5 on #7E1400
static inline UIColor *LWEDesignWrongFill(void) { return LWEDesignColorHex(0xF9DCD5, 1.0); }
static inline UIColor *LWEDesignWrongInk(void)  { return LWEDesignColorHex(0x7E1400, 1.0); }
//! Right button, #D3EEDC on #0B5A2C
static inline UIColor *LWEDesignRightFill(void) { return LWEDesignColorHex(0xD3EEDC, 1.0); }
static inline UIColor *LWEDesignRightInk(void)  { return LWEDesignColorHex(0x0B5A2C, 1.0); }

//! A system font of `size`/`weight` that follows Dynamic Type like `style` (UIFontMetrics),
//! optionally capped at `maxPointSize` (0 = no cap) so fixed-width controls still fit.
static inline UIFont *LWEDesignScaledFont(UIFontTextStyle style, CGFloat size, UIFontWeight weight, CGFloat maxPointSize)
{
  UIFont *base = [UIFont systemFontOfSize:size weight:weight];
  UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:style];
  return (maxPointSize > 0) ? [metrics scaledFontForFont:base maximumPointSize:maxPointSize]
                            : [metrics scaledFontForFont:base];
}

//! Filled button configuration whose title font is re-resolved through UIFontMetrics on every
//! configuration update, so the title tracks the Dynamic Type setting while the app is running.
API_AVAILABLE(ios(15.0))
static inline UIButtonConfiguration *LWEDesignButtonConfiguration(NSString *title, UIColor *fill, UIColor *ink,
                                                                  UIFontTextStyle style, CGFloat size, UIFontWeight weight,
                                                                  CGFloat maxPointSize, CGFloat radius)
{
  UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
  config.baseBackgroundColor = fill;
  config.baseForegroundColor = ink;
  config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
  config.background.cornerRadius = radius;
  config.title = title;
  config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
  config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *incoming) {
    NSMutableDictionary *attrs = [[incoming mutableCopy] autorelease];
    attrs[NSFontAttributeName] = LWEDesignScaledFont(style, size, weight, maxPointSize);
    return attrs;
  };
  return config;
}
