//
//  AddTagViewController.h
//  jFlash
//
//  Created by Mark Makdad on 6/28/09.
//  Copyright 2009 LONG WEEKEND LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Card.h"
#import "LWEAudioQueue.h"

@interface AddTagViewController : UITableViewController <LWEAudioQueueDelegate>

- (id) initWithCard:(Card*) card;
- (id) initForExampleSentencesWithCard:(Card *)card;
- (IBAction) addStudySet;
//! Dismisses this controller when it is shown modally (target of the "Done" button)
- (IBAction) dismissModal:(id)sender;

@property (retain) NSArray *myTagArray;
@property (retain) NSArray *sysTagArray;
@property (retain) NSArray *sentencesArray;
@property (retain) Card *currentCard;
@property BOOL showExamplesCell;

@end
