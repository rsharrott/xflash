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
  NSString *appURL = LWEAppStoreURLString();
  if (appURL == nil)
  {
    return;
  }
  NSURL *reviewURL = [NSURL URLWithString:[appURL stringByAppendingString:@"?action=write-review"]];
  [[UIApplication sharedApplication] openURL:reviewURL options:@{} completionHandler:nil];
}

- (void) _shareJFlash
{
  NSString *appURL = LWEAppStoreURLString();
  if (appURL == nil)
  {
    return;
  }
  NSArray *sharingItems = @[[NSURL URLWithString:appURL]];
  UIActivityViewController *activityController = [[[UIActivityViewController alloc] initWithActivityItems:sharingItems applicationActivities:nil] autorelease];
  activityController.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
  [self presentViewController:activityController animated:YES completion:nil];
}


//! Stores a value chosen from a row's pop-up menu
- (void) _setValue:(NSString *)value forSetting:(NSString *)setting
{
  [[NSUserDefaults standardUserDefaults] setValue:value forKey:setting];

  // One special case, theme: re-tint the window and this page's nav bar
  if ([setting isEqualToString:APP_THEME])
  {
    UIWindow *window = self.view.window;
    window.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
    self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
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
    __block SettingsViewController *blockSelf = self;   // MRC: don't retain self from the cell
    [menuCell configureWithTitle:displayName
                    optionTitles:titles
                    optionValues:values
                    currentValue:[settings objectForKey:key]
                       tintColor:[[ThemeManager sharedThemeManager] currentThemeTintColor]
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
    _menuButton = [[UIButton buttonWithConfiguration:config primaryAction:nil] retain];
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
  NSMutableArray *actions = [NSMutableArray arrayWithCapacity:[_optionValues count]];
  __block LWEMenuSettingCell *blockSelf = self;
  for (NSUInteger i = 0; i < [_optionValues count]; i++)
  {
    id value = [_optionValues objectAtIndex:i];
    NSString *optionTitle = [_optionTitles objectAtIndex:i];
    BOOL isCurrent = [value isEqual:_currentValue];
    if (isCurrent) currentTitle = optionTitle;
    UIAction *action = [UIAction actionWithTitle:optionTitle image:nil identifier:nil handler:^(__kindof UIAction *a) {
      [blockSelf _choose:value];
    }];
    action.state = isCurrent ? UIMenuElementStateOn : UIMenuElementStateOff;
    [actions addObject:action];
  }
  UIButtonConfiguration *config = [[_menuButton.configuration copy] autorelease];
  config.title = currentTitle;
  _menuButton.configuration = config;
  _menuButton.accessibilityValue = currentTitle;
  _menuButton.menu = [UIMenu menuWithTitle:@"" children:actions];
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
  [_menuButton release];
  [_stack release];
  [_optionTitles release];
  [_optionValues release];
  [_currentValue release];
  [_handler release];
  [super dealloc];
}

@end
