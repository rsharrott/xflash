//
//  UpgradeAdViewController.m
//  xFlash
//
//  Created by Mark Makdad on 6/6/12.
//  Copyright (c) 2012 Long Weekend LLC. All rights reserved.
//

#import "UpgradeAdViewController.h"

@interface UpgradeAdViewController ()
- (void) _hideButtonsWithAction:(SEL)action inView:(UIView *)view;
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

  // No App Store ID yet (kAppStoreID in Constants.m is empty), so the
  // "App Store" button would only dismiss -- hide it until there is one.
  if (LWEAppStoreURLString() == nil)
  {
    [self _hideButtonsWithAction:@selector(appStoreBtnPressed:) inView:self.view];
  }
}

// The XIB has no outlet for the App Store button, so find it by its action
- (void) _hideButtonsWithAction:(SEL)action inView:(UIView *)view
{
  for (UIView *subview in view.subviews)
  {
    if ([subview isKindOfClass:[UIControl class]])
    {
      NSArray *actions = [(UIControl *)subview actionsForTarget:self forControlEvent:UIControlEventTouchUpInside];
      if ([actions containsObject:NSStringFromSelector(action)])
      {
        subview.hidden = YES;
      }
    }
    [self _hideButtonsWithAction:action inView:subview];
  }
}

@end
