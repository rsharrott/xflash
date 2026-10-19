//
//  AppStoreLinkTest.m
//  xFlash
//
//  App Store links (Rate Us / share): the URL builders, the per-app kAppStoreID,
//  and that Settings only shows its Rate Us + share buttons when the app has an ID.
//  jFlash ships as Apple ID 6817409240; cFlash is not on the App Store, so its ID
//  stays empty and the buttons stay hidden.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "Constants.h"

@interface AppStoreLinkTest : XCTestCase
@end

@implementation AppStoreLinkTest

- (void) testURLForIDBuildsStoreURL
{
  XCTAssertEqualObjects(LWEAppStoreURLStringForID(@"123456789"), @"https://apps.apple.com/app/id123456789");
}

- (void) testURLForEmptyOrNilIDIsNil
{
  XCTAssertNil(LWEAppStoreURLStringForID(@""));
  XCTAssertNil(LWEAppStoreURLStringForID(nil));
}

//! Loads a Settings screen (without its NIB) and returns its nav item
- (UINavigationItem *) _loadedSettingsNavigationItem
{
  Class settingsClass = NSClassFromString(@"SettingsViewController");
  XCTAssertNotNil(settingsClass, @"The host app should provide SettingsViewController");
  UITableViewController *settings = [[settingsClass alloc] initWithStyle:UITableViewStyleGrouped];
  [settings loadViewIfNeeded];
  UINavigationItem *item = settings.navigationItem;
#if !__has_feature(objc_arc)
  [[item retain] autorelease];
  [settings release];
#endif
  return item;
}

#if defined(LWE_JFLASH)

- (void) testJFlashAppStoreID
{
  XCTAssertEqualObjects(kAppStoreID, @"6817409240");
}

- (void) testJFlashStoreURL
{
  XCTAssertEqualObjects(LWEAppStoreURLString(), @"https://apps.apple.com/app/id6817409240");
  XCTAssertNotNil([NSURL URLWithString:LWEAppStoreURLString()]);
}

- (void) testJFlashWriteReviewURL
{
  XCTAssertEqualObjects(LWEAppStoreWriteReviewURLString(), @"https://apps.apple.com/app/id6817409240?action=write-review");
  XCTAssertNotNil([NSURL URLWithString:LWEAppStoreWriteReviewURLString()]);
}

- (void) testJFlashSettingsShowsRateAndShare
{
  UINavigationItem *item = [self _loadedSettingsNavigationItem];
  UIBarButtonItem *rate = item.leftBarButtonItem;
  UIBarButtonItem *share = item.rightBarButtonItem;
  XCTAssertNotNil(rate, @"Rate Us should show once kAppStoreID is set");
  XCTAssertNotNil(share, @"Share should show once kAppStoreID is set");
  XCTAssertEqualObjects(NSStringFromSelector(rate.action), @"_requestReview");
  XCTAssertEqualObjects(NSStringFromSelector(share.action), @"_shareJFlash");
}

#elif defined(LWE_CFLASH)

- (void) testCFlashHasNoAppStoreIDYet
{
  XCTAssertEqualObjects(kAppStoreID, @"");
  XCTAssertNil(LWEAppStoreURLString());
  XCTAssertNil(LWEAppStoreWriteReviewURLString());
}

- (void) testCFlashSettingsHidesRateAndShare
{
  UINavigationItem *item = [self _loadedSettingsNavigationItem];
  XCTAssertNil(item.leftBarButtonItem, @"Rate Us stays hidden without an App Store ID");
  XCTAssertNil(item.rightBarButtonItem, @"Share stays hidden without an App Store ID");
}

#endif

@end
