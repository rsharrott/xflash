//
//  FirstRunViewController.m
//  jFlash
//
//  First-launch welcome sheet + first-card coach hint.
//

#import "FirstRunViewController.h"
#import "LWEDesignTokens.h"

NSString * const LWEFirstRunWelcomeShownKey  = @"firstrun_welcome_shown";
NSString * const LWEFirstRunCardHintShownKey = @"firstrun_card_hint_shown";
NSString * const LWEFirstRunCardHintDidDismissNotification = @"LWEFirstRunCardHintDidDismiss";

#if defined(LWE_JFLASH)

// Starter sets offered on the welcome sheet, in display order, after the user's current
// (default) set.  Each entry is { group_id, tag_id } in the bundled jFlash.db.  Names and
// card counts are read from the database at runtime; rows whose group or tag do not exist
// (e.g. a different database) are skipped.
//   group 16 "Kana Alphabet"         -> tag 200 "Hiragana (1 Basic)"  (also DEFAULT_TAG_ID)
//   group  9 "Survival Japanese"     -> tag 208 "Numbers"
//   group 21 "Common Phrases"        -> tag  73 "Greetings"
//   group 24 "1. Beginner 1 (≈N5)"   -> tag  95 "Beginner 1 (≈N5) 01"
static const NSInteger kLWEStarterSets[][2] = { {16, 200}, {9, 208}, {21, 73}, {24, 95} };

NSInteger LWEStarterSetCount(void)
{
  return (NSInteger)(sizeof(kLWEStarterSets) / sizeof(kLWEStarterSets[0]));
}

void LWEStarterSetAtIndex(NSInteger index, NSInteger *groupId, NSInteger *tagId)
{
  if (index < 0 || index >= LWEStarterSetCount())
  {
    if (groupId) *groupId = 0;
    if (tagId) *tagId = 0;
    return;
  }
  if (groupId) *groupId = kLWEStarterSets[index][0];
  if (tagId) *tagId = kLWEStarterSets[index][1];
}

static NSString *LWEWordCountString(NSInteger count)
{
  if (count == 1)
  {
    return NSLocalizedString(@"1 word", @"FirstRun.OneWord");
  }
  return [NSString stringWithFormat:NSLocalizedString(@"%d words", @"FirstRun.NWords"), (int)count];
}

//! Live card count for a tag, from the same link table the study code reads (the cached
//! tags.count column has been wrong for some system sets in older databases).
static NSInteger LWELiveCardCount(Tag *tag)
{
  NSString *table = ([tag isEditable] || tag.tagId == 0) ? @"card_tag_link" : @"system_card_tag_link";
  NSString *sql = [NSString stringWithFormat:@"SELECT count(card_id) AS total FROM %@ WHERE tag_id = ?", table];
  FMResultSet *rs = [[[LWEDatabase sharedLWEDatabase] dao] executeQuery:sql, [NSNumber numberWithInt:(int)tag.tagId]];
  NSInteger count = -1;
  while ([rs next])
  {
    count = [rs intForColumn:@"total"];
  }
  [rs close];
  return (count >= 0) ? count : tag.cardCount;
}

#pragma mark - Starter row

@interface LWEStarterSetRow : UIControl
{
  UILabel *_titleLabel;
  UILabel *_subtitleLabel;
  UIView *_radio;
  UIImageView *_check;
}
@property (nonatomic, retain) Tag *starterTag;
- (id) initWithTitle:(NSString *)title subtitle:(NSString *)subtitle tag:(Tag *)tag;
@end

@implementation LWEStarterSetRow
@synthesize starterTag;

- (id) initWithTitle:(NSString *)title subtitle:(NSString *)subtitle tag:(Tag *)aTag
{
  self = [super initWithFrame:CGRectZero];
  if (self)
  {
    self.starterTag = aTag;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = title;
    _titleLabel.font = LWEDesignScaledFont(UIFontTextStyleBody, 17, UIFontWeightMedium, 0);
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.textColor = LWEDesignInk();
    _titleLabel.numberOfLines = 0;
    [self addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.text = subtitle;
    _subtitleLabel.font = LWEDesignScaledFont(UIFontTextStyleFootnote, 13, UIFontWeightRegular, 0);
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    _subtitleLabel.textColor = LWEDesignMuted();
    _subtitleLabel.numberOfLines = 0;
    [self addSubview:_subtitleLabel];

    _radio = [[UIView alloc] init];
    _radio.translatesAutoresizingMaskIntoConstraints = NO;
    _radio.userInteractionEnabled = NO;
    _radio.layer.cornerRadius = 12;
    [self addSubview:_radio];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBlack];
    _check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark" withConfiguration:cfg]];
    _check.translatesAutoresizingMaskIntoConstraints = NO;
    _check.tintColor = [UIColor whiteColor];
    [_radio addSubview:_check];

    [NSLayoutConstraint activateConstraints:@[
      [self.heightAnchor constraintGreaterThanOrEqualToConstant:64],
      [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
      [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:11],
      [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_radio.leadingAnchor constant:-12],
      [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
      [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:1],
      [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_radio.leadingAnchor constant:-12],
      [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-11],
      [_radio.widthAnchor constraintEqualToConstant:24],
      [_radio.heightAnchor constraintEqualToConstant:24],
      [_radio.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
      [_radio.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_check.centerXAnchor constraintEqualToAnchor:_radio.centerXAnchor],
      [_check.centerYAnchor constraintEqualToAnchor:_radio.centerYAnchor],
    ]];

    self.isAccessibilityElement = YES;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", title, subtitle];
    [self setSelected:NO];
  }
  return self;
}

- (void) setSelected:(BOOL)selected
{
  [super setSelected:selected];
  self.backgroundColor = selected ? LWEDesignColorHex(0xFDF1EE, 1.0) : [UIColor clearColor];
  _radio.backgroundColor = selected ? LWEDesignFire() : [UIColor clearColor];
  _radio.layer.borderWidth = selected ? 0.0 : 1.7;
  _radio.layer.borderColor = LWEDesignColorHex(0xCFC6B8, 1.0).CGColor;
  _check.hidden = !selected;
  self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
}

- (void) setHighlighted:(BOOL)highlighted
{
  [super setHighlighted:highlighted];
  self.alpha = highlighted ? 0.6 : 1.0;
}

- (void) dealloc
{
  [starterTag release];
  [_titleLabel release];
  [_subtitleLabel release];
  [_check release];
  [_radio release];
  [super dealloc];
}
@end

#pragma mark - Welcome sheet

@interface FirstRunWelcomeViewController ()
{
  NSMutableArray *_rows;
  UISegmentedControl *_readingControl;
  UIButton *_startButton;
  UIActivityIndicatorView *_spinner;
  UIScrollView *_scroll;
  UILabel *_titleLabel;
  UILabel *_footerNote;
  UILabel *_scrollNote;
  UIStackView *_segRow;
  BOOL _finishing;
}
- (void) _rowTapped:(LWEStarterSetRow *)row;
- (void) _selectRow:(LWEStarterSetRow *)row;
- (void) _applyTitle;
- (void) _updateForContentSizeCategory;
+ (BOOL) _tag:(NSInteger)tagId isInGroup:(NSInteger)groupId;
- (NSArray *) _starterSets;
- (UIView *) _iconView;
- (void) _finish;
@end

@implementation FirstRunWelcomeViewController
@synthesize finishedHandler;

+ (BOOL) shouldShowWelcome
{
  // Same first-run condition the old welcome UIAlert used (fresh settings were created on
  // this launch), plus a persisted flag so the sheet can only ever appear once.
  BOOL alreadyShown = [[NSUserDefaults standardUserDefaults] boolForKey:LWEFirstRunWelcomeShownKey];
  return ([[CurrentState sharedCurrentState] isFirstLoad] && alreadyShown == NO);
}

+ (void) markWelcomeShown
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  [settings setBool:YES forKey:LWEFirstRunWelcomeShownKey];
  [settings synchronize];
}

- (id) init
{
  self = [super initWithNibName:nil bundle:nil];
  if (self)
  {
    _rows = [[NSMutableArray alloc] init];
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *))
    {
      UISheetPresentationController *sheet = self.sheetPresentationController;
      sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
      sheet.prefersGrabberVisible = YES;
      sheet.preferredCornerRadius = 36;
    }
  }
  return self;
}

- (void) dealloc
{
  [finishedHandler release];
  [_rows release];
  [_readingControl release];
  [_startButton release];
  [_spinner release];
  [_scroll release];
  [_titleLabel release];
  [_footerNote release];
  [_scrollNote release];
  [_segRow release];
  [super dealloc];
}

//! YES if the system tag is actually filed under that group (group_tag_link), so a renumbered
//! or different database can't put a tag under a heading it does not belong to.
+ (BOOL) _tag:(NSInteger)tagId isInGroup:(NSInteger)groupId
{
  FMResultSet *rs = [[[LWEDatabase sharedLWEDatabase] dao] executeQuery:@"SELECT count(*) AS total FROM group_tag_link WHERE group_id = ? AND tag_id = ?",
                     [NSNumber numberWithInt:(int)groupId], [NSNumber numberWithInt:(int)tagId]];
  NSInteger total = 0;
  while ([rs next])
  {
    total = [rs intForColumn:@"total"];
  }
  [rs close];
  return (total > 0);
}

//! Returns an array of { title, subtitle, Tag } dictionaries read from the database.
- (NSArray *) _starterSets
{
  NSMutableArray *sets = [NSMutableArray array];

  // 1. Whatever is currently active -- on a fresh install that's DEFAULT_TAG_ID (Hiragana Basic).
  Tag *current = [[CurrentState sharedCurrentState] activeTag];
  if (current && current.cardCount > 0)
  {
    [sets addObject:@{ @"title": current.tagName, @"subtitle": LWEWordCountString(LWELiveCardCount(current)), @"tag": current }];
  }

  // 2. Kana, numbers, greetings, and the first approximate-beginner set, if they exist.
  NSInteger numSets = sizeof(kLWEStarterSets) / sizeof(kLWEStarterSets[0]);
  for (NSInteger i = 0; i < numSets; i++)
  {
    Group *group = [GroupPeer retrieveGroupById:kLWEStarterSets[i][0]];
    Tag *tag = [TagPeer retrieveTagById:kLWEStarterSets[i][1]];
    if (group == nil || tag == nil || [tag.tagName length] == 0 || tag.tagId == current.tagId)
    {
      continue;
    }
    if ([FirstRunWelcomeViewController _tag:tag.tagId isInGroup:group.groupId] == NO)
    {
      continue;
    }
    NSInteger count = LWELiveCardCount(tag);
    if (count <= 0)
    {
      continue;
    }
    NSString *subtitle = [NSString stringWithFormat:@"%@ · %@", tag.tagName, LWEWordCountString(count)];
    [sets addObject:@{ @"title": group.groupName, @"subtitle": subtitle, @"tag": tag }];
  }
  return sets;
}

- (UIView *) _iconView
{
  // The app icon, if we can find it in the bundle; otherwise two little flashcards like the mock.
  UIImage *icon = [UIImage imageNamed:@"Icon"];
  UIView *wrap = [[[UIView alloc] init] autorelease];
  wrap.translatesAutoresizingMaskIntoConstraints = NO;
  if (icon)
  {
    UIImageView *iv = [[[UIImageView alloc] initWithImage:icon] autorelease];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.layer.cornerRadius = 17;
    iv.layer.cornerCurve = kCACornerCurveContinuous;
    iv.clipsToBounds = YES;
    wrap.layer.shadowColor = LWEDesignFire().CGColor;
    wrap.layer.shadowOpacity = 0.25;
    wrap.layer.shadowRadius = 9;
    wrap.layer.shadowOffset = CGSizeMake(0, 8);
    [wrap addSubview:iv];
    [NSLayoutConstraint activateConstraints:@[
      [iv.widthAnchor constraintEqualToConstant:76],
      [iv.heightAnchor constraintEqualToConstant:76],
      [iv.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
      [iv.topAnchor constraintEqualToAnchor:wrap.topAnchor],
      [iv.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
      [wrap.widthAnchor constraintEqualToConstant:76],
    ]];
    iv.isAccessibilityElement = NO;
  }
  else
  {
    NSArray *chars = @[@"日", @"海"];
    for (NSInteger i = 0; i < 2; i++)
    {
      UILabel *card = [[[UILabel alloc] initWithFrame:CGRectMake(i == 0 ? 0 : 34, i == 0 ? 4 : 0, 62, 80)] autorelease];
      card.text = chars[i];
      card.textAlignment = NSTextAlignmentCenter;
      card.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
      card.textColor = (i == 0) ? LWEDesignColorHex(0x9A8F80, 1.0) : LWEDesignYellow();
      card.backgroundColor = (i == 0) ? LWEDesignPaper2() : LWEDesignFire();
      card.layer.cornerRadius = 12;
      card.clipsToBounds = YES;
      card.transform = CGAffineTransformMakeRotation((i == 0 ? -8.0 : 5.0) * M_PI / 180.0);
      [wrap addSubview:card];
    }
    [NSLayoutConstraint activateConstraints:@[
      [wrap.widthAnchor constraintEqualToConstant:120],
      [wrap.heightAnchor constraintEqualToConstant:84],
    ]];
  }
  return wrap;
}

- (void) viewDidLoad
{
  [super viewDidLoad];
  self.view.backgroundColor = LWEDesignPaper();
  self.presentationController.delegate = self;

  // ---- Footer: Start studying (+ the note at regular text sizes), pinned above the home indicator.
  // Its title is capped (28pt) so the pinned footer never takes over the sheet at large sizes.
  UIStackView *footer = [[[UIStackView alloc] init] autorelease];
  footer.translatesAutoresizingMaskIntoConstraints = NO;
  footer.axis = UILayoutConstraintAxisVertical;
  footer.spacing = 12;
  footer.layoutMarginsRelativeArrangement = YES;
  footer.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 24, 6, 24);
  [self.view addSubview:footer];

  NSString *startTitle = NSLocalizedString(@"Start studying", @"FirstRun.StartStudying");
  if (@available(iOS 15.0, *))
  {
    UIButtonConfiguration *config = LWEDesignButtonConfiguration(startTitle, LWEDesignFire(), [UIColor whiteColor],
                                                                 UIFontTextStyleBody, 17, UIFontWeightSemibold, 28, 18);
    config.contentInsets = NSDirectionalEdgeInsetsMake(14, 44, 14, 44); // room for the spinner on the right
    _startButton = [[UIButton buttonWithConfiguration:config primaryAction:nil] retain];
  }
  else
  {
    _startButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    _startButton.backgroundColor = LWEDesignFire();
    _startButton.layer.cornerRadius = 18;
    _startButton.titleLabel.font = LWEDesignScaledFont(UIFontTextStyleBody, 17, UIFontWeightSemibold, 28);
    _startButton.titleLabel.numberOfLines = 0;
    _startButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_startButton setTitle:startTitle forState:UIControlStateNormal];
    [_startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_startButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.7] forState:UIControlStateHighlighted];
  }
  _startButton.titleLabel.adjustsFontForContentSizeCategory = YES;
  _startButton.translatesAutoresizingMaskIntoConstraints = NO;
  _startButton.layer.cornerCurve = kCACornerCurveContinuous;
  _startButton.layer.shadowColor = LWEDesignFire().CGColor;
  _startButton.layer.shadowOpacity = 0.25;
  _startButton.layer.shadowRadius = 10;
  _startButton.layer.shadowOffset = CGSizeMake(0, 8);
  [_startButton addTarget:self action:@selector(startStudying:) forControlEvents:UIControlEventTouchUpInside];
  [footer addArrangedSubview:_startButton];

  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _spinner.translatesAutoresizingMaskIntoConstraints = NO;
  _spinner.color = [UIColor whiteColor];
  _spinner.hidesWhenStopped = YES;
  [_startButton addSubview:_spinner];

  NSString *noteText = NSLocalizedString(@"You can switch sets anytime in the Study Sets tab.", @"FirstRun.SwitchSetsNote");
  UILabel *notes[2];
  for (NSInteger i = 0; i < 2; i++)
  {
    UILabel *note = [[UILabel alloc] init];
    note.text = noteText;
    note.font = LWEDesignScaledFont(UIFontTextStyleFootnote, 13, UIFontWeightRegular, 0);
    note.adjustsFontForContentSizeCategory = YES;
    note.textColor = LWEDesignMuted();
    note.textAlignment = NSTextAlignmentCenter;
    note.numberOfLines = 0;
    notes[i] = note;
  }
  _footerNote = notes[0];   // regular sizes: under the button
  _scrollNote = notes[1];   // accessibility sizes: at the end of the scrolling content
  [footer addArrangedSubview:_footerNote];

  // ---- Scrolling content (scrolls when large text makes it taller than the sheet)
  _scroll = [[UIScrollView alloc] init];
  _scroll.translatesAutoresizingMaskIntoConstraints = NO;
  _scroll.alwaysBounceVertical = NO;
  _scroll.showsVerticalScrollIndicator = YES;
  [self.view addSubview:_scroll];

  UIStackView *stack = [[[UIStackView alloc] init] autorelease];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  stack.axis = UILayoutConstraintAxisVertical;
  stack.alignment = UIStackViewAlignmentFill;
  [_scroll addSubview:stack];

  UIView *icon = [self _iconView];
  UIView *iconRow = [[[UIView alloc] init] autorelease];
  [iconRow addSubview:icon];
  [NSLayoutConstraint activateConstraints:@[
    [icon.leadingAnchor constraintEqualToAnchor:iconRow.leadingAnchor],
    [icon.topAnchor constraintEqualToAnchor:iconRow.topAnchor],
    [icon.bottomAnchor constraintEqualToAnchor:iconRow.bottomAnchor],
  ]];
  [stack addArrangedSubview:iconRow];
  [stack setCustomSpacing:20 afterView:iconRow];

  // Title: heavy, with "Flash!" in fire red (rebuilt when the text size changes)
  _titleLabel = [[UILabel alloc] init];
  _titleLabel.numberOfLines = 0;
  _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
  [self _applyTitle];
  [stack addArrangedSubview:_titleLabel];
  [stack setCustomSpacing:10 afterView:_titleLabel];

  UILabel *lede = [[[UILabel alloc] init] autorelease];
  lede.text = NSLocalizedString(@"Flashcards for kanji, kana, and vocabulary. Your decks stay on your phone. No account needed.", @"FirstRun.Lede");
  lede.font = LWEDesignScaledFont(UIFontTextStyleCallout, 16, UIFontWeightRegular, 0);
  lede.adjustsFontForContentSizeCategory = YES;
  lede.textColor = LWEDesignMuted();
  lede.numberOfLines = 0;
  [stack addArrangedSubview:lede];
  [stack setCustomSpacing:30 afterView:lede];

  // Starter set picker
  NSArray *sets = [self _starterSets];
  if ([sets count] > 0)
  {
    UILabel *pick = [[[UILabel alloc] init] autorelease];
    pick.text = NSLocalizedString(@"Pick a starter set", @"FirstRun.PickStarterSet");
    pick.font = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightSemibold, 0);
    pick.adjustsFontForContentSizeCategory = YES;
    pick.numberOfLines = 0;
    pick.textColor = LWEDesignInk();
    pick.accessibilityTraits = UIAccessibilityTraitHeader;
    UIView *pickRow = [[[UIView alloc] init] autorelease];
    pick.translatesAutoresizingMaskIntoConstraints = NO;
    [pickRow addSubview:pick];
    [NSLayoutConstraint activateConstraints:@[
      [pick.leadingAnchor constraintEqualToAnchor:pickRow.leadingAnchor constant:2],
      [pick.trailingAnchor constraintEqualToAnchor:pickRow.trailingAnchor],
      [pick.topAnchor constraintEqualToAnchor:pickRow.topAnchor],
      [pick.bottomAnchor constraintEqualToAnchor:pickRow.bottomAnchor],
    ]];
    [stack addArrangedSubview:pickRow];
    [stack setCustomSpacing:10 afterView:pickRow];

    UIStackView *list = [[[UIStackView alloc] init] autorelease];
    list.axis = UILayoutConstraintAxisVertical;
    list.backgroundColor = [UIColor whiteColor];
    list.layer.cornerRadius = 18;
    list.layer.cornerCurve = kCACornerCurveContinuous;
    list.layer.borderWidth = 1.0;
    list.layer.borderColor = [UIColor colorWithRed:60/255.0 green:40/255.0 blue:20/255.0 alpha:0.07].CGColor;
    list.clipsToBounds = YES;
    for (NSDictionary *set in sets)
    {
      if ([_rows count] > 0)
      {
        UIView *sepWrap = [[[UIView alloc] init] autorelease];
        UIView *sep = [[[UIView alloc] init] autorelease];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        sep.backgroundColor = [UIColor colorWithRed:60/255.0 green:40/255.0 blue:20/255.0 alpha:0.08];
        [sepWrap addSubview:sep];
        [NSLayoutConstraint activateConstraints:@[
          [sepWrap.heightAnchor constraintEqualToConstant:1],
          [sep.leadingAnchor constraintEqualToAnchor:sepWrap.leadingAnchor constant:18],
          [sep.trailingAnchor constraintEqualToAnchor:sepWrap.trailingAnchor],
          [sep.topAnchor constraintEqualToAnchor:sepWrap.topAnchor],
          [sep.bottomAnchor constraintEqualToAnchor:sepWrap.bottomAnchor],
        ]];
        [list addArrangedSubview:sepWrap];
      }
      LWEStarterSetRow *row = [[[LWEStarterSetRow alloc] initWithTitle:set[@"title"] subtitle:set[@"subtitle"] tag:set[@"tag"]] autorelease];
      [row addTarget:self action:@selector(_rowTapped:) forControlEvents:UIControlEventTouchUpInside];
      [list addArrangedSubview:row];
      [_rows addObject:row];
    }
    [stack addArrangedSubview:list];
    [stack setCustomSpacing:24 afterView:list];
    [self _selectRow:[_rows objectAtIndex:0]];
  }

  // Reading mode: maps onto the existing APP_READING setting (KANA / BOTH).  Label and control
  // sit side by side, or stacked at accessibility text sizes.
  _segRow = [[UIStackView alloc] init];
  _segRow.spacing = 8;
  UILabel *segLabel = [[[UILabel alloc] init] autorelease];
  segLabel.text = NSLocalizedString(@"Show readings as", @"FirstRun.ShowReadingsAs");
  segLabel.font = LWEDesignScaledFont(UIFontTextStyleSubheadline, 15, UIFontWeightMedium, 0);
  segLabel.adjustsFontForContentSizeCategory = YES;
  segLabel.numberOfLines = 0;
  segLabel.textColor = LWEDesignInk();
  [segLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [_segRow addArrangedSubview:segLabel];

  _readingControl = [[UISegmentedControl alloc] initWithItems:@[
    NSLocalizedString(@"Kana", @"FirstRun.ReadingKana"),
    NSLocalizedString(@"Kana + romaji", @"FirstRun.ReadingKanaRomaji"),
  ]];
  NSString *reading = [[NSUserDefaults standardUserDefaults] objectForKey:APP_READING];
  _readingControl.selectedSegmentIndex = [reading isEqualToString:SET_READING_KANA] ? 0 : 1;
  _readingControl.backgroundColor = LWEDesignPaper2();
  _readingControl.selectedSegmentTintColor = [UIColor whiteColor];
  _readingControl.apportionsSegmentWidthsByContent = YES;
  // Capped so both segments still fit the sheet width at the largest sizes.
  [_readingControl setTitleTextAttributes:@{ NSFontAttributeName: LWEDesignScaledFont(UIFontTextStyleSubheadline, 14, UIFontWeightMedium, 24),
                                             NSForegroundColorAttributeName: LWEDesignColorHex(0x4A4238, 1.0) } forState:UIControlStateNormal];
  [_readingControl setTitleTextAttributes:@{ NSFontAttributeName: LWEDesignScaledFont(UIFontTextStyleSubheadline, 14, UIFontWeightSemibold, 24),
                                             NSForegroundColorAttributeName: LWEDesignInk() } forState:UIControlStateSelected];
  _readingControl.accessibilityLabel = segLabel.text;
  [_readingControl setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [_readingControl setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [_readingControl.heightAnchor constraintGreaterThanOrEqualToConstant:34].active = YES;
  [_segRow addArrangedSubview:_readingControl];
  [stack addArrangedSubview:_segRow];
  [stack setCustomSpacing:24 afterView:_segRow];
  [stack addArrangedSubview:_scrollNote];

  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [_scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [_scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [_scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [_scroll.bottomAnchor constraintEqualToAnchor:footer.topAnchor],

    [stack.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor constant:34],
    [stack.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor constant:-16],
    [stack.leadingAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.leadingAnchor constant:24],
    [stack.trailingAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.trailingAnchor constant:-24],

    [footer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
    [footer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
    [footer.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    [_startButton.heightAnchor constraintGreaterThanOrEqualToConstant:56],
    [_spinner.trailingAnchor constraintEqualToAnchor:_startButton.trailingAnchor constant:-20],
    [_spinner.centerYAnchor constraintEqualToAnchor:_startButton.centerYAnchor],
  ]];
  [self _updateForContentSizeCategory];
}

- (void) _applyTitle
{
  NSString *titleText = NSLocalizedString(@"Welcome to Japanese in a Flash!", @"StudyViewController.WelcomeAlertViewTitle");
  // Keep "in a Flash!" together on the second line, as in the design.
  titleText = [titleText stringByReplacingOccurrencesOfString:@" in a Flash!" withString:@" in\u00A0a\u00A0Flash!"];
  NSMutableParagraphStyle *titlePara = [[[NSMutableParagraphStyle alloc] init] autorelease];
  titlePara.lineHeightMultiple = 0.95;
  // Capped a little so a word like "Japanese" still fits a 320pt-wide line at the largest size.
  UIFont *font = LWEDesignScaledFont(UIFontTextStyleTitle1, 31, UIFontWeightHeavy, 52);
  NSMutableAttributedString *title = [[[NSMutableAttributedString alloc] initWithString:titleText attributes:@{
    NSFontAttributeName: font,
    NSForegroundColorAttributeName: LWEDesignInk(),
    NSKernAttributeName: @(-0.9),
    NSParagraphStyleAttributeName: titlePara,
  }] autorelease];
  NSRange flash = [titleText rangeOfString:@"Flash!"];
  if (flash.location != NSNotFound)
  {
    [title addAttribute:NSForegroundColorAttributeName value:LWEDesignFire() range:flash];
  }
  _titleLabel.attributedText = title;
}

//! Accessibility text sizes: stack the reading row and move the note into the scrolling content
//! so the pinned footer stays small and the rest of the sheet can scroll.
- (void) _updateForContentSizeCategory
{
  BOOL large = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
  _segRow.axis = large ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  _segRow.alignment = large ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
  _footerNote.hidden = large;
  _scrollNote.hidden = !large;
}

- (void) traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  if ([previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory] == NO)
  {
    [self _applyTitle];
    [self _updateForContentSizeCategory];
  }
}

- (void) viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [FirstRunWelcomeViewController markWelcomeShown];
  // Hint that there's more below when the content is taller than the sheet (large text, or an
  // iPhone SE at the default size).  Flash again once the sheet has settled: the first flash can
  // finish while the sheet is still sliding up, and is easy to miss.
  [_scroll flashScrollIndicators];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    CGFloat visibleH = _scroll.bounds.size.height - _scroll.adjustedContentInset.top - _scroll.adjustedContentInset.bottom;
    if (_scroll.window != nil && _scroll.contentSize.height > visibleH + 1.0)
    {
      [_scroll flashScrollIndicators];
    }
  });
#if defined(LWE_DEBUG)
  // Screenshot hook (Debug builds only): `simctl launch <udid> <bundle> -LWEDebugAutoStartWelcome YES`
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"LWEDebugAutoStartWelcome"])
  {
    // Optionally pick a different starter row first: -LWEDebugStarterRow <index>
    NSInteger debugRow = [[NSUserDefaults standardUserDefaults] integerForKey:@"LWEDebugStarterRow"];
    if (debugRow > 0 && debugRow < (NSInteger)[_rows count])
    {
      [self _selectRow:[_rows objectAtIndex:debugRow]];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self startStudying:nil];
    });
  }
  // -LWEDebugScrollWelcomeToEnd YES: scroll to the bottom (large-text screenshots)
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"LWEDebugScrollWelcomeToEnd"])
  {
    CGFloat maxY = MAX(0, _scroll.contentSize.height - _scroll.bounds.size.height + _scroll.adjustedContentInset.bottom);
    [_scroll setContentOffset:CGPointMake(0, maxY) animated:NO];
  }
#endif
}

#pragma mark - Actions

- (void) _rowTapped:(LWEStarterSetRow *)row
{
  [self _selectRow:row];
}

- (void) _selectRow:(LWEStarterSetRow *)selected
{
  for (LWEStarterSetRow *row in _rows)
  {
    row.selected = (row == selected);
  }
}

- (IBAction) startStudying:(id)sender
{
  if (_finishing)
  {
    return;
  }
  _finishing = YES;

  // 1. Reading mode -> existing APP_READING setting (StudyViewController observes it via KVO)
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSString *reading = (_readingControl.selectedSegmentIndex == 0) ? SET_READING_KANA : SET_READING_BOTH;
  if ([[settings objectForKey:APP_READING] isEqualToString:reading] == NO)
  {
    [settings setValue:reading forKey:APP_READING];
  }

  // 2. Starter set -> same code path the Study Sets tab uses (CurrentState -setActiveTag:completionHandler:)
  Tag *chosen = nil;
  for (LWEStarterSetRow *row in _rows)
  {
    if (row.selected) chosen = row.starterTag;
  }
  CurrentState *state = [CurrentState sharedCurrentState];
  if (chosen && chosen.tagId != state.activeTag.tagId && chosen.cardCount > 0)
  {
    // While the set loads, the sheet can't be swiped away and nothing else can be changed.
    if (@available(iOS 13.0, *))
    {
      self.modalInPresentation = YES;
    }
    // (userInteractionEnabled rather than enabled, so the button keeps its colour behind the spinner)
    _startButton.userInteractionEnabled = NO;
    _readingControl.enabled = NO;
    for (LWEStarterSetRow *row in _rows)
    {
      row.enabled = NO;
    }
    [_spinner startAnimating];
    [state setActiveTag:chosen completionHandler:^{
      [_spinner stopAnimating];
      [self _finish];
    }];
  }
  else
  {
    [self _finish];
  }
}

- (void) _finish
{
  dispatch_block_t handler = [[self.finishedHandler copy] autorelease];
  [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
    if (handler) handler();
  }];
}

#pragma mark - UIAdaptivePresentationControllerDelegate

//! Swiping the sheet away keeps the default set and reading mode.
- (void) presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
  if (self.finishedHandler)
  {
    self.finishedHandler();
  }
}

@end

#pragma mark - Coach hint

static const CGFloat kLWEHintRingRadius   = 40.0;  // the tap ring is 80pt across
static const CGFloat kLWEHintArrowGap     = 14.0;  // ring edge -> bubble
static const CGFloat kLWEHintEdgeMargin   = 16.0;  // bubble <-> safe area edge
static const CGFloat kLWEHintArrowInset   = 30.0;  // arrow stays this far inside the bubble's corners

@interface FirstRunCoachHintView ()
{
  CGRect _spotlight;
  CGPoint _tapPoint;
  CAShapeLayer *_dimLayer;
  CAShapeLayer *_outlineLayer;
  UIView *_ring;
  UIView *_bubble;
  UIView *_arrow;
  BOOL _dismissing;
}
@property (nonatomic, copy) LWECoachHintSpotlightProvider spotlightProvider;
- (void) _dismiss:(id)sender;
- (void) _dimTapped:(UITapGestureRecognizer *)recognizer;
@end

@implementation FirstRunCoachHintView
@synthesize spotlightProvider;

+ (BOOL) shouldShowHint
{
  return ([[NSUserDefaults standardUserDefaults] boolForKey:LWEFirstRunCardHintShownKey] == NO);
}

+ (FirstRunCoachHintView *) showInView:(UIView *)hostView spotlightProvider:(LWECoachHintSpotlightProvider)provider
{
  FirstRunCoachHintView *hint = [[[FirstRunCoachHintView alloc] initWithFrame:hostView.bounds] autorelease];
  hint.spotlightProvider = provider;
  hint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  hint.alpha = 0.0;
  [hostView addSubview:hint];
  [hint setNeedsLayout];
  [hint layoutIfNeeded];
  [UIView animateWithDuration:0.25 animations:^{ hint.alpha = 1.0; }];
  UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, hint->_bubble);
  return hint;
}

+ (void) setNeedsLayoutInView:(UIView *)hostView
{
  for (UIView *subview in hostView.subviews)
  {
    if ([subview isKindOfClass:[FirstRunCoachHintView class]])
    {
      [subview setNeedsLayout];
    }
  }
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
    _dimLayer.fillColor = [UIColor colorWithRed:12/255.0 green:6/255.0 blue:4/255.0 alpha:0.62].CGColor;
    [self.layer addSublayer:_dimLayer];

    _outlineLayer = [[CAShapeLayer layer] retain];
    _outlineLayer.fillColor = [UIColor clearColor].CGColor;
    _outlineLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
    _outlineLayer.lineWidth = 2.0;
    [self.layer addSublayer:_outlineLayer];

    // Tap ring: a dot in two concentric circles
    _ring = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2 * kLWEHintRingRadius, 2 * kLWEHintRingRadius)];
    _ring.userInteractionEnabled = NO;
    UIView *outer = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)] autorelease];
    outer.layer.cornerRadius = 40;
    outer.layer.borderWidth = 1.5;
    outer.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
    [_ring addSubview:outer];
    UIView *inner = [[[UIView alloc] initWithFrame:CGRectMake(12, 12, 56, 56)] autorelease];
    inner.layer.cornerRadius = 28;
    inner.layer.borderWidth = 2.0;
    inner.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.7].CGColor;
    [_ring addSubview:inner];
    UIView *dot = [[[UIView alloc] initWithFrame:CGRectMake(29, 29, 22, 22)] autorelease];
    dot.layer.cornerRadius = 11;
    dot.backgroundColor = [UIColor colorWithWhite:1 alpha:0.85];
    [_ring addSubview:dot];
    [self addSubview:_ring];

    // Tip bubble
    _arrow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, 18)];
    _arrow.backgroundColor = LWEDesignPaper();
    _arrow.layer.cornerRadius = 3;
    _arrow.transform = CGAffineTransformMakeRotation(M_PI_4);
    [self addSubview:_arrow];

    _bubble = [[UIView alloc] init];
    _bubble.backgroundColor = LWEDesignPaper();
    _bubble.layer.cornerRadius = 22;
    _bubble.layer.cornerCurve = kCACornerCurveContinuous;
    _bubble.layer.shadowColor = [UIColor blackColor].CGColor;
    _bubble.layer.shadowOpacity = 0.35;
    _bubble.layer.shadowRadius = 20;
    _bubble.layer.shadowOffset = CGSizeMake(0, 14);
    [self addSubview:_bubble];

    // Dynamic Type, capped so the whole bubble still fits beside the card on a 667pt screen.
    UILabel *text = [[[UILabel alloc] init] autorelease];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.text = NSLocalizedString(@"Tap the card to see the answer, then mark it right or wrong.", @"FirstRun.CardHint");
    text.font = LWEDesignScaledFont(UIFontTextStyleBody, 17, UIFontWeightMedium, 30);
    text.adjustsFontForContentSizeCategory = YES;
    text.textColor = LWEDesignInk();
    text.numberOfLines = 0;
    [_bubble addSubview:text];

    UILabel *step = [[[UILabel alloc] init] autorelease];
    step.translatesAutoresizingMaskIntoConstraints = NO;
    step.text = NSLocalizedString(@"One-time tip", @"FirstRun.OneTimeTip");
    step.font = LWEDesignScaledFont(UIFontTextStyleFootnote, 13, UIFontWeightMedium, 24);
    step.adjustsFontForContentSizeCategory = YES;
    step.textColor = LWEDesignMuted();
    step.numberOfLines = 0;
    [_bubble addSubview:step];

    NSString *gotTitle = NSLocalizedString(@"Got it", @"FirstRun.GotIt");
    UIButton *got = nil;
    if (@available(iOS 15.0, *))
    {
      UIButtonConfiguration *config = LWEDesignButtonConfiguration(gotTitle, LWEDesignFire(), [UIColor whiteColor],
                                                                   UIFontTextStyleCallout, 16, UIFontWeightSemibold, 26, 20);
      config.contentInsets = NSDirectionalEdgeInsetsMake(8, 20, 8, 20);
      got = [UIButton buttonWithConfiguration:config primaryAction:nil];
    }
    else
    {
      got = [UIButton buttonWithType:UIButtonTypeCustom];
      got.backgroundColor = LWEDesignFire();
      got.layer.cornerRadius = 20;
      got.titleLabel.font = LWEDesignScaledFont(UIFontTextStyleCallout, 16, UIFontWeightSemibold, 26);
      [got setTitle:gotTitle forState:UIControlStateNormal];
      [got setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
      [got setTitleColor:[UIColor colorWithWhite:1 alpha:0.7] forState:UIControlStateHighlighted];
      CGSize titleSize = [gotTitle sizeWithAttributes:@{ NSFontAttributeName: got.titleLabel.font }];
      [got.widthAnchor constraintGreaterThanOrEqualToConstant:ceilf(titleSize.width) + 40].active = YES;
    }
    got.titleLabel.adjustsFontForContentSizeCategory = YES;
    got.translatesAutoresizingMaskIntoConstraints = NO;
    [got setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [got addTarget:self action:@selector(_dismiss:) forControlEvents:UIControlEventTouchUpInside];
    [_bubble addSubview:got];

    [NSLayoutConstraint activateConstraints:@[
      [text.topAnchor constraintEqualToAnchor:_bubble.topAnchor constant:18],
      [text.leadingAnchor constraintEqualToAnchor:_bubble.leadingAnchor constant:20],
      [text.trailingAnchor constraintEqualToAnchor:_bubble.trailingAnchor constant:-18],
      [got.topAnchor constraintEqualToAnchor:text.bottomAnchor constant:14],
      [got.trailingAnchor constraintEqualToAnchor:_bubble.trailingAnchor constant:-18],
      [got.heightAnchor constraintGreaterThanOrEqualToConstant:40],
      [got.bottomAnchor constraintEqualToAnchor:_bubble.bottomAnchor constant:-16],
      [step.leadingAnchor constraintEqualToAnchor:text.leadingAnchor],
      [step.trailingAnchor constraintLessThanOrEqualToAnchor:got.leadingAnchor constant:-10],
      [step.centerYAnchor constraintEqualToAnchor:got.centerYAnchor],
      [step.topAnchor constraintGreaterThanOrEqualToAnchor:text.bottomAnchor constant:8],
    ]];

    // A tap anywhere outside the bubble (on the dimmed area or the card) also dismisses.
    UITapGestureRecognizer *tap = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_dimTapped:)] autorelease];
    [self addGestureRecognizer:tap];
  }
  return self;
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
  CGRect b = self.bounds;

  // The card can move (rotation, text size, tab bar / safe-area changes), so ask again each pass.
  if (self.spotlightProvider)
  {
    CGRect spot = _spotlight;
    CGPoint tap = _tapPoint;
    self.spotlightProvider(&spot, &tap);
    _spotlight = spot;
    _tapPoint = tap;
  }

  UIBezierPath *dim = [UIBezierPath bezierPathWithRect:b];
  UIBezierPath *hole = [UIBezierPath bezierPathWithRoundedRect:_spotlight cornerRadius:32];
  [dim appendPath:hole];
  _dimLayer.frame = b;
  _dimLayer.path = dim.CGPath;
  _outlineLayer.frame = b;
  _outlineLayer.path = hole.CGPath;

  _ring.center = _tapPoint;

  // ---- Bubble: centred in the safe area (inset by a margin), below the tap ring if it fits,
  // otherwise above it, otherwise on whichever side has more room, clamped on screen.
  CGRect safe = UIEdgeInsetsInsetRect(b, self.safeAreaInsets);
  safe = CGRectInset(safe, kLWEHintEdgeMargin, kLWEHintEdgeMargin);
  CGFloat bubbleW = MIN(MAX(safe.size.width, 120.0), 420.0);
  CGFloat bubbleX = roundf(CGRectGetMidX(safe) - bubbleW / 2.0);
  CGSize fit = [_bubble systemLayoutSizeFittingSize:CGSizeMake(bubbleW, UILayoutFittingCompressedSize.height)
                      withHorizontalFittingPriority:UILayoutPriorityRequired
                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
  CGFloat bubbleH = ceilf(fit.height);

  CGFloat belowY = _tapPoint.y + kLWEHintRingRadius + kLWEHintArrowGap;
  CGFloat aboveY = _tapPoint.y - kLWEHintRingRadius - kLWEHintArrowGap - bubbleH;
  BOOL fitsBelow = (belowY + bubbleH <= CGRectGetMaxY(safe));
  BOOL fitsAbove = (aboveY >= CGRectGetMinY(safe));
  BOOL below = fitsBelow || (!fitsAbove && (CGRectGetMaxY(safe) - belowY) >= (_tapPoint.y - CGRectGetMinY(safe)));
  CGFloat bubbleY = below ? belowY : aboveY;
  BOOL clamped = NO;
  if (bubbleY + bubbleH > CGRectGetMaxY(safe)) { bubbleY = CGRectGetMaxY(safe) - bubbleH; clamped = YES; }
  if (bubbleY < CGRectGetMinY(safe))           { bubbleY = CGRectGetMinY(safe); clamped = YES; }
  _bubble.frame = CGRectMake(bubbleX, roundf(bubbleY), bubbleW, bubbleH);

  // Arrow on the edge facing the ring, kept inside the bubble's rounded corners.  If the bubble
  // had to be clamped over the ring, the arrow would point nowhere useful, so hide it.
  CGFloat arrowX = MIN(MAX(_tapPoint.x, CGRectGetMinX(_bubble.frame) + kLWEHintArrowInset), CGRectGetMaxX(_bubble.frame) - kLWEHintArrowInset);
  CGFloat arrowY = below ? CGRectGetMinY(_bubble.frame) + 1.0 : CGRectGetMaxY(_bubble.frame) - 1.0;
  _arrow.center = CGPointMake(arrowX, arrowY);
  _arrow.hidden = clamped;
}

//! Swallow all touches so the card isn't revealed underneath the tip.
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

//! VoiceOver two-finger scrub dismisses too.
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
  [settings setBool:YES forKey:LWEFirstRunCardHintShownKey];
  [settings synchronize];
  self.spotlightProvider = nil;
  [UIView animateWithDuration:0.2 animations:^{
    self.alpha = 0.0;
  } completion:^(BOOL finished) {
    [self removeFromSuperview];
    [[NSNotificationCenter defaultCenter] postNotificationName:LWEFirstRunCardHintDidDismissNotification object:nil];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
  }];
}

- (void) dealloc
{
  [spotlightProvider release];
  [_dimLayer release];
  [_outlineLayer release];
  [_ring release];
  [_bubble release];
  [_arrow release];
  [super dealloc];
}

@end

#endif
