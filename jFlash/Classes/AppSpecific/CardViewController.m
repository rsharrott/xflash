//
//  WordCardViewController.m
//  jFlash
//
//  Created by シャロット ロス on 6/3/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "CardViewController.h"
#import "LWELocalization.h"
#import "UIScrollView+LWEUtilities.h"
#import "LWEDesignTokens.h"
#import "LWEReadingLayout.h"
#if defined(LWE_JFLASH)
#import "JapaneseCard.h"
#endif
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

// Study card (J->E) metrics from the 2026 design refresh
static const CGFloat kLWEHeadwordMaxPointSize = 88.0;
static const CGFloat kLWEHeadwordMinPointSize = 34.0;
static const CGFloat kLWESpeakBtnSize         = 44.0;
static const CGFloat kLWESpeakBtnGap          = 14.0;
static const CGFloat kLWECompactCardHeight    = 420.0; // card areas shorter than this use the compact layout

// Maps iOS system text size category to a CSS font-size string for WKWebView/UIWebView HTML.
static NSString *LWEDynamicTypeCSSFontSize(void)
{
  static NSDictionary *map = nil;
  if (!map) {
    map = [@{
      UIContentSizeCategoryExtraSmall:                            @"13px",
      UIContentSizeCategorySmall:                                 @"14px",
      UIContentSizeCategoryMedium:                                @"15px",
      UIContentSizeCategoryLarge:                                 @"16px",
      UIContentSizeCategoryExtraLarge:                            @"18px",
      UIContentSizeCategoryExtraExtraLarge:                       @"20px",
      UIContentSizeCategoryExtraExtraExtraLarge:                  @"22px",
      UIContentSizeCategoryAccessibilityMedium:                   @"26px",
      UIContentSizeCategoryAccessibilityLarge:                    @"30px",
      UIContentSizeCategoryAccessibilityExtraLarge:               @"34px",
      UIContentSizeCategoryAccessibilityExtraExtraLarge:          @"38px",
      UIContentSizeCategoryAccessibilityExtraExtraExtraLarge:     @"44px",
    } retain];
  }
  NSString *category = [UIApplication sharedApplication].preferredContentSizeCategory;
  return map[category] ?: @"16px";
}

// Scale factor relative to the default (Large) category, used to scale native label font sizes.
static CGFloat LWEDynamicTypeSizeMultiplier(void)
{
  static NSDictionary *map = nil;
  if (!map) {
    map = [@{
      UIContentSizeCategoryExtraSmall:                            @(0.82f),
      UIContentSizeCategorySmall:                                 @(0.88f),
      UIContentSizeCategoryMedium:                                @(0.94f),
      UIContentSizeCategoryLarge:                                 @(1.00f),
      UIContentSizeCategoryExtraLarge:                            @(1.06f),
      UIContentSizeCategoryExtraExtraLarge:                       @(1.12f),
      UIContentSizeCategoryExtraExtraExtraLarge:                  @(1.19f),
      UIContentSizeCategoryAccessibilityMedium:                   @(1.35f),
      UIContentSizeCategoryAccessibilityLarge:                    @(1.53f),
      UIContentSizeCategoryAccessibilityExtraLarge:               @(1.76f),
      UIContentSizeCategoryAccessibilityExtraExtraLarge:          @(1.94f),
      UIContentSizeCategoryAccessibilityExtraExtraExtraLarge:     @(2.35f),
    } retain];
  }
  NSString *category = [UIApplication sharedApplication].preferredContentSizeCategory;
  NSNumber *multiplier = map[category];
  return multiplier ? multiplier.floatValue : 1.0f;
}

#if defined (LWE_CFLASH)
  #import "ChineseCard.h"
  #endif

// Private Methods
//! The "+N readings" pill is 30pt tall; its button extends this far above and below it (44pt hit area).
static const CGFloat kLWEPillHitInset = 7.0;

// Furigana reading row + "Show Reading" toggle (DD furigana spec, option A)
// Reading type: 20pt (15pt floor, 28pt Dynamic Type cap) -- see LWEReadingSizes() in LWEReadingLayout.h
static const CGFloat kLWEReadingLineFactor     = 1.4;  // line box = type size x 1.4 (20pt -> 28pt row)
#if defined(LWE_JFLASH)
static const CGFloat kLWEReadingHeadwordGap    = 6.0;  // reading row bottom -> headword em-box top
static const CGFloat kLWERomajiHeadwordGap     = 8.0;  // headword em-box bottom -> romaji line top
static const CGFloat kLWEMeaningGap            = 14.0; // romaji (or headword) -> the meaning's rule
static const CGFloat kLWEToggleRowOutset       = 8.0;  // the toggle reaches this far above and below the row
#endif
static const CGFloat kLWEToggleMinHeight       = 44.0; // the toggle's hit area
static const CGFloat kLWEReadingPillHeight     = 24.0; // the hidden-state pill
static const CGFloat kLWEReadingPillLabelSize  = 13.0;
static const NSTimeInterval kLWEReadingCrossfade = 0.12;

//! Reading shown/hidden for this run of the app (furigana spec §1, DD review of PR #21): new card views
//! (theme, direction, mode or text-size changes) pick it up; it starts hidden at launch and is never saved.
static BOOL sLWESessionReadingVisible = NO;
static void *kLWEMeaningOffsetContext = &kLWEMeaningOffsetContext;

//! The reading's size, line height and floor for the current text size (spec §7).
static void LWEReadingMetrics(BOOL compact, CGFloat *baseSize, CGFloat *minSize)
{
  LWEReadingSizes(LWEDynamicTypeSizeMultiplier(), compact, baseSize, minSize);
}

//! An SF Symbol drawn to fit a square box (a template image, so it takes the button's ink).  A plain
//! symbol image would be re-sized by the button configuration to match its title.
static UIImage *LWESymbolInBox(NSString *name, CGFloat box, UIImageSymbolWeight weight)
{
  UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:box weight:weight];
  UIImage *symbol = [UIImage systemImageNamed:name withConfiguration:config];
  if (symbol == nil || symbol.size.width <= 0 || symbol.size.height <= 0) return nil;
  CGFloat k = MIN(box / symbol.size.width, box / symbol.size.height);
  CGSize drawn = CGSizeMake(symbol.size.width * k, symbol.size.height * k);
  UIGraphicsImageRenderer *renderer = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(box, box)] autorelease];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [[symbol imageWithTintColor:[UIColor blackColor]] drawInRect:CGRectMake((box - drawn.width) / 2.0, (box - drawn.height) / 2.0, drawn.width, drawn.height)];
  }];
  return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

//! Height of text laid out at width (UILabel metrics)
static CGFloat LWETextHeight(NSAttributedString *text, CGFloat width)
{
  if ([text length] == 0) return 0;
  return ceilf([text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                                  context:nil].size.height);
}

#if defined(LWE_JFLASH)
//! First line's baseline from the top of the text, and that line's height (TextKit, as UILabel lays it out)
static void LWEFirstLineMetrics(NSAttributedString *text, CGFloat width, CGFloat *baseline, CGFloat *lineHeight)
{
  *baseline = 0;
  *lineHeight = 0;
  if ([text length] == 0) return;
  NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *layout = [[NSLayoutManager alloc] init];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(width, CGFLOAT_MAX)];
  container.lineFragmentPadding = 0;
  [layout addTextContainer:container];
  [storage addLayoutManager:layout];
  if ([layout numberOfGlyphs] > 0)
  {
    CGRect fragment = [layout lineFragmentRectForGlyphAtIndex:0 effectiveRange:NULL];
    *baseline = fragment.origin.y + [layout locationForGlyphAtIndex:0].y;
    *lineHeight = fragment.size.height;
  }
  [container release];
  [layout release];
  [storage release];
}
#endif

@interface CardViewController()
- (void) _injectMeaningHTML:(NSString*)html;
- (void) _prepareView:(Card*)card;
- (void) _updateReadingContainer;
//! Hides the toggle when the card has no reading to show, and keeps its VoiceOver label in step
- (void) _updateReadingToggle;
//! Hidden: the "Show Reading" pill.  Shown: no title and no chrome (the button stays over the reading).
- (void) _updateReadingToggleAppearance;
//! Keeps the meaning clear of the score bubble: wraps around its corner, or scrolls with a bottom inset and fade
- (void) _updateMeaningInsets;
- (void) _updateMeaningFade;
#if defined(LWE_CFLASH)
//! Fits the pinyin into the legacy reading row (spec §8)
- (CGFloat) _fitLegacyReading;
@property (nonatomic, retain) NSAttributedString *legacyReadingSource;
#endif

//! Returns YES if the contents of theLabel fit in scrollViewContainer w/o scrolling
- (BOOL) _shouldHideMoreIconForLabel:(UIView *)theLabel forScrollView:(UIScrollView *)scrollViewContainer;

#if defined(LWE_JFLASH)
- (AVSpeechSynthesisVoice *) _bestJapaneseVoice;
- (void) _updateSpeakBtnPosition;
@property (nonatomic, retain) AVSpeechSynthesizer *speechSynthesizer;

// New-style card (J->E only): big headword, reading below it, "+N readings" pill
- (void) _setupModernCard;
- (void) _layoutModernCard;
- (void) _applyReadingText;
- (void) _updateMoreReadingsBtn;
- (void) _toggleMoreReadings:(id)sender;
@property (nonatomic, retain) NSArray *kanaReadings;
@property (nonatomic, retain) NSArray *romajiReadings;
@property (nonatomic, retain) UIButton *moreReadingsBtn;
//! Romaji under the headword (Both mode, and kana-only headwords in Romaji mode)
@property (nonatomic, retain) UILabel *romajiLabel;
//! What the reading row above the headword shows (kana, or romaji in Romaji mode); nil for none
@property (nonatomic, copy) NSString *topReadingText;
#endif
@end

@implementation CardViewController
{
  BOOL _modernCard;
  BOOL _readingsExpanded;
  BOOL _toggleHiddenForNoReading;
  BOOL _topReadingIsLatin;      // the top row holds romaji (Romaji mode), not kana
  BOOL _toggleOnRomajiRow;      // kana-only headword: the toggle sits on the romaji row below it
  CGFloat _lastLayoutWidth;
  CGFloat _lastLayoutHeight;
  LWEMeaningInsets _meaningInsets;
  NSUInteger _meaningMeasureToken;
  BOOL _observingMeaningScroll;
}

+ (BOOL) sessionReadingVisible
{
  return sLWESessionReadingVisible;
}

+ (void) setSessionReadingVisible:(BOOL)visible
{
  sLWESessionReadingVisible = visible;
}

@synthesize delegate;
@synthesize meaningWebViewContainer, headwordMoreIcon, headwordLabel, readingMoreIcon, readingLabel, toggleReadingBtn;
@synthesize readingScrollContainer, headwordScrollContainer, readingVisible = _readingVisible;
@synthesize baseHtml;
@synthesize moodIcon;
#if defined(LWE_JFLASH)
@synthesize speakBtn, speechSynthesizer;
@synthesize kanaReadings, romajiReadings, moreReadingsBtn;
@synthesize romajiLabel, topReadingText;
#endif
#if defined(LWE_CFLASH)
@synthesize legacyReadingSource;
#endif

#pragma mark - Flow Methods

- (void) setupWithCard:(Card*)card
{
  LWE_DELEGATE_CALL(@selector(cardViewWillSetup:),self);
  [self _prepareView:card];
  LWE_DELEGATE_CALL(@selector(cardViewDidSetup:),self);
}

- (void) studyViewModeDidChange:(StudyViewController*)svc
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(cardViewDidChangeMode:)])
  {
    [self.delegate cardViewDidChangeMode:self];
  }
}


/**
 * Default "reveal" behavior is no
 */
- (void) reveal
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(shouldRevealCardView:)])
  {
    BOOL shouldReveal = [self.delegate shouldRevealCardView:self];
    if (shouldReveal)
    {
      LWE_DELEGATE_CALL(@selector(cardViewWillReveal:),self);
      LWE_DELEGATE_CALL(@selector(cardViewDidReveal:),self);
    }
  }
}

#pragma mark - Class Plumbing

- (id) initDisplayMainHeadword:(BOOL)displayMainHeadword
{
  // First get the appropriate NIB name & HTML to display
  NSString *nibName = nil;
  NSString *html = nil;
  if (displayMainHeadword)
  {
    // Main headword, so don't do anything differently.
    html = LWECardHTMLTemplate;
    nibName = @"CardViewController";
  }
  else
  {
    // Prepare the view for displaying in E-to-J mode
    html = LWECardHTMLTemplate_EtoJ;
    nibName = @"CardViewController-EtoJ";
  }
    
  // Now initialize the class with this information
  self = [super initWithNibName:nibName bundle:nil];
  if (self)
  {
    // The reader's show/hide choice from earlier in this session (hidden at launch)
    _readingVisible = sLWESessionReadingVisible;
#if defined(LWE_JFLASH)
    _modernCard = displayMainHeadword;
#endif
    // Replace out the CSS to match the current theme
    NSString *cssHeader = [[ThemeManager sharedThemeManager] currentThemeCSS];
    html = [html stringByReplacingOccurrencesOfString:@"##THEMECSS##" withString:cssHeader];
    
    html = [html stringByReplacingOccurrencesOfString:@"##TEXTSIZE##" withString:LWEDynamicTypeCSSFontSize()];
#if !defined(LWE_JFLASH)
    // Prefer TC glyph forms when the user studies Traditional characters.
    NSString *hwType = [[NSUserDefaults standardUserDefaults] objectForKey:APP_HEADWORD_TYPE];
    if ([hwType isEqualToString:SET_HEADWORD_TYPE_TRAD])
    {
      html = [html stringByReplacingOccurrencesOfString:@"'PingFang SC','PingFang TC'"
                                               withString:@"'PingFang TC','PingFang SC'"];
    }
#endif
    
    self.baseHtml = html;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  // Swap the English XIB text for the current language (Interface.strings)
  LWELocalizeInterface(self.view);

  // Create the WKWebView programmatically inside the XIB-instantiated container.
  // (UIWebView is removed in modern iOS so we no longer instantiate it from the XIB.)
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  _meaningWebView = [[WKWebView alloc] initWithFrame:self.meaningWebViewContainer.bounds
                                       configuration:config];
  [config release];
  _meaningWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  _meaningWebView.navigationDelegate = self;
  _meaningWebView.opaque = NO;
  _meaningWebView.backgroundColor = [UIColor clearColor];
  _meaningWebView.scrollView.backgroundColor = [UIColor clearColor];
  _meaningWebView.scrollView.bounces = NO;
  // cFlash's XIB paints this container ~98% white (master did too). On themed cards that
  // reads as a big opaque slab under the headword; jFlash's XIB is already clear.
  self.meaningWebViewContainer.backgroundColor = [UIColor clearColor];
  self.meaningWebViewContainer.opaque = NO;
  [self.meaningWebViewContainer addSubview:_meaningWebView];
  [_meaningWebView loadHTMLString:self.baseHtml baseURL:nil];
  // Long meanings scroll; the bottom fade follows the scroll position
  [_meaningWebView.scrollView addObserver:self forKeyPath:@"contentOffset" options:0 context:kLWEMeaningOffsetContext];
  _observingMeaningScroll = YES;

  // Add mood icon subview - TODO: MMA this is 90% complete, but I want to find a way to do this in the NIB
  CGRect moodIconRect = CGRectMake(235, 197, 80, 73);
  self.moodIcon.view.frame = moodIconRect;
  self.moodIcon.view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
  [self.view addSubview:self.moodIcon.view];
  [self.moodIcon updateMoodIcon:100.0f];

  // For languages such as Chinese, we may need to configure the font
  self.headwordLabel.font = [Card configureFontForLabel:self.headwordLabel];

#if defined(LWE_JFLASH)
  self.speechSynthesizer = [[[AVSpeechSynthesizer alloc] init] autorelease];

  UIButton *speak = [UIButton buttonWithType:UIButtonTypeSystem];
  UIImage *speakerImg = [UIImage systemImageNamed:@"speaker.wave.2"];
  [speak setImage:speakerImg forState:UIControlStateNormal];
  speak.tintColor = [[ThemeManager sharedThemeManager] colorForSlot:@"speakerInk"];
  speak.accessibilityLabel = NSLocalizedString(@"Speak word", @"CardViewController.SpeakWordAccessibility");
  [speak addTarget:self action:@selector(doSpeakHeadword) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:speak];
  self.speakBtn = speak;

  if (_modernCard)
  {
    [self _setupModernCard];
  }
  else
#endif
  {
    // Older card layouts (E-to-J, Chinese Flash): the XIB's white / yellow labels follow the theme card
    ThemeManager *tm = [ThemeManager sharedThemeManager];
    self.headwordLabel.textColor = [tm colorForSlot:@"headwordInk"];
    self.readingLabel.textColor = [tm colorForSlot:@"readingInk"];
    self.headwordLabel.shadowColor = nil;
    self.readingLabel.shadowColor = nil;
    [self.toggleReadingBtn setTitleColor:[tm colorForSlot:@"toggleInk"] forState:UIControlStateNormal];
    // 13pt semibold, as on the jFlash card (replaces the XIB's Helvetica-Bold 10pt)
    self.toggleReadingBtn.titleLabel.font = [UIFont systemFontOfSize:kLWEReadingPillLabelSize weight:UIFontWeightSemibold];
    // cFlash NIB bakes "Show Reading" into practice-btn-showreading.png. The toggle now stays over the
    // visible reading as its tap-to-hide target (as in the original app), so the image has to go.
    [self.toggleReadingBtn setBackgroundImage:nil forState:UIControlStateNormal];
    [self.toggleReadingBtn setBackgroundImage:nil forState:UIControlStateHighlighted];
    self.toggleReadingBtn.backgroundColor = [UIColor clearColor];
    // The pinyin is fitted in code (spec §8), centred in its row
    self.readingLabel.textAlignment = NSTextAlignmentCenter;
    self.readingLabel.numberOfLines = 0;
    self.readingLabel.lineBreakMode = NSLineBreakByWordWrapping;
  }
  self.toggleReadingBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  self.toggleReadingBtn.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
  if (@available(iOS 15.0, *))
  {
    // Pressed: label and glyph at 60% (the pill itself stays put)
    UIColor *ink = [[ThemeManager sharedThemeManager] colorForSlot:@"toggleInk"];
    self.toggleReadingBtn.configurationUpdateHandler = ^(UIButton *button) {
      UIButtonConfiguration *config = [[button.configuration copy] autorelease];
      if (config == nil) return;
      CGFloat alpha = CGColorGetAlpha(ink.CGColor);
      config.baseForegroundColor = button.isHighlighted ? [ink colorWithAlphaComponent:alpha * 0.6] : ink;
      button.configuration = config;
    };
  }
  // The toggle speaks for the reading row (see -_updateReadingToggle)
  self.readingScrollContainer.accessibilityElementsHidden = YES;
}

#if defined(LWE_JFLASH)
- (void) _setupModernCard
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  // Headword: heavy, in the theme's headword ink (Paper ink-2, Fire yellow, Water white); the size
  // is set per card in -_layoutModernCard.
  self.headwordLabel.textColor = [tm colorForSlot:@"headwordInk"];
  self.headwordLabel.shadowOffset = CGSizeZero;
  self.headwordLabel.shadowColor = nil;
  self.headwordLabel.lineBreakMode = NSLineBreakByCharWrapping;
  self.headwordLabel.numberOfLines = 0;
  self.headwordLabel.autoresizingMask = UIViewAutoresizingNone;
  self.headwordMoreIcon.hidden = YES;

  // Reading: upright (the NIB font was Helvetica Bold Oblique), attributed per card.
  self.readingLabel.numberOfLines = 0;
  self.readingLabel.lineBreakMode = NSLineBreakByWordWrapping;
  self.readingLabel.textAlignment = NSTextAlignmentCenter;
  self.readingLabel.textColor = [tm colorForSlot:@"readingInk"]; // base for non-tone readings
  self.readingLabel.shadowColor = nil;
  self.readingLabel.shadowOffset = CGSizeZero;
  self.readingLabel.autoresizingMask = UIViewAutoresizingNone;
  self.readingMoreIcon.hidden = YES;

  // Toggle: the hidden-state pill is a UIButtonConfiguration (-_updateReadingToggleAppearance)
  self.toggleReadingBtn.titleLabel.font = [UIFont systemFontOfSize:kLWEReadingPillLabelSize weight:UIFontWeightSemibold];
  [self.toggleReadingBtn setTitleColor:[tm colorForSlot:@"toggleInk"] forState:UIControlStateNormal];
  [self.toggleReadingBtn setBackgroundImage:nil forState:UIControlStateNormal];
  [self.toggleReadingBtn setBackgroundImage:nil forState:UIControlStateHighlighted];
  self.toggleReadingBtn.autoresizingMask = UIViewAutoresizingNone;

  // Romaji: its own row under the headword (17pt medium, romajiInk); hidden and shown with the reading
  UILabel *romaji = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
  romaji.backgroundColor = [UIColor clearColor];
  romaji.textAlignment = NSTextAlignmentCenter;
  romaji.numberOfLines = 0;
  romaji.lineBreakMode = NSLineBreakByWordWrapping;
  romaji.userInteractionEnabled = NO;
  romaji.isAccessibilityElement = NO; // the toggle reads it (see -_updateReadingToggle)
  [self.view insertSubview:romaji belowSubview:self.toggleReadingBtn];
  self.romajiLabel = romaji;

  // Speaker: 44pt circle next to the headword (speakerFill / speakerInk)
  UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightMedium];
  [self.speakBtn setImage:[UIImage systemImageNamed:@"speaker.wave.2" withConfiguration:cfg] forState:UIControlStateNormal];
  self.speakBtn.backgroundColor = [tm colorForSlot:@"speakerFill"];
  self.speakBtn.layer.cornerRadius = kLWESpeakBtnSize / 2.0;

  // "+N readings" pill
  UIButton *pill = nil;
  if (@available(iOS 15.0, *))
  {
    // UIButtonConfiguration (replaces the deprecated image/content edge insets): chevron after the text
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    // moreReadingsInk on moreReadingsFill; the visible pill is 30pt tall inside a 44pt-tall hit area.
    config.baseForegroundColor = [tm colorForSlot:@"moreReadingsInk"];
    config.background.backgroundColor = [tm colorForSlot:@"moreReadingsFill"];
    config.background.cornerRadius = 15.0;
    config.background.backgroundInsets = NSDirectionalEdgeInsetsMake(kLWEPillHitInset, 0, kLWEPillHitInset, 0);
    config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    config.imagePlacement = NSDirectionalRectEdgeTrailing;
    config.imagePadding = 5.0;
    config.contentInsets = NSDirectionalEdgeInsetsMake(0, 13, 0, 13);
    config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *incoming) {
      NSMutableDictionary *attrs = [[incoming mutableCopy] autorelease];
      attrs[NSFontAttributeName] = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
      return attrs;
    };
    pill = [UIButton buttonWithConfiguration:config primaryAction:nil];
  }
  else
  {
    pill = [UIButton buttonWithType:UIButtonTypeCustom];
    UIColor *pillInk = [tm colorForSlot:@"moreReadingsInk"];
    pill.backgroundColor = [tm colorForSlot:@"moreReadingsFill"];
    pill.layer.cornerRadius = 15.0;
    pill.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [pill setTitleColor:pillInk forState:UIControlStateNormal];
    [pill setTitleColor:[pillInk colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    pill.tintColor = pillInk;
    pill.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft; // chevron after the text
  }
  pill.hidden = YES;
  [pill addTarget:self action:@selector(_toggleMoreReadings:) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:pill];
  self.moreReadingsBtn = pill;
}

//! Splits "うみ; み; わた" style readings into an array of trimmed, non-empty strings
static NSArray *LWESplitReadings(NSString *readings)
{
  NSMutableArray *result = [NSMutableArray array];
  for (NSString *part in [readings componentsSeparatedByString:@";"])
  {
    NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed length] > 0) [result addObject:trimmed];
  }
  return result;
}

//! The readings with exact duplicates removed, first occurrence kept.
static NSArray *LWEUniqueReadings(NSArray *readings)
{
  NSMutableArray *result = [NSMutableArray array];
  for (NSString *reading in readings)
  {
    if ([result containsObject:reading] == NO) [result addObject:reading];
  }
  return result;
}

//! How many readings are hidden behind the "+N readings" pill for the current reading mode.
static NSInteger LWEExtraReadingCount(NSArray *kana, NSArray *romaji)
{
  NSString *mode = [[NSUserDefaults standardUserDefaults] objectForKey:APP_READING];
  if ([mode isEqualToString:SET_READING_ROMAJI])
  {
    return (NSInteger)[LWEUniqueReadings(romaji) count] - 1;
  }
  if ([mode isEqualToString:SET_READING_KANA])
  {
    return (NSInteger)[kana count] - 1;
  }
  return (NSInteger)MAX([kana count], [romaji count]) - 1;
}

//! The top reading row's text at a given size: Hiragino (via the system font) 20pt regular in
//! readingInk, tracking +0.02em (+0.01em for romaji). lineHeight > 0 fixes the line box (wrapped readings).
- (NSAttributedString *) _topReadingString:(NSString *)text size:(CGFloat)size lineHeight:(CGFloat)lineHeight
{
  if ([text length] == 0) return [[[NSAttributedString alloc] initWithString:@""] autorelease];
  NSMutableParagraphStyle *para = [[[NSMutableParagraphStyle alloc] init] autorelease];
  para.alignment = NSTextAlignmentCenter;
  para.lineBreakMode = NSLineBreakByWordWrapping;
  if (lineHeight > 0)
  {
    para.minimumLineHeight = lineHeight;
    para.maximumLineHeight = lineHeight;
  }
  return [[[NSAttributedString alloc] initWithString:text attributes:@{
    NSFontAttributeName: [UIFont systemFontOfSize:size weight:UIFontWeightRegular],
    NSForegroundColorAttributeName: [[ThemeManager sharedThemeManager] colorForSlot:@"readingInk"],
    NSKernAttributeName: @(size * (_topReadingIsLatin ? 0.01 : 0.02)),
    NSParagraphStyleAttributeName: para,
  }] autorelease];
}

//! Works out what the reading rows say (per APP_READING): kana above the headword, romaji in its
//! own row below it.  -_layoutModernCard fits the top row to the headword (spec §4).
- (void) _applyReadingText
{
  NSString *mode = [[NSUserDefaults standardUserDefaults] objectForKey:APP_READING];
  BOOL showKana = ([mode isEqualToString:SET_READING_ROMAJI] == NO);

  NSArray *kana = self.kanaReadings;
  NSArray *romaji = self.romajiReadings;
  NSString *kanaText = nil;
  NSString *romajiText = nil;
  if (_readingsExpanded)
  {
    // Kana list with the Japanese middle dot; the romaji list with an ASCII comma (a "・" or
    // a Latin "·" between romanised words reads as part of the word).  When only romaji is
    // shown, repeated romanisations (e.g. ひらがな and カタカナ spellings) are listed once.
    kanaText = [kana componentsJoinedByString:@"・"];
    NSArray *romajiList = showKana ? romaji : LWEUniqueReadings(romaji);
    romajiText = [romajiList componentsJoinedByString:@", "];
  }
  else
  {
    kanaText = [kana count] > 0 ? [kana objectAtIndex:0] : nil;
    romajiText = [romaji count] > 0 ? [romaji objectAtIndex:0] : nil;
  }
  // Kana-only headword (e.g. これ, or ありがとう with Prefer Kana): the kana reading would just repeat
  // it, so there is no row above the headword; romaji (if on) stays below it, with the toggle on it.
  // (Romaji mode: romaji is the only reading, so it takes the top row in readingInk.)
  BOOL kanaOnly = LWEReadingIsKanaOnlyHeadword(kanaText, self.headwordLabel.text, [kana count], _readingsExpanded);
  NSDictionary *rows = LWEReadingRows(mode, kanaText, romajiText, kanaOnly);
  NSString *top = [rows objectForKey:LWEReadingRowTopKey];
  NSString *below = [rows objectForKey:LWEReadingRowBelowKey];
  _topReadingIsLatin = [[rows objectForKey:LWEReadingRowTopIsLatinKey] boolValue];
  _toggleOnRomajiRow = [[rows objectForKey:LWEReadingRowToggleOnRomajiKey] boolValue];
  self.topReadingText = top;

  // Base size for now; -_layoutModernCard fits it once the headword's width is known
  CGFloat baseSize = 0, minSize = 0;
  LWEReadingMetrics(self.view.bounds.size.height > 0 && self.view.bounds.size.height < kLWECompactCardHeight, &baseSize, &minSize);
  self.readingLabel.attributedText = [self _topReadingString:top size:baseSize lineHeight:0];

  if ([below length] > 0)
  {
    CGFloat dt = LWEReadingTypeScale(LWEDynamicTypeSizeMultiplier(),
                                     self.view.bounds.size.height > 0 && self.view.bounds.size.height < kLWECompactCardHeight);
    CGFloat romajiSize = 17.0 * dt;
    NSMutableParagraphStyle *para = [[[NSMutableParagraphStyle alloc] init] autorelease];
    para.alignment = NSTextAlignmentCenter;
    para.lineBreakMode = NSLineBreakByWordWrapping;
    para.minimumLineHeight = roundf(romajiSize * 22.0 / 17.0);
    para.maximumLineHeight = para.minimumLineHeight;
    self.romajiLabel.attributedText = [[[NSAttributedString alloc] initWithString:below attributes:@{
      NSFontAttributeName: [UIFont systemFontOfSize:romajiSize weight:UIFontWeightMedium],
      NSForegroundColorAttributeName: [[ThemeManager sharedThemeManager] colorForSlot:@"romajiInk"],
      NSKernAttributeName: @(0.2),
      NSParagraphStyleAttributeName: para,
    }] autorelease];
  }
  else
  {
    self.romajiLabel.attributedText = nil;
  }
  [self _updateMoreReadingsBtn];
}

- (void) _updateMoreReadingsBtn
{
  NSInteger extra = LWEExtraReadingCount(self.kanaReadings, self.romajiReadings);
  BOOL readingShowing = (self.readingScrollContainer.hidden == NO);
  self.moreReadingsBtn.hidden = (extra <= 0 || readingShowing == NO);
  if (extra <= 0) return;

  NSString *title = nil;
  NSString *symbol = nil;
  if (_readingsExpanded)
  {
    title = NSLocalizedString(@"Fewer readings", @"CardViewController.FewerReadings");
    symbol = @"chevron.up";
  }
  else if (extra == 1)
  {
    title = NSLocalizedString(@"+1 reading", @"CardViewController.OneMoreReading");
    symbol = @"chevron.down";
  }
  else
  {
    title = [NSString stringWithFormat:NSLocalizedString(@"+%d readings", @"CardViewController.NMoreReadings"), (int)extra];
    symbol = @"chevron.down";
  }
  UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold];
  UIImage *chevron = [UIImage systemImageNamed:symbol withConfiguration:cfg];
  BOOL configured = NO;
  if (@available(iOS 15.0, *))
  {
    UIButtonConfiguration *config = [[self.moreReadingsBtn.configuration copy] autorelease];
    if (config)
    {
      config.title = title;
      config.image = chevron;
      self.moreReadingsBtn.configuration = config;
      configured = YES;
    }
  }
  if (configured == NO)
  {
    [self.moreReadingsBtn setImage:chevron forState:UIControlStateNormal];
    [self.moreReadingsBtn setTitle:title forState:UIControlStateNormal];
  }
  self.moreReadingsBtn.accessibilityLabel = _readingsExpanded
    ? NSLocalizedString(@"Show fewer readings", @"CardViewController.FewerReadingsAccessibility")
    : [NSString stringWithFormat:NSLocalizedString(@"Show %d more readings", @"CardViewController.MoreReadingsAccessibility"), (int)extra];
}

- (void) _toggleMoreReadings:(id)sender
{
  _readingsExpanded = !_readingsExpanded;
  [self _applyReadingText];
  [self _layoutModernCard];
}

- (void) _layoutModernCard
{
  CGFloat w = self.view.bounds.size.width;
  CGFloat h = self.view.bounds.size.height;
  if (w <= 0 || h <= 0) return;

  CGFloat hPad = 24.0;
  CGFloat contentW = w - 2.0 * hPad;
  CGFloat dt = MIN(LWEDynamicTypeSizeMultiplier(), 1.2f);
  // Short card: scale the headword with the available height (not below 48pt) and tighten the
  // spacing, so reading, pill and meaning still fit above the answer bar.
  BOOL compact = (h < kLWECompactCardHeight);
  CGFloat compactScale = compact ? MAX(0.55f, h / kLWECompactCardHeight) : 1.0f;

  // Re-flow the reading when the width or height changed (the reading size depends on both).
  if (fabs(w - _lastLayoutWidth) > 0.5 || fabs(h - _lastLayoutHeight) > 0.5)
  {
    _lastLayoutWidth = w;
    _lastLayoutHeight = h;
    [self _applyReadingText];
  }

  // ---- Headword font: ~88pt, scaled down to fit one line beside the speaker; wraps only if
  // it would otherwise be smaller than the minimum.
  NSString *headword = self.headwordLabel.text ?: @"";
  CGFloat textAvailW = contentW - 2.0 * (kLWESpeakBtnSize + kLWESpeakBtnGap);
  CGFloat size = floorf(MAX(compact ? 48.0f : 0.0f, kLWEHeadwordMaxPointSize * dt * compactScale));
  UIFont *font = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
  CGFloat oneLineW = [headword sizeWithAttributes:@{NSFontAttributeName: font}].width;
  if (oneLineW > textAvailW && oneLineW > 0)
  {
    size = MAX(kLWEHeadwordMinPointSize, floorf(size * textAvailW / oneLineW));
    font = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
    oneLineW = [headword sizeWithAttributes:@{NSFontAttributeName: font}].width;
  }
  CGFloat headwordInkW = MIN(oneLineW, textAvailW);

  // ---- Reading row above the headword (spec §2, §4): 20pt on a 28pt line, one line over the
  // whole word.  Too wide for max(headword + 24, 120): shrink to 15pt, then 2 balanced lines.
  CGFloat rowY = compact ? MAX(8.0, roundf(h * 0.06)) : MAX(12.0, roundf(h * 0.117));
  CGFloat rowH = 0;
  CGFloat baseSize = 0, minSize = 0;
  LWEReadingMetrics(compact, &baseSize, &minSize);
  NSString *top = self.topReadingText;
  if ([top length] > 0)
  {
    CGFloat maxW = LWEReadingMaxWidth(headwordInkW, _topReadingIsLatin, contentW);
    LWEReadingFit fit = LWEReadingFitToWidth(^CGFloat(CGFloat s) {
      return [[self _topReadingString:top size:s lineHeight:0] size].width;
    }, baseSize, minSize, maxW);
    CGFloat lineH = roundf(fit.size * kLWEReadingLineFactor);
    NSAttributedString *text = nil;
    CGFloat labelW = fit.width;
    if (fit.lines == 1)
    {
      text = [self _topReadingString:top size:fit.size lineHeight:0];
      rowH = roundf(baseSize * kLWEReadingLineFactor);
    }
    else
    {
      text = [self _topReadingString:top size:fit.size lineHeight:lineH];
      CGFloat full = ceilf([[self _topReadingString:top size:fit.size lineHeight:0] size].width);
      if (_topReadingIsLatin)
      {
        // Romaji wraps at spaces only, into two even lines
        NSAttributedString *split = LWEReadingBalancedSplitAtSpace(text);
        if (split) text = split;
        labelW = MIN(contentW, MAX(maxW, ceilf([text size].width)));
      }
      else
      {
        // Balanced: about half the reading per line, plus one glyph
        labelW = LWEReadingBalancedWrapWidth(full, fit.size, maxW);
      }
      NSInteger lines = MAX(1, (NSInteger)lroundf(LWETextHeight(text, labelW) / lineH));
      // Two lines grow the row (the headword block moves down); past two, the row scrolls.
      rowH = MAX(roundf(baseSize * kLWEReadingLineFactor), lineH * MIN(lines, 2));
    }
    self.readingLabel.attributedText = text;
    CGFloat labelH = MAX(LWETextHeight(text, labelW), 1.0);
    // The label is centred on the row; a reading taller than two lines scrolls inside it.
    BOOL scrolls = (labelH > rowH + 0.5 * lineH);
    CGFloat containerH = scrolls ? rowH : MAX(labelH, rowH);
    CGFloat containerY = rowY + roundf((rowH - containerH) / 2.0);
    self.readingScrollContainer.frame = CGRectMake(hPad, containerY, contentW, containerH);
    self.readingLabel.frame = CGRectMake(roundf((contentW - labelW) / 2.0), scrolls ? 0 : roundf((containerH - labelH) / 2.0), labelW, labelH);
    self.readingScrollContainer.contentSize = CGSizeMake(contentW, MAX(labelH, containerH));
  }
  else
  {
    self.readingLabel.attributedText = nil;
    self.readingScrollContainer.frame = CGRectMake(hPad, rowY, contentW, 0);
    self.readingScrollContainer.contentSize = CGSizeZero;
  }
  self.readingScrollContainer.contentOffset = CGPointZero;
  self.readingMoreIcon.hidden = YES;

  // ---- Headword: em-box top 6pt under the reading row (or at the row's slot when there is none).
  // Hiragino's em box is baseline - 0.88em ... baseline + 0.12em.
  CGFloat emTop = (rowH > 0) ? rowY + rowH + kLWEReadingHeadwordGap : rowY;
  self.headwordLabel.font = font;
  NSAttributedString *hwText = [[[NSAttributedString alloc] initWithString:headword attributes:@{NSFontAttributeName: font}] autorelease];
  CGFloat hwH = MAX(LWETextHeight(hwText, textAvailW), ceilf(font.lineHeight));
  CGFloat firstBaseline = 0, firstLineH = 0;
  LWEFirstLineMetrics(hwText, textAvailW, &firstBaseline, &firstLineH);
  if (firstLineH <= 0) { firstBaseline = font.ascender; firstLineH = font.lineHeight; }
  // A label taller than its text centres it: account for that offset
  CGFloat textH = LWETextHeight(hwText, textAvailW);
  CGFloat centringOffset = MAX(0, (hwH - textH) / 2.0);
  CGFloat headwordY = roundf(emTop + 0.88 * size - firstBaseline - centringOffset);
  CGFloat maxHwH = roundf(h * 0.36);
  CGFloat containerH = MIN(hwH, maxHwH);
  self.headwordScrollContainer.frame = CGRectMake(hPad, headwordY, contentW, containerH);
  self.headwordLabel.frame = CGRectMake(roundf((contentW - textAvailW) / 2.0), 0, textAvailW, hwH);
  self.headwordScrollContainer.contentSize = CGSizeMake(contentW, hwH);
  self.headwordScrollContainer.contentOffset = CGPointZero;
  self.headwordMoreIcon.hidden = YES;
  [self _updateSpeakBtnPosition];
  // Em-box bottom of the last visible headword line
  CGFloat lastBaseline = headwordY + centringOffset + firstBaseline + MAX(0, textH - firstLineH);
  CGFloat emBottom = MIN(lastBaseline + 0.12 * size, headwordY + containerH);

  // ---- Romaji: its own row, 8pt under the headword's em box (kept, blank, while the reading is hidden)
  CGFloat bottom = emBottom;
  if ([self.romajiLabel.attributedText length] > 0)
  {
    CGFloat romajiH = MAX(22.0, LWETextHeight(self.romajiLabel.attributedText, contentW));
    self.romajiLabel.frame = CGRectMake(hPad, roundf(emBottom + kLWERomajiHeadwordGap), contentW, romajiH);
    bottom = CGRectGetMaxY(self.romajiLabel.frame);
  }
  else
  {
    self.romajiLabel.frame = CGRectMake(hPad, roundf(emBottom), contentW, 0);
  }

  // ---- Toggle: content width x 44pt (or the row + 16pt), centred on the reading row; for a
  // kana-only headword it sits on the romaji row instead.
  if (_toggleOnRomajiRow)
  {
    CGRect romajiRow = self.romajiLabel.frame;
    CGFloat btnH = MAX(kLWEToggleMinHeight, romajiRow.size.height + 2.0 * kLWEToggleRowOutset);
    self.toggleReadingBtn.frame = CGRectMake(hPad, roundf(CGRectGetMidY(romajiRow) - btnH / 2.0), contentW, btnH);
  }
  else
  {
    CGFloat row = MAX(rowH, roundf(baseSize * kLWEReadingLineFactor));
    CGFloat btnH = MAX(kLWEToggleMinHeight, row + 2.0 * kLWEToggleRowOutset);
    self.toggleReadingBtn.frame = CGRectMake(hPad, roundf(rowY + row / 2.0 - btnH / 2.0), contentW, btnH);
  }

  NSInteger extra = LWEExtraReadingCount(self.kanaReadings, self.romajiReadings);
  if (extra > 0)
  {
    CGSize pillSize = [self.moreReadingsBtn sizeThatFits:CGSizeMake(contentW, 30)];
    CGFloat pillW = MIN(contentW, ceilf(pillSize.width));
    // 44pt-tall button around the 30pt pill (iOS 15+ draws the pill inset); the layout uses the visible pill.
    CGFloat inset = 0.0;
    if (@available(iOS 15.0, *)) { if (self.moreReadingsBtn.configuration != nil) inset = kLWEPillHitInset; }
    self.moreReadingsBtn.frame = CGRectMake(roundf((w - pillW) / 2.0), bottom + (compact ? 6.0 : 12.0) - inset, pillW, 30.0 + 2.0 * inset);
    bottom = CGRectGetMaxY(self.moreReadingsBtn.frame) - inset;
  }

  // ---- Meaning: a short rule, then the meaning (both drawn by the HTML template)
  CGFloat webY = roundf(bottom + (compact ? 10.0 : kLWEMeaningGap));
  CGFloat webH = MAX(60.0, h - webY - 8.0);
  self.meaningWebViewContainer.frame = CGRectMake(hPad, webY, contentW, webH);
  [self _updateMeaningInsets];
  [self _updateReadingToggleAppearance];
}
#endif

#pragma mark - Layout

- (void)layoutCardSubviews
{
#if defined(LWE_JFLASH)
  if (_modernCard)
  {
    [self _layoutModernCard];
    return;
  }
#endif
  CGFloat w = self.view.bounds.size.width;
  CGFloat h = self.view.bounds.size.height;
  if (w <= 0 || h <= 0) return;

  CGFloat hPad = 10.0;
  CGFloat contentW = w - 2.0 * hPad;

  // Reading row at ~25% from top of card area so it lands near 30% of screen height.
  CGFloat readingY = MAX(20.0, roundf(h * 0.25));
  CGFloat readingH = LWELegacyReadingRowHeight;
#if defined(LWE_CFLASH)
  // Fit the pinyin to the row's width first, then grow the row to the fitted text (two wrapped
  // lines at a large text size need ~58pt, so they'd scroll in a 42pt row)
  self.readingScrollContainer.frame = CGRectMake(hPad, readingY, contentW, readingH);
  readingH = LWELegacyReadingRowHeightFor([self _fitLegacyReading]);
#endif
  self.readingScrollContainer.frame = CGRectMake(hPad, readingY, contentW, readingH);
  self.readingMoreIcon.frame = CGRectMake(2.0, readingY + readingH - 17.0, 26.0, 17.0);
  // Toggle overlays the full reading row, grown to a 44pt hit area (1pt above and below the 42pt
  // row); positioned above the reveal-button zone so it intercepts taps without revealing.
  CGFloat toggleH = MAX(kLWEToggleMinHeight, readingH);
  self.toggleReadingBtn.frame = CGRectMake(hPad, readingY - roundf((toggleH - readingH) / 2.0), contentW, toggleH);

  // Headword immediately below reading.
  CGFloat headwordY = readingY + readingH + 4.0;
  CGFloat headwordH = 55.0;
  self.headwordScrollContainer.frame = CGRectMake(hPad, headwordY, contentW, headwordH);
  self.headwordMoreIcon.frame = CGRectMake(2.0, headwordY + headwordH - 17.0, 26.0, 17.0);
#if defined(LWE_JFLASH)
  [self _updateSpeakBtnPosition];
#endif

  // Meaning webview fills everything below the headword, giving it full space to the bottom.
  CGFloat webY = headwordY + headwordH + 8.0;
  CGFloat webH = MAX(60.0, h - webY - 8.0);
  self.meaningWebViewContainer.frame = CGRectMake(hPad, webY, contentW, webH);
#if defined(LWE_CFLASH)
  // Centre the fitted pinyin in the (possibly grown) row
  [self.readingScrollContainer resizeScrollViewWithContentView:self.readingLabel];
  [self _updateReadingContainer];
#endif
  [self _updateMeaningInsets];
  [self _updateReadingToggleAppearance];
}

#if defined(LWE_CFLASH)
- (CGFloat) _fitLegacyReading
{
  NSAttributedString *source = self.legacyReadingSource;
  CGRect row = self.readingScrollContainer.frame;
  if ([source length] == 0 || row.size.width <= 0) return 0;

  // Spec §8: 20pt regular pinyin, max width max(headword + 48, 160); shrink in 0.5pt steps to 15pt,
  // then 2 balanced lines at 15pt (21pt lines = the 42pt row), breaking at syllable spaces only.
  NSString *headword = self.headwordLabel.text ?: @"";
  CGFloat headwordInkW = MIN([headword sizeWithAttributes:@{NSFontAttributeName: self.headwordLabel.font}].width,
                             self.headwordScrollContainer.frame.size.width);
  CGFloat maxW = LWEReadingMaxWidth(headwordInkW, YES, row.size.width);
  CGFloat baseSize = 0, minSize = 0;
  LWEReadingMetrics(NO, &baseSize, &minSize);
  NSAttributedString *(^build)(CGFloat, CGFloat) = ^NSAttributedString *(CGFloat size, CGFloat lineHeight) {
    NSMutableAttributedString *text = [[source mutableCopy] autorelease];
    NSRange all = NSMakeRange(0, [text length]);
    [text addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:size weight:UIFontWeightRegular] range:all];
    NSMutableParagraphStyle *para = [[[NSMutableParagraphStyle alloc] init] autorelease];
    para.alignment = NSTextAlignmentCenter;
    para.lineBreakMode = NSLineBreakByWordWrapping;
    if (lineHeight > 0)
    {
      para.minimumLineHeight = lineHeight;
      para.maximumLineHeight = lineHeight;
    }
    [text addAttribute:NSParagraphStyleAttributeName value:para range:all];
    return text;
  };
  LWEReadingFit fit = LWEReadingFitToWidth(^CGFloat(CGFloat size) { return [build(size, 0) size].width; }, baseSize, minSize, maxW);
  NSAttributedString *text = nil;
  CGFloat labelW = fit.width;
  if (fit.lines == 1)
  {
    text = build(fit.size, 0);
  }
  else
  {
    text = build(fit.size, roundf(fit.size * kLWEReadingLineFactor));
    NSAttributedString *split = LWEReadingBalancedSplitAtSpace(text);
    if (split) text = split;
    labelW = MIN(row.size.width, MAX(maxW, ceilf([text size].width)));
  }
  self.readingLabel.attributedText = text;
  CGFloat labelH = MAX(1.0, LWETextHeight(text, labelW));
  self.readingLabel.frame = CGRectMake(roundf((row.size.width - labelW) / 2.0), 0, labelW, labelH);
  // Centres the label in the row (the layout grows the row to labelH)
  [self.readingScrollContainer resizeScrollViewWithContentView:self.readingLabel];
  [self _updateReadingContainer];
  return labelH;
}
#endif

- (CGFloat) revealAreaTop
{
  CGFloat top = CGRectGetMaxY(self.headwordScrollContainer.frame);
#if defined(LWE_JFLASH)
  if (_modernCard)
  {
    // The reading row (and its toggle) sit above the headword now: the zone starts under the
    // headword, the romaji row and the "+N readings" pill -- or under the toggle when a kana-only
    // headword puts it on the romaji row.
    if ([self.romajiLabel.attributedText length] > 0) top = MAX(top, CGRectGetMaxY(self.romajiLabel.frame));
    if (self.toggleReadingBtn.hidden == NO) top = MAX(top, CGRectGetMaxY(self.toggleReadingBtn.frame));
    if (self.moreReadingsBtn && self.moreReadingsBtn.hidden == NO)
    {
      top = MAX(top, CGRectGetMaxY(self.moreReadingsBtn.frame));
    }
    return top + 4.0;
  }
#endif
  top = MAX(top, CGRectGetMaxY(self.toggleReadingBtn.frame));
  return top + 4.0;
}

#pragma mark - IBAction Methods

#if defined(LWE_JFLASH)

- (void)_updateSpeakBtnPosition
{
  CGRect container = self.headwordScrollContainer.frame;
  if (container.size.width <= 0 || self.headwordLabel.text.length == 0) return;

  if (_modernCard)
  {
    // 44pt circle, 14pt to the right of the (centred) headword's last line
    CGRect labelFrame = self.headwordLabel.frame;
    CGSize textSize = [self.headwordLabel.text sizeWithAttributes:@{NSFontAttributeName: self.headwordLabel.font}];
    CGFloat textW = MIN(textSize.width, labelFrame.size.width);
    CGFloat centerX = container.origin.x + CGRectGetMidX(labelFrame);
    CGFloat maxX = self.view.bounds.size.width - 4.0;
    CGFloat x = MIN(roundf(centerX + textW / 2.0 + kLWESpeakBtnGap), maxX - kLWESpeakBtnSize);
    CGFloat lineH = MIN(container.size.height, self.headwordLabel.font.lineHeight);
    CGFloat y = container.origin.y + roundf((lineH - kLWESpeakBtnSize) / 2.0);
    self.speakBtn.frame = CGRectMake(x, y, kLWESpeakBtnSize, kLWESpeakBtnSize);
    return;
  }

  // Text is center-aligned in the label; compute the visual right edge from intrinsic text width.
  CGSize textSize = [self.headwordLabel.text sizeWithAttributes:
                     @{NSFontAttributeName: self.headwordLabel.font}];
  CGFloat textWidth = MIN(textSize.width, container.size.width);
  CGFloat containerCenterX = container.origin.x + container.size.width / 2.0;
  CGFloat textRightEdge = containerCenterX + textWidth / 2.0;

  CGFloat btnSize = 36.0;
  CGFloat maxX = self.view.bounds.size.width - 2.0;
  CGFloat speakX = MIN(textRightEdge + 6.0, maxX - btnSize);
  CGFloat speakY = container.origin.y + roundf((container.size.height - btnSize) / 2.0);
  self.speakBtn.frame = CGRectMake(speakX, speakY, btnSize, btnSize);
}

- (AVSpeechSynthesisVoice *)_bestJapaneseVoice
{
  AVSpeechSynthesisVoice *enhanced = nil;
  for (AVSpeechSynthesisVoice *v in [AVSpeechSynthesisVoice speechVoices]) {
    if (![v.language isEqualToString:@"ja-JP"]) continue;
    if (@available(iOS 16.0, *)) {
      if (v.quality == AVSpeechSynthesisVoiceQualityPremium) return v;
    }
    if (v.quality == AVSpeechSynthesisVoiceQualityEnhanced) enhanced = v;
  }
  return enhanced ?: [AVSpeechSynthesisVoice voiceWithLanguage:@"ja-JP"];
}

- (IBAction)doSpeakHeadword
{
  // Reading label text is "kana - romaji"; speak only the kana part.
  NSString *reading = self.readingLabel.text;
  NSString *text = [[reading componentsSeparatedByString:@" - "] firstObject];
  if (_modernCard)
  {
    // New card: the first kana reading (fall back to the headword itself)
    text = ([self.kanaReadings count] > 0) ? [self.kanaReadings objectAtIndex:0] : self.headwordLabel.text;
  }
  if (text.length == 0) return;

  [self.speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];

  AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
  utterance.voice = [self _bestJapaneseVoice];
  utterance.rate = 0.4f;
  [self.speechSynthesizer speakUtterance:utterance];
}

#endif

/**
 * If the reading scroll container is hidden, this shows it.
 * If it's showing, it hides it.
 */
- (IBAction) doToggleReadingBtn
{
  BOOL show = (self.readingScrollContainer.hidden == YES);
  void (^change)(void) = ^{
    if (show)
    {
      [self turnReadingOn];
      self.readingVisible = YES;
    }
    else
    {
      [self turnReadingOff];
      self.readingVisible = NO;
    }
    // The reader's choice holds for the rest of the session, on new card views too
    sLWESessionReadingVisible = show;
  };
  // 120ms crossfade between the pill and the reading (both states are the same height, so
  // nothing moves); instant under Reduce Motion.
  if (UIAccessibilityIsReduceMotionEnabled() || self.view.window == nil)
  {
    change();
  }
  else
  {
    [UIView transitionWithView:self.view
                      duration:kLWEReadingCrossfade
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                    animations:change
                    completion:nil];
  }
  // VoiceOver: the focused toggle now reads the reading (or "Show Reading"); say it right away
  UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.toggleReadingBtn);
}

#pragma mark - Public Helper Methods

- (void) turnReadingOn
{
  // Change state.  As in the original app, the (now blank) toggle stays over the reading row, so
  // tapping the reading hides it again (#13 had hidden the toggle here, which removed that).
  self.readingScrollContainer.hidden = NO;
#if defined(LWE_JFLASH)
  self.romajiLabel.hidden = NO;
#endif
  [self.toggleReadingBtn setTitle:@"" forState:UIControlStateNormal];
  // Relayout so the reading row (sized while hidden) gets a real frame on screen.
  [self layoutCardSubviews];
  
  // This will handle the "more" icon after the state change
  [self _updateReadingContainer];
#if defined(LWE_JFLASH)
  if (_modernCard) [self _updateMoreReadingsBtn];
#endif
  [self _updateReadingToggle];
}

- (void) turnReadingOff
{
  // This will handle the "more" icon
  [self _updateReadingContainer];
  
  self.readingScrollContainer.hidden = YES;
#if defined(LWE_JFLASH)
  // The romaji row is kept (blank) so the meaning doesn't jump
  self.romajiLabel.hidden = YES;
#endif
  self.toggleReadingBtn.hidden = NO;
  [self.toggleReadingBtn setTitle:NSLocalizedString(@"Show Reading", @"CardViewController.ShowReading") forState:UIControlStateNormal];

  // This will handle the "more" icon after the state change
  [self _updateReadingContainer];
#if defined(LWE_JFLASH)
  if (_modernCard) [self _updateMoreReadingsBtn];
#endif
  [self _updateReadingToggle];
}

//! shows or hides the reading label and toggleButton according to the readingVisible bool
- (void) resetReadingVisibility 
{
  if (self.readingVisible == NO)
  {
    [self turnReadingOff];
  }
  else
  {
    [self turnReadingOn];
  }
}

#pragma mark - Private Methods

- (void) _updateReadingToggle
{
  NSString *reading = self.readingLabel.attributedText.string ?: self.readingLabel.text;
#if defined(LWE_JFLASH)
  // Kana, then romaji (its own row under the headword)
  NSString *romajiText = self.romajiLabel.attributedText.string;
  if ([romajiText length] > 0)
  {
    reading = ([reading length] > 0) ? [NSString stringWithFormat:@"%@\n%@", reading, romajiText] : romajiText;
  }
#endif
  reading = [reading stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([reading length] == 0)
  {
    // Nothing to show (e.g. a kana-only word in kana mode): no "Show Reading" button either.
    // Only undo this hide ourselves, so the E-to-J delegate's own hide is left alone.
    if (self.toggleReadingBtn.hidden == NO) _toggleHiddenForNoReading = YES;
    self.toggleReadingBtn.hidden = YES;
    return;
  }
  if (_toggleHiddenForNoReading)
  {
    _toggleHiddenForNoReading = NO;
    self.toggleReadingBtn.hidden = NO;
  }

  if (self.readingScrollContainer.hidden)
  {
    self.toggleReadingBtn.accessibilityLabel = NSLocalizedString(@"Show Reading", @"CardViewController.ShowReading");
    self.toggleReadingBtn.accessibilityHint = nil;
  }
  else
  {
    // Reading visible: the button over it reads the reading, and says what a double-tap does
    // Spoken from the unwrapped text: a pause between the reading and romaji rows only
    NSString *spokenTop = self.readingLabel.attributedText.string ?: self.readingLabel.text;
    NSString *spokenBelow = nil;
#if defined(LWE_JFLASH)
    if (_modernCard)
    {
      spokenTop = self.topReadingText;
      spokenBelow = self.romajiLabel.attributedText.string;
    }
#elif defined(LWE_CFLASH)
    if ([self.legacyReadingSource length] > 0) spokenTop = [self.legacyReadingSource string];
#endif
    self.toggleReadingBtn.accessibilityLabel = LWEReadingSpokenLabel(spokenTop, spokenBelow);
    self.toggleReadingBtn.accessibilityHint = NSLocalizedString(@"Hides the reading", @"CardViewController.HideReadingAccessibilityHint");
  }
  // When the toggle is off screen (E-to-J after reveal), VoiceOver reads the reading row itself
  self.readingScrollContainer.accessibilityElementsHidden = (self.toggleReadingBtn.hidden == NO);
#if defined(LWE_JFLASH)
  self.romajiLabel.isAccessibilityElement = (self.toggleReadingBtn.hidden && self.romajiLabel.hidden == NO);
#endif
  [self _updateReadingToggleAppearance];
}

- (void) _updateReadingToggleAppearance
{
  UIButton *button = self.toggleReadingBtn;
  if (button == nil) return;
  BOOL readingHidden = self.readingScrollContainer.hidden;
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  if (@available(iOS 15.0, *))
  {
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.background.backgroundColor = [UIColor clearColor];
    config.contentInsets = NSDirectionalEdgeInsetsZero;
    if (readingHidden)
    {
      // 24pt pill (readingToggleFill), eye.slash 15pt semibold, 5pt gap, 13pt semibold label in
      // toggleInk; centred in the 44pt button and as wide as its content.
      // Same Dynamic Type rule as the reading (1.4x cap: 13 -> 18pt)
      CGFloat labelSize = roundf(kLWEReadingPillLabelSize * LWEReadingTypeScale(LWEDynamicTypeSizeMultiplier(), NO));
      CGFloat pillH = MAX(kLWEReadingPillHeight, roundf(labelSize * 1.85));
      CGFloat glyphSize = roundf(15.0 * labelSize / kLWEReadingPillLabelSize);
      NSString *title = NSLocalizedString(@"Show Reading", @"CardViewController.ShowReading");
      UIFont *labelFont = [UIFont systemFontOfSize:labelSize weight:UIFontWeightSemibold];
      // EN tracking 0.1; Japanese (Hiragino W6 via the system font) has none
      BOOL latinTitle = ([title canBeConvertedToEncoding:NSASCIIStringEncoding]);
      NSNumber *kern = @(latinTitle ? 0.1 : 0.0);
      UIImage *glyph = LWESymbolInBox(@"eye.slash", glyphSize, UIImageSymbolWeightSemibold);
      config.title = title;
      config.image = glyph;
      config.imagePlacement = NSDirectionalRectEdgeLeading;
      config.imagePadding = 5.0;
      config.contentInsets = NSDirectionalEdgeInsetsMake(0, 9, 0, 11);
      config.baseForegroundColor = [tm colorForSlot:@"toggleInk"];
      config.titleLineBreakMode = NSLineBreakByTruncatingTail;
      config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *incoming) {
        NSMutableDictionary *attrs = [[incoming mutableCopy] autorelease];
        attrs[NSFontAttributeName] = labelFont;
        attrs[NSKernAttributeName] = kern;
        return attrs;
      };
      CGFloat titleW = ceilf([title sizeWithAttributes:@{NSFontAttributeName: labelFont, NSKernAttributeName: kern}].width);
      CGFloat pillW = ceilf(9.0 + glyph.size.width + 5.0 + titleW + 11.0);
      CGSize bounds = button.bounds.size;
      CGFloat vInset = MAX(0, roundf((bounds.height - pillH) / 2.0));
      CGFloat hInset = MAX(0, floorf((bounds.width - pillW) / 2.0));
      config.background.backgroundColor = [tm colorForSlot:@"readingToggleFill"];
      config.background.cornerRadius = pillH / 2.0;
      config.background.backgroundInsets = NSDirectionalEdgeInsetsMake(vInset, hInset, vInset, hInset);
      config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    }
    // Shown: no title, no image, no background -- but the button stays over the reading, tappable
    button.configuration = config;
    [button setNeedsUpdateConfiguration];
  }
}

// Toggle "more" icon to indicate the user can scroll meaning down
- (BOOL) _shouldHideMoreIconForLabel:(UILabel *)theLabel forScrollView:(UIScrollView *)scrollViewContainer 
{
  return (theLabel.frame.size.height <= scrollViewContainer.frame.size.height);
}

// Prepare the view for the current card
- (void) _prepareView:(Card*)card
{
  // Reset the meaning's scroll view location.
  _meaningWebView.scrollView.contentOffset = CGPointZero;
  
  // Fix up the headword & the meaning; those are a bit easier.
  [self _injectMeaningHTML:card.meaning];
  self.headwordLabel.text = card.headword;
  
  // Now do the hard part (for CFlash)
#if defined(LWE_JFLASH)
  if (_modernCard)
  {
    // First reading only (kana, and romaji muted underneath); the rest sit behind "+N readings".
    self.kanaReadings = LWESplitReadings(card.hw_reading);
    NSString *romaji = [card isKindOfClass:[JapaneseCard class]] ? [(JapaneseCard *)card romaji] : nil;
    self.romajiReadings = LWESplitReadings(romaji);
    _readingsExpanded = NO;
    _lastLayoutWidth = self.view.bounds.size.width;
    _lastLayoutHeight = self.view.bounds.size.height;
    [self _applyReadingText];
    [self _layoutModernCard];
    [self _updateReadingToggle];
    return;
  }
  self.readingLabel.text = card.reading;
#elif defined(LWE_CFLASH)
  self.legacyReadingSource = [card attributedReading];
  self.readingLabel.attributedText = self.legacyReadingSource;
#endif
  // These calls re-size the reading & headword labels.  They used to take the scrollContainer as well,
  // but we infer it (superview) of the labels inside this call.
  CGFloat dtScale = LWEDynamicTypeSizeMultiplier();
#if defined(LWE_JFLASH)
  [self.readingLabel resizeWithMinFontSize:(NSInteger)(READING_MIN_FONTSIZE * dtScale) maxFontSize:(NSInteger)(READING_MAX_FONTSIZE * dtScale)];
#endif
  [self.headwordLabel resizeWithMinFontSize:(NSInteger)(HEADWORD_MIN_FONTSIZE * dtScale) maxFontSize:(NSInteger)(HEADWORD_MAX_FONTSIZE * dtScale)];
  
  // Now resize the scroll views as necessary based on the resized views above, if necessary.
  // This call also centers the label inside the scroll view.
#if defined(LWE_JFLASH)
  [self.readingScrollContainer resizeScrollViewWithContentView:self.readingLabel];
#endif
  [self.headwordScrollContainer resizeScrollViewWithContentView:self.headwordLabel];
#if defined(LWE_CFLASH)
  // Pinyin: 20pt regular, shrunk or wrapped to the headword (resizeWithMinFontSize: would replace
  // the attributed fonts with the XIB's)
  [self _fitLegacyReading];
#endif

  //[self _updateReadingContainer];
  self.headwordMoreIcon.hidden = [self _shouldHideMoreIconForLabel:self.headwordLabel
                                                     forScrollView:self.headwordScrollContainer];
#if defined(LWE_JFLASH)
  [self _updateSpeakBtnPosition];
#endif
  [self _updateReadingToggle];
}

- (void) _updateReadingContainer
{
  // Hide the scroll icon if the label fits, or if the reading isn't visible yet.
  BOOL shouldHideReadingScroll = [self _shouldHideMoreIconForLabel:self.readingLabel
                                                     forScrollView:self.readingScrollContainer];
  self.readingMoreIcon.hidden = (shouldHideReadingScroll || (self.readingScrollContainer.hidden == YES));
}

- (void) _injectMeaningHTML:(NSString*)html
{
  // The HTML will be encapsulated in Javascript, escape backslash, quote, and
  // newline so the resulting JS string literal stays well-formed for any
  // characters that might appear in card meanings.
  NSString *escapedHtml = [html stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
  escapedHtml = [escapedHtml stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
  escapedHtml = [escapedHtml stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
  escapedHtml = [escapedHtml stringByReplacingOccurrencesOfString:@"\r" withString:@""];
  NSString *js = [NSString stringWithFormat:@"var textElement = document.getElementById('container'); if (textElement) { textElement.innerHTML = '%@'; }",escapedHtml];

  // Save a copy of this in case the webview hasn't finished loading yet
  // (see WKNavigationDelegate callback below).
  [_tmpJavascript release];
  _tmpJavascript = [js retain];

  [_meaningWebView evaluateJavaScript:js completionHandler:nil];
  [self _updateMeaningInsets];
}

#pragma mark - Meaning vs the score bubble

- (CGSize) _meaningCornerSize
{
  UIView *bubbleView = self.moodIcon.view;
  UIImageView *bubble = self.moodIcon.talkBubble;
  BOOL bubbleVisible = (bubbleView != nil && bubbleView.hidden == NO && bubble != nil && bubble.hidden == NO);
  UIView *area = self.meaningWebViewContainer;
  if (bubbleVisible && bubble.window != nil && bubble.window == area.window)
  {
    // Where the bubble really is (the study view moves it onto the card, bottom right)
    return LWEMeaningCornerForBubble([bubble convertRect:bubble.bounds toView:area], area.bounds.size);
  }
  // Not on screen yet: the reserved 56 x 44pt corner
  CGFloat nudge = [[ThemeManager sharedThemeManager] cardRimBubbleNudge];
  return LWEMeaningCornerSize(bubbleVisible, nudge, area.bounds.size);
}

- (void) scoreBubbleDidMove
{
  [self _updateMeaningInsets];
}

- (void) _updateMeaningInsets
{
  if (_meaningWebView == nil) return;
  CGSize area = self.meaningWebViewContainer.bounds.size;
  if (area.width <= 0 || area.height <= 0) return;
  CGSize corner = [self _meaningCornerSize];
  // Two floats at the top of the meaning: a zero-width one as tall as the area above the bubble, then
  // the corner itself, so lines next to the bubble wrap short of it.  Returns the meaning's height (pt).
  NSString *js = [NSString stringWithFormat:
    @"(function(W,H,cw,ch){var c=document.getElementById('container');if(!c||!W||!window.innerWidth)return -1;"
     "var k=window.innerWidth/W,a=document.getElementById('lwe-corner-a'),b=document.getElementById('lwe-corner-b');"
     "if(!a){a=document.createElement('div');a.id='lwe-corner-a';b=document.createElement('div');b.id='lwe-corner-b';}"
     "if(c.firstChild!==a)c.insertBefore(a,c.firstChild);if(a.nextSibling!==b)c.insertBefore(b,a.nextSibling);"
     "a.style.cssText='float:right;clear:right;width:0;height:0;margin:0;padding:0;border:0;';"
     "b.style.cssText='float:right;clear:right;width:0;height:0;margin:0;padding:0;border:0;';"
     "if(cw>0&&ch>0){var top=a.getBoundingClientRect().top+window.scrollY;"
     "a.style.height=Math.max(0,H*k-ch*k-top)+'px';b.style.width=(cw*k)+'px';b.style.height=(ch*k)+'px';}"
     "return Math.ceil((c.getBoundingClientRect().bottom+window.scrollY)/k);})(%.1f,%.1f,%.1f,%.1f)",
     area.width, area.height, corner.width, corner.height];
  NSUInteger token = ++_meaningMeasureToken;
  [_meaningWebView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
    if (token != _meaningMeasureToken || ![result isKindOfClass:[NSNumber class]]) return;
    CGFloat contentHeight = [result doubleValue];
    if (contentHeight < 0) return;
    CGSize nowArea = self.meaningWebViewContainer.bounds.size;
    LWEMeaningInsets insets = LWEMeaningInsetsFor(contentHeight, nowArea.height, [self _meaningCornerSize]);
    if (insets.wrapCorner == NO)
    {
      // Scrolling (or no bubble): no corner notch; the bottom inset lets the end scroll clear of the bubble
      [_meaningWebView evaluateJavaScript:@"(function(){['lwe-corner-a','lwe-corner-b'].forEach(function(i){var e=document.getElementById(i);if(e){e.style.width='0';e.style.height='0';}});})()" completionHandler:nil];
    }
    _meaningInsets = insets;
    UIScrollView *scroll = _meaningWebView.scrollView;
    UIEdgeInsets inset = scroll.contentInset;
    inset.bottom = insets.bottomInset;
    scroll.contentInset = inset;
    UIEdgeInsets indicators = scroll.verticalScrollIndicatorInsets;
    indicators.bottom = insets.bottomInset;
    scroll.verticalScrollIndicatorInsets = indicators;
    [self _updateMeaningFade];
  }];
}

- (void) _updateMeaningFade
{
  UIView *area = self.meaningWebViewContainer;
  UIScrollView *scroll = _meaningWebView.scrollView;
  CGFloat h = area.bounds.size.height;
  if (_meaningInsets.scrolls == NO || h <= 0)
  {
    area.layer.mask = nil;
    return;
  }
  // Scrolling: visible down to the bubble's top, with a soft fade there while more is below
  CGFloat visibleH = LWEMeaningVisibleHeight(_meaningInsets, h);
  BOOL fade = (visibleH > LWEMeaningFadeHeight * 2.0) &&
              LWEMeaningShowsBottomFade(_meaningInsets, scroll.contentOffset.y, scroll.contentSize.height, scroll.bounds.size.height);
  CAGradientLayer *mask = [area.layer.mask isKindOfClass:[CAGradientLayer class]] ? (CAGradientLayer *)area.layer.mask : nil;
  if (mask == nil)
  {
    mask = [CAGradientLayer layer];
    mask.colors = @[(id)[UIColor blackColor].CGColor, (id)[UIColor blackColor].CGColor,
                    (id)[UIColor clearColor].CGColor, (id)[UIColor clearColor].CGColor];
    area.layer.mask = mask;
  }
  CGFloat fadeTop = fade ? (visibleH - LWEMeaningFadeHeight) : MAX(0.0, visibleH - 0.5);
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  mask.frame = area.bounds;
  mask.locations = @[@0.0, @(fadeTop / h), @(visibleH / h), @1.0];
  [CATransaction commit];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (context == kLWEMeaningOffsetContext)
  {
    [self _updateMeaningFade];
    return;
  }
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


#pragma mark - WKNavigationDelegate

/**
 * The HTML template loads from a string and a JS-injection request can race the
 * load. If the JS was queued before the WebView finished loading, replay it now.
 */
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
  if (_tmpJavascript)
  {
    [_meaningWebView evaluateJavaScript:_tmpJavascript completionHandler:nil];
    [_tmpJavascript release];
    _tmpJavascript = nil;
  }
  [self _updateMeaningInsets];
}

#pragma mark - Plumbing

- (void)viewDidUnload
{
  [super viewDidUnload];
  self.readingScrollContainer = nil;
  self.headwordScrollContainer = nil;
  self.headwordMoreIcon = nil;
  self.readingMoreIcon = nil;
  self.headwordLabel = nil;
  self.readingLabel = nil;
  self.toggleReadingBtn = nil;
  self.meaningWebViewContainer = nil;
  self.moodIcon = nil;
#if defined(LWE_JFLASH)
  self.speakBtn = nil;
  self.speechSynthesizer = nil;
  self.moreReadingsBtn = nil;
  self.romajiLabel = nil;
#endif
}


- (void)dealloc
{
  [moodIcon release];

  [baseHtml release];
  [_tmpJavascript release];

  [headwordScrollContainer release];
  [headwordMoreIcon release];
  [headwordLabel release];

  [readingScrollContainer release];
  [readingMoreIcon release];
  [readingLabel release];
  [toggleReadingBtn release];

#if defined(LWE_JFLASH)
  [speakBtn release];
  [speechSynthesizer release];
  [kanaReadings release];
  [romajiReadings release];
  [moreReadingsBtn release];
  [romajiLabel release];
  [topReadingText release];
#endif
#if defined(LWE_CFLASH)
  [legacyReadingSource release];
#endif

  if (_observingMeaningScroll)
  {
    [_meaningWebView.scrollView removeObserver:self forKeyPath:@"contentOffset" context:kLWEMeaningOffsetContext];
  }
  _meaningWebView.navigationDelegate = nil;
  [_meaningWebView release];
  [meaningWebViewContainer release];

  [super dealloc];
}

@end

// HTML Header content that will be displayed in the meaning UIWebView before the actual meaning
NSString * const LWECardHTMLTemplate = @""
"<html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8' />"
#if defined(LWE_JFLASH)
// 2026 card: large, upright meaning; no maximum-scale, so pinch zoom stays available.
// POS pills (dfn) contain hiragana — Hiragino first there. Body keeps Helvetica Neue
// for Latin glosses, with Hiragino as fallback so any kana in glosses still draw.
"<meta name='viewport' content='width=device-width, initial-scale=1' />"
"<style>"
"body{ background-color:transparent; margin:0; padding:0; text-align:center; font-size:calc(##TEXTSIZE## * 1.5); font-weight:600; font-style:normal; font-family:'Helvetica Neue','Hiragino Sans','Hiragino Kaku Gothic ProN',-apple-system,Helvetica,sans-serif; line-height:1.25; letter-spacing:-0.4px; -webkit-text-size-adjust:none; } "
"dfn{ text-shadow:none; font-style:normal; font-weight:600; color:#3a2a00; position:relative; top:-3px; font-family:'Hiragino Sans','Hiragino Kaku Gothic ProN',-apple-system,sans-serif; font-size:13px; letter-spacing:0.1px; background-color:#FFD60A; line-height:1; margin:0 0 0 8px; padding:5px 9px 6px; -webkit-border-radius:8px; border:0; display:inline-block; vertical-align:middle; } "
"#container{ width:100%; text-align:center; padding-top:0; } "
// Meaning ink, the rule colour and the noun pill come from the theme CSS (meaningInk, meaningRule).
"#container:before{ content:''; display:block; width:40px; height:2px; border-radius:1px; margin:0 auto 22px auto; } "
"ol{text-align:left; font-size:0.75em; line-height:1.35; width:auto; margin:0 12px; padding-left:22px;} "
"li{margin:0px; margin-bottom:8px;} "
#else
// Chinese Flash: same readable meaning size as jFlash. Without a viewport meta, WKWebView
// laid the page out at ~980px and scaled it down to ~5–6pt on phone. Match jFlash's
// viewport + ~1.5× body, with list items at 0.75em (~18pt at default Dynamic Type).
"<meta name='viewport' content='width=device-width, initial-scale=1' />"
"<style>"
"body{ background-color:transparent; margin:0; padding:0; text-align:center; font-size:calc(##TEXTSIZE## * 1.5); font-weight:600; font-style:normal; font-family:'PingFang SC','PingFang TC',-apple-system,'Helvetica Neue',Helvetica,sans-serif; line-height:1.35; letter-spacing:-0.2px; -webkit-text-size-adjust:none; } "
"dfn{ text-shadow:none; font-style:normal; font-weight:600; color:#3a2a00; position:relative; top:-2px; font-family:'PingFang SC','PingFang TC',-apple-system,sans-serif; font-size:13px; letter-spacing:0.1px; background-color:#FFD60A; line-height:1; margin:0 0 0 8px; padding:4px 8px 5px; -webkit-border-radius:8px; border:0; display:inline-block; vertical-align:middle; } "
"#container{ width:100%; text-align:center; padding-top:8px; box-sizing:border-box; } "
"ol{ text-align:left; font-size:0.75em; line-height:1.4; width:auto; margin:0 12px; padding-left:22px; } "
"li{ margin:0 0 8px 0; } "
#endif
"##THEMECSS##"
"</style></head>"
"<body><div id='container'>"
"</div></body></html>";

// English-first cards show the Japanese answer in this web view: name a Japanese font first in jFlash
// (Helvetica has no kana/kanji); cFlash keeps its original stack so Chinese doesn't get Japanese glyph forms.
#if defined(LWE_JFLASH)
  #define LWE_ETOJ_FONT_STACK "'Hiragino Sans','Hiragino Kaku Gothic ProN',Helvetica,sans-serif"
#else
  #define LWE_ETOJ_FONT_STACK "Helvetica,sanserif"
#endif
NSString * const LWECardHTMLTemplate_EtoJ = @""
"<html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8' />"
"<style>"
"html,body{ height:100%; } "
"body{ background-color:transparent; display:-webkit-flex; display:flex; -webkit-justify-content:center; justify-content:center; -webkit-align-items:flex-start; align-items:flex-start; margin:0; padding:10px 0 0 0; box-sizing:border-box; font-size:##TEXTSIZE##; font-weight:bold; font-family:" LWE_ETOJ_FONT_STACK "; color:#fff; line-height:1.4; } "
"dfn{ text-shadow:none; font-weight:normal; color:#000; position:relative; top:-1px; font-family:verdana; font-size:10.5px; background-color:#C79810; line-height:1.4; margin:4px 4px 0px 0px; height:14px; padding:2px 3px; -webkit-border-radius:4px; border:1px solid #F9F7ED; display:inline-block;} "
"#container{ width:100%; text-align:center; font-size:34px; padding-left:3px; line-height:1.4; } "
"ol{color:white; text-align:left; width:240px; margin:0px; margin-left:24px; padding-left:10px;} "
"li{color:white; margin:0px; margin-bottom:7px;} "
"##THEMECSS##"
"</style></head>"
"<body><div id='container'>"
"</div></body></html>";
