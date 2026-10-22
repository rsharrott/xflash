//
//  JapaneseLayoutTest.m
//  xFlash
//
//  Layout checks for the Japanese UI (shared by jFlashTest and cFlashTest):
//  - Example sentences: the Add button of an expanded sentence's word list (ja 追加) and the other
//    pill buttons never wrap onto two lines, in every theme, in a phone-width web view.
//  - Settings (jFlash): the Rate Us bar item is a star icon with a localized VoiceOver label, and
//    neither bar item overlaps or truncates the 設定 / Settings title on an iPhone SE or a 17 Pro.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "ExampleSentencesViewController.h"
#import "ThemeManager.h"

#if __has_feature(objc_arc)
#define LWE_TEST_AUTORELEASE(x) (x)
#else
#define LWE_TEST_AUTORELEASE(x) [(x) autorelease]
#endif

//! A long reading, so the reading cell wants all the room it can get
//! ExampleSentencesViewController lives in the host app; its C symbols aren't exported to the test bundle
static Class LWESentencesClass(void)
{
  return NSClassFromString(@"ExampleSentencesViewController");
}

static NSString *LWETemplate(void)
{
  return [(id)LWESentencesClass() sentencesHTMLTemplate];
}

static NSString *LWEWordCells(NSString *reading, NSInteger cardId, NSString *addTitle)
{
  return [(id)LWESentencesClass() wordCellsHTMLWithReading:reading cardId:cardId addTitle:addTitle];
}

static NSString * const kLWELongReading = @"つづける - tsuzukeru (to continue, to keep on)";

@interface JapaneseLayoutTest : XCTestCase <WKNavigationDelegate>
@property (nonatomic, retain) XCTestExpectation *loadExpectation;
@end

@implementation JapaneseLayoutTest
@synthesize loadExpectation;

#pragma mark - Example sentences: template

//! The CSS rule body that starts with `selector{` (or `selector {`) in the sentences template
- (NSString *) _ruleForSelector:(NSString *)selector
{
  NSString *html = LWETemplate();
  XCTAssertNotNil(html, @"The host app provides the sentences template");
  for (NSString *open in [NSArray arrayWithObjects:@"{", @" {", nil])
  {
    NSString *needle = [NSString stringWithFormat:@"\"%@%@", selector, open];
    NSRange start = [html rangeOfString:needle];
    if (start.location == NSNotFound)
    {
      needle = [NSString stringWithFormat:@"%@%@", selector, open];
      start = [html rangeOfString:needle];
    }
    if (start.location != NSNotFound)
    {
      NSUInteger from = NSMaxRange(start);
      NSRange end = [html rangeOfString:@"}" options:0 range:NSMakeRange(from, [html length] - from)];
      return [html substringWithRange:NSMakeRange(from, end.location - from)];
    }
  }
  return nil;
}

- (void) testTemplateButtonsNeverWrap
{
  NSString *button = [self _ruleForSelector:@".button"];
  XCTAssertNotNil(button, @"The sentences template styles .button");
  XCTAssertTrue([button rangeOfString:@"white-space:nowrap"].location != NSNotFound, @".button must not wrap (追加 broke into 追 / 加): %@", button);

  NSString *addCell = [self _ruleForSelector:@".ExpandedSentencesTable td.AddCell"];
  XCTAssertNotNil(addCell, @"The Add column has its own rule");
  XCTAssertTrue([addCell rangeOfString:@"white-space:nowrap"].location != NSNotFound, @"The Add column must not wrap: %@", addCell);
  XCTAssertTrue([addCell rangeOfString:@"width:1%"].location != NSNotFound, @"The Add column shrinks to its button: %@", addCell);
}

- (void) testWordCellsMarkup
{
  NSString *cells = LWEWordCells(@"ついか", 1234, @"追加");
  XCTAssertTrue([cells rangeOfString:@"<td class='AddCell'>"].location != NSNotFound, @"%@", cells);
  XCTAssertTrue([cells rangeOfString:@"<span class='button'>追加</span>"].location != NSNotFound, @"%@", cells);
  NSString *addLink = @"http://xflash.com/1?id=1234";
  XCTAssertTrue([cells rangeOfString:addLink].location != NSNotFound, @"%@", cells);
  XCTAssertTrue([cells rangeOfString:@"<td class='ContentCell'>ついか</td>"].location != NSNotFound, @"%@", cells);
  // The rows are injected into a double-quoted JavaScript string (-_showCardsForSentences:...)
  XCTAssertEqual([cells rangeOfString:@"\""].location, (NSUInteger)NSNotFound, @"No double quotes: %@", cells);
}

#pragma mark - Example sentences: rendered

- (void) webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
  [self.loadExpectation fulfill];
}

//! Renders one expanded sentence (3 word rows) in `themeKey` with `addTitle` at `width` points and
//! returns per-row metrics of the Add button: line boxes, button left/right, reading cell right, page width
- (NSArray *) _addButtonMetricsForTheme:(NSString *)themeKey addTitle:(NSString *)addTitle width:(CGFloat)width
{
  NSDictionary *theme = [[[ThemeManager sharedThemeManager] themes] objectForKey:themeKey];
  NSString *themeCSS = [theme objectForKey:@"SENTENCES_CSS"] ?: @"";
  NSMutableString *rows = [NSMutableString string];
  NSArray *headwords = [NSArray arrayWithObjects:@"勉強", @"続ける", @"ください", nil];
  NSArray *readings = [NSArray arrayWithObjects:@"べんきょう - benkyou", kLWELongReading, @"ください - kudasai", nil];
  for (NSUInteger i = 0; i < [headwords count]; i++)
  {
    [rows appendFormat:@"<tr class='HeadwordRow'><td class='HeadwordCell'>%@</td>%@</tr>",
      [headwords objectAtIndex:i], LWEWordCells([readings objectAtIndex:i], (NSInteger)i + 1, addTitle)];
  }
  NSString *examples = [NSString stringWithFormat:@"<ol><li><div class='ja'>勉強を続けて下さい。</div><div class='en'>Please go on with your study.</div>"
                        "<div class='showWordsDiv'><a href='#'><span class='button'>閉じる</span></a></div>"
                        "<div><table class='ExpandedSentencesTable' cellpadding='5'>%@</table></div></li></ol>", rows];
  NSString *html = [LWETemplate() stringByReplacingOccurrencesOfString:@"##THEMECSS##" withString:themeCSS];
  html = [html stringByReplacingOccurrencesOfString:@"##EXAMPLES##" withString:examples];

  WKWebView *webView = LWE_TEST_AUTORELEASE([[WKWebView alloc] initWithFrame:CGRectMake(0, 0, width, 900)]);
  webView.navigationDelegate = self;
  self.loadExpectation = [self expectationWithDescription:@"load"];
  [webView loadHTMLString:html baseURL:nil];
  // Cold WKWebView startup on the Intel CI simulator can take longer than 15s.
  // The layout assertions below are unchanged.
  [self waitForExpectationsWithTimeout:60 handler:nil];

  NSString *js = @"(function(){var out=[];var W=document.documentElement.clientWidth;"
    "var bs=document.querySelectorAll('.AddCell .button');"
    "for(var i=0;i<bs.length;i++){var b=bs[i];var r=document.createRange();r.selectNodeContents(b);"
    "var lines=r.getClientRects().length;var bb=b.getBoundingClientRect();"
    "var c=b.closest('tr').querySelector('.ContentCell').getBoundingClientRect();"
    "out.push([lines,bb.left,bb.right,c.right,W,bb.height]);}"
    "var close=document.querySelector('.showWordsDiv .button');var cr=document.createRange();cr.selectNodeContents(close);"
    "out.push([cr.getClientRects().length]);return JSON.stringify(out);})()";
  __block NSString *json = nil;
  XCTestExpectation *evaluated = [self expectationWithDescription:@"js"];
  [webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
    XCTAssertNil(error);
    json = [result copy];
    [evaluated fulfill];
  }];
  [self waitForExpectationsWithTimeout:15 handler:nil];
  webView.navigationDelegate = nil;
  self.loadExpectation = nil;
  NSArray *metrics = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
#if !__has_feature(objc_arc)
  [json release];
#endif
  return metrics;
}

- (void) testAddButtonStaysOnOneLineInEveryTheme
{
  NSArray *themeKeys = [[ThemeManager sharedThemeManager] themeKeysList];
  XCTAssertTrue([themeKeys count] > 0);
  // 320pt: narrower than the sentences web view on an iPhone SE (3rd gen), the smallest supported phone
  for (NSString *themeKey in themeKeys)
  {
    for (NSString *title in [NSArray arrayWithObjects:@"追加", @"Add", nil])
    {
      NSArray *metrics = [self _addButtonMetricsForTheme:themeKey addTitle:title width:320];
      XCTAssertEqual([metrics count], (NSUInteger)4, @"%@ %@: three Add buttons + the Close button", themeKey, title);
      for (NSUInteger i = 0; i + 1 < [metrics count]; i++)
      {
        NSArray *m = [metrics objectAtIndex:i];
        double left = [[m objectAtIndex:1] doubleValue], right = [[m objectAtIndex:2] doubleValue];
        double readingRight = [[m objectAtIndex:3] doubleValue], pageWidth = [[m objectAtIndex:4] doubleValue];
        XCTAssertEqual([[m objectAtIndex:0] integerValue], 1, @"%@: '%@' (row %lu) must stay on one line: %@", themeKey, title, (unsigned long)i, m);
        XCTAssertTrue(right <= pageWidth + 0.5, @"%@: '%@' must fit the page: %@", themeKey, title, m);
        XCTAssertTrue(left >= readingRight - 0.5, @"%@: '%@' must not overlap the reading: %@", themeKey, title, m);
        XCTAssertTrue(right - left >= 30, @"%@: '%@' keeps a tappable pill: %@", themeKey, title, m);
      }
      XCTAssertEqual([[[metrics lastObject] objectAtIndex:0] integerValue], 1, @"%@: 閉じる stays on one line", themeKey);
    }
  }
}

#if defined(LWE_JFLASH)

#pragma mark - Settings: Rate Us

- (UITableViewController *) _newSettings
{
  Class settingsClass = NSClassFromString(@"SettingsViewController");
  XCTAssertNotNil(settingsClass);
  return [[settingsClass alloc] initWithStyle:UITableViewStyleGrouped];
}

- (void) testRateUsIsAStarWithLocalizedVoiceOverLabel
{
  UITableViewController *settings = [self _newSettings];
  [settings loadViewIfNeeded];
  UIBarButtonItem *rate = settings.navigationItem.leftBarButtonItem;
  XCTAssertNotNil(rate);
  XCTAssertNotNil(rate.image, @"Rate Us is icon-only so it can't crowd the title");
  XCTAssertEqualObjects(rate.accessibilityLabel, NSLocalizedString(@"Rate Us", nil));
  XCTAssertTrue([rate.accessibilityLabel length] > 0);
  XCTAssertEqualObjects(NSStringFromSelector(rate.action), @"_requestReview");
#if !__has_feature(objc_arc)
  [settings release];
#endif

  // VoiceOver labels in both languages
  NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:@"Rate Us", @"en", @"App Storeで評価", @"ja", nil];
  for (NSString *lang in expected)
  {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings" inDirectory:nil forLocalization:lang];
    XCTAssertNotNil(path, @"%@ strings ship", lang);
    NSDictionary *strings = [NSDictionary dictionaryWithContentsOfFile:path];
    XCTAssertEqualObjects([strings objectForKey:@"Rate Us"], [expected objectForKey:lang]);
  }
}

static void LWECollectViews(UIView *view, Class cls, NSMutableArray *out)
{
  if ([view isKindOfClass:cls] && !view.hidden && view.alpha > 0.01) [out addObject:view];
  for (UIView *sub in view.subviews) LWECollectViews(sub, cls, out);
}

//! Lays Settings out in a nav bar `size` wide with `title`, then checks title vs. bar buttons
- (void) _checkTitle:(NSString *)title fitsOnScreenSize:(CGSize)size
{
  UITableViewController *settings = [self _newSettings];
  settings.title = title;
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
  UIWindowScene *scene = nil;
  for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
  {
    if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
  }
  UIWindow *window = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] init];
  window.frame = CGRectMake(0, 0, size.width, size.height);
  window.rootViewController = nav;
  window.hidden = NO;
  [nav.view setNeedsLayout];
  [nav.view layoutIfNeeded];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
  [nav.navigationBar layoutIfNeeded];

  UINavigationBar *bar = nav.navigationBar;
  NSMutableArray *labels = [NSMutableArray array];
  LWECollectViews(bar, [UILabel class], labels);
  UILabel *titleLabel = nil;
  for (UILabel *label in labels)
  {
    if ([label.text isEqualToString:title] && label.window != nil) { titleLabel = label; break; }
  }
  XCTAssertNotNil(titleLabel, @"%@ title label in the nav bar", title);
  CGRect titleFrame = [titleLabel convertRect:titleLabel.bounds toView:nil];
  XCTAssertTrue(titleFrame.size.width + 0.5 >= titleLabel.intrinsicContentSize.width, @"%@ is not truncated at %.0fpt (%@ vs %.1f)", title, size.width, NSStringFromCGRect(titleFrame), titleLabel.intrinsicContentSize.width);
  XCTAssertTrue(CGRectGetMinX(titleFrame) >= 0 && CGRectGetMaxX(titleFrame) <= size.width, @"%@ on screen", title);

  // Bar buttons: the outermost visible controls in the bar other than the title (the star and the share button)
  NSMutableArray *controls = [NSMutableArray array];
  LWECollectViews(bar, [UIControl class], controls);
  NSMutableArray *buttons = [NSMutableArray array];
  for (UIControl *control in controls)
  {
    if (control.window == nil || [titleLabel isDescendantOfView:control] || [control isDescendantOfView:titleLabel]) continue;
    if (CGRectGetWidth(control.bounds) < 20 || CGRectGetWidth(control.bounds) > 250) continue;
    BOOL nested = NO;
    for (UIControl *other in controls)
    {
      if (other != control && other.window && ![titleLabel isDescendantOfView:other] && [control isDescendantOfView:other]) { nested = YES; break; }
    }
    if (!nested) [buttons addObject:control];
  }
  XCTAssertEqual([buttons count], (NSUInteger)2, @"%@ at %.0fpt: Rate Us and Share in the bar (found %@)", title, size.width, buttons);
  for (UIControl *button in buttons)
  {
    CGRect buttonFrame = [button convertRect:button.bounds toView:nil];
    // Icon-only, like Share: a text label (App Storeで評価) is what pushed the title off centre
    XCTAssertTrue(CGRectGetWidth(buttonFrame) <= 50, @"%@ at %.0fpt: bar button %@ should be one icon wide", title, size.width, NSStringFromCGRect(buttonFrame));
    // ...and keeps at least 8pt of air from the title
    XCTAssertFalse(CGRectIntersectsRect(CGRectInset(buttonFrame, -8, 0), titleFrame), @"%@ at %.0fpt: bar button %@ crowds title %@", title, size.width, NSStringFromCGRect(buttonFrame), NSStringFromCGRect(titleFrame));
  }
  // With one icon on each side the title sits centred
  XCTAssertEqualWithAccuracy(CGRectGetMidX(titleFrame), size.width / 2.0, 4.0, @"%@ centred at %.0fpt", title, size.width);

  window.hidden = YES;
  window.rootViewController = nil;
#if !__has_feature(objc_arc)
  [window release];
  [nav release];
  [settings release];
#endif
}

- (void) testSettingsTitleHasRoomOnSmallAndLargePhones
{
  CGSize se3 = CGSizeMake(375, 667);       // iPhone SE (3rd generation)
  CGSize pro17 = CGSizeMake(402, 874);     // iPhone 17 Pro
  for (NSString *title in [NSArray arrayWithObjects:@"設定", @"Settings", nil])
  {
    [self _checkTitle:title fitsOnScreenSize:se3];
    [self _checkTitle:title fitsOnScreenSize:pro17];
  }
}

#endif

@end
