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
//! Headword yellow, #FFD60A
static inline UIColor *LWEDesignYellow(void)    { return LWEDesignColorHex(0xFFD60A, 1.0); }
//! Warm paper background, #FBF8F3
static inline UIColor *LWEDesignPaper(void)     { return LWEDesignColorHex(0xFBF8F3, 1.0); }
//! Darker paper (segmented control track), #E7E1D6
static inline UIColor *LWEDesignPaper2(void)    { return LWEDesignColorHex(0xE7E1D6, 1.0); }
//! Secondary button fill on paper, #EDE6DA
static inline UIColor *LWEDesignPaperButton(void) { return LWEDesignColorHex(0xEDE6DA, 1.0); }
//! Primary ink, #1D1A16
static inline UIColor *LWEDesignInk(void)       { return LWEDesignColorHex(0x1D1A16, 1.0); }
//! Muted ink, #6F665B
static inline UIColor *LWEDesignMuted(void)     { return LWEDesignColorHex(0x6F665B, 1.0); }
//! Wrong button, #F9DCD5 on #7E1400
static inline UIColor *LWEDesignWrongFill(void) { return LWEDesignColorHex(0xF9DCD5, 1.0); }
static inline UIColor *LWEDesignWrongInk(void)  { return LWEDesignColorHex(0x7E1400, 1.0); }
//! Right button, #D3EEDC on #0B5A2C
static inline UIColor *LWEDesignRightFill(void) { return LWEDesignColorHex(0xD3EEDC, 1.0); }
static inline UIColor *LWEDesignRightInk(void)  { return LWEDesignColorHex(0x0B5A2C, 1.0); }
