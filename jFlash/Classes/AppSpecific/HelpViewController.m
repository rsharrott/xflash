//
//  HelpViewController.m
//  jFlash
//
//  Created by シャロット ロス on 12/28/09.
//  Copyright 2009 LONG WEEKEND INC.. All rights reserved.
//

#import "HelpViewController.h"
#import "HelpWebViewController.h"

#define SUPPORT_ALERT_CANCEL_IDX 0
#define SUPPORT_ALERT_SITE_IDX 1
#define SUPPORT_ALERT_EMAIL_IDX 2

/**
 * View controller for the user help.
 * Loads a web view controller w/ HTML data when a user
 * selects one of the  cells from the table on this view
 */
@implementation HelpViewController
@synthesize sectionTitles, htmlFilenames;

/**
 * Initializer - sets all of the titles and filenames of the help files.
 */
- (void) viewDidLoad
{
  // Set the tab bar controller image png to the targets
  NSArray *names = [NSArray arrayWithObjects:NSLocalizedString(@"Welcome",@"HelpViewController.Table_Welcome"),
                    NSLocalizedString(@"Study Sets",@"HelpViewController.Table_StudySets"),
                    NSLocalizedString(@"Practice",@"HelpViewController.Table_Practice"),
                    NSLocalizedString(@"Browse Mode",@"HelpViewController.Table_BrowseMode"),
                    NSLocalizedString(@"Search",@"HelpViewController.Table_WordSearch"),
                    NSLocalizedString(@"Corrections",@"HelpViewController.Table_Corrections"),
                    NSLocalizedString(@"Learning Algorithm",@"HelpViewController.Table_LearningAlgorithm"),
                    NSLocalizedString(@"Multiple Users",@"HelpViewController.Table_Sharing"),
                    NSLocalizedString(@"Integration",@"HelpViewController.Table_Integration"),
#if defined (LWE_JFLASH)
                    // The tag glossary is only in JFlash
                    NSLocalizedString(@"Tag Glossary",@"HelpViewController.Table_TagGlossary"),
#endif
                    nil];
  self.sectionTitles = names;
  
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 52;

  UIBarButtonItem *supportBtn = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Ask Us", @"HelpViewController.GetSatsifactionLink")
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self action:@selector(_supportBtnPressed:)] autorelease];
  self.navigationItem.rightBarButtonItem = supportBtn;

  
  // We use absolute sizes though so let the old devices scale the images down.
  self.htmlFilenames = [NSArray arrayWithObjects:@"welcome@2x",
                        @"studysets@2x",
                        @"practice@2x",
                        @"browse@2x",
                        @"search@2x",
                        @"corrections@2x",
                        @"algorithm@2x",
                        @"share@2x",
                        @"integration@2x",
#if defined (LWE_JFLASH)
                        // We only use this in JFlash
                        @"tags@2x",
#endif
                        nil];
  currentIndex = 0;
}

/** Sets the nav bar tint to the current theme and sets the background to our standard */
- (void)viewWillAppear: (BOOL)animated
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
}

#pragma mark - 

/** Changes the help view to the next page */
- (void) navigateToNextHelpPage
{
  NSInteger newIndex = currentIndex + 1;
  // Note that newIndex is a 0-based index, whereas count returns a 1-based count - so we use greater than, not equal
  if (newIndex < [self.htmlFilenames count] && newIndex < [self.sectionTitles count])
  {
    // This SHOULD be the HelpWebViewController - but you never know!
    UIViewController *tmpVC = [self.navigationController topViewController];
    if ([tmpVC respondsToSelector:@selector(loadPageWithBundleFilename:usingTitle:)])
    {
      [tmpVC performSelector:@selector(loadPageWithBundleFilename:usingTitle:) withObject:[self.htmlFilenames objectAtIndex:newIndex] withObject:[self.sectionTitles objectAtIndex:newIndex]];
      currentIndex = newIndex;
      
      // Also figure out if we need to kill the next button if we have gone to the last page
      // Again note that the indices for these two ways of counting are off by 1
      if (currentIndex == ([self.sectionTitles count]-1))
      {
        tmpVC.navigationItem.rightBarButtonItem = nil;
      }
    }
  }
}

#pragma mark - 

- (void) _supportBtnPressed:(id)sender
{
  UIAlertController *alert = [UIAlertController
    alertControllerWithTitle:NSLocalizedString(@"Support", @"HelpViewController.SupportAlertMsgTitle")
                     message:NSLocalizedString(@"Do you have a question?\nA feature request?\n\nVisit our support site or send us an email!", @"HelpViewController.SupportAlertMsgMsg")
              preferredStyle:UIAlertControllerStyleAlert];

#if defined (LWE_JFLASH)
  // Only Japanese in a Flash! has a live support site & privacy policy
  [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Visit Support Site", @"Visit Site")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a) {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:LWE_SUPPORT_URL] options:@{} completionHandler:nil];
  }]];
#endif

  [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Send an Email", @"Mail Us")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a) {
    if ([MFMailComposeViewController canSendMail]) {
      MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
      picker.mailComposeDelegate = self;
      [picker setSubject:@"Please Make This Awesome."];
      [picker setToRecipients:[NSArray arrayWithObjects:LWE_SUPPORT_EMAIL, nil]];
      [self presentViewController:picker animated:YES completion:nil];
      [picker release];
    } else {
      [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Email Not Available", @"emailVM.notAvailable.title")
                                         message:[NSString stringWithFormat:NSLocalizedString(@"It looks like your device isn't set up for Mail yet. You can write to us at %@.", @"emailVM.notAvailable.body"), LWE_SUPPORT_EMAIL]];
    }
  }]];

#if defined (LWE_JFLASH)
  [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Privacy Policy", @"HelpViewController.PrivacyPolicy")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a) {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:LWE_PRIVACY_URL] options:@{} completionHandler:nil];
  }]];
#endif

  [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No Thanks", @"Cancel")
                                           style:UIAlertActionStyleCancel handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - MFMailComposeViewControllerDelegate Methods

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

/** Returns the number of items in array sectionTitles */
- (NSInteger) tableView: (UITableView *) tableView numberOfRowsInSection:(NSInteger)section
{
  return [self.sectionTitles count];
}

/**
 * Creates a cell with default style with an accessory disclosure indicator
 * The text of the cell is held in sectionTitles
 */
- (UITableViewCell *)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  cell = [LWEUITableUtils reuseCellForIdentifier:@"help" onTable:tableView usingStyle:UITableViewCellStyleDefault];
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  cell.selectionStyle = UITableViewCellSelectionStyleGray;
  cell.textLabel.numberOfLines = 0;
  cell.textLabel.text = [self.sectionTitles objectAtIndex:indexPath.row];
  return cell;  
}

#pragma mark - UITableViewDelegate Methods

/** Loads the HelpWebViewController with the selected row's HTML file */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [self.tableView deselectRowAtIndexPath:indexPath animated:NO];

  NSInteger row = indexPath.row;
  currentIndex = row;
  HelpWebViewController *webViewController = [[HelpWebViewController alloc] initWithFilename:[self.htmlFilenames objectAtIndex:row]
                                                                                  usingTitle:[self.sectionTitles objectAtIndex:row]];
  // If there is a next, show the next button - note the array indices are different so we need a -1
  if (currentIndex < ([self.sectionTitles count]-1))
  {
    UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next >",@"HelpViewController.Next") style:UIBarButtonItemStylePlain target:self action:@selector(navigateToNextHelpPage)];
    webViewController.navigationItem.rightBarButtonItem = btn;
    [btn release];
  }
  [self.navigationController pushViewController:webViewController animated:YES];
  [webViewController release];
}

# pragma mark - Class Plumbing

- (void)dealloc
{
  [sectionTitles release];
  [htmlFilenames release];
  [super dealloc];
}

@end