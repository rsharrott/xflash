//
//  ExternalAppManager.m
//  xFlash
//
//  Created by Mark Makdad on 2/23/12.
//  Copyright (c) 2012 Long Weekend LLC. All rights reserved.
//

#import "ExternalAppManager.h"
#import "NSURL+IFUnicodeURL.h"

@interface ExternalAppManager ()
- (NSString*) _getDecodedSearchTerm:(NSURL *)url;
- (void) _removeReturnHeaderFromSearch;
@end

@implementation ExternalAppManager

@synthesize searchNav, searchTerm;
@synthesize externalBundleId, appLaunchedFromURL;

/**
 * This method "sets up" the state of the external app manager instance with details from the
 * incoming URL + the source bundle ID.
 * Usually we would "runSearch" immediately thereafter, but sometimes the app isn't finished
 * loading yet, so we give the client the opportunity to conduct them separately.
 */
- (void) configureManagerForURL:(NSURL *)incomingURL sourceBundleId:(NSString *)sourceBundleId
{
  self.searchTerm = [self _getDecodedSearchTerm:incomingURL];
  self.externalBundleId = sourceBundleId;
  self.appLaunchedFromURL = YES;
}

/**
 * To add more "knowledge" to JFlash about who might be calling it from the outside, add
 * to this method (and the one below it)
 */
- (NSString *) handlerForBundleId:(NSString *)bundleId
{
  if ([bundleId isEqualToString:@"com.longweekendmobile.Rikai"])
  {
    return @"rikai";
  }
  else if ([bundleId isEqualToString:@"com.longweekendmobile.RikaiChinese"])
  {
    return @"crikai";
  }
  else
  {
    // Unknown caller: ignore it (no analytics/error reporting -- the app collects no data)
    return nil;
  }
}

/**
 * To add more "knowledge" to JFlash about who might be calling it from the outside, add
 * to this method.
 */
- (NSString *) nameForBundleId:(NSString *)bundleId
{
  if ([bundleId isEqualToString:@"com.longweekendmobile.Rikai"])
  {
    return NSLocalizedString(@"Rikai Browser",@"Rikai Browser");
  }
  else if ([bundleId isEqualToString:@"com.longweekendmobile.RikaiChinese"])
  {
    return NSLocalizedString(@"Rikai Browser",@"Rikai Browser");
  }
  else
  {
    return nil;
  }
}

- (void) runSearch
{
  LWE_ASSERT_EXC(self.searchTerm,@"Need search term - Run - (void) configureManagerForURL:(NSURL *)incomingURL sourceBundleId:(NSString *)sourceBundleId first!!");
  
  // Reset the search view to the root search view (so that the "topViewController" is the search VC)
  [self.searchNav popToRootViewControllerAnimated:NO];
  
  SearchViewController *searchVC = (SearchViewController*)[self.searchNav topViewController];
  LWE_ASSERT_EXC([searchVC isKindOfClass:[SearchViewController class]], @"Whoa");
  
  // Tell the search VC to search
  [searchVC runSearchAndSetSearchBarForString:self.searchTerm];
}

- (void) resetState
{
  self.searchTerm = nil;
  self.externalBundleId = nil;
  self.appLaunchedFromURL = NO;
  [self _removeReturnHeaderFromSearch];
}

- (BOOL) externalAppWantsReturn
{
  BOOL wantsReturn = NO;
  // ONLY return if we know where we are going to, we have a xxxx:// handler defined, AND the app can open that handler.
  if (self.externalBundleId && [self handlerForBundleId:self.externalBundleId])
  {
    NSString *urlString = [NSString stringWithFormat:@"%@://",[self handlerForBundleId:self.externalBundleId]];
    wantsReturn = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]];
  }
  return wantsReturn;
}

- (IBAction)returnToExternalApp:(id)sender
{
  LWE_ASSERT_EXC(self.externalBundleId, @"You must have a bundle ID");

  NSString *handler = [self handlerForBundleId:self.externalBundleId];
  LWE_ASSERT_EXC(handler, @"You must have a URL handler set for bundle ID");
  
  NSString *urlString = [NSString stringWithFormat:@"%@://foobar",handler];
  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
}

#pragma mark - Private Methods

- (NSString*) _getDecodedSearchTerm:(NSURL *)url  
{
  // Get the PLIST data about our scheme - use this because we could be JFlash://, cFlash://, etc.
  NSArray *urlSchemes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
  NSDictionary *schemeInfo = [urlSchemes objectAtIndex:0];
  NSString *scheme = [(NSArray*)[schemeInfo objectForKey:@"CFBundleURLSchemes"] objectAtIndex:0];
  NSString *schemeUri = [NSString stringWithFormat:@"%@://",scheme];
  
  NSString *term = [url unicodeAbsoluteString];
  if ([term isEqualToString:@""] || [term isEqualToString:schemeUri])
  {
    term = [[url absoluteString] stringByRemovingPercentEncoding];
  }
  
  // Replace out the schema name
  term = [term stringByReplacingOccurrencesOfString:schemeUri withString:@""];
  return term;
}

- (void) _removeReturnHeaderFromSearch
{
  // Set the view controller to no longer show the header
  SearchViewController *searchVC = (SearchViewController*)[[self.searchNav viewControllers] objectAtIndex:0];
  LWE_ASSERT_EXC([searchVC isKindOfClass:[SearchViewController class]], @"Whoa");
  
  // We need to reload the table once to kill the header
  [searchVC.tableView reloadData];
}


#pragma mark - Class Plumbing

- (void) dealloc
{
  [searchTerm release];
  [externalBundleId release];
  [searchNav release];
  [super dealloc];
}

@end
