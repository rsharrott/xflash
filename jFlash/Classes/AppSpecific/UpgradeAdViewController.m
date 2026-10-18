//
//  UpgradeAdViewController.m
//  xFlash
//
//  Created by Mark Makdad on 6/6/12.
//  Copyright (c) 2012 Long Weekend LLC. All rights reserved.
//

#import "UpgradeAdViewController.h"

@interface UpgradeAdViewController ()
@end

@implementation UpgradeAdViewController

#pragma mark - IBAction Methods

// Default action for when the "Go to the App Store" or equivalent button is pressed
- (IBAction)appStoreBtnPressed:(id)sender
{
  // The old store links (Rikai Browser / legacy jFlash) are no longer on the App Store.
  // Open the new app's page once it has an App Store ID (kAppStoreID in Constants.m).
  NSString *appURL = LWEAppStoreURLString();
  if (appURL)
  {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appURL] options:@{} completionHandler:nil];
  }
  [self dismissViewControllerAnimated:YES completion:nil];
}

// When we want this VC to disappear
- (IBAction)dismissBtnPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIViewController Methods

- (void)viewDidLoad
{
  [super viewDidLoad];
}

@end
