//
//  SettingsViewController.m
//  jFlash
//
//  Created by シャロット ロス on 5/17/09.
//  Copyright 2009 LONG WEEKEND INC. All rights reserved.
//

#import "SettingsViewController.h"
#import "PluginSettingsViewController.h"
#import "AlgorithmSettingsViewController.h"
#import "ReminderSettingsViewController.h"
#import "UserViewController.h"
#import "UserPeer.h"

#import "ChineseSettingsDataSource.h"
#import "JapaneseSettingsDataSource.h"

@implementation SettingsViewController
@synthesize sectionArray, dataSource;
@synthesize downloadManager, pluginManager;

NSString * const APP_ABOUT = @"about";
NSString * const APP_NEW_UPDATE = @"new_update";

#pragma mark -

/**
 * Some might say this shouldn't be here.  Then again, this code will change once per xFlash, so I think it 
 * makes sense to keep it with the settings.  Though, it does have knowledge of its own delegate, at least
 * on its constructor.
 */
- (void) awakeFromNib
{
#if defined(LWE_JFLASH)
  self.dataSource = [[[JapaneseSettingsDataSource alloc] init] autorelease];
#elif defined(LWE_CFLASH)
  self.dataSource = [[[ChineseSettingsDataSource alloc] init] autorelease];
#endif
  
  // Update the badge value now that the outlet to the plugin manager is set
  [self updateBadgeValue];

  // Add an observer on the plugin manager so we can update the available for download badge
  [self.pluginManager addObserver:self forKeyPath:@"downloadablePlugins" options:NSKeyValueObservingOptionNew context:NULL];
}

/** Customized to add support for observers/notifications */
- (void) viewDidLoad
{
  [super viewDidLoad];
  self.sectionArray = [self.dataSource settingsArrayWithPluginManager:self.pluginManager];

  // Rate & share only make sense once the app is on the App Store. Until kAppStoreID
  // is set (see Constants.m) both buttons stay hidden so nobody hits a dead link.
  if (LWEAppStoreURLString())
  {
    UIBarButtonItem *rateUsBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Rate Us",@"SettingsViewController.RateUsButton") style:UIBarButtonItemStylePlain target:self action:@selector(_requestReview)];
    self.navigationItem.leftBarButtonItem = rateUsBtn;
    [rateUsBtn release];

    UIBarButtonItem *shareBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(_shareJFlash)];
    self.navigationItem.rightBarButtonItem = shareBtn;
    [shareBtn release];
  }

  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 60;

  // Shared paper screen (same in every theme): paper-2 behind paper cells, hairline separators
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  self.tableView.backgroundColor = [tm colorForSlot:@"groupedBackground"];
  self.tableView.separatorColor = [tm colorForSlot:@"separator"];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  //Added this in, so that it refreshes it self when the user is going to this Settings view,
  // after the user changes something that is connected with the appearance of this VC
  // (e.g. after they change users, et al)
  self.sectionArray = [self.dataSource settingsArrayWithPluginManager:self.pluginManager];
  [self.tableView reloadData];

  // Show Study Reminders as Off if notifications aren't allowed for the app
  [ReminderSettingsViewController syncReminderSettingWithNotificationPermission:^{
    [self.tableView reloadData];
  }];
}

#pragma mark - Badge

- (void) updateBadgeValue
{
  NSInteger pluginCount = [self.pluginManager.downloadablePlugins count];
  if (pluginCount > 0)
  {
    self.navigationController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%d",pluginCount];
  }
  else
  {
    self.navigationController.tabBarItem.badgeValue = nil;
  }
}


#pragma mark - KVO

//! Monitor the plugin situation and update ourselves accordingly
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"downloadablePlugins"] && [object isKindOfClass:[PluginManager class]])
  {
    // First, update the badge value if necessary
    [self updateBadgeValue];
    
    // Second, reload the table -- chances are something changed that on the plugin row
    self.sectionArray = [self.dataSource settingsArrayWithPluginManager:self.pluginManager];
    [self.tableView reloadData];
  }
}

#pragma mark - Private Methods

//! "Rate Us" is a user-initiated action, so open the App Store's write-a-review page directly
//! (Apple's recommendation for buttons; SKStoreReviewController is rate-limited, may show
//! nothing, and its ObjC API is deprecated in iOS 18).
- (void) _requestReview
{
  NSString *reviewURLString = LWEAppStoreWriteReviewURLString();
  if (reviewURLString == nil)
  {
    return;
  }
  NSURL *reviewURL = [NSURL URLWithString:reviewURLString];
  [[UIApplication sharedApplication] openURL:reviewURL options:@{} completionHandler:nil];
}

- (void) _shareJFlash
{
  [self _shareAppURLString:LWEAppStoreURLString()];
}

//! Presents the share sheet for a store URL; no-op if the string is nil or won't parse (malformed ID)
- (BOOL) _shareAppURLString:(NSString *)appURLString
{
  NSURL *appURL = (appURLString != nil) ? [NSURL URLWithString:appURLString] : nil;
  if (appURL == nil)
  {
    return NO;
  }
  NSArray *sharingItems = @[appURL];
  UIActivityViewController *activityController = [[[UIActivityViewController alloc] initWithActivityItems:sharingItems applicationActivities:nil] autorelease];
  activityController.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
  [self presentViewController:activityController animated:YES completion:nil];
  return YES;
}


//! Stores a value chosen from a row's pop-up menu
- (void) _setValue:(NSString *)value forSetting:(NSString *)setting
{
  [[NSUserDefaults standardUserDefaults] setValue:value forKey:setting];

  // Theme change: retint window + nav bar, refresh tab bar fill, reload rows
  if ([setting isEqualToString:APP_THEME])
  {
    ThemeManager *tm = [ThemeManager sharedThemeManager];
    UIWindow *window = self.view.window;
    window.tintColor = [tm currentThemeTintColor];
    self.navigationController.navigationBar.tintColor = [tm currentThemeTintColor];
    // Re-colour the cream tab bar's selected state (tint); unselected stays paper/ink-2
    UITabBar *tabBar = self.tabBarController.tabBar;
    UITabBarAppearance *app = [[tabBar.standardAppearance copy] autorelease];
    if (app == nil)
    {
      app = [[[UITabBarAppearance alloc] init] autorelease];
      [app configureWithOpaqueBackground];
    }
    app.backgroundColor = [tm colorForSlot:@"tabBarFill"];
    tabBar.standardAppearance = app;
    tabBar.scrollEdgeAppearance = app;
    [self.tableView reloadData];
  }
}


# pragma mark - UITableViewDataSource Methods

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
  return [self.sectionArray count];
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[[self.sectionArray objectAtIndex:section] objectAtIndex:0] count];
}

- (UITableViewCell *)tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  
  // Get our key name and display name
  NSArray *thisSectionArray = [self.sectionArray objectAtIndex:indexPath.section];
  NSString *key = [[thisSectionArray objectAtIndex:1] objectAtIndex:indexPath.row];
  NSString *displayName = [[thisSectionArray objectAtIndex:0] objectAtIndex:indexPath.row];
  
  // Handle special cases first
  if (key == APP_USER)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:APP_USER onTable:lclTableView usingStyle:UITableViewCellStyleValue1];
    cell.detailTextLabel.text = [[UserPeer userWithUserId:[settings integerForKey:APP_USER]] userNickname];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  }
  else if (key == APP_PLUGIN)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:APP_PLUGIN onTable:lclTableView usingStyle:UITableViewCellStyleValue1];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSInteger numInstalled = [self.pluginManager.loadedPlugins count];
    if (numInstalled > 0)
    {
      cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d installed",@"SettingsViewController.Plugins_NumInstalled"),numInstalled];
    }
    else
    {
      cell.detailTextLabel.text = NSLocalizedString(@"None",@"Global.None");
    }
  }
  else if (key == APP_REMINDER)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:APP_REMINDER onTable:lclTableView usingStyle:UITableViewCellStyleValue1];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSNumber *reminderSetting = [settings objectForKey:APP_REMINDER];
    if ([reminderSetting intValue] > 0)
    {
      cell.detailTextLabel.text = NSLocalizedString(@"On",@"Global.On");
    }
    else
    {
      cell.detailTextLabel.text = NSLocalizedString(@"Off",@"Global.Off");
    }
  }
  else if (key == APP_ABOUT)
  {
    // About section
    cell = [LWEUITableUtils reuseCellForIdentifier:APP_ABOUT onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
  }
  else if (key == APP_ALGORITHM)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:APP_ALGORITHM onTable:lclTableView usingStyle:UITableViewCellStyleValue1];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.detailTextLabel.text = [AlgorithmSettingsViewController displayNameForDifficulty:[settings integerForKey:APP_DIFFICULTY]];
  }
	else if (key == APP_NEW_UPDATE)
	{
		cell = [LWEUITableUtils reuseCellForIdentifier:APP_NEW_UPDATE onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;	
	}
  else
  {
    // A setting with a fixed list of values: a pop-up menu showing the current value
    LWEMenuSettingCell *menuCell = [lclTableView dequeueReusableCellWithIdentifier:@"menuSetting"];
    if (menuCell == nil)
    {
      menuCell = [[[LWEMenuSettingCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"menuSetting"] autorelease];
    }
    NSDictionary *names = [self.dataSource.settingsHash objectForKey:key];
    NSArray *values = [self.dataSource.settingsOrder objectForKey:key];
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[values count]];
    for (NSString *value in values)
    {
      [titles addObject:[names objectForKey:value]];
    }
    ThemeManager *tm = [ThemeManager sharedThemeManager];
    id currentValue = [settings objectForKey:key];
    // Unknown/legacy theme keys (e.g. TAME) resolve to the default theme so the menu shows Paper
    if ([key isEqualToString:APP_THEME])
    {
      currentValue = [[tm _currentTheme] objectForKey:@"key"];
    }
    // Theme names that VoiceOver would misread (ja 紅 / 藍) get an explicit reading; other rows use the titles
    NSMutableArray *axLabels = nil;
    if ([key isEqualToString:APP_THEME])
    {
      axLabels = [NSMutableArray arrayWithCapacity:[values count]];
      for (NSString *value in values)
      {
        NSString *ax = [tm accessibilityNameForThemeKey:value];
        [axLabels addObject:(ax ?: (id)[NSNull null])];
      }
    }
    menuCell.optionAccessibilityLabels = axLabels;
    __block SettingsViewController *blockSelf = self;   // MRC: don't retain self from the cell
    // Design: every Settings row value uses muted cellValueInk, never the accent
    [menuCell configureWithTitle:displayName
                    optionTitles:titles
                    optionValues:values
                    currentValue:currentValue
                       tintColor:[tm colorForSlot:@"cellValueInk"]
                         handler:^(id value) {
      [blockSelf _setValue:value forSetting:key];
    }];
    return menuCell;
  }
  
  cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
  cell.textLabel.numberOfLines = 0;
  cell.textLabel.text = displayName;
  return cell;  
}

#pragma mark - UITableViewDelegate Methods



//! Paper cells: paper fill, ink label, muted value (shared by every theme)
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  cell.backgroundColor = [tm colorForSlot:@"cellFill"];
  cell.textLabel.textColor = [tm colorForSlot:@"cellLabelInk"];
  cell.detailTextLabel.textColor = [tm colorForSlot:@"cellValueInk"];
  // #12's menu rows use a custom titleLabel, not textLabel
  if ([cell isKindOfClass:[LWEMenuSettingCell class]])
  {
    ((LWEMenuSettingCell *)cell).titleLabel.textColor = [tm colorForSlot:@"cellLabelInk"];
  }
}

//! Section headers in ink-2 on paper-2
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
  if ([view isKindOfClass:[UITableViewHeaderFooterView class]])
  {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.textColor = [[ThemeManager sharedThemeManager] colorForSlot:@"sectionHeaderInk"];
  }
}

//! Make selection for a table cell
- (void)tableView:(UITableView *)lclTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [lclTableView deselectRowAtIndexPath:indexPath animated:NO];
  
  NSInteger section = indexPath.section;
  NSInteger row = indexPath.row;

  NSArray *thisSectionArray = [self.sectionArray objectAtIndex:section];
  NSString *key = [[thisSectionArray objectAtIndex:1] objectAtIndex:row];

  if (key == APP_USER)
  {
    UserViewController *userView = [[UserViewController alloc] init];
    [self.navigationController pushViewController:userView animated:YES];
    [userView release];
  }
  else if (key == APP_PLUGIN || key == APP_NEW_UPDATE)
  {
		// TODO: iPad customization!
		PluginSettingsViewController *psvc = [[PluginSettingsViewController alloc] initWithNibName:@"PluginSettingsView" bundle:nil];
    psvc.pluginManager = self.pluginManager;
		[self.navigationController pushViewController:psvc animated:YES];
		[psvc release];
  }
  else if (key == APP_ABOUT)
  {
    // Do nothing, about section
  }
  else if (key == APP_REMINDER)
  {
    ReminderSettingsViewController *tmpVC = [[ReminderSettingsViewController alloc] init];
    [self.navigationController pushViewController:tmpVC animated:YES];
    [tmpVC release];
  }
  else if (key == APP_ALGORITHM)
  {
    AlgorithmSettingsViewController *avc = [[AlgorithmSettingsViewController alloc] init];
    [self.navigationController pushViewController:avc animated:YES];
    [avc release];
  }
  // Rows with a fixed list of values are changed from their pop-up menu button, not by tapping the row
}

- (NSString *) tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
  NSArray *thisSectionArray = [self.sectionArray objectAtIndex:section];
  return [thisSectionArray objectAtIndex:2];
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
  NSArray *thisSectionArray = [self.sectionArray objectAtIndex:section];
  NSArray *keys = [thisSectionArray objectAtIndex:1];
  if ([[keys objectAtIndex:0] isEqualToString:APP_ABOUT])
  {
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    return [NSString stringWithFormat:NSLocalizedString(@"Settings: %@, Data: %@, Build: %@", @"SettingsViewController.VersionFooter"),[settings objectForKey:APP_SETTINGS_VERSION],[settings objectForKey:APP_DATA_VERSION],[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
  }
  else
  {
    return nil;
  }
}

# pragma mark - Housekeeping

- (void)dealloc
{
  [self.pluginManager removeObserver:self forKeyPath:@"downloadablePlugins"];
  [pluginManager release];

  [downloadManager release];
  [dataSource release];
  [sectionArray release];
  [super dealloc];
}

@end


#pragma mark - LWEMenuSettingCell

//! The cell's pop-up button. It takes touches anywhere inside touchTargetView (its cell), so
//! UIKit treats a tap on the row title as a tap inside the button and opens the menu.
@interface LWEMenuRowButton : UIButton
@property (nonatomic, assign) UIView *touchTargetView;
@end

@implementation LWEMenuRowButton
@synthesize touchTargetView;

- (BOOL) pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  if (self.touchTargetView != nil)
  {
    CGPoint targetPoint = [self convertPoint:point toView:self.touchTargetView];
    if ([self.touchTargetView pointInside:targetPoint withEvent:event])
    {
      return YES;
    }
  }
  return [super pointInside:point withEvent:event];
}
@end

@interface LWEMenuSettingCell ()
{
  UIStackView *_stack;
  NSArray *_optionTitles;
  NSArray *_optionValues;
  id _currentValue;
  void (^_handler)(id value);
}
- (void) _rebuildMenu;
@end

@implementation LWEMenuSettingCell

@synthesize titleLabel = _titleLabel, menuButton = _menuButton;
@synthesize optionAccessibilityLabels = _optionAccessibilityLabels;

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
  if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]))
  {
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.numberOfLines = 0;
    _titleLabel.isAccessibilityElement = NO;   // the button reads "Title, Value"
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.image = [UIImage systemImageNamed:@"chevron.up.chevron.down"];
    config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleFootnote scale:UIImageSymbolScaleSmall];
    config.imagePlacement = NSDirectionalRectEdgeTrailing;
    config.imagePadding = 4;
    config.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 0);
    config.titleLineBreakMode = NSLineBreakByWordWrapping;
    config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *incoming) {
      NSMutableDictionary *outgoing = [[incoming mutableCopy] autorelease];
      UIFont *body = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
      UIFontDescriptor *semibold = [body.fontDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorTraitsAttribute: @{UIFontWeightTrait: @(UIFontWeightSemibold)}}];
      [outgoing setObject:[UIFont fontWithDescriptor:semibold size:0] forKey:NSFontAttributeName];
      return outgoing;
    };
    _menuButton = [[LWEMenuRowButton buttonWithConfiguration:config primaryAction:nil] retain];
    ((LWEMenuRowButton *)_menuButton).touchTargetView = self;
    _menuButton.showsMenuAsPrimaryAction = YES;
    _menuButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentTrailing;
    [_menuButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_menuButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _stack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _menuButton]];
    _stack.spacing = 8;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_stack];
    UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
      [_stack.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
      [_stack.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
      [_stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
      [_stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],
      [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    [self _updateForContentSize:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_contentSizeCategoryDidChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
  }
  return self;
}

- (void) _updateForContentSize:(UIContentSizeCategory)category
{
  if (category == nil) category = [UIApplication sharedApplication].preferredContentSizeCategory;
  BOOL large = UIContentSizeCategoryIsAccessibilityCategory(category);
  _stack.axis = large ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  _stack.alignment = large ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
  _stack.spacing = large ? 0 : 8;
  UIButtonConfiguration *config = [[_menuButton.configuration copy] autorelease];
  config.contentInsets = large ? NSDirectionalEdgeInsetsMake(4, 0, 8, 0) : NSDirectionalEdgeInsetsMake(8, 8, 8, 0);
  _menuButton.configuration = config;
  _menuButton.contentHorizontalAlignment = large ? UIControlContentHorizontalAlignmentLeading : UIControlContentHorizontalAlignmentTrailing;
}

- (void) _contentSizeCategoryDidChange:(NSNotification *)notification
{
  [self _updateForContentSize:[notification.userInfo objectForKey:UIContentSizeCategoryNewValueKey]];
}

- (void) configureWithTitle:(NSString *)title
                optionTitles:(NSArray *)optionTitles
                optionValues:(NSArray *)optionValues
                currentValue:(id)currentValue
                   tintColor:(UIColor *)tintColor
                     handler:(void (^)(id value))handler
{
  _titleLabel.text = title;
  [_optionTitles release];
  _optionTitles = [optionTitles copy];
  [_optionValues release];
  _optionValues = [optionValues copy];
  [_currentValue release];
  _currentValue = [currentValue retain];
  [_handler release];
  _handler = [handler copy];

  UIButtonConfiguration *config = [[_menuButton.configuration copy] autorelease];
  config.baseForegroundColor = tintColor;
  _menuButton.configuration = config;
  _menuButton.accessibilityLabel = title;
  [self _rebuildMenu];
}

//! Button title = current value; the menu lists every option in order with a checkmark on the current one
- (void) _rebuildMenu
{
  NSString *currentTitle = @"";
  NSString *currentAccessibilityLabel = nil;
  NSMutableArray *actions = [NSMutableArray arrayWithCapacity:[_optionValues count]];
  __block LWEMenuSettingCell *blockSelf = self;
  for (NSUInteger i = 0; i < [_optionValues count]; i++)
  {
    id value = [_optionValues objectAtIndex:i];
    NSString *optionTitle = [_optionTitles objectAtIndex:i];
    BOOL isCurrent = [value isEqual:_currentValue];
    id axLabel = (i < [_optionAccessibilityLabels count]) ? [_optionAccessibilityLabels objectAtIndex:i] : nil;
    if (![axLabel isKindOfClass:[NSString class]]) axLabel = nil;
    if (isCurrent)
    {
      currentTitle = optionTitle;
      currentAccessibilityLabel = axLabel;
    }
    UIAction *action = [UIAction actionWithTitle:optionTitle image:nil identifier:nil handler:^(__kindof UIAction *a) {
      [blockSelf _choose:value];
    }];
    action.state = isCurrent ? UIMenuElementStateOn : UIMenuElementStateOff;
    // The open menu's rows: UIAction has no usable accessibilityLabel (it reads back nil and VoiceOver
    // ignores it), so a reading that differs from the title is shown as the row's subtitle (紅 / くれない).
    // VoiceOver reads the subtitle after the title; it also helps sighted learners.
    if (axLabel && ![axLabel isEqualToString:optionTitle]) action.subtitle = axLabel;
    [actions addObject:action];
  }
  // A stored value that isn't one of the options (old or hand-edited defaults): show the first
  // option rather than an empty button. Nothing is checkmarked, so picking any option fixes it.
  if ([currentTitle length] == 0 && [_optionTitles count] > 0)
  {
    currentTitle = [_optionTitles objectAtIndex:0];
  }
  UIButtonConfiguration *config = [[_menuButton.configuration copy] autorelease];
  config.title = currentTitle;
  _menuButton.configuration = config;
  _menuButton.accessibilityValue = currentAccessibilityLabel ?: currentTitle;
  _menuButton.menu = [UIMenu menuWithTitle:@"" children:actions];
}

//! The whole row is the pop-up button's target: a tap anywhere on the row (title included) opens the menu
- (UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  UIView *hit = [super hitTest:point withEvent:event];
  if (hit != nil && _menuButton.enabled && _menuButton.hidden == NO && [self pointInside:point withEvent:event])
  {
    return _menuButton;
  }
  return hit;
}

//! A reused row must not keep the previous row's spoken labels (e.g. five theme readings mapped by index onto a shorter menu)
- (void) prepareForReuse
{
  [super prepareForReuse];
  self.optionAccessibilityLabels = nil;
  _menuButton.accessibilityLabel = nil;
  _menuButton.accessibilityValue = nil;
}

- (void) _choose:(id)value
{
  if ([value isEqual:_currentValue]) return;
  [_currentValue release];
  _currentValue = [value retain];
  [self _rebuildMenu];
  if (_handler) _handler(value);
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
  [_titleLabel release];
  [_optionAccessibilityLabels release];
  ((LWEMenuRowButton *)_menuButton).touchTargetView = nil;   // the button can outlive the cell (e.g. while its menu is up)
  [_menuButton release];
  [_stack release];
  [_optionTitles release];
  [_optionValues release];
  [_currentValue release];
  [_handler release];
  [super dealloc];
}

@end
