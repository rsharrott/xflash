    //
//  PluginSettingsViewController.m
//  jFlash
//
//  Created by Mark Makdad on 6/3/10.
//  Copyright 2010 Long Weekend Inc. All rights reserved.
//

#import "PluginSettingsViewController.h"
#import "Constants.h"
#import "DSActivityView.h"

#define PLUGIN_SETTINGS_INSTALLED_SECTION 1
#define PLUGIN_SETTINGS_AVAILABLE_SECTION 0

// Private Methods
@interface PluginSettingsViewController()
- (void) _reloadTableData;
- (void)_changeLastUpdateLabel;
@end

@implementation PluginSettingsViewController

@synthesize tableView, availablePlugins, installedPlugins;
@synthesize btnCheckUpdate, lblLastUpdate, pluginManager;

#pragma mark - Check Update Now Button

/**
 * The button check for update will trigger this function, and checks for update
 * with the Plugin Manager. 
 *
 * However, the real method call for updating the available for update list
 * happens in the performCheckUpdateWithLoadingView. The reason is, this method
 * will show the loading screen, and call the other method with the perform
 * selector, with delay. So it allows the iOS to draw the loading screen, and
 * perform the task with the loading screen on top.
 */
- (IBAction) checkUpdatePlugin:(id)sender
{
	//Give the waiting loading screen. It looks a bit messy
	//but its for the sake of it blocks all of the view underneath, so it
	//avoids user clicks the other button while it still loading and
	//perform the checking for update.
  [DSBezelActivityView newActivityViewForView:self.view
                                    withLabel:NSLocalizedString(@"Please Wait",@"PleaseWait")];
	
	[self performSelector:@selector(performCheckUpdateWithLoadingView) withObject:nil afterDelay:0.1f];
}

/**
 * This method will perform the real check update method on the
 * plugin manager.
 */
- (void)performCheckUpdateWithLoadingView
{
  [self _changeLastUpdateLabel];
  [self.pluginManager checkNewPluginsWithCompletion:^(BOOL success) {
    if (success == NO)
    {
      // If we failed to check for plugins, we probably have no network connectivity.
      [LWEUIAlertView noNetworkAlert];
    }
    [self _reloadTableData];
    [DSBezelActivityView removeViewAnimated:YES];
  }];
}

#pragma mark -

//! UIView delegate - sets tint color et al of the nav bar
- (void)viewWillAppear: (BOOL)animated
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  // TODO: iPad customization!
  self.view.backgroundColor = [[ThemeManager sharedThemeManager] backgroundColor];
  self.tableView.backgroundColor = [UIColor clearColor];
}


//! UIView delegate - sets title & creates plugin arrays
- (void)viewDidLoad
{
  [super viewDidLoad];
  self.navigationItem.title = NSLocalizedString(@"Get Updates",@"PluginSettingsViewController.NavBarTitle");
	
	_dateFormatter = [[NSDateFormatter alloc] init];
	[_dateFormatter setDateStyle:NSDateFormatterLongStyle];

  [self _reloadTableData];
	[self _changeLastUpdateLabel];

  CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
  UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 96)];
  headerView.backgroundColor = [UIColor clearColor];
  headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

  self.btnCheckUpdate.frame = CGRectMake(16, 12, screenWidth - 32, 44);
  self.btnCheckUpdate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [headerView addSubview:self.btnCheckUpdate];
  // Nothing to check against while remote plugins are off
  self.btnCheckUpdate.hidden = ([PluginManager remotePluginsEnabled] == NO);

  self.lblLastUpdate.frame = CGRectMake(16, 64, screenWidth - 32, 21);
  self.lblLastUpdate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [headerView addSubview:self.lblLastUpdate];

  self.tableView.tableHeaderView = headerView;
  [headerView release];

  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 52;

  // Set YELLOW, not RED
  NSMutableArray *colors = [NSMutableArray arrayWithCapacity:4];
  UIColor *color = nil;
  //#e4ce9f, 228,206,159 - top of top
  color = [UIColor colorWithRed:0.891 green:0.805 blue:0.621 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  //#efcd64, 239,205,100 - bottom of top
  color = [UIColor colorWithRed:0.933 green:0.8 blue:0.39 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  //#efbc22, 239,188,34 - top of bottom
  color = [UIColor colorWithRed:0.933 green:0.734 blue:0.133 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  //#f6dc24, 246,220,36 - bottom of bottom
  color = [UIColor colorWithRed:0.960 green:0.859 blue:0.141 alpha:1.0];
  [colors addObject:(id)[color CGColor]];
  
  // Watch for plugins installing so we can reload the table
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_pluginDidInstall:) name:LWEPluginDidInstall object:nil];
}

- (void) viewDidUnload
{
  [super viewDidUnload];
  self.tableView = nil;
  self.btnCheckUpdate = nil;
  self.lblLastUpdate = nil;
}

//! Helper method for notification
- (void) _reloadTableData
{
  // Refresh plugin data
  self.installedPlugins = [[self.pluginManager loadedPlugins] allValues];
  self.availablePlugins = [self.pluginManager.downloadablePlugins allValues];
  [self.tableView reloadData];
}

// We used to call the _reloadTableData method above, but this is far sexier
- (void) _pluginDidInstall:(NSNotification *)notification
{
  Plugin *installedPlugin = (Plugin*)notification.object;
  LWE_ASSERT_EXC([installedPlugin isKindOfClass:[Plugin class]], @"WTF Plugin Manager is passing us bogus objs");
  
  NSInteger index = [self.availablePlugins indexOfObject:installedPlugin];
  if (index != NSNotFound)
  {
    // Do the data stuff first - remove
    NSMutableArray *tmpArray = [[self.availablePlugins mutableCopy] autorelease];
    [tmpArray removeObjectAtIndex:index];
    self.availablePlugins = (NSArray*)tmpArray;
    
    // Add to installed
    tmpArray = [[self.installedPlugins mutableCopy] autorelease];
    [tmpArray addObject:installedPlugin];
    self.installedPlugins = (NSArray*)tmpArray;
    
    // What to update
    NSIndexPath *rowToDelete = [NSIndexPath indexPathForRow:index inSection:PLUGIN_SETTINGS_AVAILABLE_SECTION];
    NSIndexPath *rowToInsert = [NSIndexPath indexPathForRow:([self.installedPlugins count] - 1) inSection:PLUGIN_SETTINGS_INSTALLED_SECTION];

    // Now do the table
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:rowToInsert] withRowAnimation:UITableViewRowAnimationLeft];
    [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:rowToDelete] withRowAnimation:UITableViewRowAnimationRight];
    [self.tableView endUpdates];
    
    // In case "available" went to zero, get rid of the title
    [self.tableView reloadSectionIndexTitles];
  }
}


#pragma mark - UITableViewDataSource Methods

//! Hardcoded to 2 - installed and available
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
  return 2;
}

//! Return the number of plugins of each type
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == PLUGIN_SETTINGS_INSTALLED_SECTION)
  {
    return [self.installedPlugins count];
  }
  else
  {
    // section == PLUGIN_SETTINGS_AVAILABLE_SECTION
    return [self.availablePlugins count];
  }
}

//! Makes the table cells
- (UITableViewCell *)tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  if (indexPath.section == PLUGIN_SETTINGS_INSTALLED_SECTION)
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"installed" onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    Plugin *thePlugin = [self.installedPlugins objectAtIndex:indexPath.row];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = thePlugin.name;
  }
  else
  {
    cell = [LWEUITableUtils reuseCellForIdentifier:@"available" onTable:lclTableView usingStyle:UITableViewCellStyleSubtitle];
    Plugin *thePlugin = [self.availablePlugins objectAtIndex:indexPath.row];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = thePlugin.name;
    cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12];    
    cell.detailTextLabel.text = thePlugin.details;
  }

  return cell;  
}

#pragma mark - UITableViewDelegate Methods

//! what to do if selected
- (void)tableView:(UITableView *)lclTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [lclTableView deselectRowAtIndexPath:indexPath animated:YES];
  if (indexPath.section == PLUGIN_SETTINGS_AVAILABLE_SECTION)
  {
    Plugin *plugin = [self.availablePlugins objectAtIndex:indexPath.row];
    [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldShowDownloadModal object:plugin userInfo:nil];
  }
}

//! Get the titles
- (NSString *)tableView: (UITableView*) lclTableView titleForHeaderInSection:(NSInteger)section
{
  NSString *returnVal = nil;
  if (section == PLUGIN_SETTINGS_INSTALLED_SECTION && [self.installedPlugins count])
  {
    returnVal = NSLocalizedString(@"Installed",@"PluginSettingsViewController.TableHeader_Installed");
  }
  else if (section == PLUGIN_SETTINGS_AVAILABLE_SECTION && [self.availablePlugins count])
  {
    returnVal = NSLocalizedString(@"Available (Tap to Download)",@"PluginSettingsViewController.TableHeader_Available");
  }
  return returnVal;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [availablePlugins release];
  [installedPlugins release];
  [btnCheckUpdate release];
  [lblLastUpdate release];
  [_dateFormatter release];

  [super dealloc];
}

#pragma mark - Private methods

//! This is the handy method to retreive the last update date from the user setting, OR update it with the updated date and display it right away (Including the saving back to user setting process)
- (void)_changeLastUpdateLabel
{
	NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
	NSString *str = nil;
	
	NSDate *date = [settings valueForKey:PLUGIN_LAST_UPDATE];
	if ([date isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]])
	{
		str = NSLocalizedString(@"Never",@"NeverUpdated");
	}
	else 
	{
		str = [_dateFormatter stringFromDate:date];
	}
	
  self.lblLastUpdate.text = [NSString stringWithFormat:NSLocalizedString(@"Last update : %@",@"LastUpdate"), str];
  if ([PluginManager remotePluginsEnabled] == NO)
  {
    self.lblLastUpdate.text = NSLocalizedString(@"Online updates are not available right now.",@"PluginSettings.UpdatesUnavailable");
  }
}

@end