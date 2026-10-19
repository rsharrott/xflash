//
//  StudySetBadgeAccessibilityTest.m
//  jFlash
//
//  VoiceOver value for the Starred / Recommended badge drawn on Study Sets rows
//  (LWEStudySetBadgeAccessibilityValue / LWEStudySetApplyBadgeAccessibility in StudySetViewController.m).
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "StudySetViewController.h"

@interface StudySetBadgeAccessibilityTest : XCTestCase
@end

@implementation StudySetBadgeAccessibilityTest

#pragma mark - Helpers

//! Localizable.strings of the host app for one localization (en / ja)
- (NSDictionary *) _stringsForLocalization:(NSString *)localization
{
  NSString *path = [[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings" inDirectory:nil forLocalization:localization];
  XCTAssertNotNil(path, @"host app should ship %@.lproj/Localizable.strings", localization);
  return path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
}

#pragma mark - Strings

- (void) testBadgeWordsAreLocalizedInEnglishAndJapanese
{
  NSDictionary *en = [self _stringsForLocalization:@"en"];
  NSDictionary *ja = [self _stringsForLocalization:@"ja"];
  XCTAssertEqualObjects([en objectForKey:@"Starred"], @"Starred");
  XCTAssertEqualObjects([en objectForKey:@"Recommended"], @"Recommended");
  XCTAssertEqualObjects([ja objectForKey:@"Starred"], @"スター付き");
  XCTAssertEqualObjects([ja objectForKey:@"Recommended"], @"おすすめ");
}

#pragma mark - LWEStudySetBadgeAccessibilityValue (en)

- (void) testAnnouncesBadgeOnceWhenTitleDoesNotSayIt
{
  XCTAssertEqualObjects(LWEStudySetBadgeAccessibilityValue(@"JLPT N1~N4", @"Recommended", @"Recommended"), @"Recommended");
  XCTAssertEqualObjects(LWEStudySetBadgeAccessibilityValue(@"Survival Japanese", @"Recommended", @"Recommended"), @"Recommended");
  XCTAssertEqualObjects(LWEStudySetBadgeAccessibilityValue(@"Long Weekend Favorites", @"Starred", @"Starred"), @"Starred");
}

- (void) testSkipsBadgeWhenTitleAlreadySaysIt
{
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"My Starred Words", @"Starred", @"Starred"));
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"Recommended", @"Recommended", @"Recommended"));
}

- (void) testTitleMatchIsCaseInsensitive
{
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"my starred words", @"Starred", @"Starred"));
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"MY STARRED WORDS", @"Starred", @"Starred"));
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"recommended sets", @"Recommended", @"Recommended"));
}

- (void) testNilOrEmptyTitleStillAnnouncesBadge
{
  XCTAssertEqualObjects(LWEStudySetBadgeAccessibilityValue(nil, @"Starred", @"Starred"), @"Starred");
  XCTAssertEqualObjects(LWEStudySetBadgeAccessibilityValue(@"", @"Recommended", @"Recommended"), @"Recommended");
}

#pragma mark - LWEStudySetBadgeAccessibilityValue (ja)

- (void) testJapaneseTitleContainingJapaneseWordSkipsBadge
{
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"スター付きの単語", @"Starred", @"スター付き"));
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"おすすめ", @"Recommended", @"おすすめ"));
}

- (void) testJapaneseBadgeAnnouncedOnceForOtherTitles
{
  XCTAssertEqualObjects(LWEStudySetBadgeAccessibilityValue(@"日本語能力試験", @"Recommended", @"おすすめ"), @"おすすめ");
  XCTAssertEqualObjects(LWEStudySetBadgeAccessibilityValue(@"Long Weekend Favorites", @"Starred", @"スター付き"), @"スター付き");
}

- (void) testEnglishTitleWithJapaneseUIStillSkipsBadge
{
  // Set names come from the database in English, so in the ja UI "My Starred Words" already says it
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"My Starred Words", @"Starred", @"スター付き"));
  XCTAssertNil(LWEStudySetBadgeAccessibilityValue(@"Recommended", @"Recommended", @"おすすめ"));
}

#pragma mark - LWEStudySetApplyBadgeAccessibility (cell reuse)

- (void) testApplySetsValueOnBadgedRow
{
  UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"group"] autorelease];
  LWEStudySetApplyBadgeAccessibility(cell, YES, @"JLPT N1~N4", @"Recommended", @"Recommended");
  XCTAssertEqualObjects(cell.accessibilityValue, @"Recommended");
}

- (void) testApplyClearsValueWhenReusedForRowWithoutBadge
{
  UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"group"] autorelease];
  LWEStudySetApplyBadgeAccessibility(cell, YES, @"JLPT N1~N4", @"Recommended", @"Recommended");
  XCTAssertEqualObjects(cell.accessibilityValue, @"Recommended");
  // Same cell reused for a plain group
  LWEStudySetApplyBadgeAccessibility(cell, NO, @"Common Words", @"Recommended", @"Recommended");
  XCTAssertNil(cell.accessibilityValue);
}

- (void) testApplyClearsValueWhenReusedForTitleThatSaysIt
{
  UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"normal"] autorelease];
  LWEStudySetApplyBadgeAccessibility(cell, YES, @"Long Weekend Favorites", @"Starred", @"Starred");
  XCTAssertEqualObjects(cell.accessibilityValue, @"Starred");
  LWEStudySetApplyBadgeAccessibility(cell, YES, @"My Starred Words", @"Starred", @"Starred");
  XCTAssertNil(cell.accessibilityValue);
}

@end
