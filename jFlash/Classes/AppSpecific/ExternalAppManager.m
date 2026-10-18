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
  self.searchTerm = [self searchTermForURL:incomingURL];
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
  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
}

#pragma mark - Private Methods

- (NSString *) searchTermForURL:(NSURL *)url
{
  if (url == nil)
  {
    return nil;
  }

  // IFUnicodeURL turns a punycode host (jflash://xn--...) back into the Japanese/Chinese term
  NSString *term = [url unicodeAbsoluteString];
  NSString *bareScheme = [url.scheme length] ? [NSString stringWithFormat:@"%@://",url.scheme] : nil;
  if ([term length] == 0 || (bareScheme && [term caseInsensitiveCompare:bareScheme] == NSOrderedSame))
  {
    // stringByRemovingPercentEncoding returns nil for malformed escapes; keep the raw string then
    NSString *raw = [url absoluteString];
    term = [raw stringByRemovingPercentEncoding] ?: raw;
  }
  if (term == nil)
  {
    return nil;
  }

  // Strip "<scheme>://" (or "<scheme>:") whatever its case -- jflash://, JFlash://, cflash://, ...
  if ([url.scheme length])
  {
    NSString *prefixes[] = { [NSString stringWithFormat:@"%@://",url.scheme], [NSString stringWithFormat:@"%@:",url.scheme] };
    for (NSUInteger i = 0; i < 2; i++)
    {
      NSRange r = [term rangeOfString:prefixes[i] options:(NSAnchoredSearch | NSCaseInsensitiveSearch)];
      if (r.location != NSNotFound)
      {
        term = [term substringFromIndex:NSMaxRange(r)];
        break;
      }
    }
  }

  // Path/query parts can still carry %-escapes (e.g. %20); decode them if they're well-formed
  term = [term stringByRemovingPercentEncoding] ?: term;

  // A trailing slash (jflash://word/) isn't part of the term
  term = [term stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
  term = [term stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return ([term length] > 0) ? term : nil;
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
