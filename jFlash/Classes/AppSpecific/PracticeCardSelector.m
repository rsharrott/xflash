//
//  PracticeCardSelector.m
//  xFlash
//
//  Created by Mark Makdad on 12/27/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "PracticeCardSelector.h"
#import "PracticeCardSelectorMath.h"

@implementation PracticeCardSelector
#pragma mark - Level algorithm

/**
 * Calculates next card level based on current performance & Tag progress
 */
- (NSInteger)calculateNextCardLevelForTag:(Tag *)tag error:(NSError **)error
{
  LWE_ASSERT_EXC(([tag.cardLevelCounts count] == 6),@"There must be 6 card levels (1-5 plus unseen cards)");
  
  // control variables
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  BOOL hideLearnedCards = [settings boolForKey:APP_HIDE_BURIED_CARDS];
  
  // Total number of cards in this set and its level
  NSInteger numLevels = 5;
  NSInteger unseenCount = [[tag.cardLevelCounts objectAtIndex:kLWEUnseenCardLevel] integerValue];
  NSInteger totalCardsInSet = tag.cardCount;
  
  // This is a quick return case; if all cards are unseen, just return that
  if (unseenCount == totalCardsInSet)
  {
    return kLWEUnseenCardLevel;
  }
  
  //if the hide learned cards is set to ON. Try to simulate with the decreased numLevels (hardcoded)
  //and also tell that the totalCardsInSet is no longer the whole sets but the ones NOT in the buried section.
  if (hideLearnedCards)
  {
    // In this mode, we don't have 5 levels, we have four.
    numLevels = 4;
    
    // If all cards are learned, return "Learned" along with an error
    NSInteger learnedCount = [[tag.cardLevelCounts objectAtIndex:kLWELearnedCardLevel] intValue];
    totalCardsInSet = totalCardsInSet - learnedCount;
    if ((totalCardsInSet == 0) && (learnedCount > 0))
    {
      if (error != NULL)
      {
        *error = [NSError errorWithDomain:kTagErrorDomain code:kAllBuriedAndHiddenError userInfo:nil];
      }
      return kLWELearnedCardLevel;
    }
  }
  
  LWE_ASSERT_EXC(totalCardsInSet > 0, @"Beyond this point we assume we have some cards!");
  
  // Get m cards in n bins, figure out total percentages
  NSInteger cardsSeenTotal = 0, numeratorTotal = 0;
  long levelCounts[LWE_SRS_MAX_LEVELS + 1] = {0};
  levelCounts[kLWEUnseenCardLevel] = unseenCount;
  for (NSInteger levelId = 1; levelId <= numLevels; levelId++)
  {
    NSInteger tmpTotal = [[tag.cardLevelCounts objectAtIndex:levelId] integerValue];
    levelCounts[levelId] = tmpTotal;
    cardsSeenTotal = cardsSeenTotal + tmpTotal;
    numeratorTotal = numeratorTotal + (tmpTotal * levelId);
  }
  
  CGFloat p_unseen = [self calculateProbabilityOfUnseenWithCardsSeen:cardsSeenTotal 
                                                          totalCards:totalCardsInSet
                                                           numerator:numeratorTotal 
                                                       levelOneCards:levelCounts[1]];
  
  // Uniform in [0,1). (rand() was never seeded -- the app delegate seeds random() -- so use arc4random.)
  double randomNum = (double)arc4random() / ((double)UINT32_MAX + 1.0);
  
  // Russian roulette: each seen level gets a slice of (1 - p_unseen), weighted towards less-known
  // levels; the remaining p_unseen slice is the unseen level. See PracticeCardSelectorMath.h
  long nextLevel = LWEPickCardLevel(levelCounts, numLevels, p_unseen, randomNum);
  if (nextLevel < 0)
  {
    // Every level is empty -- shouldn't happen given the assert above
    if (error != NULL)
    {
      *error = [NSError errorWithDomain:kTagErrorDomain code:kLWETagUnknownError userInfo:nil];
    }
    return kLWEUnseenCardLevel;
  }
  return (NSInteger)nextLevel;
}

/**
 *  \brief  Calculate the probability of the unseen cards showing for the next 'round'
 *  \return The float ranged 0-1 for the probability of unseen card showing next.
 */
- (CGFloat)calculateProbabilityOfUnseenWithCardsSeen:(NSInteger)cardsSeenTotal totalCards:(NSInteger)totalCardsInSet numerator:(NSInteger)numeratorTotal levelOneCards:(NSInteger)levelOneTotal
{
  NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
  NSInteger maxCardsToStudy = [settings integerForKey:APP_MAX_STUDYING];
  NSInteger weightingFactor = [settings integerForKey:APP_FREQUENCY_MULTIPLIER];
  LWE_ASSERT_EXC((maxCardsToStudy > 0), @"This value must be non-zero");
  LWE_ASSERT_EXC((weightingFactor > 0), @"This value must be non-zero");
  
  return (CGFloat)LWEProbabilityOfUnseenCard(cardsSeenTotal, totalCardsInSet, numeratorTotal,
                                             levelOneTotal, maxCardsToStudy, weightingFactor);
}


@end
