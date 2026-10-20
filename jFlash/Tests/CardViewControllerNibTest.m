//
//  CardViewControllerNibTest.m
//  xFlash
//
//  Loads each CardViewController NIB with a real CardViewController as File's Owner,
//  so a stale outlet (e.g. a 'delegate' connection left over from the old web view)
//  fails here as an NSUnknownKeyException instead of crashing the app at launch.
//
//  Also guards against ITMS-90809: App Store Connect rejects any build whose binary or
//  compiled nibs mention the deprecated UIKit web view class, even from dead code.
//

#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "CardViewController.h"

@interface CardViewControllerNibTest : XCTestCase
@end

@implementation CardViewControllerNibTest

//! The banned class name, built at runtime so this test bundle doesn't contain it either.
+ (NSString *) _legacyWebViewClassName
{
  return [@"UI" stringByAppendingString:@"WebView"];
}

- (void) _collectViewsUnder:(UIView *)view into:(NSMutableArray *)views
{
  [views addObject:view];
  for (UIView *subview in view.subviews)
  {
    [self _collectViewsUnder:subview into:views];
  }
}

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

/**
 * Loads the controller's view the way the app does (viewDidLoad included) and checks the
 * meaning area: a WKWebView set up like the old web view (clear, no bounce, delegate wired),
 * and nothing anywhere in the view tree that is, or descends from, the legacy web view.
 */
- (void) _assertViewHostsWKWebViewWithMainHeadword:(BOOL)displayMainHeadword
{
  CardViewController *owner = [[CardViewController alloc] initDisplayMainHeadword:displayMainHeadword];
  NSString *nibName = owner.nibName;
  UIView *root = owner.view;
  XCTAssertNotNil(root, @"%@: view should load", nibName);

  NSMutableArray *views = [NSMutableArray array];
  [self _collectViewsUnder:root into:views];

  Class legacy = NSClassFromString([[self class] _legacyWebViewClassName]);
  NSMutableArray *webViews = [NSMutableArray array];
  for (UIView *view in views)
  {
    if (legacy)
    {
      XCTAssertFalse([view isKindOfClass:legacy], @"%@: %@ in the view tree is a legacy web view", nibName, view);
    }
    XCTAssertFalse([NSStringFromClass([view class]) isEqualToString:[[self class] _legacyWebViewClassName]],
                   @"%@: legacy web view class in the view tree", nibName);
    if ([view isKindOfClass:[WKWebView class]])
    {
      [webViews addObject:view];
    }
  }

  XCTAssertEqual([webViews count], (NSUInteger)1, @"%@: the card should host exactly one WKWebView", nibName);
  WKWebView *webView = [webViews firstObject];
  XCTAssertEqual(webView.superview, owner.meaningWebViewContainer, @"%@: WKWebView should live in meaningWebViewContainer", nibName);
  XCTAssertFalse(webView.opaque, @"%@: meaning web view should be transparent", nibName);
  XCTAssertEqualObjects(webView.backgroundColor, [UIColor clearColor], @"%@: meaning web view background should be clear", nibName);
  XCTAssertEqualObjects(webView.scrollView.backgroundColor, [UIColor clearColor], @"%@: meaning scroll view background should be clear", nibName);
  XCTAssertFalse(webView.scrollView.bounces, @"%@: meaning web view should not bounce", nibName);
  XCTAssertEqual((id)webView.navigationDelegate, (id)owner, @"%@: navigation delegate should be the card view controller", nibName);
  XCTAssertEqualObjects(owner.meaningWebViewContainer.backgroundColor, [UIColor clearColor], @"%@: container should be clear", nibName);
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

- (void) testEtoJViewHostsWKWebViewAndNoLegacyWebView
{
  [self _assertViewHostsWKWebViewWithMainHeadword:NO];
}

- (void) testMainHeadwordViewHostsWKWebViewAndNoLegacyWebView
{
  [self _assertViewHostsWKWebViewWithMainHeadword:YES];
}

/**
 * No class compiled into the app (main binary or Xcode's debug dylib) may subclass or
 * extend the legacy web view; the old UIWebView+LWENoBounces category is what got the
 * first upload rejected.
 */
- (void) testAppDefinesNoLegacyWebViewSubclassOrCategory
{
  Class legacy = NSClassFromString([[self class] _legacyWebViewClassName]);
  if (legacy == Nil) return; // the SDK no longer ships it at all
  XCTAssertFalse([legacy instancesRespondToSelector:NSSelectorFromString(@"shutOffBouncing")],
                 @"The old no-bounces category is still compiled in");

  NSString *bundlePath = [[[NSBundle mainBundle] bundlePath] stringByResolvingSymlinksInPath];
  unsigned int imageCount = 0;
  const char **images = objc_copyImageNames(&imageCount);
  NSUInteger appImages = 0;
  for (unsigned int i = 0; i < imageCount; i++)
  {
    NSString *image = [[NSString stringWithUTF8String:images[i]] stringByResolvingSymlinksInPath];
    if (![image hasPrefix:bundlePath] || [image rangeOfString:@".xctest/"].location != NSNotFound) continue;
    appImages++;
    unsigned int classCount = 0;
    const char **classNames = objc_copyClassNamesForImage(images[i], &classCount);
    for (unsigned int c = 0; c < classCount; c++)
    {
      Class cls = objc_getClass(classNames[c]);
      for (Class sup = class_getSuperclass(cls); sup != Nil; sup = class_getSuperclass(sup))
      {
        XCTAssertFalse(sup == legacy, @"%s subclasses the legacy web view", classNames[c]);
      }
    }
    free(classNames);
  }
  free(images);
  XCTAssertTrue(appImages > 0, @"Should find the app's own code images under %@", bundlePath);
}

/**
 * Apple's scan reads the compiled nibs as well as the binary. Check every compiled nib
 * in the app bundle (including the IB class metadata) for the banned class name.
 */
- (void) testCompiledNibsDoNotMentionLegacyWebView
{
  NSData *needle = [[[self class] _legacyWebViewClassName] dataUsingEncoding:NSUTF8StringEncoding];
  NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
  NSDirectoryEnumerator *walker = [[NSFileManager defaultManager] enumeratorAtPath:bundlePath];
  NSUInteger nibFiles = 0;
  BOOL sawEtoJ = NO;
  for (NSString *relative in walker)
  {
    if ([relative rangeOfString:@".xctest/"].location != NSNotFound) continue;
    BOOL inNib = ([[relative pathExtension] isEqualToString:@"nib"] || [relative rangeOfString:@".nib/"].location != NSNotFound);
    if (!inNib) continue;
    NSString *full = [bundlePath stringByAppendingPathComponent:relative];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir] || isDir) continue;
    nibFiles++;
    if ([relative hasPrefix:@"CardViewController-EtoJ.nib"]) sawEtoJ = YES;
    NSData *data = [NSData dataWithContentsOfFile:full options:NSDataReadingMappedIfSafe error:NULL];
    XCTAssertTrue([data rangeOfData:needle options:0 range:NSMakeRange(0, [data length])].location == NSNotFound,
                  @"Compiled nib %@ mentions the legacy web view", relative);
  }
  XCTAssertTrue(nibFiles > 0, @"Should find compiled nibs in %@", bundlePath);
  XCTAssertTrue(sawEtoJ, @"Should find the compiled CardViewController-EtoJ nib");
}

@end
