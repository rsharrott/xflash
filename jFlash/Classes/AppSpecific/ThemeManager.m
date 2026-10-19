//
//  jFlash
//
//  Created by Mark Makdad on 5/31/10.
//  Copyright 2010 Long Weekend Inc. All rights reserved.
//

#import "ThemeManager.h"
#import "SynthesizeSingleton.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

// Theme configuration names (stored in NSUserDefaults under APP_THEME)
NSString * const SET_THEME_PAPER     = @"PAPER";
NSString * const SET_THEME_FIRE      = @"FIRE";
NSString * const SET_THEME_WATER     = @"WATER";
NSString * const SET_THEME_KIMONO    = @"KIMONO";
NSString * const SET_THEME_KUTANI    = @"KUTANI";
NSString * const DEFAULT_THEME       = @"PAPER";

static const NSInteger kLWECardDecorationHostTag = 9002;
static const CGFloat kLWESeigaihaBandHeight = 44.0;

// Keys inside each theme dictionary
static NSString * const kLWEThemeSlotsKey = @"slots";
static NSString * const kLWEThemeSentencesCSSKey = @"SENTENCES_CSS";

const CGFloat kLWECardInset = 12.0;
const CGFloat kLWECardCornerRadius = 28.0;

//! Parses "#RRGGBB" or "rgba(r,g,b,a)" (r/g/b 0-255, a 0-1).  Returns nil for anything else.
static UIColor *LWEThemeColorFromString(NSString *value)
{
  if ([value isKindOfClass:[NSString class]] == NO) return nil;
  if ([value hasPrefix:@"#"] && [value length] == 7)
  {
    unsigned int hex = 0;
    if ([[NSScanner scannerWithString:[value substringFromIndex:1]] scanHexInt:&hex] == NO) return nil;
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0];
  }
  if ([value hasPrefix:@"rgba("] && [value hasSuffix:@")"])
  {
    NSString *inner = [value substringWithRange:NSMakeRange(5, [value length] - 6)];
    NSArray *parts = [inner componentsSeparatedByString:@","];
    if ([parts count] != 4) return nil;
    return [UIColor colorWithRed:[[parts objectAtIndex:0] doubleValue] / 255.0
                           green:[[parts objectAtIndex:1] doubleValue] / 255.0
                            blue:[[parts objectAtIndex:2] doubleValue] / 255.0
                           alpha:[[parts objectAtIndex:3] doubleValue]];
  }
  return nil;
}

//! Builds one theme dictionary (shared + themed slots merged; themed wins)
static NSDictionary *LWEThemeDictionary(NSString *key, NSString *name, NSString *filename,
                                        CGFloat r, CGFloat g, CGFloat b, NSString *webSelected,
                                        NSString *css, NSString *sentencesCSS,
                                        NSDictionary *sharedSlots, NSDictionary *themedSlots, NSDictionary *cardSlots)
{
  NSMutableDictionary *slots = [NSMutableDictionary dictionaryWithDictionary:sharedSlots];
  [slots addEntriesFromDictionary:themedSlots];
  [slots addEntriesFromDictionary:cardSlots];
  return @{ @"key": key,
            @"name": name,
            @"filename": filename,
            @"R": [NSNumber numberWithFloat:r],
            @"G": [NSNumber numberWithFloat:g],
            @"B": [NSNumber numberWithFloat:b],
            @"WEB_SELECTED": webSelected,
            @"CSS": css,
            kLWEThemeSentencesCSSKey: sentencesCSS,
            kLWEThemeSlotsKey: [NSDictionary dictionaryWithDictionary:slots] };
}

//! Manages themes and returns values depending on current user theme
@implementation ThemeManager

@synthesize themes, orderedThemes;

SYNTHESIZE_SINGLETON_FOR_CLASS(ThemeManager);

/**
 * Initialize theme manager (defines all themes as well).
 * Themes: Paper, Fire, Water, Kimono (B), Kutani share one paper screen;
 * a theme changes only the study card, accent, and optional card decorations.
 */
- (id) init
{
  if ((self = [super init]))
  {
    // Shared paper screen (identical in every theme; themes/v2 README section 3, "shared" rows)
    NSDictionary *sharedSlots = @{
      @"backgroundColor": @"#E7E1D6",
      @"screenBackground": @"#E7E1D6",
      @"footInk": @"#3A352E",
      @"pageDotOn": @"#3A352E",
      @"pageDotOff": @"#CFC6B8",
      @"stripInk": @"#3A352E",
      @"showAnswerFill": @"#FFFDF9",
      @"tabBarFill": @"#FBF8F3",
      @"tabSelectedPill": @"#EDE6DA",
      @"tabInk": @"#3A352E",
      @"navBarFill": @"#E7E1D6",
      @"navTitleInk": @"#1D1A16",
      @"groupedBackground": @"#E7E1D6",
      @"cellFill": @"#FBF8F3",
      @"cellLabelInk": @"#1D1A16",
      @"cellValueInk": @"#6F665B",
      @"sectionHeaderInk": @"#3A352E",
      @"separator": @"rgba(60,40,20,0.08)",
      @"chevronInk": @"#6F665B",
      @"selectedCellInk": @"#FFFFFF",
      @"moodBubbleInk": @"#1D1A16",
    };
    // PAPER: themed slots
    NSDictionary *paperSlots = @{
      @"tint": @"#8E1400",
      @"cardFill": @"#FBF8F3",
      @"headwordInk": @"#3A352E",
      @"readingInk": @"#3A352E",
      @"romajiInk": @"#6F665B",
      @"meaningInk": @"#1D1A16",
      @"meaningRule": @"#CFC6B8",
      @"toggleInk": @"#8E1400",
      @"readingToggleFill": @"rgba(58,53,46,0.14)",
      @"speakerFill": @"#F6E7E1",
      @"speakerInk": @"#8E1400",
      @"moreReadingsFill": @"#EDE6DA",
      @"moreReadingsInk": @"#3A352E",
      @"stripBarFill": @"#8E1400",
      @"stripBarTrack": @"#CFC6B8",
      @"showAnswerBorder": @"#8E1400",
      @"showAnswerInk": @"#8E1400",
      @"showAnswerSubInk": @"#A3341C",
      @"progressBarFill": @"#8E1400",
      @"progressAccentInk": @"#8E1400",
      @"selectedCellFill": @"#8E1400",
      @"moodBubbleFill": @"#F6E7E1",
    };
    // CSS: PAPER
    NSString *paperCSS = @"body{color:#1D1A16;} #container:before{background:#CFC6B8;} ol,li{color:#1D1A16;} dfn{background-color:#FFD60A;border-color:#FFD60A;color:#3A2A00;}";
    NSString *paperSentencesCSS = @"body{color:#1D1A16;} .headwordLabel{color:#3A352E;} .readingLabel{color:#3A352E;} .romaji,.exTitle{color:#6F665B;} li{background:#EDE6DA;} .ja{color:#1D1A16;} .hl{color:#8E1400;background:transparent;text-decoration-line:underline;text-decoration-color:#8E1400;text-decoration-thickness:2px;} .en,.ContentCell{color:#3A352E;} .button{color:#8E1400;background:#FBF8F3;} .ExpandedSentencesTable td{border-top-color:rgba(60,40,20,0.08);} .HeadwordCell{color:#1D1A16;} dfn{background-color:#FFD60A;color:#3A2A00;}";
    // FIRE: themed slots
    NSDictionary *fireSlots = @{
      @"tint": @"#C01B00",
      @"cardFill": @"#8E1400",
      @"headwordInk": @"#FFD60A",
      @"readingInk": @"#FFFFFF",
      @"romajiInk": @"rgba(255,255,255,0.88)",
      @"meaningInk": @"#FFFFFF",
      @"meaningRule": @"rgba(255,255,255,0.30)",
      @"toggleInk": @"rgba(255,255,255,0.88)",
      @"readingToggleFill": @"rgba(255,255,255,0.14)",
      @"speakerFill": @"rgba(255,255,255,0.16)",
      @"speakerInk": @"#FFFFFF",
      @"moreReadingsFill": @"rgba(255,255,255,0.14)",
      @"moreReadingsInk": @"#FFFFFF",
      @"stripBarFill": @"#C01B00",
      @"stripBarTrack": @"#CFC6B8",
      @"showAnswerBorder": @"#C01B00",
      @"showAnswerInk": @"#C01B00",
      @"showAnswerSubInk": @"#A3341C",
      @"progressBarFill": @"#C01B00",
      @"progressAccentInk": @"#C01B00",
      @"selectedCellFill": @"#C01B00",
      @"moodBubbleFill": @"#F6E7E1",
    };
    // CSS: FIRE
    NSString *fireCSS = @"body{color:#FFFFFF;} #container:before{background:rgba(255,255,255,0.30);} ol,li{color:#FFFFFF;} dfn{background-color:#FFD60A;border-color:#FFD60A;color:#3A2A00;}";
    NSString *fireSentencesCSS = @"body{color:#FFFFFF;} .headwordLabel{color:#FFD60A;} .readingLabel{color:#FFFFFF;} .romaji,.exTitle{color:rgba(255,255,255,0.88);} li{background:rgba(255,255,255,0.14);} .ja{color:#FFFFFF;} .hl{color:#3A2A00;background:#FFD60A;text-decoration-line:none;} .en,.ContentCell{color:rgba(255,255,255,0.88);} .button{color:#FFFFFF;background:#8E1400;} .ExpandedSentencesTable td{border-top-color:rgba(255,255,255,0.30);} .HeadwordCell{color:#FFD60A;} dfn{background-color:#FFD60A;color:#3A2A00;}";
    // WATER: themed slots
    NSDictionary *waterSlots = @{
      @"tint": @"#1356A7",
      @"cardFill": @"#134685",
      @"headwordInk": @"#FFFFFF",
      @"readingInk": @"#FFFFFF",
      @"romajiInk": @"rgba(255,255,255,0.88)",
      @"meaningInk": @"#FFFFFF",
      @"meaningRule": @"rgba(255,255,255,0.30)",
      @"toggleInk": @"rgba(255,255,255,0.88)",
      @"readingToggleFill": @"rgba(255,255,255,0.14)",
      @"speakerFill": @"rgba(255,255,255,0.16)",
      @"speakerInk": @"#FFFFFF",
      @"moreReadingsFill": @"rgba(255,255,255,0.14)",
      @"moreReadingsInk": @"#FFFFFF",
      @"stripBarFill": @"#1356A7",
      @"stripBarTrack": @"#CFC6B8",
      @"showAnswerBorder": @"#1356A7",
      @"showAnswerInk": @"#1356A7",
      @"showAnswerSubInk": @"#6F665B",
      @"progressBarFill": @"#1356A7",
      @"progressAccentInk": @"#1356A7",
      @"selectedCellFill": @"#1356A7",
      @"moodBubbleFill": @"#FBF8F3",
    };
    // CSS: WATER
    NSString *waterCSS = @"body{color:#FFFFFF;} #container:before{background:rgba(255,255,255,0.30);} ol,li{color:#FFFFFF;} dfn{background-color:#FFD60A;border-color:#FFD60A;color:#3A2A00;}";
    NSString *waterSentencesCSS = @"body{color:#FFFFFF;} .headwordLabel{color:#FFFFFF;} .readingLabel{color:#FFFFFF;} .romaji,.exTitle{color:rgba(255,255,255,0.88);} li{background:rgba(255,255,255,0.14);} .ja{color:#FFFFFF;} .hl{color:#3A2A00;background:#FFD60A;text-decoration-line:none;} .en,.ContentCell{color:rgba(255,255,255,0.88);} .button{color:#FFFFFF;background:#134685;} .ExpandedSentencesTable td{border-top-color:rgba(255,255,255,0.30);} .HeadwordCell{color:#FFFFFF;} dfn{background-color:#FFD60A;color:#3A2A00;}";

    // Card shape is shared (inset 12pt, radius 28); only the shadow differs.  One CALayer shadow
    // (CSS blur / 2 = shadowRadius) plus an optional 1pt ring: Paper ring + e2, Fire fire-lg, Water ring + e3.
    NSDictionary *paperCard = @{ @"cardShadow": @"rgba(40,30,20,0.08)", @"cardShadowY": @10, @"cardShadowBlur": @24, @"cardRing": @"rgba(60,40,20,0.08)" };
    NSDictionary *fireCard  = @{ @"cardShadow": @"rgba(120,20,0,0.22)", @"cardShadowY": @24, @"cardShadowBlur": @60 };
    NSDictionary *waterCard = @{ @"cardShadow": @"rgba(40,30,20,0.16)", @"cardShadowY": @18, @"cardShadowBlur": @40, @"cardRing": @"rgba(60,40,20,0.08)" };
    // Kimono B uses Paper's shadow-ring + e2; Kutani uses Water's ring + e3.
    NSDictionary *kimonoCard = @{ @"cardShadow": @"rgba(40,30,20,0.08)", @"cardShadowY": @10, @"cardShadowBlur": @24, @"cardRing": @"rgba(60,40,20,0.08)",
                                  @"cardPattern": @"seigaiha", @"cardPatternInk": @"rgba(255,253,249,0.45)" };
    NSDictionary *kutaniCard = @{ @"cardShadow": @"rgba(40,30,20,0.16)", @"cardShadowY": @18, @"cardShadowBlur": @40, @"cardRing": @"rgba(60,40,20,0.08)",
                                  @"cardRimColor": @"#E2B13A", @"cardRimOpacity": @0.7,
                                  @"cardRimOuterInset": @3, @"cardRimOuterWidth": @1.25,
                                  @"cardRimInnerInset": @6, @"cardRimInnerWidth": @0.75,
                                  @"cardRimBubbleNudge": @4 };

    // KIMONO B (ai × kaki): washed-persimmon card, indigo ink/accent, seigaiha band
    NSDictionary *kimonoSlots = @{
      @"tint": @"#1F3558",
      @"cardFill": @"#EEA57A",
      @"headwordInk": @"#1F3558",
      @"readingInk": @"#1F3558",
      @"romajiInk": @"#1F3558",
      @"meaningInk": @"#1F3558",
      @"meaningRule": @"#8A3B1C",
      @"toggleInk": @"#1F3558",
      @"readingToggleFill": @"rgba(31,53,88,0.14)",
      @"speakerFill": @"#FFFDF9",
      @"speakerInk": @"#1F3558",
      @"moreReadingsFill": @"#FFFDF9",
      @"moreReadingsInk": @"#1F3558",
      @"stripBarFill": @"#1F3558",
      @"stripBarTrack": @"#CFC6B8",
      @"showAnswerBorder": @"#1F3558",
      @"showAnswerInk": @"#1F3558",
      @"showAnswerSubInk": @"#6F665B",
      @"progressBarFill": @"#1F3558",
      @"progressAccentInk": @"#1F3558",
      @"selectedCellFill": @"#1F3558",
      @"moodBubbleFill": @"#FBF8F3",
    };
    NSString *kimonoCSS = @"body{color:#1F3558;} #container:before{background:#8A3B1C;} ol,li{color:#1F3558;} dfn{background-color:#FFD60A;border-color:#FFD60A;color:#3A2A00;}";
    // Light-card sentences: kakishibu underline (README hl color + v2 quiet-underline pattern)
    NSString *kimonoSentencesCSS = @"body{color:#1D1A16;} .headwordLabel{color:#1F3558;} .readingLabel{color:#1F3558;} .romaji,.exTitle{color:#1F3558;} li{background:#FBF8F3;} .ja{color:#1D1A16;} .hl{color:#8A3B1C;background:transparent;text-decoration-line:underline;text-decoration-color:#8A3B1C;text-decoration-thickness:2px;} .en,.ContentCell{color:#3A352E;} .button{color:#1F3558;background:#EEA57A;} .ExpandedSentencesTable td{border-top-color:rgba(60,40,20,0.08);} .HeadwordCell{color:#1F3558;} dfn{background-color:#FFD60A;color:#3A2A00;}";

    // KUTANI: deep green glaze, ochre ink, aubergine accent, double rim
    NSDictionary *kutaniSlots = @{
      @"tint": @"#553366",
      @"cardFill": @"#1E4A3A",
      @"headwordInk": @"#E2B13A",
      @"readingInk": @"#FBF8F3",
      @"romajiInk": @"rgba(255,255,255,0.88)",
      @"meaningInk": @"#FBF8F3",
      @"meaningRule": @"#E2B13A",
      @"toggleInk": @"rgba(255,255,255,0.88)",
      @"readingToggleFill": @"rgba(255,255,255,0.14)",
      @"speakerFill": @"rgba(255,255,255,0.16)",
      @"speakerInk": @"#FBF8F3",
      @"moreReadingsFill": @"rgba(255,255,255,0.14)",
      @"moreReadingsInk": @"#FBF8F3",
      @"stripBarFill": @"#553366",
      @"stripBarTrack": @"#CFC6B8",
      @"showAnswerBorder": @"#553366",
      @"showAnswerInk": @"#553366",
      @"showAnswerSubInk": @"#6F665B",
      @"progressBarFill": @"#553366",
      @"progressAccentInk": @"#553366",
      @"selectedCellFill": @"#553366",
      @"moodBubbleFill": @"#FBF8F3",
    };
    NSString *kutaniCSS = @"body{color:#FBF8F3;} #container:before{background:#E2B13A;} ol,li{color:#FBF8F3;} dfn{background-color:#E2B13A;border-color:#E2B13A;color:#3A2A00;}";
    // Dark-card sentences: ochre marker (task dark-card pattern; README had color-only hl)
    NSString *kutaniSentencesCSS = @"body{color:#FBF8F3;} .headwordLabel{color:#E2B13A;} .readingLabel{color:#FBF8F3;} .romaji,.exTitle{color:rgba(255,255,255,0.88);} li{background:transparent;} .ja{color:#FBF8F3;} .hl{color:#3A2A00;background:#E2B13A;text-decoration-line:none;} .en,.ContentCell{color:rgba(255,255,255,0.88);} .button{color:#FBF8F3;background:rgba(255,255,255,0.16);} .ExpandedSentencesTable td{border-top-color:rgba(255,255,255,0.30);} .HeadwordCell{color:#E2B13A;} dfn{background-color:#E2B13A;color:#3A2A00;} .showWordsDiv{display:flex;align-items:center;} li{margin:0;border-radius:0;padding-bottom:14px;position:relative;} li+li{padding-top:15px;} li+li::before{content:\"\";position:absolute;left:16px;right:16px;top:0;height:1px;background:rgba(226,177,58,0.45);}";

#if !defined(LWE_JFLASH)
    // Chinese Flash keeps its own noun-pill colours; the meaning ink still follows the card.
    paperCSS = @"body{color:#1D1A16;} ol,li{color:#1D1A16;} dfn, button { background-color:orange; border-color:yellow; }";
    fireCSS  = @"body{color:#FFFFFF;} ol,li{color:#FFFFFF;} dfn, button { background-color:orange; border-color:yellow; }";
    waterCSS = @"body{color:#FFFFFF;} ol,li{color:#FFFFFF;} dfn { background-color:lightsteelblue; border-color:white; }";
    kimonoCSS = @"body{color:#1F3558;} ol,li{color:#1F3558;} dfn, button { background-color:orange; border-color:yellow; }";
    kutaniCSS = @"body{color:#FBF8F3;} ol,li{color:#FBF8F3;} dfn { background-color:#E2B13A; border-color:#E2B13A; color:#3A2A00; }";
#endif

    NSDictionary *paper = LWEThemeDictionary(SET_THEME_PAPER, @"Paper", @"red", 0.557, 0.078, 0.000, @"f6e7e1",
                                             paperCSS, paperSentencesCSS, sharedSlots, paperSlots, paperCard);
    NSDictionary *fire = LWEThemeDictionary(SET_THEME_FIRE, @"Fire", @"red", 0.753, 0.105, 0.000, @"f6e7e1",
                                            fireCSS, fireSentencesCSS, sharedSlots, fireSlots, fireCard);
    NSDictionary *water = LWEThemeDictionary(SET_THEME_WATER, @"Water", @"blue", 0.075, 0.337, 0.655, @"ede6da",
                                             waterCSS, waterSentencesCSS, sharedSlots, waterSlots, waterCard);
    NSDictionary *kimono = LWEThemeDictionary(SET_THEME_KIMONO, @"Kimono", @"blue", 0.122, 0.208, 0.345, @"ede6da",
                                              kimonoCSS, kimonoSentencesCSS, sharedSlots, kimonoSlots, kimonoCard);
    NSDictionary *kutani = LWEThemeDictionary(SET_THEME_KUTANI, @"Kutani", @"red", 0.333, 0.200, 0.400, @"ede6da",
                                              kutaniCSS, kutaniSentencesCSS, sharedSlots, kutaniSlots, kutaniCard);

    // Display order: Paper, Fire, Water, Kimono, Kutani.  Default stays Paper.
    [self setOrderedThemes:@[paper, fire, water, kimono, kutani]];
    [self setThemes:@{ SET_THEME_PAPER: paper, SET_THEME_FIRE: fire, SET_THEME_WATER: water,
                       SET_THEME_KIMONO: kimono, SET_THEME_KUTANI: kutani }];
  }
  return self;  
}

//! Returns the current theme - never nil: a missing or unknown stored key (e.g. a dev build that still has "TAME") uses DEFAULT_THEME
- (NSDictionary*) _currentTheme
{
  NSString *key = [[NSUserDefaults standardUserDefaults] objectForKey:APP_THEME];
  NSDictionary *theme = ([key isKindOfClass:[NSString class]]) ? [[self themes] objectForKey:key] : nil;
  return theme ?: [[self themes] objectForKey:DEFAULT_THEME];
}

/**
 * Returns the background for gray backgrounded tables: paper-2, shared by every theme
 */
- (UIColor*) backgroundColor
{
  return [self colorForSlot:@"backgroundColor"];
}

- (UIColor*) colorForSlot:(NSString*)slot
{
  return [self colorForSlot:slot themeKey:nil];
}

- (UIColor*) colorForSlot:(NSString*)slot themeKey:(NSString*)themeKey
{
  NSDictionary *theme = (themeKey ? [[self themes] objectForKey:themeKey] : nil) ?: [self _currentTheme];
  // Optional slots (cardRing, cardPatternInk, …) are simply absent — return nil.
  id raw = [[theme objectForKey:kLWEThemeSlotsKey] objectForKey:slot];
  if (raw == nil) return nil;
  UIColor *color = LWEThemeColorFromString(raw);
  if (color == nil)
  {
    NSAssert(NO, @"ThemeManager: unparseable slot '%@' (%@) on theme '%@'", slot, raw, [theme objectForKey:@"key"]);
    // Fallback so callers that put the result in a dictionary never store nil
    return [UIColor colorWithWhite:0.4 alpha:1.0];
  }
  return color;
}

- (void) applyCardStyleToLayer:(CALayer*)layer
{
  NSDictionary *slots = [[self _currentTheme] objectForKey:kLWEThemeSlotsKey];
  layer.backgroundColor = [self colorForSlot:@"cardFill"].CGColor;
  layer.cornerRadius = kLWECardCornerRadius;
  UIColor *ring = [self colorForSlot:@"cardRing"];
  layer.borderColor = ring.CGColor;
  layer.borderWidth = ring ? 1.0 : 0.0;
  UIColor *shadow = [self colorForSlot:@"cardShadow"];
  CGFloat alpha = shadow ? CGColorGetAlpha(shadow.CGColor) : 0;
  layer.shadowColor = shadow ? [shadow colorWithAlphaComponent:1.0].CGColor : [UIColor blackColor].CGColor;
  layer.shadowOpacity = (float)alpha;
  layer.shadowOffset = CGSizeMake(0, [[slots objectForKey:@"cardShadowY"] floatValue]);
  layer.shadowRadius = [[slots objectForKey:@"cardShadowBlur"] floatValue] / 2.0;
  layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:layer.bounds cornerRadius:kLWECardCornerRadius].CGPath;
}

//! Renders the Kimono seigaiha band (top 44pt) as a single bitmap; geometry matches design-review build_kimono.py
static UIImage *LWESeigaihaImage(CGFloat width, CGFloat scale, UIColor *cardFill, UIColor *stroke)
{
  if (width <= 0 || scale <= 0) return nil;
  CGSize size = CGSizeMake(width, kLWESeigaihaBandHeight);
  UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
  fmt.scale = scale;
  fmt.opaque = NO;
  UIGraphicsImageRenderer *renderer = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt] autorelease];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
    CGContextRef ctx = rendererContext.CGContext;
    CGContextSetLineWidth(ctx, 1.0);
    [stroke setStroke];
    [cardFill setFill];
    // Rows every 6pt; odd rows shifted 12pt.  Draw top row first so lower rows overlap.
    for (CGFloat y = 0; y <= kLWESeigaihaBandHeight + 12.0; y += 6.0)
    {
      NSInteger row = (NSInteger)lround(y / 6.0);
      CGFloat xOff = (row % 2 == 0) ? 0.0 : 12.0;
      for (CGFloat x = -24.0 + xOff; x <= width + 24.0; x += 24.0)
      {
        CGContextAddEllipseInRect(ctx, CGRectMake(x - 12.0, y - 12.0, 24.0, 24.0));
        CGContextFillPath(ctx);
        CGFloat radii[3] = { 11.0, 7.5, 4.0 };
        for (int i = 0; i < 3; i++)
        {
          CGFloat r = radii[i];
          CGContextAddEllipseInRect(ctx, CGRectMake(x - r, y - r, r * 2.0, r * 2.0));
          CGContextStrokePath(ctx);
        }
      }
    }
  }];
}

- (CGFloat) cardRimBubbleNudge
{
  NSDictionary *slots = [[self _currentTheme] objectForKey:kLWEThemeSlotsKey];
  return [[slots objectForKey:@"cardRimBubbleNudge"] floatValue];
}

- (void) applyCardDecorationsToView:(UIView*)view includePattern:(BOOL)includePattern
{
  if (view == nil) return;
  NSDictionary *slots = [[self _currentTheme] objectForKey:kLWEThemeSlotsKey];
  NSString *pattern = [slots objectForKey:@"cardPattern"];
  UIColor *rimColor = [self colorForSlot:@"cardRimColor"];
  CGFloat rimOpacity = [[slots objectForKey:@"cardRimOpacity"] floatValue];
  BOOL wantPattern = includePattern && [pattern isEqualToString:@"seigaiha"];
  BOOL wantRim = (rimColor != nil);

  UIView *host = [view viewWithTag:kLWECardDecorationHostTag];
  if (wantPattern == NO && wantRim == NO)
  {
    [host removeFromSuperview];
    return;
  }
  if (host == nil)
  {
    host = [[[UIView alloc] initWithFrame:view.bounds] autorelease];
    host.tag = kLWECardDecorationHostTag;
    host.userInteractionEnabled = NO;
    host.backgroundColor = [UIColor clearColor];
    host.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [view insertSubview:host atIndex:0];
  }
  host.frame = view.bounds;
  host.layer.cornerRadius = kLWECardCornerRadius;
  host.clipsToBounds = YES;

  // Rebuild only when theme, bounds, or includePattern change (viewDidLayoutSubviews is frequent).
  NSString *themeKey = [[self _currentTheme] objectForKey:@"key"] ?: @"";
  NSString *sig = [NSString stringWithFormat:@"%@|%.1f|%.1f|%d", themeKey, view.bounds.size.width, view.bounds.size.height, (int)includePattern];
  if ([host.accessibilityIdentifier isEqualToString:sig] && host.layer.sublayers.count > 0)
    return;
  host.accessibilityIdentifier = sig;

  // Drop prior decoration layers
  NSArray *sub = [NSArray arrayWithArray:host.layer.sublayers];
  for (CALayer *layer in sub)
  {
    if ([layer.name hasPrefix:@"lwe.cardDecor."])
      [layer removeFromSuperlayer];
  }

  if (wantPattern)
  {
    UIColor *fill = [self colorForSlot:@"cardFill"];
    UIColor *ink = [self colorForSlot:@"cardPatternInk"] ?: LWEThemeColorFromString(@"rgba(255,253,249,0.45)");
    CGFloat scale = view.window.screen.scale;
    if (scale <= 0) scale = [UIScreen mainScreen].scale;
    UIImage *img = LWESeigaihaImage(view.bounds.size.width, scale, fill, ink);
    CALayer *band = [CALayer layer];
    band.name = @"lwe.cardDecor.seigaiha";
    band.frame = CGRectMake(0, 0, view.bounds.size.width, kLWESeigaihaBandHeight);
    band.contents = (id)img.CGImage;
    band.contentsGravity = kCAGravityResize;
    CAGradientLayer *fade = [CAGradientLayer layer];
    fade.frame = band.bounds;
    fade.colors = [NSArray arrayWithObjects:
                   (id)[UIColor whiteColor].CGColor,
                   (id)[UIColor whiteColor].CGColor,
                   (id)[UIColor clearColor].CGColor, nil];
    fade.locations = [NSArray arrayWithObjects:@0, @0.55, @1, nil];
    band.mask = fade;
    [host.layer addSublayer:band];
  }

  if (wantRim)
  {
    CGFloat outerInset = [[slots objectForKey:@"cardRimOuterInset"] floatValue];
    CGFloat outerWidth = [[slots objectForKey:@"cardRimOuterWidth"] floatValue];
    CGFloat innerInset = [[slots objectForKey:@"cardRimInnerInset"] floatValue];
    CGFloat innerWidth = [[slots objectForKey:@"cardRimInnerWidth"] floatValue];
    UIColor *stroke = [rimColor colorWithAlphaComponent:(rimOpacity > 0 ? rimOpacity : 0.7)];
    CGFloat pairs[2][2] = { { outerInset, outerWidth }, { innerInset, innerWidth } };
    for (int i = 0; i < 2; i++)
    {
      CGFloat inset = pairs[i][0];
      CGFloat width = pairs[i][1];
      CAShapeLayer *rim = [CAShapeLayer layer];
      rim.name = (i == 0) ? @"lwe.cardDecor.rimOuter" : @"lwe.cardDecor.rimInner";
      rim.fillColor = [UIColor clearColor].CGColor;
      rim.strokeColor = stroke.CGColor;
      rim.lineWidth = width;
      CGRect r = CGRectInset(view.bounds, inset, inset);
      CGFloat radius = MAX(0, kLWECardCornerRadius - inset);
      rim.path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius].CGPath;
      [host.layer addSublayer:rim];
    }
  }
}

/**
 * Returns the current theme's tint color as a UIColor
 */
- (UIColor*) currentThemeTintColor
{
  // Calling currentThemeTintColor:(float)customAlpha
  return [self currentThemeTintColor:1.0f];
}

/**
 * Returns the current theme's tint color as a UIColor
 */
- (UIColor*) currentThemeTintColor:(float)customAlpha
{
  NSDictionary* tm = [self _currentTheme];
  return [UIColor colorWithRed:[[tm objectForKey:@"R"] floatValue] green:[[tm objectForKey:@"G"] floatValue] blue:[[tm objectForKey:@"B"] floatValue] alpha:customAlpha];
}  


/**
 * Returns the current theme's name
 */
- (NSString*) currentThemeName
{
  NSDictionary *tm = [self _currentTheme];
  return [tm objectForKey:@"name"];
}


/**
 * Returns the current theme's file extension name (for dynamic loading)
 */
- (NSString*) currentThemeFileName
{
  NSDictionary *tm = [self _currentTheme];
  return [tm objectForKey:@"filename"];
}


/**
 * Returns the current theme's CSS for card meaning
 */
- (NSString*) currentThemeCSS
{
  NSDictionary *tm = [self _currentTheme];
  return [tm objectForKey:@"CSS"];
}


/**
 * Returns the current theme's CSS for the example sentences page
 */
- (NSString*) sentencesCSS
{
  return [[self _currentTheme] objectForKey:kLWEThemeSentencesCSSKey];
}


/**
 * Returns the current theme's HTML color for selected text in UIWebKit
 */
- (NSString*) currentThemeWebSelectionColor
{
  NSDictionary* tm = [self _currentTheme];
  return [tm objectForKey:@"WEB_SELECTED"];
}


/**
 * Depending on element type, returns stylized code (this is one stage of a two stage refactor)
 */
- (NSString*) elementWithCurrentTheme:(NSString*)element
{
  return [NSString stringWithFormat:@"/%@theme-cookie-cutters/%@",[self currentThemeFileName],element];
}


//! Provide list of names for all available themes
- (NSArray*) themeNameList
{
  return [self _themeListWithKey:@"name"];
}


//! Single-kanji ja names are read wrongly by VoiceOver (紅 → こう), so give them an explicit reading.
//! The default value keeps cFlash (no Localizable.strings) on the English name.
- (NSString*) accessibilityNameForThemeKey:(NSString*)themeKey
{
  if ([themeKey isEqualToString:SET_THEME_FIRE])
  {
    return NSLocalizedStringWithDefaultValue(@"Fire.accessibility", nil, [NSBundle mainBundle], @"Fire", @"Theme name read by VoiceOver: Fire");
  }
  if ([themeKey isEqualToString:SET_THEME_WATER])
  {
    return NSLocalizedStringWithDefaultValue(@"Water.accessibility", nil, [NSBundle mainBundle], @"Water", @"Theme name read by VoiceOver: Water");
  }
  return nil;
}


//! Provide dictionary-safe key reference names for all available themes
- (NSArray*) themeKeysList
{
  return [self _themeListWithKey:@"key"];
}


- (NSString*) themeKeyAfter:(NSString*)themeKey
{
  NSArray *keys = [self themeKeysList];
  NSUInteger idx = [keys indexOfObject:themeKey];
  if (idx == NSNotFound || idx + 1 >= [keys count])
  {
    return [keys firstObject];
  }
  return [keys objectAtIndex:idx + 1];
}


//! Generalized enumerator that generates array of "key" by each theme, in display order
- (NSArray*) _themeListWithKey:(NSString*)key
{
  NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity:[[self orderedThemes] count]];
  for (NSDictionary *theme in [self orderedThemes])
  {
    [tmpArray addObject:[theme objectForKey:key]];
  }
  return [NSArray arrayWithArray:tmpArray];
}
         
    
//! Dealloc to get rid of themes dictionary
- (void) dealloc
{
  [self setThemes:nil];
  [self setOrderedThemes:nil];
  [super dealloc];
}
@end
