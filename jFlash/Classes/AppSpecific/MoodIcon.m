//
//  MoodIcon.m
//  jFlash
//
//  Created by シャロット ロス on 2/13/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "MoodIcon.h"

//! Handles "hot head" mood icons
@implementation MoodIcon
@synthesize talkBubble;

@synthesize percentCorrectLabel, moodIconBtn, view;

- (void) awakeFromNib
{
  [[NSBundle mainBundle] loadNibNamed:@"MoodIcon" owner:self options:nil];
  [self applyTheme];
}

//! Themes v2: the 67% bubble fill follows the card (fire-wash on Paper/Fire, paper on Water)
- (void) applyTheme
{
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  UIColor *fill = [tm colorForSlot:@"moodBubbleFill"];
  UIColor *ink = [tm colorForSlot:@"moodBubbleInk"];
  if (self.talkBubble && fill)
  {
    // talkbubble-ft.png is a white bubble; template+tint paints moodBubbleFill
    UIImage *base = self.talkBubble.image ?: [UIImage imageNamed:@"talkbubble-ft.png"];
    self.talkBubble.image = [base imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.talkBubble.tintColor = fill;
  }
  if (self.percentCorrectLabel && ink)
  {
    self.percentCorrectLabel.textColor = ink;
  }
}

- (void) setButtonEnabled:(BOOL)enable
{
  self.moodIconBtn.enabled = enable;
}

/**
 * Turns the % correct button on and off, in case it is in the way of the meaning
 */
- (IBAction) doTogglePercentCorrectBtn
{
  // Hide the percentage talk bubble on click; use its current state to check which we should do.
  if (self.talkBubble.hidden == YES)
  {
    [self turnPercentCorrectOn];
  }
  else
  {
    [self turnPercentCorrectOff];
  }
}

#pragma mark -

- (void) turnPercentCorrectOff
{
  self.talkBubble.hidden = YES;
  self.percentCorrectLabel.hidden = YES;
}

- (void) turnPercentCorrectOn
{
  self.talkBubble.hidden = NO;
  self.percentCorrectLabel.hidden = NO;
}

- (void) updateMoodIcon:(CGFloat)percentCorrect
{
  self.percentCorrectLabel.text = [NSString stringWithFormat:@"%.0f%%",percentCorrect];

  // TODO: iPad customization!
  NSArray *hotHeadsArray = [[NSArray alloc] initWithObjects:
                            @"mood-icons/positive/hh-ecstatic.png", @"mood-icons/positive/hh-happy.png",
                            @"mood-icons/positive/hh-jolly.png", @"mood-icons/neutral/hh-small-smile.png",
                            @"mood-icons/neutral/hh-my-name-is-forest.png",@"mood-icons/neutral/hh-uncommunicative.png",
                            @"mood-icons/negative/hh-wounded.png", @"mood-icons/negative/hh-losin-it.png",
                            @"mood-icons/negative/hh-pissed.png", @"mood-icons/negative/hh-sea-sick.png",
                            @"mood-icons/negative/hh-wounded.png", nil];
  //  NSArray* transitionHHArray = [[NSArray alloc] initWithObjects: @"positive/hh-on-a-roll.png", @"positive/hh-smug.png", @"negative/hh-aggro.png", @"negative/hh-frustrated.png", nil]; 
  //  bool shouldAnimate = NO;
  //NSArray* transitionHHAnimationArray;
  
  NSInteger loopCount = 0;
  
  CGFloat a = 100.0f; 
  NSString *hotheadName = nil;

  // default when no animtions
  ThemeManager *tm = [ThemeManager sharedThemeManager];
  hotheadName = [tm elementWithCurrentTheme:[hotHeadsArray objectAtIndex:0]];
  while (a >= 0)
  {
    if (percentCorrect <= a && percentCorrect > a - 10)
    {
      hotheadName = [tm elementWithCurrentTheme:[hotHeadsArray objectAtIndex:loopCount]];
      break;
    }
    a -= 10;
    loopCount++;
  }
  
  [self.moodIconBtn setBackgroundImage:[UIImage imageNamed:hotheadName] forState:UIControlStateNormal];
  [hotHeadsArray release];
  [self applyTheme];
}

- (void)dealloc
{
  [view release];
  [moodIconBtn release];
  [percentCorrectLabel release];
  [talkBubble release];
  [super dealloc];
}
@end
