//
//  AppBundleResourcesTest.m
//  xFlash
//
//  Build-config files must not ship inside the app. jFlash used to copy Entitlements.plist (get-task-allow = false,
//  also set as CODE_SIGN_ENTITLEMENTS) into its bundle; it was removed because Xcode now injects get-task-allow
//  itself and the stale value broke signing with development profiles. jFlashTest and cFlashTest are hosted, so
//  [NSBundle mainBundle] is the app under test.
//
//  Note: an incremental build into old DerivedData can leave a previously copied Entitlements.plist in the .app;
//  clean the build folder if this fails right after pulling.
//

#import <XCTest/XCTest.h>

@interface AppBundleResourcesTest : XCTestCase
@end

@implementation AppBundleResourcesTest

- (void)testAppBundleHasNoEntitlementsPlist
{
  NSBundle *app = [NSBundle mainBundle];
  XCTAssertTrue([[app bundlePath] hasSuffix:@".app"], @"tests should run hosted in the app, got %@", [app bundlePath]);
  XCTAssertNil([app pathForResource:@"Entitlements" ofType:@"plist"],
               @"Entitlements.plist is a code-signing input and must not be copied into the app bundle");
}

@end
