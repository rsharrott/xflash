//
//  ExternalAppManager.h
//  xFlash
//
//  Created by Mark Makdad on 2/23/12.
//  Copyright (c) 2012 Long Weekend LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SearchViewController.h"

@interface ExternalAppManager : NSObject

//! This method configures the instance based on the incoming URL and bundle ID
- (void) configureManagerForURL:(NSURL *)incomingURL sourceBundleId:(NSString *)sourceBundleId;

//! The search term carried by a jflash://TERM URL, or nil if there isn't one (e.g. a bare jflash://)
- (NSString *) searchTermForURL:(NSURL *)url;

//! This method translates between a bundleID and the URL handler for that bundle -- e.g. com.lwe.jflash ==> jflash (as in jflash://)
- (NSString *) handlerForBundleId:(NSString *)bundleId;

//! This method translates between a bundleID and what the app should display to the user for that app ID
- (NSString *) nameForBundleId:(NSString *)bundleId;

//! Use this method to tell the external app manager we no longer care about where we came from
- (void) resetState;

//! Actually do the search
- (void) runSearch;

//! Returns YES if the external app wants to be returned to.
- (BOOL) externalAppWantsReturn;

//! Return to the current external app
- (IBAction)returnToExternalApp:(id)sender;

@property (retain, nonatomic) IBOutlet UINavigationController *searchNav;
@property (retain, nonatomic) NSString *externalBundleId;
@property (retain, nonatomic) NSString *searchTerm;

@property BOOL appLaunchedFromURL;

@end
