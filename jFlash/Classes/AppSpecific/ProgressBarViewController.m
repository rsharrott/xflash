//
//  ProgressBarViewController.m
//  jFlash
//
//  Created by シャロット ロス on 5/27/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "ProgressBarViewController.h"
#import "LWELocalization.h"

// The label tags are set in the NIB file!! Be careful!  (That's how we find out what the labels are, not a reference)
#define PROGRESS_BAR_TAG 100
#define PROGRESS_LABEL_TAG 200

@implementation ProgressBarViewController
@synthesize tag;

- (void)viewDidLoad
{
  [super viewDidLoad];
  // Level names (tags 301-305) come from the NIB in English; Interface.strings has the short translations.
  LWELocalizeInterface(self.view);
}

- (UIProgressView *)_progressBarForLevel:(NSInteger)i
{
    // Get the current progress view for this guy and remove him (we are going to re-add)
    UIProgressView *progressView = (UIProgressView *)[self.view viewWithTag:(i+PROGRESS_BAR_TAG)];
    if (progressView == nil)
    {
        progressView = [[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault] autorelease];
        progressView.tag = i+PROGRESS_BAR_TAG;
        [self.view addSubview:progressView];
    }
    // Themes v2: one fill for all five levels (the theme accent) on the shared line track
    ThemeManager *tm = [ThemeManager sharedThemeManager];
    [progressView setProgressTintColor:[tm colorForSlot:@"stripBarFill"]];
    [progressView setTrackTintColor:[tm colorForSlot:@"stripBarTrack"]];
    return progressView;
}

// draws the progress bar
- (void) drawProgressBar
{
  CGFloat totalWidth = self.view.bounds.size.width;
  if (totalWidth <= 0) totalWidth = 320.0;
  CGFloat colW = totalWidth / 5.0;
  CGFloat hPad = 4.0;

  NSInteger thisLevelCount = self.tag.seenCardCount;
  UIColor *stripInk = [[ThemeManager sharedThemeManager] colorForSlot:@"stripInk"];

  // For levels 1-5
  for (NSInteger i = 1; i < 6; i++)
  {
    UIProgressView *progressView = [self _progressBarForLevel:i];

    if (i > 1)
    {
      thisLevelCount -= [[self.tag.cardLevelCounts objectAtIndex:i-1] intValue];
    }
    CGFloat progress = 0.0f;
    if (self.tag.seenCardCount > 0)
    {
      progress = ((CGFloat)thisLevelCount / (CGFloat)tag.seenCardCount);
    }
    progressView.progress = progress;

    CGFloat colX = (i - 1) * colW;
    progressView.frame = CGRectMake(colX + hPad, 19, colW - 2 * hPad, 14);
  }

  // Update count labels (tags 201-205) and header labels (tags 301-305)
  for (NSInteger i = 1; i < 6; i++)
  {
    CGFloat colX = (i - 1) * colW;
    CGFloat labelX = colX + hPad;
    CGFloat labelW = colW - 2 * hPad;

    UILabel *countLabel = (UILabel*)[self.view viewWithTag:(i + PROGRESS_LABEL_TAG)];
    if (countLabel)
    {
      countLabel.text = [NSString stringWithFormat:@"%d", [[self.tag.cardLevelCounts objectAtIndex:i] integerValue]];
      countLabel.frame = CGRectMake(labelX, 20, labelW, 21);
      countLabel.textColor = stripInk;
      [self.view bringSubviewToFront:countLabel];
    }

    UILabel *headerLabel = (UILabel*)[self.view viewWithTag:(i + 300)];
    if (headerLabel)
    {
      headerLabel.frame = CGRectMake(labelX, -1, labelW, 21);
      headerLabel.textColor = stripInk;
    }
  }
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  if (self.tag) [self drawProgressBar];
}

- (void)dealloc
{
  [tag release];
  [super dealloc];
}


@end
