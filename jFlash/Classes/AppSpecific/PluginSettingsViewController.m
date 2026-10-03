    //
//  PluginSettingsViewController.m
//  jFlash
//
//  Created by Mark Makdad on 6/3/10.
//  Copyright 2010 Long Weekend Inc. All rights reserved.
//

#import "PluginSettingsViewController.h"
#import "Constants.h"
#define PLUGIN_SETTINGS_INSTALLED_SECTION 0

// Private Methods
@interface PluginSettingsViewController()
- (void) _reloadTableData;
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
  // Kept so the legacy XIB action stays wired. Plugins are no longer fetched online.
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
  self.navigationItem.title = NSLocalizedString(@"Plugins",@"PluginSettingsViewController.NavBarTitle");

  [self _reloadTableData];

  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 52;

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
  self.availablePlugins = [NSArray array];
  [self.tableView reloadData];
}

// We used to call the _reloadTableData method above, but this is far sexier
- (void) _pluginDidInstall:(NSNotification *)notification
{
  [self _reloadTableData];
}


#pragma mark - UITableViewDataSource Methods

//! Installed plugins only. Nothing is offered for download.
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

//! Return the number of plugins of each type
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [self.installedPlugins count];
}

//! Makes the table cells
- (UITableViewCell *)tableView:(UITableView *)lclTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [LWEUITableUtils reuseCellForIdentifier:@"installed" onTable:lclTableView usingStyle:UITableViewCellStyleDefault];
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.accessoryType = UITableViewCellAccessoryCheckmark;
  Plugin *thePlugin = [self.installedPlugins objectAtIndex:indexPath.row];
  cell.textLabel.numberOfLines = 0;
  cell.textLabel.text = thePlugin.name;
  return cell;
}

#pragma mark - UITableViewDelegate Methods

//! what to do if selected
- (void)tableView:(UITableView *)lclTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [lclTableView deselectRowAtIndexPath:indexPath animated:YES];
}

//! Get the titles
- (NSString *)tableView: (UITableView*) lclTableView titleForHeaderInSection:(NSInteger)section
{
  if ([self.installedPlugins count])
  {
    return NSLocalizedString(@"Installed",@"PluginSettingsViewController.TableHeader_Installed");
  }
  return nil;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [availablePlugins release];
  [installedPlugins release];
  [btnCheckUpdate release];
  [lblLastUpdate release];
  [super dealloc];
}

#pragma mark - Private methods

@end