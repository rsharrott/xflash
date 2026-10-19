//
//  ProgressDetailsViewController.h
//  jFlash
//
//  Created by Ross Sharrott on 11/23/09.
//  Copyright 2009 LONG WEEKEND LLC. All rights reserved.
//
//  The study progress sheet (2026 "paper bottom sheet", design option A).
//  Built in code and presented as a UISheetPresentationController page sheet whose first
//  detent is sized to the content (iOS 16+; large only on iOS 15), plus large. It replaced
//  the fixed 320x480 ProgressView.xib overlay.
//

#import <UIKit/UIKit.h>
#import "Tag.h"

@interface ProgressDetailsViewController : UIViewController

/**
 Designated initializer.  All the data the sheet shows is passed in here (and kept in
 properties), so nothing is written to views before -viewDidLoad.
 \param rightCount  answers marked Right (or buried) this session
 \param wrongCount  answers marked Wrong this session
 */
- (id) initWithTag:(Tag *)tag rightCount:(NSInteger)rightCount wrongCount:(NSInteger)wrongCount
       rightStreak:(NSInteger)rightStreak wrongStreak:(NSInteger)wrongStreak;

//! Re-reads the properties and rebuilds the sheet's content (no-op until the view has loaded).
- (void) updateView;

- (IBAction) dismiss;
- (IBAction) switchToSettings:(id)sender;

@property (nonatomic, retain) Tag *tag;
@property (nonatomic) NSInteger rightCount;
@property (nonatomic) NSInteger wrongCount;
@property (nonatomic) NSInteger rightStreak;
@property (nonatomic) NSInteger wrongStreak;

@end
