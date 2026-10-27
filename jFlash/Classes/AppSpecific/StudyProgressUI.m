//
//  StudyProgressUI.m
//  jFlash
//
//  The learned-count ring and the one-time "Your progress lives here" tip.
//  Colours come from ThemeManager slots (the tip's dark bubble is cellLabelInk,
//  the same ink the sheet uses for titles) so every shipping theme follows.
//

#import "StudyProgressUI.h"
#import "LWEDesignTokens.h"
#import "ThemeManager.h"
#import <objc/runtime.h>

#pragma mark - Ring

@implementation LWEProgressRingView
{
  CAShapeLayer *_track;
  CAShapeLayer *_fill;
  CGFloat _fraction;
}

- (id) initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    self.backgroundColor = [UIColor clearColor];
    self.isAccessibilityElement = NO;
    _track = [[CAShapeLayer layer] retain];
    _fill = [[CAShapeLayer layer] retain];
    _track.fillColor = [UIColor clearColor].CGColor;
    _fill.fillColor = [UIColor clearColor].CGColor;
    _track.lineWidth = 2.0;
    _fill.lineWidth = 2.0;
    _fill.lineCap = kCALineCapRound;
    _track.lineCap = kCALineCapRound;
    [self.layer addSublayer:_track];
    [self.layer addSublayer:_fill];
  }
  return self;
}

- (CGFloat) fraction
{
  return _fraction;
}

- (void) setFraction:(CGFloat)fraction
{
  if (fraction < 0.0f) fraction = 0.0f;
  if (fraction > 1.0f) fraction = 1.0f;
  _fraction = fraction;
  _fill.strokeEnd = fraction;
}

- (void) applyTrackColor:(UIColor *)track fillColor:(UIColor *)fill
{
  if (track) _track.strokeColor = track.CGColor;
  if (fill) _fill.strokeColor = fill.CGColor;
}

- (void) layoutSubviews
{
  [super layoutSubviews];
  CGRect b = CGRectInset(self.bounds, 1.0, 1.0);
  CGPoint c = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
  CGFloat radius = MIN(b.size.width, b.size.height) / 2.0;
  UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:c radius:radius startAngle:(CGFloat)-M_PI_2 endAngle:(CGFloat)(M_PI_2 * 3.0) clockwise:YES];
  _track.path = path.CGPath;
  _fill.path = path.CGPath;
  _track.frame = self.bounds;
  _fill.frame = self.bounds;
  _fill.strokeEnd = _fraction;
}

- (void) dealloc
{
  [_track release];
  [_fill release];
  [super dealloc];
}

@end

#pragma mark - Tip

static const CGFloat kLWEProgressTipMargin = 16.0;
static const CGFloat kLWEProgressTipArrowInset = 28.0;
static const CGFloat kLWEProgressTipGap = 12.0;

@interface StudyProgressTipView ()
{
  CGRect _spotlight;
  CAShapeLayer *_dimLayer;
  CAShapeLayer *_outlineLayer;
  UIView *_bubble;
  UIView *_arrow;
  UILabel *_titleLabel;
  UILabel *_bodyLabel;
  BOOL _dismissing;
}
@property (nonatomic, copy) LWEProgressTipSpotlightProvider spotlightProvider;
- (void) _dismiss:(id)sender;
- (void) _dimTapped:(UITapGestureRecognizer *)recognizer;
- (void) _applyThemeColors;
@end

@implementation StudyProgressTipView
@synthesize spotlightProvider;

+ (StudyProgressTipView *) showInView:(UIView *)hostView spotlightProvider:(LWEProgressTipSpotlightProvider)provider
{
  if (hostView == nil) return nil;
  StudyProgressTipView *existing = [StudyProgressTipView tipInView:hostView];
  if (existing) return existing;
  StudyProgressTipView *tip = [[[StudyProgressTipView alloc] initWithFrame:hostView.bounds] autorelease];
  tip.spotlightProvider = provider;
  tip.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  tip.alpha = 0.0;
  [hostView addSubview:tip];
  [tip setNeedsLayout];
  [tip layoutIfNeeded];
  [UIView animateWithDuration:0.25 animations:^{ tip.alpha = 1.0; }];
  UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, tip->_titleLabel);
  return tip;
}

+ (void) setNeedsLayoutInView:(UIView *)hostView
{
  StudyProgressTipView *tip = [StudyProgressTipView tipInView:hostView];
  [tip setNeedsLayout];
}

+ (StudyProgressTipView *) tipInView:(UIView *)hostView
{
  for (UIView *subview in hostView.subviews)
  {
    if ([subview isKindOfClass:[StudyProgressTipView class]]) return (StudyProgressTipView *)subview;
  }
  return nil;
}

- (id) initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    self.backgroundColor = [UIColor clearColor];
    self.accessibilityViewIsModal = YES;

    _dimLayer = [[CAShapeLayer layer] retain];
    _dimLayer.fillRule = kCAFillRuleEvenOdd;
    [self.layer addSublayer:_dimLayer];

    _outlineLayer = [[CAShapeLayer layer] retain];
    _outlineLayer.fillColor = [UIColor clearColor].CGColor;
    _outlineLayer.lineWidth = 2.0;
    [self.layer addSublayer:_outlineLayer];

    _arrow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 16)];
    _arrow.userInteractionEnabled = NO;
    _arrow.isAccessibilityElement = NO;
    _arrow.layer.cornerRadius = 2;
    _arrow.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
    [self addSubview:_arrow];

    _bubble = [[UIView alloc] init];
    _bubble.layer.cornerRadius = 18;
    _bubble.layer.cornerCurve = kCACornerCurveContinuous;
    _bubble.layer.shadowOpacity = 0.28f;
    _bubble.layer.shadowRadius = 18;
    _bubble.layer.shadowOffset = CGSizeMake(0, 10);
    [self addSubview:_bubble];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = NSLocalizedString(@"Your progress lives here", @"StudyProgress.TipTitle");
    _titleLabel.font = LWEDesignScaledFont(UIFontTextStyleHeadline, 17, UIFontWeightBold, 28);
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.numberOfLines = 0;
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [_bubble addSubview:_titleLabel];

    _bodyLabel = [[UILabel alloc] init];
    _bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _bodyLabel.text = NSLocalizedString(@"Tap the level bars, or the count under the card, to see how far along you are in this set.", @"StudyProgress.TipBody");
    _bodyLabel.font = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightRegular, 24);
    _bodyLabel.adjustsFontForContentSizeCategory = YES;
    _bodyLabel.numberOfLines = 0;
    [_bubble addSubview:_bodyLabel];

    NSString *gotTitle = NSLocalizedString(@"Got it", @"FirstRun.GotIt");
    UIButton *got = [UIButton buttonWithType:UIButtonTypeCustom];
    got.translatesAutoresizingMaskIntoConstraints = NO;
    got.accessibilityLabel = gotTitle;
    [got setTitle:gotTitle forState:UIControlStateNormal];
    got.titleLabel.font = LWEDesignScaledFont(UIFontTextStyleBody, 17, UIFontWeightSemibold, 26);
    got.titleLabel.adjustsFontForContentSizeCategory = YES;
    got.titleLabel.adjustsFontSizeToFitWidth = YES;
    got.titleLabel.minimumScaleFactor = 0.7;
    got.layer.cornerRadius = 22;
    got.layer.cornerCurve = kCACornerCurveContinuous;
    [got addTarget:self action:@selector(_dismiss:) forControlEvents:UIControlEventTouchUpInside];
    [_bubble addSubview:got];

    [NSLayoutConstraint activateConstraints:@[
      [_titleLabel.topAnchor constraintEqualToAnchor:_bubble.topAnchor constant:16],
      [_titleLabel.leadingAnchor constraintEqualToAnchor:_bubble.leadingAnchor constant:18],
      [_titleLabel.trailingAnchor constraintEqualToAnchor:_bubble.trailingAnchor constant:-18],
      [_bodyLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6],
      [_bodyLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
      [_bodyLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
      [got.topAnchor constraintEqualToAnchor:_bodyLabel.bottomAnchor constant:14],
      [got.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
      [got.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
      [got.heightAnchor constraintGreaterThanOrEqualToConstant:44],
      [got.bottomAnchor constraintEqualToAnchor:_bubble.bottomAnchor constant:-16],
    ]];

    // Don't cancel the Got it button: the recognizer only dismisses taps outside the bubble.
    UITapGestureRecognizer *tap = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_dimTapped:)] autorelease];
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];
    [self _applyThemeColors];
  }
  return self;
}

- (void) _applyThemeColors
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  UIColor *ink = [tm colorForSlot:@"cellLabelInk"] ?: LWEDesignInk();
  UIColor *paper = [tm colorForSlot:@"showAnswerFill"] ?: LWEDesignPaperRaised();
  UIColor *accent = [tm colorForSlot:@"stripBarFill"] ?: ink;
  _dimLayer.fillColor = [ink colorWithAlphaComponent:0.55].CGColor;
  _outlineLayer.strokeColor = accent.CGColor;
  _bubble.backgroundColor = ink;
  _bubble.layer.shadowColor = ink.CGColor;
  _arrow.backgroundColor = ink;
  _titleLabel.textColor = paper;
  _bodyLabel.textColor = [paper colorWithAlphaComponent:0.92];
  for (UIView *subview in _bubble.subviews)
  {
    if ([subview isKindOfClass:[UIButton class]] == NO) continue;
    UIButton *got = (UIButton *)subview;
    got.backgroundColor = paper;
    [got setTitleColor:ink forState:UIControlStateNormal];
    [got setTitleColor:[ink colorWithAlphaComponent:0.7] forState:UIControlStateHighlighted];
  }
}

- (void) traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  [self setNeedsLayout];
}

- (void) safeAreaInsetsDidChange
{
  [super safeAreaInsetsDidChange];
  [self setNeedsLayout];
}

- (void) layoutSubviews
{
  [super layoutSubviews];
  [self _applyThemeColors];
  CGRect b = self.bounds;
  if (self.spotlightProvider)
  {
    CGRect spot = _spotlight;
    self.spotlightProvider(&spot);
    _spotlight = spot;
  }

  CGFloat radius = 20.0;
  UIBezierPath *dim = [UIBezierPath bezierPathWithRect:b];
  UIBezierPath *hole = [UIBezierPath bezierPathWithRoundedRect:_spotlight cornerRadius:radius];
  [dim appendPath:hole];
  _dimLayer.frame = b;
  _dimLayer.path = dim.CGPath;
  _outlineLayer.frame = b;
  _outlineLayer.path = hole.CGPath;

  CGRect safe = UIEdgeInsetsInsetRect(b, self.safeAreaInsets);
  safe = CGRectInset(safe, kLWEProgressTipMargin, kLWEProgressTipMargin);
  CGFloat bubbleW = MIN(MAX(safe.size.width, 120.0), 420.0);
  CGFloat bubbleX = roundf(CGRectGetMidX(safe) - bubbleW / 2.0f);
  CGSize fit = [_bubble systemLayoutSizeFittingSize:CGSizeMake(bubbleW, UILayoutFittingCompressedSize.height)
                      withHorizontalFittingPriority:UILayoutPriorityRequired
                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
  CGFloat bubbleH = ceilf(fit.height);
  CGFloat belowY = CGRectGetMaxY(_spotlight) + kLWEProgressTipGap;
  CGFloat aboveY = CGRectGetMinY(_spotlight) - kLWEProgressTipGap - bubbleH;
  BOOL fitsBelow = (belowY + bubbleH <= CGRectGetMaxY(safe) + 0.5f);
  BOOL fitsAbove = (aboveY >= CGRectGetMinY(safe) - 0.5f);
  BOOL below = fitsBelow || (fitsAbove == NO);
  CGFloat bubbleY = below ? belowY : aboveY;
  BOOL clamped = NO;
  if (bubbleY + bubbleH > CGRectGetMaxY(safe)) { bubbleY = CGRectGetMaxY(safe) - bubbleH; clamped = YES; }
  if (bubbleY < CGRectGetMinY(safe)) { bubbleY = CGRectGetMinY(safe); clamped = YES; }
  _bubble.frame = CGRectMake(bubbleX, roundf(bubbleY), bubbleW, bubbleH);

  CGFloat anchorX = CGRectGetMidX(_spotlight);
  CGFloat arrowX = MIN(MAX(anchorX, CGRectGetMinX(_bubble.frame) + kLWEProgressTipArrowInset), CGRectGetMaxX(_bubble.frame) - kLWEProgressTipArrowInset);
  CGFloat arrowY = below ? CGRectGetMinY(_bubble.frame) + 1.0f : CGRectGetMaxY(_bubble.frame) - 1.0f;
  _arrow.center = CGPointMake(arrowX, arrowY);
  _arrow.hidden = clamped;
}

- (UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  UIView *hit = [super hitTest:point withEvent:event];
  return hit ?: self;
}

- (void) _dimTapped:(UITapGestureRecognizer *)recognizer
{
  if (CGRectContainsPoint(_bubble.frame, [recognizer locationInView:self]) == NO)
  {
    [self _dismiss:recognizer];
  }
}

- (BOOL) accessibilityPerformEscape
{
  [self _dismiss:nil];
  return YES;
}

- (void) _dismiss:(id)sender
{
  if (_dismissing) return;
  _dismissing = YES;
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  LWEStudyProgressTipMarkShown(settings);
  [settings synchronize];
  self.spotlightProvider = nil;
  [UIView animateWithDuration:0.2 animations:^{
    self.alpha = 0.0;
  } completion:^(BOOL finished) {
    [self removeFromSuperview];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
  }];
}

- (void) clearSpotlightProvider
{
  self.spotlightProvider = nil;
}

- (void) dealloc
{
  [spotlightProvider release];
  [_dimLayer release];
  [_outlineLayer release];
  [_bubble release];
  [_arrow release];
  [_titleLabel release];
  [_bodyLabel release];
  [super dealloc];
}

@end

#pragma mark - Weak holder

@implementation LWEWeakHolder
{
  id _object;
}

- (id) initWithObject:(id)object
{
  self = [super init];
  if (self) objc_storeWeak(&_object, object);
  return self;
}

- (id) object
{
  return objc_loadWeak(&_object);
}

- (void) dealloc
{
  objc_storeWeak(&_object, nil);
  [super dealloc];
}

@end

#pragma mark - Tap pill

@implementation LWETapPillView

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesBegan:touches withEvent:event];
  self.alpha = 0.65;
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesEnded:touches withEvent:event];
  self.alpha = 1.0;
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesCancelled:touches withEvent:event];
  self.alpha = 1.0;
}

@end
