//
//  PracticeCardSelectorMath.h
//  xFlash
//
//  Pure (no NSUserDefaults, no Tag, no randomness) versions of the Practice
//  mode card-level math, so it can be unit tested. PracticeCardSelector reads
//  the settings and the Tag's level counts and calls these.
//
//  Header-only (static inline): it's in the project as a header reference only, not a compile source.
//

#ifndef LWE_PRACTICE_CARD_SELECTOR_MATH_H
#define LWE_PRACTICE_CARD_SELECTOR_MATH_H

#include <math.h>

/** Level numbers used by the math (same values as kLWEUnseenCardLevel / kLWELearnedCardLevel). */
#define LWE_SRS_UNSEEN_LEVEL 0
#define LWE_SRS_MAX_LEVELS 5

/**
 * Maps the "Frequency of New Cards" slider value (1...4, right-hand label "More Often")
 * to the exponent used on the "how well do you know the seen cards" term below.
 *
 * That term is ((mean level - 1) / 4) ^ exponent, a number in [0,1], so a LARGER
 * exponent means FEWER new cards. The old code used the slider value directly as the
 * exponent, which made "More Often" mean less often. 4/frequency inverts it while
 * keeping the Medium preset (frequency 2 -> exponent 2) exactly as before:
 *   1 -> 4, 2 -> 2, 3 -> 1.33, 4 -> 1
 */
static inline double LWEUnseenExponentForFrequency(long frequency)
{
  if (frequency < 1) frequency = 1;
  if (frequency > 4) frequency = 4;
  return 4.0 / (double)frequency;
}

/**
 * Probability (0...1) that the next card should be an unseen one.
 *
 * \param cardsSeenTotal  cards in the study levels being considered (1...numLevels)
 * \param totalCardsInSet cardsSeenTotal + unseen cards
 * \param numeratorTotal  sum of (cards at level * level), for the mean level
 * \param levelOneTotal   cards at level 1 ("Studying")
 * \param maxCardsToStudy the "Number of Cards in Study Pool" setting
 * \param frequency       the "Frequency of New Cards" setting (1...4)
 *
 * All arguments are signed on purpose: (maxCardsToStudy - cardsSeenTotal) goes
 * negative once you've seen more cards than the pool size, and that has to clamp
 * to 0, not wrap around to 2^64.
 */
static inline double LWEProbabilityOfUnseenCard(long cardsSeenTotal, long totalCardsInSet, long numeratorTotal,
                                                long levelOneTotal, long maxCardsToStudy, long frequency)
{
  // Nothing left to introduce, or the "Studying" pile is already full
  if ((cardsSeenTotal >= totalCardsInSet) || (maxCardsToStudy <= 0) || (levelOneTotal >= maxCardsToStudy))
  {
    return 0.0;
  }
  // Nothing seen yet (and there are unseen cards): it has to be a new card. Also avoids 0/0 for the mean.
  if (cardsSeenTotal <= 0)
  {
    return 1.0;
  }

  // How well the seen cards are known: mean level 1 -> 0, mean level 5 -> 1
  double mean = (double)numeratorTotal / (double)cardsSeenTotal;
  double known = (mean - 1.0) / 4.0;
  if (known < 0.0) known = 0.0;
  if (known > 1.0) known = 1.0;
  double p_unseen = pow(known, LWEUnseenExponentForFrequency(frequency));

  // How much room is left in the study pool: 1 when empty, 0 when full or over
  long roomLeft = maxCardsToStudy - cardsSeenTotal;
  if (roomLeft < 0) roomLeft = 0;
  double room = pow((double)roomLeft, 0.25) / pow((double)maxCardsToStudy, 0.25);

  p_unseen = p_unseen + (1.0 - p_unseen) * room;
  if (p_unseen < 0.0) p_unseen = 0.0;
  if (p_unseen > 1.0) p_unseen = 1.0;
  return p_unseen;
}

/**
 * Picks the next card level ("roulette wheel").
 *
 * \param levelCounts  levelCounts[i] = number of cards at level i, for i = 0 (unseen) ... numLevels
 * \param numLevels    5 normally, 4 when Learned cards are hidden (level 5 is then never picked)
 * \param p_unseen     from LWEProbabilityOfUnseenCard
 * \param randomNum    uniform random number in [0,1)
 *
 * Seen level i gets (1 - p_unseen) * w_i / sum(w), where w_i = count_i * (numLevels - i + 1),
 * so lower (less known) levels come up more often. The remaining p_unseen is the unseen level.
 * Never returns an empty level as long as at least one level 0...numLevels has cards;
 * returns -1 if they are all empty.
 */
static inline long LWEPickCardLevel(const long *levelCounts, long numLevels, double p_unseen, double randomNum)
{
  if (numLevels > LWE_SRS_MAX_LEVELS) numLevels = LWE_SRS_MAX_LEVELS;
  if (isnan(p_unseen) || p_unseen < 0.0) p_unseen = 0.0;
  if (p_unseen > 1.0) p_unseen = 1.0;

  long denominatorTotal = 0;
  for (long levelId = 1; levelId <= numLevels; levelId++)
  {
    denominatorTotal += levelCounts[levelId] * (numLevels - levelId + 1);
  }

  if (denominatorTotal > 0)
  {
    double pTotal = 0.0;
    for (long levelId = 1; levelId <= numLevels; levelId++)
    {
      double weight = (double)(levelCounts[levelId] * (numLevels - levelId + 1)) / (double)denominatorTotal;
      pTotal += (1.0 - p_unseen) * weight;
      if (levelCounts[levelId] > 0 && pTotal > randomNum)
      {
        return levelId;
      }
    }
  }

  // The rest of the wheel belongs to unseen cards
  if (levelCounts[LWE_SRS_UNSEEN_LEVEL] > 0)
  {
    return LWE_SRS_UNSEEN_LEVEL;
  }

  // No unseen cards: only reachable through float rounding (randomNum ~ 1.0) or bad counts.
  // Hand back the highest non-empty seen level rather than an empty unseen level.
  for (long levelId = numLevels; levelId >= 1; levelId--)
  {
    if (levelCounts[levelId] > 0)
    {
      return levelId;
    }
  }
  return -1;
}

#endif
