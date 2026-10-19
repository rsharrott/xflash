//
//  AppIconTest.m
//  jFlash
//
//  App icon A ships from the single-size AppIcon set in Images.xcassets (Any / Dark / Tinted).
//  These checks catch a lost ASSETCATALOG_COMPILER_APPICON_NAME or an emptied icon set, which
//  App Store Connect would reject.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>

@interface AppIconTest : XCTestCase
@end

@implementation AppIconTest

- (void)testAppHasPrimaryIconName
{
  NSDictionary *icons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
  NSDictionary *primary = [icons objectForKey:@"CFBundlePrimaryIcon"];
  XCTAssertEqualObjects([primary objectForKey:@"CFBundleIconName"], @"AppIcon",
                        @"jFlash should get its icon from the AppIcon set in Images.xcassets");
}

- (void)testWelcomeIconImageIsBundled
{
  // FirstRunViewController shows [UIImage imageNamed:@"Icon"]; it now comes from Icon.imageset.
  UIImage *icon = [UIImage imageNamed:@"Icon"];
  XCTAssertNotNil(icon);
  XCTAssertEqualWithAccuracy(icon.size.width, 76.0, 0.5);
}

@end
