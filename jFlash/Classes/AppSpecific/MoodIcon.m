//
//  MoodIcon.m
//  jFlash
//
//  Created by シャロット ロス on 2/13/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "MoodIcon.h"

@interface MoodIcon ()
//! The last score shown (or hidden) in the bubble, so VoiceOver can read it again when it reappears
@property (nonatomic, assign) CGFloat lastPercentCorrect;
@property (nonatomic, assign) BOOL hasPercentCorrect;
@end

//! Handles "hot head" mood icons
@implementation MoodIcon
@synthesize lastPercentCorrect, hasPercentCorrect;
@synthesize talkBubble;

@synthesize percentCorrectLabel, moodIconBtn, view;

- (void) awakeFromNib
{
  [[NSBundle mainBundle] loadNibNamed:@"MoodIcon" owner:self options:nil];
  // VoiceOver: one "Session score, 100% right" element (the face); the bubble's "100%" is not read twice
  self.moodIconBtn.isAccessibilityElement = YES;
  self.moodIconBtn.accessibilityLabel = NSLocalizedString(@"Session score", @"MoodIcon.SessionScoreAccessibility");
  self.percentCorrectLabel.isAccessibilityElement = NO;
  self.percentCorrectLabel.accessibilityElementsHidden = YES;
  self.talkBubble.isAccessibilityElement = NO;
  [self _updateAccessibility];
  [self applyTheme];
}

+ (NSString *) accessibilityValueForPercentCorrect:(CGFloat)percentCorrect
{
  return [NSString stringWithFormat:NSLocalizedString(@"%ld%% right", @"MoodIcon.PercentRightAccessibility"), (long)lroundf(percentCorrect)];
}

//! Practice mode: tapping the face shows / hides the bubble, so it is a button; otherwise plain text
//! (not a "dimmed" button).  VoiceOver reads the score only while the bubble shows it: with the
//! bubble hidden there is no value, and in Browse mode (not tappable, no score on screen) the face is
//! not an element at all.
- (void) _updateAccessibility
{
  BOOL enabled = self.moodIconBtn.enabled;
  BOOL scoreShown = (self.talkBubble.hidden == NO);
  self.moodIconBtn.isAccessibilityElement = [MoodIcon scoreBubbleIsAccessibilityElementWhenEnabled:enabled bubbleHidden:self.talkBubble.hidden];
  self.moodIconBtn.accessibilityTraits = enabled ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
  self.moodIconBtn.accessibilityHint = enabled ? NSLocalizedString(@"Shows or hides the score", @"MoodIcon.ToggleHint") : nil;
  self.moodIconBtn.accessibilityValue = (scoreShown && self.hasPercentCorrect) ? [MoodIcon accessibilityValueForPercentCorrect:self.lastPercentCorrect] : nil;
}

+ (BOOL) scoreBubbleIsAccessibilityElementWhenEnabled:(BOOL)enabled bubbleHidden:(BOOL)bubbleHidden
{
  // Tappable (Practice): always, so it can be found to show the score again.  Otherwise only while it shows a score.
  return enabled || (bubbleHidden == NO);
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
  [self _updateAccessibility];
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
  [self _updateAccessibility];
}

- (void) turnPercentCorrectOn
{
  self.talkBubble.hidden = NO;
  self.percentCorrectLabel.hidden = NO;
  [self _updateAccessibility];
}

- (void) updateMoodIcon:(CGFloat)percentCorrect
{
  self.percentCorrectLabel.text = [NSString stringWithFormat:@"%.0f%%",percentCorrect];
  self.lastPercentCorrect = percentCorrect;
  self.hasPercentCorrect = YES;
  [self _updateAccessibility];

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
