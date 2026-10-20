//
//  ProgressBarViewController.h
//  jFlash
//
//  Created by シャロット ロス on 5/27/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Tag.h"

//! What VoiceOver says for the progress strip: each level's name and count, "Studying 3, Right 1x 15, ...".
//! names and counts pair up by index; a level with no name is skipped.
static inline NSString *LWEProgressAccessibilitySummary(NSArray *names, NSArray *counts)
{
  NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[names count]];
  for (NSUInteger i = 0; i < [names count]; i++)
  {
    NSString *name = [[names objectAtIndex:i] description];
    if ([name length] == 0) continue;
    NSString *count = (i < [counts count]) ? [[counts objectAtIndex:i] description] : @"";
    [parts addObject:([count length] > 0 ? [NSString stringWithFormat:@"%@ %@", name, count] : name)];
  }
  return [parts componentsJoinedByString:@", "];
}

@interface ProgressBarViewController : UIViewController

- (void) drawProgressBar;

//! The strip as VoiceOver reads it (the level names are the localized labels on the strip)
- (NSString *) accessibilitySummary;

@property (nonatomic, retain) Tag *tag;

@end
