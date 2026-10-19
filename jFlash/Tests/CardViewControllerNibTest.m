//
//  CardViewControllerNibTest.m
//  xFlash
//
//  Loads each CardViewController NIB with a real CardViewController as File's Owner,
//  so a stale outlet (e.g. a 'delegate' connection left over from a former UIWebView)
//  fails here as an NSUnknownKeyException instead of crashing the app at launch.
//

#import <XCTest/XCTest.h>
#import "CardViewController.h"

@interface CardViewControllerNibTest : XCTestCase
@end

@implementation CardViewControllerNibTest

- (void) _assertNibNamed:(NSString *)nibName loadsWithMainHeadword:(BOOL)displayMainHeadword
{
  CardViewController *owner = [[CardViewController alloc] initDisplayMainHeadword:displayMainHeadword];
  XCTAssertNotNil(owner, @"Should create a CardViewController");
  XCTAssertEqualObjects(owner.nibName, nibName, @"Should use the %@ NIB", nibName);

  NSArray *objects = nil;
  XCTAssertNoThrow(objects = [[NSBundle mainBundle] loadNibNamed:nibName owner:owner options:nil],
                   @"%@ should load without throwing (stale outlet?)", nibName);
  XCTAssertTrue([objects count] > 0, @"%@ should contain top-level objects", nibName);
  XCTAssertNotNil(owner.meaningWebViewContainer, @"%@ should connect meaningWebViewContainer", nibName);
  // The surviving 'delegate' outlets: both scroll views report scrolling to the card view controller
  XCTAssertNotNil(owner.readingScrollContainer, @"%@ should connect readingScrollContainer", nibName);
  XCTAssertNotNil(owner.headwordScrollContainer, @"%@ should connect headwordScrollContainer", nibName);
  XCTAssertEqual((id)owner.readingScrollContainer.delegate, (id)owner, @"%@: reading scroll view's delegate should be File's Owner", nibName);
  XCTAssertEqual((id)owner.headwordScrollContainer.delegate, (id)owner, @"%@: headword scroll view's delegate should be File's Owner", nibName);
#if !__has_feature(objc_arc)
  [owner release];
#endif
}

- (void) testEtoJNibLoadsWithCardViewControllerOwner
{
  [self _assertNibNamed:@"CardViewController-EtoJ" loadsWithMainHeadword:NO];
}

- (void) testMainHeadwordNibLoadsWithCardViewControllerOwner
{
  [self _assertNibNamed:@"CardViewController" loadsWithMainHeadword:YES];
}

@end
