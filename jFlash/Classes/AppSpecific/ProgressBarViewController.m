//
//  ProgressBarViewController.m
//  jFlash
//
//  Created by シャロット ロス on 5/27/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "ProgressBarViewController.h"
#import "LWELocalization.h"
#import "LWEDesignTokens.h"

// The label tags are set in the NIB file!! Be careful!  (That's how we find out what the labels are, not a reference)
#define PROGRESS_BAR_TAG 100
#define PROGRESS_LABEL_TAG 200

//! Level names. Capped so "Right 1x" / "正解1回" still fit a column on a narrow phone.
static UIFont *LWEProgressStripHeaderFont(void)
{
  return LWEDesignScaledFont(UIFontTextStyleCaption2, 11, UIFontWeightSemibold, 15);
}

//! The count under each bar. Slightly larger than the name, still capped.
static UIFont *LWEProgressStripCountFont(void)
{
  return LWEDesignScaledFont(UIFontTextStyleCaption1, 13, UIFontWeightBold, 18);
}

@implementation ProgressBarViewController
@synthesize tag;

+ (CGFloat) preferredStripHeight
{
  // 6pt pad above the name, gaps, a 4pt bar, 6pt pad under the count. At least 44pt so the
  // whole panel (the button that opens the sheet) meets the minimum hit size.
  CGFloat block = ceil(LWEProgressStripHeaderFont().lineHeight) + 2.0 + 4.0 + 1.0 + ceil(LWEProgressStripCountFont().lineHeight);
  return MAX(44.0, block + 12.0);
}

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
  CGFloat hPad = 2.0;

  NSInteger thisLevelCount = self.tag.seenCardCount;
  UIColor *stripInk = [[ThemeManager sharedThemeManager] colorForSlot:@"stripInk"];
  UIFont *headerFont = LWEProgressStripHeaderFont();
  UIFont *countFont = LWEProgressStripCountFont();
  CGFloat headerH = ceil(headerFont.lineHeight);
  CGFloat countH = ceil(countFont.lineHeight);
  CGFloat barH = 4.0;
  CGFloat block = headerH + 2.0 + barH + 1.0 + countH;
  CGFloat y = MAX(0.0, floor((self.view.bounds.size.height - block) / 2.0));

  // For levels 1-5. Bars stay cumulative over seen cards (level i = cards at level >= i ÷ seen).
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
    progressView.frame = CGRectMake(colX + hPad, y + headerH + 2.0, colW - 2 * hPad, barH);
  }

  // Update count labels (tags 201-205) and header labels (tags 301-305)
  for (NSInteger i = 1; i < 6; i++)
  {
    CGFloat colX = (i - 1) * colW;
    CGFloat labelX = colX + hPad;
    CGFloat labelW = colW - 2 * hPad;

    UILabel *headerLabel = (UILabel*)[self.view viewWithTag:(i + 300)];
    if (headerLabel)
    {
      headerLabel.font = headerFont;
      headerLabel.adjustsFontForContentSizeCategory = YES;
      headerLabel.adjustsFontSizeToFitWidth = YES;
      headerLabel.minimumScaleFactor = 0.7;
      headerLabel.textAlignment = NSTextAlignmentCenter;
      headerLabel.frame = CGRectMake(labelX, y, labelW, headerH);
      headerLabel.textColor = stripInk;
    }

    UILabel *countLabel = (UILabel*)[self.view viewWithTag:(i + PROGRESS_LABEL_TAG)];
    if (countLabel)
    {
      countLabel.text = [NSString stringWithFormat:@"%d", [[self.tag.cardLevelCounts objectAtIndex:i] integerValue]];
      countLabel.font = countFont;
      countLabel.adjustsFontForContentSizeCategory = YES;
      countLabel.adjustsFontSizeToFitWidth = YES;
      countLabel.minimumScaleFactor = 0.7;
      countLabel.textAlignment = NSTextAlignmentCenter;
      countLabel.frame = CGRectMake(labelX, y + headerH + 2.0 + barH + 1.0, labelW, countH);
      countLabel.textColor = stripInk;
      [self.view bringSubviewToFront:countLabel];
    }
  }
}

- (NSString *) accessibilitySummary
{
  NSMutableArray *names = [NSMutableArray arrayWithCapacity:5];
  NSMutableArray *counts = [NSMutableArray arrayWithCapacity:5];
  for (NSInteger i = 1; i < 6; i++)
  {
    UILabel *headerLabel = (UILabel *)[self.view viewWithTag:(i + 300)];
    UILabel *countLabel = (UILabel *)[self.view viewWithTag:(i + PROGRESS_LABEL_TAG)];
    [names addObject:([headerLabel isKindOfClass:[UILabel class]] ? (headerLabel.text ?: @"") : @"")];
    [counts addObject:([countLabel isKindOfClass:[UILabel class]] ? (countLabel.text ?: @"") : @"")];
  }
  return LWEProgressAccessibilitySummary(names, counts);
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
