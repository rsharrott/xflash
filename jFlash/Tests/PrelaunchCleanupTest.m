//
//  PrelaunchCleanupTest.m
//  xFlash
//
//  Pre-launch cleanup and reviewer follow-ups, checked in the host app (jFlashTest and cFlashTest are
//  hosted, so [NSBundle mainBundle] is the app and app classes are reachable through the runtime):
//  - jFlash's bundle ID and URL type name are com.japaneseinaflash.jflash, and the URL type still registers the jflash:// / cflash:// scheme
//  - Settings pop-up rows: readings reach the open menu's rows (as subtitles) and are cleared on reuse
//  - the search-result star isn't colour-only (filled symbol + spoken value)
//

#import <XCTest/XCTest.h>
#import "SettingsViewController.h"
#import "SearchViewController.h"

@interface PrelaunchCleanupTest : XCTestCase
@end

@implementation PrelaunchCleanupTest

#pragma mark - Info.plist

- (void) testURLTypeKeepsTheAppScheme
{
  NSArray *urlTypes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
  XCTAssertEqual([urlTypes count], (NSUInteger)1, @"One URL type");
  NSDictionary *type = [urlTypes firstObject];
#if defined(LWE_JFLASH)
  XCTAssertEqualObjects([[NSBundle mainBundle] bundleIdentifier], @"com.japaneseinaflash.jflash", @"Bundle ID is on the japaneseinaflash.com domain");
  XCTAssertEqualObjects([type objectForKey:@"CFBundleURLName"], @"com.japaneseinaflash.jflash", @"URL type named after the bundle ID, not Long Weekend's");
  XCTAssertEqualObjects([type objectForKey:@"CFBundleURLSchemes"], @[@"jflash"], @"jflash:// still opens the app");
#else
  XCTAssertEqualObjects([type objectForKey:@"CFBundleURLSchemes"], @[@"cflash"], @"cflash:// still opens the app");
#endif
}

- (void) testLaunchScreenIsUILaunchScreenNotALaunchImage
{
  NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
  XCTAssertNotNil([info objectForKey:@"UILaunchScreen"], @"UILaunchScreen provides the launch screen");
  XCTAssertNil([info objectForKey:@"UILaunchImages"], @"No asset-catalog launch images are compiled in");
  XCTAssertNil([info objectForKey:@"UILaunchImageFile"]);
}

#pragma mark - Settings pop-up rows (#18 follow-up)

- (LWEMenuSettingCell *) _menuCell
{
  Class cellClass = NSClassFromString(@"LWEMenuSettingCell");
  XCTAssertNotNil(cellClass, @"LWEMenuSettingCell is in the host app");
  return [[[cellClass alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"test"] autorelease];
}

- (void) _configure:(LWEMenuSettingCell *)cell current:(NSString *)current
{
  [cell configureWithTitle:@"Theme"
              optionTitles:@[@"Paper", @"紅", @"藍"]
              optionValues:@[@"PAPER", @"FIRE", @"WATER"]
              currentValue:current
                 tintColor:[UIColor grayColor]
                   handler:nil];
}

- (void) testMenuRowsCarryTheSpokenLabels
{
  LWEMenuSettingCell *cell = [self _menuCell];
  cell.optionAccessibilityLabels = @[[NSNull null], @"くれない", @"あい"];
  [self _configure:cell current:@"FIRE"];
  XCTAssertEqualObjects(cell.menuButton.accessibilityLabel, @"Theme");
  XCTAssertEqualObjects(cell.menuButton.accessibilityValue, @"くれない", @"Button value is the current option's reading");
  NSArray *rows = cell.menuButton.menu.children;
  XCTAssertEqual([rows count], (NSUInteger)3);
  if ([rows count] == 3)
  {
    XCTAssertEqualObjects(((UIAction *)rows[0]).title, @"Paper");
    XCTAssertNil(((UIAction *)rows[0]).subtitle, @"NSNull: no subtitle, the row reads its title");
    XCTAssertEqualObjects(((UIAction *)rows[1]).title, @"紅", @"Visible title unchanged");
    XCTAssertEqualObjects(((UIAction *)rows[1]).subtitle, @"くれない", @"Open-menu row shows and reads the reading");
    XCTAssertEqualObjects(((UIAction *)rows[2]).subtitle, @"あい");
  }
}

- (void) testMenuRowsSkipASubtitleThatRepeatsTheTitle
{
  // en: Fire.accessibility == "Fire", so the row isn't "Fire / Fire"
  LWEMenuSettingCell *cell = [self _menuCell];
  cell.optionAccessibilityLabels = @[[NSNull null], @"Fire", @"Water"];
  [cell configureWithTitle:@"Theme" optionTitles:@[@"Paper", @"Fire", @"Water"] optionValues:@[@"PAPER", @"FIRE", @"WATER"]
              currentValue:@"WATER" tintColor:[UIColor grayColor] handler:nil];
  XCTAssertEqualObjects(cell.menuButton.accessibilityValue, @"Water");
  for (UIAction *row in cell.menuButton.menu.children)
  {
    XCTAssertNil(row.subtitle, @"%@", row.title);
  }
}

- (void) testPrepareForReuseClearsSpokenLabels
{
  LWEMenuSettingCell *cell = [self _menuCell];
  cell.optionAccessibilityLabels = @[[NSNull null], @"くれない", @"あい"];
  [self _configure:cell current:@"WATER"];
  XCTAssertEqualObjects(cell.menuButton.accessibilityValue, @"あい");

  [cell prepareForReuse];
  XCTAssertNil(cell.optionAccessibilityLabels, @"Theme readings don't carry over to the next row");
  XCTAssertNil(cell.menuButton.accessibilityLabel);
  XCTAssertNil(cell.menuButton.accessibilityValue);

  // Reused for a row that sets no labels: everything reads the visible titles
  [cell configureWithTitle:@"Headword" optionTitles:@[@"Japanese", @"English"] optionValues:@[@"J", @"E"]
              currentValue:@"E" tintColor:[UIColor grayColor] handler:nil];
  XCTAssertEqualObjects(cell.menuButton.accessibilityLabel, @"Headword");
  XCTAssertEqualObjects(cell.menuButton.accessibilityValue, @"English", @"Not the old theme reading at index 1");
  for (UIAction *row in cell.menuButton.menu.children)
  {
    XCTAssertNil(row.subtitle, @"%@: no theme reading left over", row.title);
  }
}

#pragma mark - Search-result star

- (void) testSearchStarIsNotColourOnly
{
  XCTAssertEqualObjects(LWESearchStarSymbolName(YES), @"star.fill");
  XCTAssertEqualObjects(LWESearchStarSymbolName(NO), @"star");
  XCTAssertNotNil([UIImage systemImageNamed:LWESearchStarSymbolName(YES)]);
  XCTAssertNotNil([UIImage systemImageNamed:LWESearchStarSymbolName(NO)]);

  UIButton *star = [UIButton buttonWithType:UIButtonTypeCustom];
  LWESearchStarApplyAccessibility(star, YES);
  XCTAssertEqualObjects(star.accessibilityLabel, NSLocalizedString(@"Star", nil));
  XCTAssertEqualObjects(star.accessibilityValue, NSLocalizedString(@"Starred", nil));
  // Reused for an unstarred row: the value changes, it isn't left as "Starred"
  LWESearchStarApplyAccessibility(star, NO);
  XCTAssertEqualObjects(star.accessibilityLabel, NSLocalizedString(@"Star", nil));
  XCTAssertEqualObjects(star.accessibilityValue, NSLocalizedString(@"Not starred", nil));
  XCTAssertNotEqualObjects(NSLocalizedString(@"Starred", nil), NSLocalizedString(@"Not starred", nil));
}

#if defined(LWE_JFLASH)
- (void) testSearchStarStringsAreLocalized
{
  NSBundle *app = [NSBundle mainBundle];
  NSDictionary *expected = @{@"en": @[@"Star", @"Starred", @"Not starred"], @"ja": @[@"スター", @"スター付き", @"スターなし"]};
  for (NSString *lang in expected)
  {
    NSString *path = [app pathForResource:@"Localizable" ofType:@"strings" inDirectory:nil forLocalization:lang];
    NSDictionary *strings = [NSDictionary dictionaryWithContentsOfFile:path];
    XCTAssertNotNil(strings, @"%@ Localizable.strings", lang);
    NSArray *keys = @[@"Star", @"Starred", @"Not starred"];
    for (NSUInteger i = 0; i < [keys count]; i++)
    {
      XCTAssertEqualObjects([strings objectForKey:keys[i]], expected[lang][i], @"%@: %@", lang, keys[i]);
    }
  }
}
#endif

@end
