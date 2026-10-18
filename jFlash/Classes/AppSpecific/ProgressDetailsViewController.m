//
//  ProgressDetailsViewController.m
//  jFlash
//
//  Created by Ross Sharrott on 11/23/09.
//  Copyright 2009 LONG WEEKEND LLC. All rights reserved.
//

#import "ProgressDetailsViewController.h"
#import "LWELocalization.h"
#import "LWEDesignTokens.h"

//! Mascot next to the encouragement line (same image the old XIB used; folder reference in jFlash and cFlash).
static NSString * const kLWEProgressMascotImage = @"redtheme-cookie-cutters/mood-icons/positive/hh-happy.png";

@interface ProgressDetailsViewController ()
{
  UIScrollView *_scroll;
  UIStackView *_stack;
}
- (void) _buildContent;
@end

@implementation ProgressDetailsViewController
@synthesize tag, rightCount, wrongCount, rightStreak, wrongStreak;

#pragma mark - Formatting

//! Grouped integer in the current locale ("1,234" / "1,234")
static NSString *LWEProgressNumber(NSInteger value)
{
  static NSNumberFormatter *formatter = nil;
  if (formatter == nil)
  {
    formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.usesGroupingSeparator = YES;
    formatter.maximumFractionDigits = 0;
  }
  return [formatter stringFromNumber:[NSNumber numberWithInteger:value]];
}

//! Whole-number percentage in the current locale ("22%")
static NSString *LWEProgressPercent(CGFloat fraction)
{
  static NSNumberFormatter *formatter = nil;
  if (formatter == nil)
  {
    formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterPercentStyle;
    formatter.maximumFractionDigits = 0;
  }
  return [formatter stringFromNumber:[NSNumber numberWithDouble:fraction]];
}

//! Replaces %1$@, %2$@ ... in a localized format with attributed arguments; the rest of the text gets |attrs|.
static NSAttributedString *LWEProgressAttributedFormat(NSString *format, NSDictionary *attrs, NSArray *args)
{
  NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] initWithString:format attributes:attrs] autorelease];
  for (NSInteger i = (NSInteger)[args count] - 1; i >= 0; i--)
  {
    NSString *token = [NSString stringWithFormat:@"%%%ld$@", (long)(i + 1)];
    NSRange range = [[result string] rangeOfString:token];
    if (range.location == NSNotFound && [args count] == 1)
    {
      range = [[result string] rangeOfString:@"%@"];
    }
    if (range.location != NSNotFound)
    {
      [result replaceCharactersInRange:range withAttributedString:[args objectAtIndex:i]];
    }
  }
  return result;
}

static UILabel *LWEProgressLabel(UIFont *font, UIColor *color)
{
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = font;
  label.textColor = color;
  label.numberOfLines = 0;
  label.adjustsFontForContentSizeCategory = YES;
  return label;
}

//! Wraps |content| in a rounded, filled box with the given insets (a plain view, so the corner radius clips the fill).
static UIView *LWEProgressBox(UIView *content, UIColor *fill, CGFloat radius, NSDirectionalEdgeInsets insets)
{
  UIView *box = [[[UIView alloc] init] autorelease];
  box.translatesAutoresizingMaskIntoConstraints = NO;
  box.backgroundColor = fill;
  box.layer.cornerRadius = radius;
  box.layer.cornerCurve = kCACornerCurveContinuous;
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [box addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.topAnchor constraintEqualToAnchor:box.topAnchor constant:insets.top],
    [content.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-insets.bottom],
    [content.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:insets.leading],
    [content.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-insets.trailing],
  ]];
  return box;
}

#pragma mark - Init

- (id) initWithTag:(Tag *)aTag rightCount:(NSInteger)right wrongCount:(NSInteger)wrong
       rightStreak:(NSInteger)rStreak wrongStreak:(NSInteger)wStreak
{
  self = [super initWithNibName:nil bundle:nil];
  if (self)
  {
    self.tag = aTag;
    self.rightCount = right;
    self.wrongCount = wrong;
    self.rightStreak = rStreak;
    self.wrongStreak = wStreak;

    self.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = self.sheetPresentationController;
    sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
    sheet.prefersGrabberVisible = YES;
    sheet.preferredCornerRadius = 28; // radius-3xl
    sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    sheet.prefersEdgeAttachedInCompactHeight = YES;
  }
  return self;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  return [self initWithTag:nil rightCount:0 wrongCount:0 rightStreak:0 wrongStreak:0];
}

#pragma mark - UIViewController Methods

- (void) viewDidLoad
{
  [super viewDidLoad];
  self.view.backgroundColor = LWEDesignPaper();

  _scroll = [[UIScrollView alloc] init];
  _scroll.translatesAutoresizingMaskIntoConstraints = NO;
  _scroll.alwaysBounceVertical = YES;
  _scroll.showsVerticalScrollIndicator = YES;
  [self.view addSubview:_scroll];

  _stack = [[UIStackView alloc] init];
  _stack.translatesAutoresizingMaskIntoConstraints = NO;
  _stack.axis = UILayoutConstraintAxisVertical;
  _stack.alignment = UIStackViewAlignmentFill;
  _stack.spacing = 12; // space-3
  _stack.layoutMarginsRelativeArrangement = YES;
  // Top leaves room for the grabber; sides are space-5.
  _stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(20, 20, 24, 20);
  [_scroll addSubview:_stack];

  UILayoutGuide *content = _scroll.contentLayoutGuide;
  UILayoutGuide *frame = _scroll.frameLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [_scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [_scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [_scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [_scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    [_stack.topAnchor constraintEqualToAnchor:content.topAnchor],
    [_stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
    [_stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [_stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [_stack.widthAnchor constraintEqualToAnchor:frame.widthAnchor],
  ]];

  [self _buildContent];
}

- (void) viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  // At accessibility text sizes the medium detent shows only the header, so open full height.
  if (UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory))
  {
    self.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
  }
}

- (void) traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  if ([previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory] == NO)
  {
    // Rows switch between side-by-side and stacked layouts, and the attributed text re-resolves its fonts.
    [self _buildContent];
  }
}

- (void) updateView
{
  if ([self isViewLoaded])
  {
    [self _buildContent];
  }
}

#pragma mark - Content

- (BOOL) _isAccessibilitySize
{
  return UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
}

- (UIView *) _headerView
{
  UILabel *title = LWEProgressLabel(LWEDesignScaledFont(UIFontTextStyleTitle2, 22, UIFontWeightBold, 0), LWEDesignInk());
  title.text = self.tag.tagName;
  title.numberOfLines = [self _isAccessibilitySize] ? 0 : 3;
  title.lineBreakMode = NSLineBreakByTruncatingTail;
  title.accessibilityTraits = UIAccessibilityTraitHeader;

  // Close: a 32pt paper-button circle inside a 44pt tap target.
  UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
  close.translatesAutoresizingMaskIntoConstraints = NO;
  close.accessibilityLabel = NSLocalizedString(@"Close", @"ProgressDetailsViewController.Close");
  [close addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
  UIView *circle = [[[UIView alloc] init] autorelease];
  circle.translatesAutoresizingMaskIntoConstraints = NO;
  circle.userInteractionEnabled = NO;
  circle.backgroundColor = LWEDesignPaperButton();
  circle.layer.cornerRadius = 16;
  [close addSubview:circle];
  UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
  UIImageView *xmark = [[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"xmark" withConfiguration:symbolConfig]] autorelease];
  xmark.translatesAutoresizingMaskIntoConstraints = NO;
  xmark.tintColor = LWEDesignInk2();
  [circle addSubview:xmark];
  [NSLayoutConstraint activateConstraints:@[
    [close.widthAnchor constraintEqualToConstant:44],
    [close.heightAnchor constraintEqualToConstant:44],
    [circle.widthAnchor constraintEqualToConstant:32],
    [circle.heightAnchor constraintEqualToConstant:32],
    [circle.centerXAnchor constraintEqualToAnchor:close.centerXAnchor],
    [circle.centerYAnchor constraintEqualToAnchor:close.centerYAnchor],
    [xmark.centerXAnchor constraintEqualToAnchor:circle.centerXAnchor],
    [xmark.centerYAnchor constraintEqualToAnchor:circle.centerYAnchor],
  ]];

  UIStackView *row = [[[UIStackView alloc] initWithArrangedSubviews:@[title, close]] autorelease];
  row.axis = UILayoutConstraintAxisHorizontal;
  row.alignment = UIStackViewAlignmentTop;
  row.spacing = 12;
  [close setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [close setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  return row;
}

//! "You are studying 14 cards out of 14 in this set." with the two numbers large and bold.
- (UIView *) _leadView
{
  NSInteger maxStudying = [[NSUserDefaults standardUserDefaults] integerForKey:APP_MAX_STUDYING];
  NSInteger totalWords = self.tag.cardCount;
  BOOL capped = (maxStudying > 0 && totalWords > maxStudying);
  NSInteger studying = capped ? maxStudying : totalWords;

  NSDictionary *textAttrs = @{ NSFontAttributeName: LWEDesignScaledFont(UIFontTextStyleBody, 17, UIFontWeightMedium, 0),
                               NSForegroundColorAttributeName: LWEDesignInk2() };
  NSDictionary *numberAttrs = @{ NSFontAttributeName: LWEDesignScaledFont(UIFontTextStyleTitle1, 28, UIFontWeightBold, 0),
                                 NSForegroundColorAttributeName: LWEDesignInk() };
  NSMutableAttributedString *current = [[[NSMutableAttributedString alloc] initWithString:LWEProgressNumber(studying) attributes:numberAttrs] autorelease];
  if (capped)
  {
    // The asterisk points at the footnote under the sentence.
    NSMutableDictionary *starAttrs = [[numberAttrs mutableCopy] autorelease];
    starAttrs[NSForegroundColorAttributeName] = LWEDesignFire();
    [current appendAttributedString:[[[NSAttributedString alloc] initWithString:@"*" attributes:starAttrs] autorelease]];
  }
  NSAttributedString *total = [[[NSAttributedString alloc] initWithString:LWEProgressNumber(totalWords) attributes:numberAttrs] autorelease];

  NSString *format = NSLocalizedString(@"You are studying %1$@ cards out of %2$@ in this set.", @"ProgressDetailsViewController.StudyingSentence");
  UILabel *lead = LWEProgressLabel(textAttrs[NSFontAttributeName], LWEDesignInk2());
  lead.attributedText = LWEProgressAttributedFormat(format, textAttrs, @[current, total]);
  return lead;
}

//! "*You can change this in Settings ›" -- one button, so the whole line is the tap target and it wraps.
- (UIView *) _settingsLinkView
{
  UIFont *font = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightRegular, 0);
  UIFont *linkFont = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightSemibold, 0);
  NSString *note = NSLocalizedString(@"*You can change this in", @"ProgressDetailsViewController.ChangeInSettings");
  NSString *settings = LWEInterfaceString(@"Settings");

  // No space after a full-width colon (ja: ※枚数の変更：設定 ›)
  NSString *gap = [note hasSuffix:@"\uFF1A"] ? @"" : @" ";
  NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] initWithString:[note stringByAppendingString:gap]
                                                                             attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: LWEDesignMuted() }] autorelease];
  [text appendAttributedString:[[[NSAttributedString alloc] initWithString:[settings stringByAppendingString:@"\u00A0\u203A"]
                                                                attributes:@{ NSFontAttributeName: linkFont, NSForegroundColorAttributeName: LWEDesignFire() }] autorelease]];

  // A label inside a plain button: the label wraps and drives the height (UIButton's own title
  // label doesn't report a multi-line size), the button keeps a 44pt minimum tap height.
  UILabel *label = LWEProgressLabel(font, LWEDesignMuted());
  label.attributedText = text;
  label.userInteractionEnabled = NO;
  UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  [button addSubview:label];
  button.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", note, settings];
  button.accessibilityTraits = UIAccessibilityTraitButton;
  [button addTarget:self action:@selector(switchToSettings:) forControlEvents:UIControlEventTouchUpInside];
  [button addTarget:self action:@selector(_dimLink:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
  [button addTarget:self action:@selector(_undimLink:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];
  NSLayoutConstraint *top = [label.topAnchor constraintEqualToAnchor:button.topAnchor constant:4];
  top.priority = UILayoutPriorityDefaultHigh;
  [NSLayoutConstraint activateConstraints:@[
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    [label.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
    [label.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
    [label.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
    [label.topAnchor constraintGreaterThanOrEqualToAnchor:button.topAnchor constant:4],
    top,
  ]];
  return button;
}

- (UIView *) _chipWithTitle:(NSString *)title value:(NSInteger)value fill:(UIColor *)fill ink:(UIColor *)ink
{
  UILabel *titleLabel = LWEProgressLabel(LWEDesignScaledFont(UIFontTextStyleFootnote, 13, UIFontWeightSemibold, 0), ink);
  titleLabel.text = title;
  UILabel *valueLabel = LWEProgressLabel(LWEDesignScaledFont(UIFontTextStyleTitle1, 28, UIFontWeightBold, 0), ink);
  valueLabel.text = LWEProgressNumber(value);

  UIStackView *texts = [[[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, valueLabel]] autorelease];
  texts.axis = UILayoutConstraintAxisVertical;
  texts.spacing = 2;
  // radius-xl, same as the answer buttons
  UIView *chip = LWEProgressBox(texts, fill, 18, NSDirectionalEdgeInsetsMake(12, 16, 12, 16));
  chip.isAccessibilityElement = YES;
  chip.accessibilityLabel = title;
  chip.accessibilityValue = valueLabel.text;
  return chip;
}

- (UIView *) _pillWithTitle:(NSString *)title value:(NSString *)value
{
  UIFont *font = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightMedium, 0);
  UIFont *bold = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightBold, 0);
  NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] initWithString:[title stringByAppendingString:@"  "]
                                                                             attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: LWEDesignInk2() }] autorelease];
  [text appendAttributedString:[[[NSAttributedString alloc] initWithString:value
                                                                attributes:@{ NSFontAttributeName: bold, NSForegroundColorAttributeName: LWEDesignInk() }] autorelease]];
  UILabel *label = LWEProgressLabel(font, LWEDesignInk2());
  label.attributedText = text;

  UIView *pill = LWEProgressBox(label, LWEDesignPaperButton(), 12, NSDirectionalEdgeInsetsMake(8, 12, 8, 12)); // radius-md
  pill.isAccessibilityElement = YES;
  pill.accessibilityLabel = title;
  pill.accessibilityValue = value;
  return pill;
}

- (UIView *) _ruleView
{
  UIView *rule = [[[UIView alloc] init] autorelease];
  rule.translatesAutoresizingMaskIntoConstraints = NO;
  rule.backgroundColor = LWEDesignHairline();
  [rule.heightAnchor constraintEqualToConstant:1].active = YES;
  return rule;
}

//! A thin (6pt) bar: paper-2 track, token fire fill (muted for Unseen).
- (UIView *) _trackWithFraction:(CGFloat)fraction fill:(UIColor *)fillColor hasCards:(BOOL)hasCards
{
  UIView *track = [[[UIView alloc] init] autorelease];
  track.translatesAutoresizingMaskIntoConstraints = NO;
  track.backgroundColor = LWEDesignPaper2();
  track.layer.cornerRadius = 3;
  track.clipsToBounds = YES;
  UIView *fill = [[[UIView alloc] init] autorelease];
  fill.translatesAutoresizingMaskIntoConstraints = NO;
  fill.backgroundColor = fillColor;
  fill.layer.cornerRadius = 3;
  [track addSubview:fill];

  NSLayoutConstraint *width = [fill.widthAnchor constraintEqualToAnchor:track.widthAnchor multiplier:MAX(0.0, MIN(1.0, fraction))];
  width.priority = UILayoutPriorityDefaultHigh;
  NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
    [track.heightAnchor constraintEqualToConstant:6],
    [track.widthAnchor constraintGreaterThanOrEqualToConstant:56],
    [fill.leadingAnchor constraintEqualToAnchor:track.leadingAnchor],
    [fill.topAnchor constraintEqualToAnchor:track.topAnchor],
    [fill.bottomAnchor constraintEqualToAnchor:track.bottomAnchor],
    [fill.widthAnchor constraintLessThanOrEqualToAnchor:track.widthAnchor],
    width,
  ]];
  if (hasCards)
  {
    // A level with a few cards still shows a dot rather than nothing.
    [constraints addObject:[fill.widthAnchor constraintGreaterThanOrEqualToConstant:6]];
  }
  [NSLayoutConstraint activateConstraints:constraints];
  track.isAccessibilityElement = NO;
  return track;
}

//! The level list: Unseen, a hairline, then Studying ... Learned.  Labels and values share column widths.
- (UIView *) _levelsView
{
  NSArray *names = @[NSLocalizedString(@"Unseen", @"ProgressDetailsViewController.UnseenLevel"),
                     LWEInterfaceString(@"Studying"), LWEInterfaceString(@"Right 1x"), LWEInterfaceString(@"Right 2x"),
                     LWEInterfaceString(@"Right 3x"), LWEInterfaceString(@"Learned")];
  BOOL stacked = [self _isAccessibilitySize];
  UIFont *font = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightMedium, 0);
  UIFont *pctFont = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightRegular, 0);
  NSInteger total = self.tag.cardCount;

  UIStackView *list = [[[UIStackView alloc] init] autorelease];
  list.axis = UILayoutConstraintAxisVertical;
  list.spacing = stacked ? 12 : 8;
  UILabel *firstName = nil, *firstValue = nil;
  NSMutableArray *constraints = [NSMutableArray array];
  for (NSInteger i = 0; i < 6 && i < (NSInteger)[self.tag.cardLevelCounts count]; i++)
  {
    NSInteger count = [[self.tag.cardLevelCounts objectAtIndex:i] integerValue];
    CGFloat fraction = (total > 0) ? ((CGFloat)count / (CGFloat)total) : 0.0;

    UILabel *name = LWEProgressLabel(font, (i == kLWEUnseenCardLevel) ? LWEDesignInk2() : LWEDesignInk());
    name.text = [names objectAtIndex:i];
    NSString *countText = LWEProgressNumber(count);
    NSString *pctText = LWEProgressPercent(fraction);
    NSMutableAttributedString *valueText = [[[NSMutableAttributedString alloc] initWithString:countText
                                                                                   attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: LWEDesignInk2() }] autorelease];
    [valueText appendAttributedString:[[[NSAttributedString alloc] initWithString:[@" \u00B7 " stringByAppendingString:pctText]
                                                                       attributes:@{ NSFontAttributeName: pctFont, NSForegroundColorAttributeName: LWEDesignMuted() }] autorelease]];
    UILabel *value = LWEProgressLabel(font, LWEDesignInk2());
    value.attributedText = valueText;
    UIView *track = [self _trackWithFraction:fraction fill:(i == kLWEUnseenCardLevel ? LWEDesignMuted() : LWEDesignFire()) hasCards:(count > 0)];

    UIStackView *row = nil;
    if (stacked)
    {
      UIStackView *texts = [[[UIStackView alloc] initWithArrangedSubviews:@[name, value]] autorelease];
      texts.axis = UILayoutConstraintAxisVertical;
      texts.spacing = 2;
      row = [[[UIStackView alloc] initWithArrangedSubviews:@[texts, track]] autorelease];
      row.axis = UILayoutConstraintAxisVertical;
      row.spacing = 6;
    }
    else
    {
      name.numberOfLines = 1;
      value.numberOfLines = 1;
      value.textAlignment = NSTextAlignmentRight;
      [name setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal]; // < the equal-width column constraints
      [name setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
      [value setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal]; // < the equal-width column constraints
      [value setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
      row = [[[UIStackView alloc] initWithArrangedSubviews:@[name, track, value]] autorelease];
      row.axis = UILayoutConstraintAxisHorizontal;
      row.alignment = UIStackViewAlignmentCenter;
      row.spacing = 12;
      // Grid columns: every label (and every value) as wide as the widest one.
      if (firstName)
      {
        [constraints addObject:[name.widthAnchor constraintEqualToAnchor:firstName.widthAnchor]];
        [constraints addObject:[value.widthAnchor constraintEqualToAnchor:firstValue.widthAnchor]];
      }
      else
      {
        firstName = name;
        firstValue = value;
      }
    }
    row.isAccessibilityElement = YES;
    row.accessibilityLabel = name.text;
    row.accessibilityValue = [NSString stringWithFormat:@"%@, %@", countText, pctText];
    [list addArrangedSubview:row];

    if (i == kLWEUnseenCardLevel)
    {
      UIView *gap = [self _ruleView];
      [list addArrangedSubview:gap];
      [list setCustomSpacing:(stacked ? 12 : 8) afterView:row];
    }
  }
  [NSLayoutConstraint activateConstraints:constraints];
  return list;
}

//! One of a few fixed, localized lines picked from the session state (no numbers in them).
- (NSString *) _encouragementLine
{
  NSInteger learned = ([self.tag.cardLevelCounts count] > kLWELearnedCardLevel) ? [[self.tag.cardLevelCounts objectAtIndex:kLWELearnedCardLevel] integerValue] : 0;
  if (self.tag.cardCount > 0 && learned == self.tag.cardCount)
  {
    return NSLocalizedString(@"You've learned every card in this set.", @"ProgressDetailsViewController.AllLearned");
  }
  if (self.rightCount + self.wrongCount == 0)
  {
    return NSLocalizedString(@"Answer a few cards and this session's counts show up here.", @"ProgressDetailsViewController.NoAnswersYet");
  }
  return NSLocalizedString(@"You're doing great, keep going!", @"ProgressDetailsViewController.Motivation");
}

- (UIView *) _moodView
{
  UIImageView *mascot = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:kLWEProgressMascotImage]] autorelease];
  mascot.translatesAutoresizingMaskIntoConstraints = NO;
  mascot.contentMode = UIViewContentModeScaleAspectFit;
  mascot.isAccessibilityElement = NO;
  [NSLayoutConstraint activateConstraints:@[
    [mascot.widthAnchor constraintEqualToConstant:29],
    [mascot.heightAnchor constraintEqualToConstant:44],
  ]];
  UILabel *line = LWEProgressLabel(LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightMedium, 0), LWEDesignInk2());
  line.text = [self _encouragementLine];
  UIStackView *row = [[[UIStackView alloc] initWithArrangedSubviews:@[mascot, line]] autorelease];
  row.axis = UILayoutConstraintAxisHorizontal;
  row.alignment = UIStackViewAlignmentCenter;
  row.spacing = 12;
  return row;
}

- (void) _buildContent
{
  for (UIView *view in [[_stack.arrangedSubviews copy] autorelease])
  {
    [_stack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  if (self.tag == nil)
  {
    return;
  }
  BOOL stacked = [self _isAccessibilitySize];

  UIView *header = [self _headerView];
  [_stack addArrangedSubview:header];
  UIView *lead = [self _leadView];
  [_stack addArrangedSubview:lead];
  [_stack setCustomSpacing:4 afterView:lead];
  UIView *link = [self _settingsLinkView];
  [_stack addArrangedSubview:link];
  [_stack setCustomSpacing:8 afterView:link];

  // ---- This session: Wrong / Right chips (answer-button colours), then the Streak pill
  UILabel *session = LWEProgressLabel(LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightSemibold, 0), LWEDesignInk());
  session.text = NSLocalizedString(@"This session", @"ProgressDetailsViewController.ThisSession");
  session.accessibilityTraits = UIAccessibilityTraitHeader;
  [_stack addArrangedSubview:session];
  [_stack setCustomSpacing:8 afterView:session];

  UIView *wrong = [self _chipWithTitle:NSLocalizedString(@"Times Wrong", @"ProgressDetailsViewController.TimesWrong")
                                 value:self.wrongCount fill:LWEDesignWrongFill() ink:LWEDesignWrongInk()];
  UIView *right = [self _chipWithTitle:NSLocalizedString(@"Times Right", @"ProgressDetailsViewController.TimesRight")
                                 value:self.rightCount fill:LWEDesignRightFill() ink:LWEDesignRightInk()];
  UIStackView *chips = [[[UIStackView alloc] initWithArrangedSubviews:@[wrong, right]] autorelease];
  chips.axis = stacked ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  chips.distribution = UIStackViewDistributionFillEqually;
  chips.alignment = UIStackViewAlignmentFill;
  chips.spacing = 12;
  [_stack addArrangedSubview:chips];

  NSString *streakValue = nil;
  if (self.wrongStreak > 0)
  {
    streakValue = [NSString stringWithFormat:NSLocalizedString(@"%@ wrong", @"ProgressDetailsViewController.NumWrongStreak"), LWEProgressNumber(self.wrongStreak)];
  }
  else
  {
    streakValue = [NSString stringWithFormat:NSLocalizedString(@"%@ right", @"ProgressDetailsViewController.NumRightStreak"), LWEProgressNumber(self.rightStreak)];
  }
  UIView *streak = [self _pillWithTitle:NSLocalizedString(@"Streak", @"ProgressDetailsViewController.Streak") value:streakValue];
  // Seen: cards in this set answered at least once, ever (total minus Unseen; the same counts the bars use).
  NSString *seenValue = [NSString stringWithFormat:NSLocalizedString(@"%1$@ of %2$@", @"ProgressDetailsViewController.SeenOfTotal"),
                         LWEProgressNumber(self.tag.seenCardCount), LWEProgressNumber(self.tag.cardCount)];
  UIView *seen = [self _pillWithTitle:NSLocalizedString(@"Seen", @"ProgressDetailsViewController.SeenInSet") value:seenValue];
  UIStackView *pills = [[[UIStackView alloc] initWithArrangedSubviews:@[streak, seen]] autorelease];
  pills.axis = stacked ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  pills.alignment = stacked ? UIStackViewAlignmentLeading : UIStackViewAlignmentTop;
  pills.spacing = 8;
  UIStackView *pillRow = [[[UIStackView alloc] initWithArrangedSubviews:@[pills]] autorelease];
  pillRow.alignment = UIStackViewAlignmentLeading; // pills hug their text instead of stretching
  pillRow.axis = UILayoutConstraintAxisVertical;
  [_stack addArrangedSubview:pillRow];

  [_stack addArrangedSubview:[self _ruleView]];
  UIView *levels = [self _levelsView];
  [_stack addArrangedSubview:levels];
  [_stack setCustomSpacing:16 afterView:levels];
  [_stack addArrangedSubview:[self _moodView]];
}

#pragma mark - IBActions

- (void) _dimLink:(UIButton *)sender   { sender.alpha = 0.5; }
- (void) _undimLink:(UIButton *)sender { sender.alpha = 1.0; }

- (IBAction) switchToSettings:(id)sender
{
  // Dismiss first, then switch tabs, so the tab bar isn't changed under a presented sheet.
  NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:SETTINGS_VIEW_CONTROLLER_TAB_INDEX] forKey:@"index"];
  [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
    [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldSwitchTab object:self userInfo:userInfo];
  }];
}

- (IBAction) dismiss
{
  [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Class Plumbing

- (void) dealloc
{
  [tag release];
  [_stack release];
  [_scroll release];
  [super dealloc];
}

@end
