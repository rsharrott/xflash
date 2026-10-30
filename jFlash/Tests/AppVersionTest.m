//
//  AppVersionTest.m
//  xFlash
//
//  The host app's version comes from the MARKETING_VERSION / CURRENT_PROJECT_VERSION build settings
//  (the Info.plists reference them), so App Store Connect's "Manage Version and Build Number" never
//  sees an empty CFBundleShortVersionString / CFBundleVersion. Compiled into jFlashTest and cFlashTest;
//  both are hosted, so [NSBundle mainBundle] is the app under test.
//

#import <XCTest/XCTest.h>

@interface AppVersionTest : XCTestCase
@end

@implementation AppVersionTest

- (NSString *) _infoString:(NSString *)key
{
  id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
  XCTAssertTrue(value == nil || [value isKindOfClass:[NSString class]], @"%@ is a string", key);
  return value;
}

- (void) testShortVersionStringIsSet
{
  NSString *version = [self _infoString:@"CFBundleShortVersionString"];
  XCTAssertTrue([version length] > 0, @"CFBundleShortVersionString is not empty");
  XCTAssertFalse([version containsString:@"$("], @"MARKETING_VERSION was substituted: %@", version);
#if defined(LWE_JFLASH)
  XCTAssertEqualObjects(version, @"1.1", @"Japanese in a Flash launches as 1.1");
#endif
}

- (void) testBundleVersionIsANonEmptyInteger
{
  NSString *build = [self _infoString:@"CFBundleVersion"];
  XCTAssertTrue([build length] > 0, @"CFBundleVersion is not empty");
  NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
  XCTAssertEqual([build rangeOfCharacterFromSet:nonDigits].location, (NSUInteger)NSNotFound, @"CFBundleVersion is an integer: %@", build);
  XCTAssertTrue([build integerValue] > 0, @"CFBundleVersion is a positive integer: %@", build);
}

@end
