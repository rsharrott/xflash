//
//  SearchViewController.h
//  jFlash
//
//  Created by Mark Makdad on 8/2/09.
//  Copyright 2009 LONG WEEKEND INC.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CardPeer.h"
#import "ExampleSentencePeer.h"
#import "AddTagViewController.h"
#import "PluginManager.h"
#import "ExternalAppManager.h"
#import "GradientButton.h"

// View tags for the custom table view cells
#define SEARCH_CELL_HEADWORD 200
#define SEARCH_CELL_READING 201
#define SEARCH_CELL_MEANING 202
#define SEARCH_CELL_BUTTON 203

//! State machine for searching
typedef enum searchStates
{
  kSearchNoSearch,              //! Default state when not searching
  kSearchSearching,             //! When a search is active but nothing is happening yet
  kSearchHasResults,            //! Any search returned results 
  kSearchHasNoResults,          //! Regular search returned nothing
} LWEFlashSearchStates;

@class ExternalAppManager;

/**
 * Handles dictionary-like search functions inside JFlash
 */
@interface SearchViewController : UITableViewController <UISearchBarDelegate>
{
  LWEFlashSearchStates _searchState;              //! Holds the "state" of the search
  NSArray *_currentResultArray;                   //! Holds the current results (switched when the user switches the pill control)
}

- (IBAction) returnToExternalApp:(id)sender;

//! Calls "runSearchForString" after programmatically populating the search bar w/ text - used for Rikai
- (void) runSearchAndSetSearchBarForString:(NSString*)text;

//! Call to search the database & populate the table w/ results
- (void) runSearchForString:(NSString*)text;

// UIView-related properties
@property (nonatomic, retain) IBOutlet UITableViewCell *searchingCell;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UISearchBar *searchBar;

//! The view to show in the header when the user comes from an external app
@property (nonatomic, retain) IBOutlet UIView *returnToExternalAppView;
@property (nonatomic, retain) IBOutlet GradientButton *externalAppBtn;

@property (nonatomic, retain) IBOutlet PluginManager *pluginManager;
@property (nonatomic, retain) IBOutlet ExternalAppManager *externalAppManager;

@end
