//
//  MoodIcon.h
//  jFlash
//
//  Created by シャロット ロス on 2/13/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MoodIcon : NSObject

//! Update the mood icon depending on the current percentage correct
- (void) updateMoodIcon:(CGFloat)percentCorrect;
- (void) applyTheme;

//! VoiceOver value for the score bubble: "100% right" (localized)
+ (NSString *) accessibilityValueForPercentCorrect:(CGFloat)percentCorrect;

- (IBAction) doTogglePercentCorrectBtn;

- (void) turnPercentCorrectOff;
- (void) turnPercentCorrectOn;

//! If Enabled, you can tap the mood icon (practice mode)
- (void) setButtonEnabled:(BOOL)isEnabled;

@property (retain, nonatomic) IBOutlet UIView *view;
@property (retain, nonatomic) IBOutlet UIButton *moodIconBtn;
@property (retain, nonatomic) IBOutlet UILabel *percentCorrectLabel;
@property (retain, nonatomic) IBOutlet UIImageView *talkBubble;

@end
