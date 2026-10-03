//
//  StudyViewController.m
//  jFlash
//
//  Created by シャロット ロス on 5/4/09.
//  Copyright LONG WEEKEND INC 2009. All rights reserved.
//

#import "jFlashAppDelegate.h"
#import "CurrentState.h"
#import "SettingsViewController.h"
#import "StudyViewController.h"
#import "LWENetworkUtils.h"
#import "AddTagViewController.h"
#import "UpdateManager.h"
#import "CardViewController.h"

@interface StudyViewController()
//private methods
- (void) _applicationDidEnterBackground:(NSNotification*)notification;
- (void) _contentSizeCategoryDidChange:(NSNotification*)notification;
- (BOOL) _shouldShowExampleViewForCard:(Card*)card;
- (BOOL) _shouldShowSampleAudioButtonForCard:(Card*)card;
- (void) _tagContentDidChange:(NSNotification*)notification;
- (void) _setupScrollView;
- (void)_setupPageControl:(NSInteger)page;
- (void) _setupDelegateForStudyMode:(NSString*)studyMode;
- (void) _setupSubviews;
- (Card*) _getNextCardWithDirection:(NSString*)directionOrNil currentCard:(Card *)theCurrentCard;
@end
