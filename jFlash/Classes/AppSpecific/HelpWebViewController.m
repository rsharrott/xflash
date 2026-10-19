//
//  HelpWebViewController.m
//  jFlash
//
//  Created by Mark Makdad on 4/10/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "HelpWebViewController.h"

@implementation HelpWebViewController

@synthesize filename, webViewContainer;

/**
 * Initializes the class and sets HTML filename to use and the title of the nav bar.
 * \param filename String containing the filename only (no path) of the HTML to load
 * \param title String to appear in the navigation bar
 */
- (id)initWithFilename:(NSString *)fn usingTitle:(NSString*) title
{
  if ((self = [super init]))
  {
    self.filename = fn;
    self.title = title;
  }
  return self;
}


/** Calls _loadPageWithBundleFilename and re-sets title */
- (void) loadPageWithBundleFilename:(NSString*)fn usingTitle:(NSString*) title
{
  self.filename = fn;
  self.title = title;
  [self _loadPageWithBundleFilename:fn];
}


/** Creates the WKWebView programmatically inside the XIB-instantiated container. */
- (void) viewDidLoad
{
  [super viewDidLoad];

  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  _webView = [[WKWebView alloc] initWithFrame:self.webViewContainer.bounds
                                configuration:config];
  [config release];
  _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  _webView.navigationDelegate = self;
  _webView.scrollView.bounces = NO;
  [self.webViewContainer addSubview:_webView];

  [self _loadPageWithBundleFilename:self.filename];
}


/** Sets the nav bar tint to the current theme and sets the background to our standard */
- (void)viewWillAppear: (BOOL)animated
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
  self.view.backgroundColor = [[ThemeManager sharedThemeManager] backgroundColor];
}


/**
 * Loads the filename into the WKWebView - there should be no extension on the filename (but the actual file should be .html).
 * When the app is running in Japanese, help/ja/<name>.html is used if it exists; otherwise help/<name>.html (English).
 * Pages in help/ja link ../help.css and ../img/, so read access is granted to the whole help folder.
 */
- (void) _loadPageWithBundleFilename:(NSString*)fname
{
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *language = [[bundle preferredLocalizations] firstObject];
  NSString *urlAddress = nil;
  if ([language hasPrefix:@"ja"])
  {
    urlAddress = [bundle pathForResource:fname ofType:@"html" inDirectory:@"help/ja"];
  }
  if (urlAddress == nil)
  {
    urlAddress = [bundle pathForResource:fname ofType:@"html" inDirectory:@"help"];
  }
  if (urlAddress == nil) return;

  NSURL *url = [NSURL fileURLWithPath:urlAddress];
  NSURL *helpFolder = [NSURL fileURLWithPath:[[bundle resourcePath] stringByAppendingPathComponent:@"help"] isDirectory:YES];
  // WKWebView requires a readAccessURL for file:// loads to grant directory access.
  [_webView loadFileURL:url allowingReadAccessToURL:helpFolder];
}


//! Standard dealloc
- (void)dealloc
{
  _webView.navigationDelegate = nil;
  [_webView release];
  [filename release];
  [webViewContainer release];
  [super dealloc];
}


@end
