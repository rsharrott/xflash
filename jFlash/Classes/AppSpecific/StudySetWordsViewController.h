//
//  StudySetWordViewController.h
//  jFlash
//
//  Created by Ross Sharrott on 6/28/09.
//  Copyright 2009 LONG WEEKEND LLC All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TagPeer.h"
#import "Tag.h"
#import "CardPeer.h"

enum settingsRows
{
  kWordSetOptionsStart = 0,
  kWordSetOptionsEditSet = 1,
  settingsRowsLength
};

enum wordsSections
{
  kWordSetOptionsSection = 0,
  kWordSetListSections = 1,
  wordsSectionsLength
};

@interface StudySetWordsViewController : UITableViewController

- (id) initWithTag:(Tag*)initTag;

@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) Tag *tag;
//! Card-id NSNumbers until a row is shown, then the Card for that row.
@property (retain) NSMutableArray *cards;

@end