//
//  CFlashAccessibilityTest.m
//  xFlash
//
//  Chinese Flash versions of the PR #28 accessibility tests (jFlash: CardReadingTest.m): the score
//  bubble (including Browse mode), the study progress strip, Reduce Motion, list contrast, the Study
//  Sets nav bar and the reveal's scroll-indicator flash.  The practice bar's "Learned" label is not
//  covered: Chinese Flash keeps the original icon bar (ActionBarViewController -viewDidLoad).
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "CardViewController.h"
#import "PracticeModeCardViewDelegate.h"
#import "ChineseCard.h"
#import "MoodIcon.h"
#import "StudyViewController.h"
#import "ProgressBarViewController.h"
#import "StudySetViewController.h"
#import "ThemeManager.h"

//! Stands in for a Group, so the Study Sets screen can load without the database
@interface LWEStudySetStubGroup : NSObject
@property (nonatomic, retain) NSString *groupName;
@property (nonatomic) NSInteger groupId;
@property (nonatomic, retain) NSArray *tags; //!< childTags (empty when nil)
@end

@implementation LWEStudySetStubGroup
@synthesize groupName, groupId, tags;
- (NSArray *) childTags { return tags ?: [NSArray array]; }
- (BOOL) isTopLevelGroup { return NO; }
- (void) dealloc { [groupName release]; [tags release]; [super dealloc]; }
@end

//! Stands in for a Tag row (name, id, word count), so set rows draw without the database
@interface LWEStudySetStubTag : NSObject
@property (nonatomic, retain) NSString *tagName;
@property (nonatomic) NSInteger tagId;
@property (nonatomic) NSInteger cardCount;
@end

@implementation LWEStudySetStubTag
@synthesize tagName, tagId, cardCount;
- (BOOL) isEditable { return NO; }
- (void) dealloc { [tagName release]; [super dealloc]; }
@end

//! count stub sets, "Set 1" ... (ids from 1000, so none is the starred set)
static NSMutableArray *LWEStudySetStubTags(NSInteger count)
{
  NSMutableArray *tags = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0; i < count; i++)
  {
    LWEStudySetStubTag *tag = [[LWEStudySetStubTag alloc] init];
    tag.tagName = [NSString stringWithFormat:@"Set %ld", (long)(i + 1)];
    tag.tagId = 1000 + i;
    tag.cardCount = 100;
    [tags addObject:tag];
    [tag release];
  }
  return tags;
}

//! Lets queued main-queue work (the one-shot re-hide reset after -viewDidAppear:) run
static void LWEStudySetSpinMainQueue(void)
{
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

static void LWEStudySetTestNoop(id self, SEL _cmd) {}

/**
 * The host app's StudySetViewController (the test bundle doesn't compile its own copy, so it is looked
 * up at run time), with -reloadSubgroupData stubbed out so the screen loads without the database.
 */
static Class LWEStudySetControllerClassWithoutDatabase(void)
{
  Class base = NSClassFromString(@"StudySetViewController");
  if (base == nil) return nil;
  const char *name = "LWEStudySetViewControllerWithoutDatabase";
  Class cls = objc_getClass(name);
  if (cls == nil)
  {
    cls = objc_allocateClassPair(base, name, 0);
    class_addMethod(cls, @selector(reloadSubgroupData), (IMP)LWEStudySetTestNoop, "v@:");
    objc_registerClassPair(cls);
  }
  return cls;
}

@interface CFlashAccessibilityTest : XCTestCase
@end

@implementation CFlashAccessibilityTest

#pragma mark - Helpers

- (CardViewController *) _newCardViewWithDelegate:(id<CardViewControllerDelegate>)delegate
{
  CardViewController *cvc = [[[CardViewController alloc] initDisplayMainHeadword:YES] autorelease];
  cvc.delegate = delegate;
  cvc.view.frame = CGRectMake(0, 0, 402, 494);
  return cvc;
}

- (ChineseCard *) _cardWithHeadword:(NSString *)headword reading:(NSString *)reading meaning:(NSString *)meaning
{
  ChineseCard *card = [[[ChineseCard alloc] init] autorelease];
  card._headword = headword;
  card.headword_simp = headword;
  card.hw_reading = reading;
  card._meaning = meaning;
  return card;
}

static CGFloat LWECFTestRelativeLuminance(UIColor *color)
{
  CGFloat rgb[4] = {0, 0, 0, 1};
  [color getRed:&rgb[0] green:&rgb[1] blue:&rgb[2] alpha:&rgb[3]];
  CGFloat lin[3];
  for (int i = 0; i < 3; i++)
  {
    lin[i] = (rgb[i] <= 0.03928) ? rgb[i] / 12.92 : pow((rgb[i] + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}

static CGFloat LWECFTestContrast(UIColor *a, UIColor *b)
{
  CGFloat la = LWECFTestRelativeLuminance(a), lb = LWECFTestRelativeLuminance(b);
  return (MAX(la, lb) + 0.05) / (MIN(la, lb) + 0.05);
}

#pragma mark - Score bubble

- (void) testScoreBubbleAccessibilityValue
{
  NSString *expected = [NSString stringWithFormat:NSLocalizedString(@"%ld%% right", nil), 100L];
  XCTAssertEqualObjects([MoodIcon accessibilityValueForPercentCorrect:100.0f], expected);
  NSString *v = [MoodIcon accessibilityValueForPercentCorrect:66.6f];
  XCTAssertTrue([v rangeOfString:@"67"].location != NSNotFound, @"Rounded like the bubble: %@", v);
}

- (void) testScoreBubbleReadsTheScoreInPracticeMode
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  MoodIcon *mood = cvc.moodIcon;
  XCTAssertNotNil(mood.moodIconBtn);
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:100.0f];
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityLabel, NSLocalizedString(@"Session score", nil));
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:100.0f]);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityHint, NSLocalizedString(@"Shows or hides the score", nil));
  XCTAssertFalse(mood.percentCorrectLabel.isAccessibilityElement, @"The bubble's \"100%%\" is not read twice");
}

- (void) testBrowseModeScoreBubbleHasNoScoreForVoiceOver
{
  Class browseClass = NSClassFromString(@"BrowseModeCardViewDelegate");
  XCTAssertNotNil(browseClass);
  id<CardViewControllerDelegate> browse = [[[browseClass alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:browse];
  MoodIcon *mood = cvc.moodIcon;
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:100.0f];
  XCTAssertTrue(mood.talkBubble.hidden);
  XCTAssertNil(mood.moodIconBtn.accessibilityValue, @"No score read while none is on screen");
  XCTAssertFalse(mood.moodIconBtn.isAccessibilityElement);
  [cvc setupWithCard:[self _cardWithHeadword:@"你好" reading:@"ni3 hao3" meaning:@"hello"]];
  XCTAssertNil(mood.moodIconBtn.accessibilityValue, @"...on the next card too");

  cvc.delegate = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  [cvc studyViewModeDidChange:nil];
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement);
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:100.0f]);
}

- (void) testPracticeScoreBubbleHiddenByTapHasNoValue
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  MoodIcon *mood = cvc.moodIcon;
  [cvc studyViewModeDidChange:nil];
  [mood updateMoodIcon:67.0f];
  [mood doTogglePercentCorrectBtn];
  XCTAssertNil(mood.moodIconBtn.accessibilityValue);
  XCTAssertTrue(mood.moodIconBtn.isAccessibilityElement, @"Still a button, to show the score again");
  [mood doTogglePercentCorrectBtn];
  XCTAssertEqualObjects(mood.moodIconBtn.accessibilityValue, [MoodIcon accessibilityValueForPercentCorrect:67.0f]);
}

#pragma mark - Scroll-indicator flash

- (void) testMeaningScrollFlashDoesNotCarryOverToTheNextCard
{
  PracticeModeCardViewDelegate *practice = [[[PracticeModeCardViewDelegate alloc] init] autorelease];
  CardViewController *cvc = [self _newCardViewWithDelegate:practice];
  [cvc setupWithCard:[self _cardWithHeadword:@"你好" reading:@"ni3 hao3" meaning:@"hello"]];
  XCTAssertFalse([cvc meaningScrollFlashPending]);
  [practice cardViewDidReveal:cvc];
  XCTAssertTrue([cvc meaningScrollFlashPending]);
  [cvc setupWithCard:[self _cardWithHeadword:@"一半" reading:@"yi1 ban4" meaning:@"half"]];
  XCTAssertFalse([cvc meaningScrollFlashPending], @"The next card starts with no flash pending");
}

#pragma mark - Study screen

- (void) testProgressStripAccessibilitySummary
{
  NSArray *names = @[@"Studying", @"Right 1x", @"Right 2x", @"Right 3x", @"Learned"];
  NSArray *counts = @[@"3", @"15", @"0", @"0", @"2"];
  XCTAssertEqualObjects(LWEProgressAccessibilitySummary(names, counts),
                        @"Studying 3, Right 1x 15, Right 2x 0, Right 3x 0, Learned 2");
  XCTAssertEqualObjects(LWEProgressAccessibilitySummary(@[@"Studying", @""], @[@"3", @"4"]), @"Studying 3", @"Unnamed levels are skipped");
}

- (void) testCardTransitionHonoursReduceMotion
{
  XCTAssertEqualObjects(LWECardTransitionType(NO), kCATransitionPush);
  XCTAssertEqualObjects(LWECardTransitionSubtype(NO, kCATransitionFromLeft), kCATransitionFromLeft);
  XCTAssertEqualObjects(LWECardTransitionType(YES), kCATransitionFade);
  XCTAssertNil(LWECardTransitionSubtype(YES, kCATransitionFromLeft));
}

#pragma mark - Study Sets

- (void) testListSubtitleInkMeetsAAInEveryTheme
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  for (NSString *key in [tm themeKeysList])
  {
    UIColor *ink = [tm colorForSlot:@"cellValueInk" themeKey:key];
    XCTAssertNotNil(ink, @"%@", key);
    for (UIColor *fill in @[[UIColor whiteColor], ([tm colorForSlot:@"cellFill" themeKey:key] ?: [UIColor whiteColor])])
    {
      CGFloat ratio = LWECFTestContrast(ink, fill);
      XCTAssertGreaterThanOrEqual(ratio, 4.5, @"%@: %.2f:1", key, ratio);
    }
  }
}

- (void) testStudySetNavigationBarIsOpaqueInTheThemeColours
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  for (NSString *key in [tm themeKeysList])
  {
    UIColor *fill = [tm colorForSlot:@"navBarFill" themeKey:key];
    UIColor *ink = [tm colorForSlot:@"navTitleInk" themeKey:key];
    XCTAssertNotNil(fill, @"%@", key);
    UINavigationItem *item = [[[UINavigationItem alloc] initWithTitle:@"HSK"] autorelease];
    UIColor *hairline = [tm colorForSlot:@"separator" themeKey:key];
    LWEStudySetApplyNavigationBarAppearance(item, fill, ink, hairline);
    for (UINavigationBarAppearance *a in @[item.standardAppearance, item.scrollEdgeAppearance, item.compactAppearance, item.compactScrollEdgeAppearance])
    {
      XCTAssertEqualObjects(a.backgroundColor, fill, @"%@", key);
      CGFloat red = 0, green = 0, blue = 0, alpha = 0;
      [a.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
      XCTAssertEqualWithAccuracy(alpha, 1.0, 0.001, @"%@: opaque", key);
      XCTAssertEqualObjects(a.titleTextAttributes[NSForegroundColorAttributeName], ink, @"%@", key);
      XCTAssertEqualObjects(a.shadowColor, hairline, @"%@: theme hairline", key);
    }
  }
}

- (void) testStudySetViewControllerAppliesTheNavigationBarAppearance
{
  // Review nit: the screen itself must use the helper (not just the helper being right), on every bar state
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  UIColor *fill = [tm colorForSlot:@"navBarFill"];
  UIColor *ink = [tm colorForSlot:@"navTitleInk"];
  UIColor *hairline = [tm colorForSlot:@"separator"];
  XCTAssertNotNil(fill);
  Class studySetClass = LWEStudySetControllerClassWithoutDatabase();
  XCTAssertNotNil(studySetClass);
  LWEStudySetStubGroup *group = [[[LWEStudySetStubGroup alloc] init] autorelease];
  group.groupName = @"Test Group";
  StudySetViewController *vc = [[[studySetClass alloc] initWithGroup:(Group *)group] autorelease];
  [vc loadViewIfNeeded];
  UINavigationItem *item = vc.navigationItem;
  for (int pass = 0; pass < 2; pass++)
  {
    NSArray *states = @[item.standardAppearance ?: [NSNull null], item.scrollEdgeAppearance ?: [NSNull null],
                        item.compactAppearance ?: [NSNull null], item.compactScrollEdgeAppearance ?: [NSNull null]];
    for (id a in states)
    {
      XCTAssertTrue([a isKindOfClass:[UINavigationBarAppearance class]], @"pass %d: every bar state has the appearance", pass);
      if ([a isKindOfClass:[UINavigationBarAppearance class]] == NO) continue;
      UINavigationBarAppearance *appearance = (UINavigationBarAppearance *)a;
      XCTAssertEqualObjects(appearance.backgroundColor, fill, @"pass %d", pass);
      XCTAssertEqualObjects(appearance.titleTextAttributes[NSForegroundColorAttributeName], ink, @"pass %d", pass);
      XCTAssertEqualObjects(appearance.shadowColor, hairline, @"pass %d: theme hairline", pass);
    }
    // viewWillAppear: puts it back (the theme may have changed in Settings)
    item.standardAppearance = nil;
    item.scrollEdgeAppearance = nil;
    item.compactAppearance = nil;
    item.compactScrollEdgeAppearance = nil;
    [vc viewWillAppear:NO];
  }
  // Paper list behind the rows, not the XIB's system grouped grey
  XCTAssertEqualObjects(vc.tableView.backgroundColor, [tm colorForSlot:@"groupedBackground"]);
  XCTAssertEqualWithAccuracy(vc.tableView.sectionHeaderTopPadding, 0, 0.001);
}

- (void) testStudySetSearchBarScrollRoomLetsAShortListHideTheSearchBar
{
  // Short group (4 sets): 675pt visible + 64pt bar - 723pt content = 16pt more needed
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(675, 64, 723), 16, 0.001);
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(675, 64, 739), 0, 0.001, @"exactly enough");
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(675, 64, 1810), 0, 0.001, @"long list needs nothing");
  XCTAssertEqualWithAccuracy(LWEStudySetSearchBarScrollRoom(500.25, 56, 500), 57, 0.001, @"rounded up to whole points");
}

/**
 * Review nit on #32: the real controller in a 375x675 window.  A short group gets bottom room so the
 * search bar hides fully, a long list gets none, and while searching (results from all sets) the
 * target is 0.  The re-hide flag is cleared by a status-bar tap, the search field and after
 * -viewDidAppear:, and the re-hide is skipped while searching.
 */
- (void) testStudySetSearchBarScrollRoomAndReHideInAWindow
{
  Class studySetClass = LWEStudySetControllerClassWithoutDatabase();
  XCTAssertNotNil(studySetClass);
  if (studySetClass == nil) return;

  UIWindowScene *scene = nil;
  for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
  {
    if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
  }
  UIWindow *window = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] init];
  window.frame = CGRectMake(0, 0, 375, 675);

  // Short group: 4 sets
  LWEStudySetStubGroup *shortGroup = [[[LWEStudySetStubGroup alloc] init] autorelease];
  shortGroup.groupName = @"JLPT N4";
  shortGroup.tags = LWEStudySetStubTags(4);
  StudySetViewController *vc = [[[studySetClass alloc] initWithGroup:(Group *)shortGroup] autorelease];
  window.rootViewController = vc;
  window.hidden = NO;
  UITableView *tv = vc.tableView;
  [vc viewWillAppear:NO]; // reload + -hideSearchBar
  [window layoutIfNeeded];
  [tv layoutIfNeeded];
  [vc updateSearchBarScrollRoom];

  CGFloat barHeight = vc.searchBar.frame.size.height;
  XCTAssertGreaterThan(barHeight, 0);
  CGFloat hiddenY = -tv.adjustedContentInset.top + barHeight;
  CGFloat maxY = tv.contentSize.height + tv.adjustedContentInset.bottom - tv.bounds.size.height;
  CGFloat shortRoom = tv.contentInset.bottom;
  XCTAssertGreaterThan(shortRoom, 0, @"short group: room to scroll the search bar off");
  XCTAssertGreaterThanOrEqual(maxY, hiddenY - 0.5, @"the hidden offset is reachable");
  XCTAssertEqualWithAccuracy(tv.contentOffset.y, hiddenY, 0.5, @"search bar fully hidden");
  XCTAssertTrue(vc.keepsSearchBarHidden);

  // The re-hide puts a clamped offset back while the flag is set
  tv.contentOffset = CGPointMake(0, -tv.adjustedContentInset.top);
  [vc updateSearchBarScrollRoom];
  XCTAssertEqualWithAccuracy(tv.contentOffset.y, hiddenY, 0.5, @"re-hidden before the user scrolls");

  // Status-bar tap clears it, and the scroll to the top then stays
  XCTAssertTrue([vc scrollViewShouldScrollToTop:tv]);
  XCTAssertFalse(vc.keepsSearchBarHidden, @"status-bar tap");
  tv.contentOffset = CGPointMake(0, -tv.adjustedContentInset.top);
  [vc updateSearchBarScrollRoom];
  XCTAssertEqualWithAccuracy(tv.contentOffset.y, -tv.adjustedContentInset.top, 0.5, @"no snap back after a status-bar tap");

  // -viewDidAppear: clears it once, after the in-window layout
  [vc hideSearchBar];
  XCTAssertTrue(vc.keepsSearchBarHidden);
  [vc viewDidAppear:NO];
  LWEStudySetSpinMainQueue();
  XCTAssertFalse(vc.keepsSearchBarHidden, @"one-shot: cleared after viewDidAppear");

  // The search field clears it (searching is set first so the delegate skips the all-sets query)
  [vc hideSearchBar];
  XCTAssertTrue(vc.keepsSearchBarHidden);
  [vc setValue:@YES forKey:@"searching"];
  [vc searchBarTextDidBeginEditing:vc.searchBar];
  XCTAssertFalse(vc.keepsSearchBarHidden, @"search field");

  // Searching: a long result list (from all sets) gets no room, and the re-hide is skipped
  [vc setValue:@YES forKey:@"searching"];
  vc.tagArray = LWEStudySetStubTags(40);
  [tv reloadData];
  [tv layoutIfNeeded];
  [vc updateSearchBarScrollRoom];
  XCTAssertEqualWithAccuracy(tv.contentInset.bottom, 0, 0.5, @"searching: target inset 0");
  [vc setValue:@YES forKey:@"keepSearchBarHidden"];
  tv.contentOffset = CGPointMake(0, -tv.adjustedContentInset.top);
  [vc updateSearchBarScrollRoom];
  XCTAssertEqualWithAccuracy(tv.contentOffset.y, -tv.adjustedContentInset.top, 0.5, @"no re-hide while searching");
  maxY = tv.contentSize.height + tv.adjustedContentInset.bottom - tv.bounds.size.height;
  CGFloat lastRowBottom = CGRectGetMaxY([tv rectForRowAtIndexPath:[NSIndexPath indexPathForRow:39 inSection:0]]);
  XCTAssertLessThan(maxY + tv.bounds.size.height - lastRowBottom, 60, @"results end near the bottom, no blank space");

  // Done searching: the group's room comes back
  [vc setValue:@NO forKey:@"searching"];
  [vc doDoneSearching];
  [tv layoutIfNeeded];
  [vc updateSearchBarScrollRoom];
  // The group's rows again (the exact room can differ by a few points once the rows are measured)
  hiddenY = -tv.adjustedContentInset.top + barHeight;
  maxY = tv.contentSize.height + tv.adjustedContentInset.bottom - tv.bounds.size.height;
  XCTAssertGreaterThan(tv.contentInset.bottom, 0, @"room back after searching");
  XCTAssertEqualWithAccuracy(maxY, hiddenY, 1.0, @"just enough room: the hidden offset is the end of the list");
  XCTAssertEqualWithAccuracy(tv.contentOffset.y, hiddenY, 0.5, @"search bar hidden again after searching");
  LWEStudySetSpinMainQueue();
  XCTAssertFalse(vc.keepsSearchBarHidden, @"one-shot after done searching too");

  window.hidden = YES;
  window.rootViewController = nil;

  // Long group: 40 sets need no room
  LWEStudySetStubGroup *longGroup = [[[LWEStudySetStubGroup alloc] init] autorelease];
  longGroup.groupName = @"Long";
  longGroup.tags = LWEStudySetStubTags(40);
  StudySetViewController *longVC = [[[studySetClass alloc] initWithGroup:(Group *)longGroup] autorelease];
  window.rootViewController = longVC;
  window.hidden = NO;
  [longVC viewWillAppear:NO];
  [window layoutIfNeeded];
  [longVC.tableView layoutIfNeeded];
  [longVC updateSearchBarScrollRoom];
  XCTAssertEqualWithAccuracy(longVC.tableView.contentInset.bottom, 0, 0.5, @"long list needs no room");
  XCTAssertEqualWithAccuracy(longVC.tableView.contentOffset.y, -longVC.tableView.adjustedContentInset.top + longVC.searchBar.frame.size.height, 0.5);

  window.hidden = YES;
  window.rootViewController = nil;
  [window release];
}

@end
