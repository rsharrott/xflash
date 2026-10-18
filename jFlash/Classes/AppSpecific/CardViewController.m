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
#if defined(LWE_JFLASH)
#import "JapaneseCard.h"
#endif
#import <AVFoundation/AVFoundation.h>

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
  #import "TTTAttributedLabel.h"
#endif

// Private Methods
//! The "+N readings" pill is 30pt tall; its button extends this far above and below it (44pt hit area).
static const CGFloat kLWEPillHitInset = 7.0;

@interface CardViewController()
- (void) _injectMeaningHTML:(NSString*)html;
- (void) _prepareView:(Card*)card;
- (void) _updateReadingContainer;

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
#endif
@end

@implementation CardViewController
{
  BOOL _modernCard;
  BOOL _readingsExpanded;
  CGFloat _lastLayoutWidth;
  CGFloat _lastLayoutHeight;
}

@synthesize delegate;
@synthesize meaningWebViewContainer, headwordMoreIcon, headwordLabel, readingMoreIcon, readingLabel, toggleReadingBtn;
@synthesize readingScrollContainer, headwordScrollContainer, readingVisible = _readingVisible;
@synthesize baseHtml;
@synthesize moodIcon;
#if defined(LWE_JFLASH)
@synthesize speakBtn, speechSynthesizer;
@synthesize kanaReadings, romajiReadings, moreReadingsBtn;
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
#if defined(LWE_JFLASH)
    _modernCard = displayMainHeadword;
#endif
    // Replace out the CSS to match the current theme
    NSString *cssHeader = [[ThemeManager sharedThemeManager] currentThemeCSS];
    html = [html stringByReplacingOccurrencesOfString:@"##THEMECSS##" withString:cssHeader];
    
    html = [html stringByReplacingOccurrencesOfString:@"##TEXTSIZE##" withString:LWEDynamicTypeCSSFontSize()];
    
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
  [self.meaningWebViewContainer addSubview:_meaningWebView];
  [_meaningWebView loadHTMLString:self.baseHtml baseURL:nil];

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
  speak.tintColor = [UIColor whiteColor];
  speak.accessibilityLabel = NSLocalizedString(@"Speak word", @"CardViewController.SpeakWordAccessibility");
  [speak addTarget:self action:@selector(doSpeakHeadword) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:speak];
  self.speakBtn = speak;

  if (_modernCard)
  {
    [self _setupModernCard];
  }
#endif
}

#if defined(LWE_JFLASH)
- (void) _setupModernCard
{
  // Headword: heavy & yellow; the size is set per card in -_layoutModernCard.
  self.headwordLabel.textColor = LWEDesignYellow();
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
  self.readingLabel.shadowColor = nil;
  self.readingLabel.shadowOffset = CGSizeZero;
  self.readingLabel.autoresizingMask = UIViewAutoresizingNone;
  self.readingMoreIcon.hidden = YES;

  self.toggleReadingBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
  [self.toggleReadingBtn setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.85] forState:UIControlStateNormal];
  self.toggleReadingBtn.autoresizingMask = UIViewAutoresizingNone;

  // Speaker: 44pt translucent circle next to the headword
  UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightMedium];
  [self.speakBtn setImage:[UIImage systemImageNamed:@"speaker.wave.2" withConfiguration:cfg] forState:UIControlStateNormal];
  self.speakBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
  self.speakBtn.layer.cornerRadius = kLWESpeakBtnSize / 2.0;

  // "+N readings" pill
  UIButton *pill = nil;
  if (@available(iOS 15.0, *))
  {
    // UIButtonConfiguration (replaces the deprecated image/content edge insets): chevron after the text
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    // White text (5.1:1 on the pill); the visible pill is 30pt tall inside a 44pt-tall hit area.
    config.baseForegroundColor = [UIColor whiteColor];
    config.background.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
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
    pill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    pill.layer.cornerRadius = 15.0;
    pill.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [pill setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.88] forState:UIControlStateNormal];
    [pill setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.5] forState:UIControlStateHighlighted];
    pill.tintColor = [UIColor colorWithWhite:1.0 alpha:0.88];
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

//! Builds the reading label: kana on one line, muted romaji on the next (per APP_READING).
- (void) _applyReadingText
{
  NSString *mode = [[NSUserDefaults standardUserDefaults] objectForKey:APP_READING];
  BOOL showKana = ([mode isEqualToString:SET_READING_ROMAJI] == NO);
  BOOL showRomaji = ([mode isEqualToString:SET_READING_KANA] == NO);

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

  // A short card (small phone, or a tall answer bar at large text sizes) keeps the reading at
  // its base size so the meaning still has room.
  CGFloat dt = (self.view.bounds.size.height > 0 && self.view.bounds.size.height < kLWECompactCardHeight)
             ? 1.0f : MIN(LWEDynamicTypeSizeMultiplier(), 1.35f);
  NSMutableParagraphStyle *para = [[[NSMutableParagraphStyle alloc] init] autorelease];
  para.alignment = NSTextAlignmentCenter;
  para.paragraphSpacing = 2.0;
  para.lineBreakMode = NSLineBreakByWordWrapping;

  NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] init] autorelease];
  if (showKana && [kanaText length] > 0)
  {
    CGFloat kanaSize = (_readingsExpanded ? 24.0 : 30.0) * dt;
    // Long readings shrink to stay on one line (down to 20pt), then wrap.
    CGFloat availW = self.view.bounds.size.width - 48.0;
    CGFloat kanaW = [kanaText sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:kanaSize weight:UIFontWeightMedium]}].width;
    if (availW > 0 && kanaW > availW)
    {
      kanaSize = MAX(20.0, floorf(kanaSize * availW / kanaW));
    }
    [text appendAttributedString:[[[NSAttributedString alloc] initWithString:kanaText attributes:@{
      NSFontAttributeName: [UIFont systemFontOfSize:kanaSize weight:UIFontWeightMedium],
      NSForegroundColorAttributeName: [UIColor whiteColor],
      NSParagraphStyleAttributeName: para,
    }] autorelease]];
  }
  if (showRomaji && [romajiText length] > 0)
  {
    BOOL romajiOnly = ([text length] == 0);
    if (!romajiOnly)
    {
      [text appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
    }
    CGFloat romajiSize = (romajiOnly ? 24.0 : 17.0) * dt;
    [text appendAttributedString:[[[NSAttributedString alloc] initWithString:romajiText attributes:@{
      NSFontAttributeName: [UIFont systemFontOfSize:romajiSize weight:UIFontWeightMedium],
      NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:(romajiOnly ? 1.0 : 0.88)],
      NSKernAttributeName: @(0.2),
      NSParagraphStyleAttributeName: para,
    }] autorelease]];
  }
  [text addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, [text length])];
  self.readingLabel.attributedText = text;
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

  // Re-flow the reading for the final width (the first card is prepared before layout).
  // Re-flow the reading when the width or height changed (the reading size depends on both).
  if (fabs(w - _lastLayoutWidth) > 0.5 || fabs(h - _lastLayoutHeight) > 0.5)
  {
    _lastLayoutWidth = w;
    _lastLayoutHeight = h;
    [self _applyReadingText];
  }

  // ---- Headword: ~88pt, scaled down to fit one line beside the speaker; wraps only if
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
  }
  self.headwordLabel.font = font;
  CGRect hwBounds = [headword boundingRectWithSize:CGSizeMake(textAvailW, CGFLOAT_MAX)
                                           options:NSStringDrawingUsesLineFragmentOrigin
                                        attributes:@{NSFontAttributeName: font}
                                           context:nil];
  CGFloat hwH = ceilf(MAX(hwBounds.size.height, font.lineHeight));
  CGFloat maxHwH = roundf(h * 0.36);
  CGFloat containerH = MIN(hwH, maxHwH);

  CGFloat headwordY = compact ? MAX(8.0, roundf(h * 0.06)) : MAX(16.0, roundf(h * 0.16));
  self.headwordScrollContainer.frame = CGRectMake(hPad, headwordY, contentW, containerH);
  self.headwordLabel.frame = CGRectMake(roundf((contentW - textAvailW) / 2.0), 0, textAvailW, hwH);
  self.headwordScrollContainer.contentSize = CGSizeMake(contentW, hwH);
  self.headwordScrollContainer.contentOffset = CGPointZero;
  self.headwordMoreIcon.hidden = YES;
  [self _updateSpeakBtnPosition];

  // ---- Reading under the headword
  CGFloat readingY = headwordY + containerH + (compact ? 6.0 : 16.0);
  CGSize readingFit = [self.readingLabel.attributedText boundingRectWithSize:CGSizeMake(contentW, CGFLOAT_MAX)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                     context:nil].size;
  CGFloat readingH = MAX(44.0, ceilf(readingFit.height));
  CGFloat readingContainerH = MIN(readingH, roundf(h * 0.3));
  self.readingScrollContainer.frame = CGRectMake(hPad, readingY, contentW, readingContainerH);
  self.readingLabel.frame = CGRectMake(0, 0, contentW, readingH);
  self.readingScrollContainer.contentSize = CGSizeMake(contentW, readingH);
  self.readingMoreIcon.hidden = YES;
  // Toggle ("Show Reading") overlays the reading row
  self.toggleReadingBtn.frame = CGRectMake(hPad, readingY, contentW, readingContainerH);

  CGFloat bottom = readingY + readingContainerH;
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
  CGFloat webY = bottom + (compact ? 10.0 : 20.0);
  CGFloat webH = MAX(60.0, h - webY - 8.0);
  self.meaningWebViewContainer.frame = CGRectMake(hPad, webY, contentW, webH);
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
  CGFloat readingH = 42.0;
  self.readingScrollContainer.frame = CGRectMake(hPad, readingY, contentW, readingH);
  self.readingMoreIcon.frame = CGRectMake(2.0, readingY + readingH - 17.0, 26.0, 17.0);
  // Toggle overlays the full reading row; positioned above the reveal-button zone
  // so it intercepts taps without triggering the definition reveal.
  self.toggleReadingBtn.frame = CGRectMake(hPad, readingY, contentW, readingH);

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
}

- (CGFloat) revealAreaTop
{
  CGFloat top = CGRectGetMaxY(self.headwordScrollContainer.frame);
  top = MAX(top, CGRectGetMaxY(self.toggleReadingBtn.frame));
#if defined(LWE_JFLASH)
  if (self.moreReadingsBtn && self.moreReadingsBtn.hidden == NO)
  {
    top = MAX(top, CGRectGetMaxY(self.moreReadingsBtn.frame));
  }
#endif
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
  if (self.readingScrollContainer.hidden == YES)
  {
    [self turnReadingOn];
    self.readingVisible = YES;
  }
  else
  {
    [self turnReadingOff];
    self.readingVisible = NO;
  }
}

#pragma mark - Public Helper Methods

- (void) turnReadingOn
{
  // Change state
  self.readingScrollContainer.hidden = NO;
  [self.toggleReadingBtn setTitle:@"" forState:UIControlStateNormal];
  
  // This will handle the "more" icon after the state change
  [self _updateReadingContainer];
#if defined(LWE_JFLASH)
  if (_modernCard) [self _updateMoreReadingsBtn];
#endif
}

- (void) turnReadingOff
{
  // This will handle the "more" icon
  [self _updateReadingContainer];
  
  self.readingScrollContainer.hidden = YES;
  [self.toggleReadingBtn setTitle:NSLocalizedString(@"Show Reading", @"CardViewController.ShowReading") forState:UIControlStateNormal];

  // This will handle the "more" icon after the state change
  [self _updateReadingContainer];
#if defined(LWE_JFLASH)
  if (_modernCard) [self _updateMoreReadingsBtn];
#endif
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
    return;
  }
  self.readingLabel.text = card.reading;
#elif defined(LWE_CFLASH)
  [(TTTAttributedLabel *)self.readingLabel setText:[card attributedReading]];
#endif
  // These calls re-size the reading & headword labels.  They used to take the scrollContainer as well,
  // but we infer it (superview) of the labels inside this call.
  CGFloat dtScale = LWEDynamicTypeSizeMultiplier();
  [self.readingLabel resizeWithMinFontSize:(NSInteger)(READING_MIN_FONTSIZE * dtScale) maxFontSize:(NSInteger)(READING_MAX_FONTSIZE * dtScale)];
  [self.headwordLabel resizeWithMinFontSize:(NSInteger)(HEADWORD_MIN_FONTSIZE * dtScale) maxFontSize:(NSInteger)(HEADWORD_MAX_FONTSIZE * dtScale)];
  
  // Now resize the scroll views as necessary based on the resized views above, if necessary.
  // This call also centers the label inside the scroll view.
  [self.readingScrollContainer resizeScrollViewWithContentView:self.readingLabel];
  [self.headwordScrollContainer resizeScrollViewWithContentView:self.headwordLabel];

  //[self _updateReadingContainer];
  self.headwordMoreIcon.hidden = [self _shouldHideMoreIconForLabel:self.headwordLabel
                                                     forScrollView:self.headwordScrollContainer];
#if defined(LWE_JFLASH)
  [self _updateSpeakBtnPosition];
#endif
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
#endif

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
"<meta name='viewport' content='width=device-width, initial-scale=1' />"
"<style>"
"body{ background-color:transparent; margin:0; padding:0; text-align:center; font-size:calc(##TEXTSIZE## * 1.5); font-weight:600; font-style:normal; font-family:-apple-system,'Helvetica Neue',Helvetica,sans-serif; color:#fff; line-height:1.25; letter-spacing:-0.4px; -webkit-text-size-adjust:none; } "
"dfn{ text-shadow:none; font-style:normal; font-weight:600; color:#3a2a00; position:relative; top:-3px; font-family:-apple-system,sans-serif; font-size:13px; letter-spacing:0.1px; background-color:#FFD60A; line-height:1; margin:0 0 0 8px; padding:5px 9px 6px; -webkit-border-radius:8px; border:0; display:inline-block; vertical-align:middle; } "
"#container{ width:100%; text-align:center; padding-top:0; } "
"#container:before{ content:''; display:block; width:40px; height:2px; border-radius:1px; background:rgba(255,255,255,0.3); margin:0 auto 22px auto; } "
"ol{color:white; text-align:left; font-size:0.75em; line-height:1.35; width:auto; margin:0 12px; padding-left:22px;} "
"li{color:white; margin:0px; margin-bottom:8px;} "
#else
// Chinese Flash keeps the original card styling.
"<style>"
"body{ background-color:transparent; margin:0; padding:0; text-align:center; font-size:##TEXTSIZE##; font-weight:bold; font-family:Helvetica,sanserif; color:#fff; line-height:1.4; } "
"dfn{ text-shadow:none; font-weight:normal; color:#000; position:relative; top:-1px; font-family:verdana; font-size:10.5px; background-color:#C79810; line-height:1.4; margin:4px 4px 0px 0px; height:14px; padding:2px 3px; -webkit-border-radius:4px; border:1px solid #F9F7ED; display:inline-block;} "
"#container{ width:100%; text-align:center; padding-top:12px; } "
"ol{color:white; text-align:left; width:240px; margin:0px; margin-left:24px; padding-left:10px;} "
"li{color:white; margin:0px; margin-bottom:7px;} "
#endif
"##THEMECSS##"
"</style></head>"
"<body><div id='container'>"
"</div></body></html>";

// English-first cards show the Japanese answer in this web view: name a Japanese font first in jFlash
// (Helvetica has no kana/kanji); cFlash keeps its original stack so Chinese doesn't get Japanese glyph forms.
#if defined(LWE_JFLASH)
  #define LWE_ETOJ_FONT_STACK "-apple-system,'Hiragino Sans','Hiragino Kaku Gothic ProN',sans-serif"
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
