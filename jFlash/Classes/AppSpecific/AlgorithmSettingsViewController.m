//
//  AlgorithmSettingsViewController.m
//  jFlash
//
//  Created by シャロット ロス on 6/9/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "AlgorithmSettingsViewController.h"

#define FREQUENCY_SLIDER_TAG 100
#define MAX_CARDS_SLIDER_TAG 101

enum AlgorithmSections
{
  kPresetSection = 0,
  kCustomSection,          // only while Custom is selected
  kHideLearnedSection
};

enum CustomSectionRows
{
  kMaxCardsRow = 0,
  kFrequencyRow,
  NUM_CUSTOM_ROWS
};

// Easy / Medium / Hard (Custom uses the saved custom values)
static const NSInteger kPresetMaxCards[3] = {10, 30, 40};
static const NSInteger kPresetFrequency[3] = {1, 2, 3};

#pragma mark - LWEStepSlider

//! A UISlider for whole-number settings: VoiceOver swipes move it by one step, and it reads the number.
@interface LWEStepSlider : UISlider
@end

@implementation LWEStepSlider

- (void) _stepBy:(NSInteger)delta
{
  float newValue = roundf(self.value) + (float)delta;
  newValue = MAX(self.minimumValue, MIN(self.maximumValue, newValue));
  if (newValue != self.value)
  {
    self.value = newValue;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
  }
}

- (void) accessibilityIncrement { [self _stepBy:1]; }
- (void) accessibilityDecrement { [self _stepBy:-1]; }

- (NSString *) accessibilityValue
{
  return [NSString stringWithFormat:@"%ld", (long)lroundf(self.value)];
}

@end

#pragma mark - LWESliderSettingCell

/**
 * Title + current value on top, then "min [slider] max". At accessibility text sizes the title and
 * value stack vertically and the end labels move below the slider, so nothing is squeezed or clipped.
 */
@interface LWESliderSettingCell : UITableViewCell
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *valueLabel;
@property (nonatomic, readonly) LWEStepSlider *slider;
- (void) setMinimumText:(NSString *)minText maximumText:(NSString *)maxText;
@end

@interface LWESliderSettingCell ()
{
  UIStackView *_topStack;
  UIStackView *_sliderStack;
  UIStackView *_endLabelsStack;
  UILabel *_minInline, *_maxInline, *_minBelow, *_maxBelow;
}
@end

@implementation LWESliderSettingCell

@synthesize titleLabel = _titleLabel, valueLabel = _valueLabel, slider = _slider;

static UILabel *LWESettingLabel(UIFontTextStyle style)
{
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.font = [UIFont preferredFontForTextStyle:style];
  label.adjustsFontForContentSizeCategory = YES;
  label.numberOfLines = 0;
  return label;
}

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
  if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]))
  {
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _titleLabel = [LWESettingLabel(UIFontTextStyleBody) retain];
    _valueLabel = [LWESettingLabel(UIFontTextStyleTitle2) retain];
    UIFontDescriptor *bold = [_valueLabel.font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    _valueLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2] scaledFontForFont:[UIFont fontWithDescriptor:bold size:0]];
    _valueLabel.textAlignment = NSTextAlignmentNatural;
    _valueLabel.isAccessibilityElement = NO;   // the slider reads its own value
    [_valueLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_valueLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _slider = [[LWEStepSlider alloc] init];
    [_slider setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _minInline = [LWESettingLabel(UIFontTextStyleFootnote) retain];
    _maxInline = [LWESettingLabel(UIFontTextStyleFootnote) retain];
    _minBelow = [LWESettingLabel(UIFontTextStyleFootnote) retain];
    _maxBelow = [LWESettingLabel(UIFontTextStyleFootnote) retain];
    for (UILabel *l in @[_minInline, _maxInline, _minBelow, _maxBelow])
    {
      l.textColor = [UIColor secondaryLabelColor];
      l.isAccessibilityElement = NO;
      [l setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
      [l setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    }
    _minInline.numberOfLines = 1;
    _maxInline.numberOfLines = 1;
    _maxBelow.textAlignment = NSTextAlignmentRight;

    _topStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _valueLabel]];
    _topStack.spacing = 12;
    _topStack.alignment = UIStackViewAlignmentFirstBaseline;

    _sliderStack = [[UIStackView alloc] initWithArrangedSubviews:@[_minInline, _slider, _maxInline]];
    _sliderStack.spacing = 10;
    _sliderStack.alignment = UIStackViewAlignmentCenter;

    _endLabelsStack = [[UIStackView alloc] initWithArrangedSubviews:@[_minBelow, _maxBelow]];
    _endLabelsStack.distribution = UIStackViewDistributionFillEqually;
    _endLabelsStack.spacing = 12;
    _endLabelsStack.alignment = UIStackViewAlignmentTop;

    UIStackView *outer = [[[UIStackView alloc] initWithArrangedSubviews:@[_topStack, _sliderStack, _endLabelsStack]] autorelease];
    outer.axis = UILayoutConstraintAxisVertical;
    outer.spacing = 8;
    outer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:outer];
    UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
      [outer.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
      [outer.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
      [outer.topAnchor constraintEqualToAnchor:margins.topAnchor],
      [outer.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
    ]];
    [self _updateForContentSize:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_contentSizeCategoryDidChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
  }
  return self;
}

- (void) setMinimumText:(NSString *)minText maximumText:(NSString *)maxText
{
  _minInline.text = minText;
  _minBelow.text = minText;
  _maxInline.text = maxText;
  _maxBelow.text = maxText;
}

- (void) _updateForContentSize:(UIContentSizeCategory)category
{
  if (category == nil) category = [UIApplication sharedApplication].preferredContentSizeCategory;
  BOOL large = UIContentSizeCategoryIsAccessibilityCategory(category);
  _topStack.axis = large ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  _topStack.alignment = large ? UIStackViewAlignmentLeading : UIStackViewAlignmentFirstBaseline;
  _minInline.hidden = large;
  _maxInline.hidden = large;
  _endLabelsStack.hidden = !large;
}

- (void) _contentSizeCategoryDidChange:(NSNotification *)notification
{
  [self _updateForContentSize:[notification.userInfo objectForKey:UIContentSizeCategoryNewValueKey]];
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
  [_titleLabel release];
  [_valueLabel release];
  [_slider release];
  [_minInline release];
  [_maxInline release];
  [_minBelow release];
  [_maxBelow release];
  [_topStack release];
  [_sliderStack release];
  [_endLabelsStack release];
  [super dealloc];
}

@end

#pragma mark - AlgorithmSettingsViewController

@interface AlgorithmSettingsViewController ()
- (NSInteger) _difficulty;
- (void) _selectDifficulty:(NSInteger)difficulty;
- (NSString *) _detailForMaxCards:(NSInteger)maxCards frequency:(NSInteger)frequency;
@end

@implementation AlgorithmSettingsViewController

+ (NSString *) displayNameForDifficulty:(NSInteger)difficulty
{
  switch (difficulty)
  {
    case 0: return NSLocalizedString(@"Easy", @"AlgorithmVC.Preset_Easy");
    case 1: return NSLocalizedString(@"Medium", @"AlgorithmVC.Preset_Medium");
    case 2: return NSLocalizedString(@"Hard", @"AlgorithmVC.Preset_Hard");
    default: return NSLocalizedString(@"Custom", @"AlgorithmVC.Preset_Custom");
  }
}

- (id) init
{
  // Built in code (Auto Layout + Dynamic Type); the old AlgorithmSettingsView XIB is no longer used.
  return [super initWithStyle:UITableViewStyleGrouped];
}

#pragma mark - UIViewController Methods

- (void) viewDidLoad
{
  [super viewDidLoad];
  self.navigationItem.title = NSLocalizedString(@"Change Difficulty",@"AlgorithmSettingsViewController.NavBarTitle");
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 60;
  [self.tableView registerClass:[LWESliderSettingCell class] forCellReuseIdentifier:@"slider"];

  // Users who were already on Custom keep their values: copy them into the Custom slots once
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  if ([self _difficulty] == LWE_CUSTOM_DIFFICULTY && [settings objectForKey:APP_CUSTOM_MAX_STUDYING] == nil)
  {
    [settings setInteger:[settings integerForKey:APP_MAX_STUDYING] forKey:APP_CUSTOM_MAX_STUDYING];
    [settings setInteger:[settings integerForKey:APP_FREQUENCY_MULTIPLIER] forKey:APP_CUSTOM_FREQUENCY_MULTIPLIER];
  }
}

- (void) viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  self.tableView.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
}

#pragma mark - Settings

- (NSInteger) _difficulty
{
  NSInteger difficulty = [[NSUserDefaults standardUserDefaults] integerForKey:APP_DIFFICULTY];
  if (difficulty < 0 || difficulty >= LWE_NUM_DIFFICULTIES) difficulty = DEFAULT_DIFFICULTY;
  return difficulty;
}

- (NSInteger) _customMaxCards
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  id value = [settings objectForKey:APP_CUSTOM_MAX_STUDYING];
  NSInteger maxCards = value ? [value integerValue] : [settings integerForKey:APP_MAX_STUDYING];
  return MAX(MIN_MAX_STUDYING, MIN(MAX_MAX_STUDYING, maxCards));
}

- (NSInteger) _customFrequency
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  id value = [settings objectForKey:APP_CUSTOM_FREQUENCY_MULTIPLIER];
  NSInteger frequency = value ? [value integerValue] : [settings integerForKey:APP_FREQUENCY_MULTIPLIER];
  return MAX(MIN_FREQUENCY_MULTIPLIER, MIN(MAX_FREQUENCY_MULTIPLIER, frequency));
}

//! Stores the difficulty and the values the card selector uses. Presets never touch the Custom slots.
- (void) _selectDifficulty:(NSInteger)difficulty
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSInteger oldDifficulty = [self _difficulty];
  if (difficulty == LWE_CUSTOM_DIFFICULTY)
  {
    NSInteger maxCards = [self _customMaxCards];
    NSInteger frequency = [self _customFrequency];
    [settings setInteger:maxCards forKey:APP_CUSTOM_MAX_STUDYING];
    [settings setInteger:frequency forKey:APP_CUSTOM_FREQUENCY_MULTIPLIER];
    [settings setInteger:maxCards forKey:APP_MAX_STUDYING];
    [settings setInteger:frequency forKey:APP_FREQUENCY_MULTIPLIER];
  }
  else
  {
    [settings setInteger:kPresetMaxCards[difficulty] forKey:APP_MAX_STUDYING];
    [settings setInteger:kPresetFrequency[difficulty] forKey:APP_FREQUENCY_MULTIPLIER];
  }
  [settings setInteger:difficulty forKey:APP_DIFFICULTY];

  // Show or hide the sliders, and move the checkmark
  BOOL wasCustom = (oldDifficulty == LWE_CUSTOM_DIFFICULTY);
  BOOL isCustom = (difficulty == LWE_CUSTOM_DIFFICULTY);
  [self.tableView performBatchUpdates:^{
    NSMutableArray *presetRows = [NSMutableArray arrayWithCapacity:LWE_NUM_DIFFICULTIES];
    for (NSInteger row = 0; row < LWE_NUM_DIFFICULTIES; row++)
    {
      [presetRows addObject:[NSIndexPath indexPathForRow:row inSection:kPresetSection]];
    }
    [self.tableView reloadRowsAtIndexPaths:presetRows withRowAnimation:UITableViewRowAnimationNone];
    if (isCustom && !wasCustom)
    {
      [self.tableView insertSections:[NSIndexSet indexSetWithIndex:kCustomSection] withRowAnimation:UITableViewRowAnimationFade];
    }
    else if (wasCustom && !isCustom)
    {
      [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:kCustomSection] withRowAnimation:UITableViewRowAnimationFade];
    }
  } completion:nil];
}

- (NSString *) _detailForMaxCards:(NSInteger)maxCards frequency:(NSInteger)frequency
{
  return [NSString stringWithFormat:NSLocalizedString(@"%ld cards · new cards %ld of 4", @"AlgorithmVC.PresetDetail: study pool size, then new-card frequency (1-4)"),
          (long)maxCards, (long)frequency];
}

//! Maps a table section to our enum (the Custom section is only there while Custom is selected)
- (NSInteger) _sectionKind:(NSInteger)section
{
  if (section == 0) return kPresetSection;
  if ([self _difficulty] == LWE_CUSTOM_DIFFICULTY) return section;
  return kHideLearnedSection;
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
  return ([self _difficulty] == LWE_CUSTOM_DIFFICULTY) ? 3 : 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  switch ([self _sectionKind:section])
  {
    case kPresetSection: return LWE_NUM_DIFFICULTIES;
    case kCustomSection: return NUM_CUSTOM_ROWS;
    default: return 1;
  }
}

- (UITableViewCell *) tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSInteger kind = [self _sectionKind:indexPath.section];
  if (kind == kPresetSection)
  {
    UITableViewCell *cell = [lclTableView dequeueReusableCellWithIdentifier:@"preset"];
    if (cell == nil)
    {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"preset"] autorelease];
      cell.textLabel.numberOfLines = 0;
      cell.detailTextLabel.numberOfLines = 0;
      cell.textLabel.adjustsFontForContentSizeCategory = YES;
      cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
      cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    NSInteger row = indexPath.row;
    BOOL selected = (row == [self _difficulty]);
    cell.textLabel.text = [[self class] displayNameForDifficulty:row];
    UIFont *body = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    if (selected)
    {
      UIFontDescriptor *bold = [body.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
      body = [UIFont fontWithDescriptor:bold size:0];
    }
    cell.textLabel.font = body;
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    if (row == LWE_CUSTOM_DIFFICULTY)
    {
      cell.detailTextLabel.text = [self _detailForMaxCards:[self _customMaxCards] frequency:[self _customFrequency]];
    }
    else
    {
      cell.detailTextLabel.text = [self _detailForMaxCards:kPresetMaxCards[row] frequency:kPresetFrequency[row]];
    }
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.accessibilityTraits = selected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    return cell;
  }
  else if (kind == kCustomSection)
  {
    LWESliderSettingCell *cell = [lclTableView dequeueReusableCellWithIdentifier:@"slider" forIndexPath:indexPath];
    UISlider *slider = cell.slider;
    [slider removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    slider.minimumTrackTintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
    cell.valueLabel.textColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
    if (indexPath.row == kMaxCardsRow)
    {
      cell.titleLabel.text = NSLocalizedString(@"Number of Cards in Study Pool",@"AlgorithmVC.NumberCards");
      slider.tag = MAX_CARDS_SLIDER_TAG;
      slider.minimumValue = MIN_MAX_STUDYING;
      slider.maximumValue = MAX_MAX_STUDYING;
      slider.value = [self _customMaxCards];
      [cell setMinimumText:[NSString stringWithFormat:@"%d", MIN_MAX_STUDYING] maximumText:[NSString stringWithFormat:@"%d", MAX_MAX_STUDYING]];
    }
    else
    {
      cell.titleLabel.text = NSLocalizedString(@"Frequency of New Cards",@"AlgorithmVC.NewCardFrequency");
      slider.tag = FREQUENCY_SLIDER_TAG;
      slider.minimumValue = MIN_FREQUENCY_MULTIPLIER;
      slider.maximumValue = MAX_FREQUENCY_MULTIPLIER;
      slider.value = [self _customFrequency];
      [cell setMinimumText:NSLocalizedString(@"Less Often", @"AlgorithmVC.NewCardFrequency_LessOften")
               maximumText:NSLocalizedString(@"More Often", @"AlgorithmVC.NewCardFrequency_MoreOften")];
    }
    slider.accessibilityLabel = cell.titleLabel.text;
    cell.valueLabel.text = [NSString stringWithFormat:@"%ld", (long)lroundf(slider.value)];
    return cell;
  }
  else
  {
    UITableViewCell *cell = [lclTableView dequeueReusableCellWithIdentifier:@"showBuried"];
    if (cell == nil)
    {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"showBuried"] autorelease];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
      cell.textLabel.adjustsFontForContentSizeCategory = YES;
      UISwitch *switchView = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
      [switchView addTarget:self action:@selector(switchView_eventValueChanged:) forControlEvents:UIControlEventValueChanged];
      cell.accessoryView = switchView;
    }
    cell.textLabel.text = NSLocalizedString(@"Hide Learned Cards",@"AlgorithmVC.HideLearnedCards");
    UISwitch *switchView = (UISwitch *)cell.accessoryView;
    switchView.on = [settings boolForKey:APP_HIDE_BURIED_CARDS];
    switchView.onTintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
    switchView.accessibilityLabel = cell.textLabel.text;
    return cell;
  }
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  switch ([self _sectionKind:section])
  {
    case kPresetSection: return NSLocalizedString(@"Difficulty", @"AlgorithmVC.Difficulty");
    case kCustomSection: return NSLocalizedString(@"Custom", @"AlgorithmVC.Preset_Custom");
    default: return nil;
  }
}

#pragma mark - UITableViewDelegate Methods

- (NSIndexPath *) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  return ([self _sectionKind:indexPath.section] == kPresetSection) ? indexPath : nil;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  if ([self _sectionKind:indexPath.section] == kPresetSection && indexPath.row != [self _difficulty])
  {
    [self _selectDifficulty:indexPath.row];
  }
}

#pragma mark - Slider

//! Snaps to whole steps; writes both the Custom slot and the live value the card selector reads
- (void) sliderValueChanged:(UISlider *)sender
{
  NSInteger value = lroundf(sender.value);
  sender.value = (float)value;

  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  if (sender.tag == MAX_CARDS_SLIDER_TAG)
  {
    value = MAX(MIN_MAX_STUDYING, MIN(MAX_MAX_STUDYING, value));
    if (value == [settings integerForKey:APP_CUSTOM_MAX_STUDYING] && value == [settings integerForKey:APP_MAX_STUDYING]) return;
    [settings setInteger:value forKey:APP_CUSTOM_MAX_STUDYING];
    [settings setInteger:value forKey:APP_MAX_STUDYING];
  }
  else if (sender.tag == FREQUENCY_SLIDER_TAG)
  {
    value = MAX(MIN_FREQUENCY_MULTIPLIER, MIN(MAX_FREQUENCY_MULTIPLIER, value));
    if (value == [settings integerForKey:APP_CUSTOM_FREQUENCY_MULTIPLIER] && value == [settings integerForKey:APP_FREQUENCY_MULTIPLIER]) return;
    [settings setInteger:value forKey:APP_CUSTOM_FREQUENCY_MULTIPLIER];
    [settings setInteger:value forKey:APP_FREQUENCY_MULTIPLIER];
  }

  // Update the number next to the slider and the Custom row's summary, without reloading the slider cell
  for (UITableViewCell *cell in [self.tableView visibleCells])
  {
    if ([cell isKindOfClass:[LWESliderSettingCell class]] && ((LWESliderSettingCell *)cell).slider == sender)
    {
      ((LWESliderSettingCell *)cell).valueLabel.text = [NSString stringWithFormat:@"%ld", (long)value];
    }
  }
  UITableViewCell *customRow = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:LWE_CUSTOM_DIFFICULTY inSection:kPresetSection]];
  customRow.detailTextLabel.text = [self _detailForMaxCards:[self _customMaxCards] frequency:[self _customFrequency]];
}

#pragma mark - UISwitch

- (void) switchView_eventValueChanged:(UISwitch *)switchView
{
  [[NSUserDefaults standardUserDefaults] setBool:[switchView isOn] forKey:APP_HIDE_BURIED_CARDS];
}

@end
