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


//! Makes "setting" move to its next state
- (void) iterateSetting: (NSString*) setting
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSDictionary *dict = [self.dataSource.settingsHash objectForKey:setting];
  NSEnumerator *enumerator = [dict keyEnumerator];
  NSString *currentValue = [settings objectForKey:setting];
  NSString *lclKey = nil;
  NSString *nextValue = nil;
  
  // Find current match in the enumeration and return the next object
  while ((lclKey = [enumerator nextObject]))
  {
    if ([lclKey isEqual:currentValue])
    {
      nextValue = [enumerator nextObject];
      break;
    }
  }
  // Now check if we got nothing because we were at the end of the list
  if (nextValue == nil)
  {
    NSEnumerator *tmpEnumerator = [dict keyEnumerator];
    nextValue = [tmpEnumerator nextObject];
  }
  [settings setValue:nextValue forKey:setting];
  
  return;
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
    cell = [LWEUITableUtils reuseCellForIdentifier:APP_ALGORITHM onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
  }
	else if (key == APP_NEW_UPDATE)
	{
		cell = [LWEUITableUtils reuseCellForIdentifier:APP_NEW_UPDATE onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;	
	}
  else
  {
    // Anything else
    cell = [LWEUITableUtils reuseCellForIdentifier:key onTable:lclTableView usingStyle:UITableViewCellStyleValue1];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.detailTextLabel.text = [[self.dataSource.settingsHash objectForKey:key] objectForKey:[settings objectForKey:key]];        
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
    ReminderSettingsViewController *tmpVC = [[ReminderSettingsViewController alloc] initWithNibName:@"ReminderSettingsViewController" bundle:nil];
    [self.navigationController pushViewController:tmpVC animated:YES];
    [tmpVC release];
  }
  else if (key == APP_ALGORITHM)
  {
    AlgorithmSettingsViewController *avc = [[AlgorithmSettingsViewController alloc] init];
    [self.navigationController pushViewController:avc animated:YES];
    [avc release];
  }
  else
  {
    // Everything else
    [self iterateSetting:key];
    [lclTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                        withRowAnimation:UITableViewRowAnimationNone];
    
    // One special case, theme: reload the nav bar for this page
    if ([key isEqualToString:APP_THEME])
    {
      UIWindow *window = self.view.window;
      window.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
      self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
    }
  }
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
    return [NSString stringWithFormat:@"Settings: %@, Data: %@, Build: %@",[settings objectForKey:APP_SETTINGS_VERSION],[settings objectForKey:APP_DATA_VERSION],[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
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