//
//  DownloadManagerTabAnimationTest.m
//  jFlash
//
//  Settings tab "downloading" gear animation in DownloadManager: starting twice must not orphan the
//  first repeating timer, and stopping restores the gearshape SF Symbols.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "DownloadManager.h"
#import "jFlashAppDelegate.h"
#import "Constants.h"

@interface DownloadManager (TabAnimationTesting)
- (void) tabIconTimerDidFire:(NSTimer *)timer;
@end

@interface DownloadManagerTabAnimationTest : XCTestCase
@property (retain) DownloadManager *manager;
@end

@implementation DownloadManagerTabAnimationTest
@synthesize manager;

- (void) setUp
{
  [super setUp];
  self.manager = [[[DownloadManager alloc] init] autorelease];
}

- (void) tearDown
{
  [self.manager.tabIconTimer invalidate];
  self.manager = nil;
  [super tearDown];
}

//! PNG bytes of an image, for comparing images by content rather than by pointer
static NSData *LWEPNGData(UIImage *image)
{
  return image ? UIImagePNGRepresentation(image) : nil;
}

//! The host app's Settings tab item, or nil (test skipped) if the tab bar isn't loaded
- (UITabBarItem *) _settingsTabItem
{
  jFlashAppDelegate *appDelegate = (jFlashAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSArray *vcs = appDelegate.tabBarController.viewControllers;
  if ([vcs count] <= SETTINGS_VIEW_CONTROLLER_TAB_INDEX)
  {
    return nil;
  }
  return [[vcs objectAtIndex:SETTINGS_VIEW_CONTROLLER_TAB_INDEX] tabBarItem];
}

- (void) testStartSchedulesARepeatingTimerWithGearFrames
{
  [self.manager startTabAnimation];
  NSTimer *timer = self.manager.tabIconTimer;
  XCTAssertNotNil(timer);
  XCTAssertTrue([timer isValid]);
  XCTAssertEqual([self.manager.tabIconImages count], (NSUInteger)3, @"0/15/30 degree gear frames");
  XCTAssertEqual(self.manager.tabIconIndex, (NSInteger)0);
  for (UIImage *frame in self.manager.tabIconImages)
  {
    XCTAssertEqual(frame.renderingMode, UIImageRenderingModeAlwaysTemplate, @"frames are tinted by the tab bar");
  }
}

- (void) testStartingTwiceInvalidatesTheFirstTimer
{
  [self.manager startTabAnimation];
  NSTimer *first = [[self.manager.tabIconTimer retain] autorelease];
  XCTAssertTrue([first isValid]);

  [self.manager startTabAnimation];
  NSTimer *second = self.manager.tabIconTimer;
  XCTAssertNotNil(second);
  XCTAssertTrue(second != first, @"a new timer replaces the old one");
  XCTAssertFalse([first isValid], @"the first timer must be invalidated, not orphaned");
  XCTAssertTrue([second isValid]);
}

- (void) testStopInvalidatesTimer
{
  // -stopTabAnimation also resets the host app's Settings tab item
  if ([self _settingsTabItem] == nil)
  {
    XCTSkip(@"host app tab bar not loaded");
  }
  [self.manager startTabAnimation];
  NSTimer *timer = [[self.manager.tabIconTimer retain] autorelease];
  [self.manager stopTabAnimation];
  XCTAssertFalse([timer isValid]);
  XCTAssertNil(self.manager.tabIconTimer);
}

- (void) testStopRestoresSettingsTabSymbols
{
  UITabBarItem *item = [self _settingsTabItem];
  if (item == nil)
  {
    XCTSkip(@"host app tab bar not loaded");
  }
  UIImage *originalImage = [[item.image retain] autorelease];
  UIImage *originalSelected = [[item.selectedImage retain] autorelease];

  [self.manager startTabAnimation];
  [self.manager tabIconTimerDidFire:self.manager.tabIconTimer];
  NSData *firstFrame = LWEPNGData([self.manager.tabIconImages objectAtIndex:0]);
  XCTAssertNotNil(firstFrame);
  XCTAssertEqualObjects(LWEPNGData(item.image), firstFrame, @"first gear frame shown while downloading");
  XCTAssertEqualObjects(LWEPNGData(item.selectedImage), firstFrame, @"same frame when Settings is selected");
  // UITabBarItem may hand back its own copy of selectedImage, so compare what it is, not the pointer
  XCTAssertFalse(item.image.isSymbolImage, @"animation frames are drawn bitmaps");
  XCTAssertFalse(item.selectedImage.isSymbolImage, @"the frame also shows when Settings is selected");
  XCTAssertTrue(CGSizeEqualToSize(item.selectedImage.size, item.image.size));
  XCTAssertEqual(self.manager.tabIconIndex, (NSInteger)1);

  [self.manager stopTabAnimation];
  XCTAssertTrue(item.image.isSymbolImage, @"stop restores the gearshape symbol");
  XCTAssertTrue(item.selectedImage.isSymbolImage, @"stop restores the gearshape.fill symbol");
  XCTAssertEqualObjects(LWEPNGData(item.image), LWEPNGData([UIImage systemImageNamed:@"gearshape"]));
  XCTAssertEqualObjects(LWEPNGData(item.selectedImage), LWEPNGData([UIImage systemImageNamed:@"gearshape.fill"]));
  XCTAssertNotEqualObjects(LWEPNGData(item.image), LWEPNGData(item.selectedImage));

  // Leave the host app's tab item as we found it
  item.image = originalImage;
  item.selectedImage = originalSelected;
}

- (void) testTimerFireWrapsAroundTheFrames
{
  if ([self _settingsTabItem] == nil)
  {
    XCTSkip(@"host app tab bar not loaded");
  }
  UITabBarItem *item = [self _settingsTabItem];
  UIImage *originalImage = [[item.image retain] autorelease];
  UIImage *originalSelected = [[item.selectedImage retain] autorelease];

  [self.manager startTabAnimation];
  for (NSInteger i = 0; i < 3; i++)
  {
    [self.manager tabIconTimerDidFire:self.manager.tabIconTimer];
  }
  XCTAssertEqual(self.manager.tabIconIndex, (NSInteger)0, @"index wraps after the last frame");
  [self.manager stopTabAnimation];

  item.image = originalImage;
  item.selectedImage = originalSelected;
}

@end
