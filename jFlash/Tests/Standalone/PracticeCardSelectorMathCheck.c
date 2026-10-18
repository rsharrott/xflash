//
//  PracticeCardSelectorMathCheck.c
//  Standalone check for PracticeCardSelectorMath.h (no Xcode, no simulator needed):
//
//    cd jFlash/Tests/Standalone
//    cc -std=c99 -Wall -Wextra -I ../../Classes/AppSpecific PracticeCardSelectorMathCheck.c -lm -o /tmp/srs_check
//    /tmp/srs_check
//

#include <stdio.h>
#include <math.h>
#include "PracticeCardSelectorMath.h"

static int failures = 0;
#define CHECK(cond, ...) do { if (!(cond)) { failures++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

// The pre-fix formula, verbatim apart from types: cardsSeenTotal was NSUInteger, so
// (maxCardsToStudy - cardsSeenTotal) was evaluated unsigned.
static double OldProbabilityOfUnseen(unsigned long cardsSeenTotal, unsigned long totalCardsInSet,
                                     unsigned long numeratorTotal, unsigned long levelOneTotal,
                                     long maxCardsToStudy, long weightingFactor)
{
  if ((cardsSeenTotal == totalCardsInSet) || (levelOneTotal >= (unsigned long)maxCardsToStudy)) return 0;
  double mean = (double)numeratorTotal / (double)cardsSeenTotal;
  double p = pow((mean - 1.0) / 4.0, weightingFactor);
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wsign-conversion"
  p = p + (1.0 - p) * (pow((maxCardsToStudy - cardsSeenTotal), 0.25) / pow(maxCardsToStudy, 0.25));
#pragma GCC diagnostic pop
  return p;
}

// Fraction of picks (over an even grid of random numbers) that land on each level
static void Distribution(const long *counts, long numLevels, double pUnseen, double *out)
{
  const int N = 100000;
  for (int i = 0; i <= LWE_SRS_MAX_LEVELS; i++) out[i] = 0;
  for (int i = 0; i < N; i++)
  {
    long level = LWEPickCardLevel(counts, numLevels, pUnseen, (i + 0.5) / N);
    if (level >= 0) out[level] += 1.0 / N;
  }
}

int main(void)
{
  // --- The reported bug: Medium (pool 30, frequency 2), 40 cards seen, only 10 of them in Studying ---
  // levels: 0 unseen=60, 1=10, 2=10, 3=10, 4=10, 5=0 -> numerator 10+20+30+40 = 100, mean 2.5
  long counts[6] = {60, 10, 10, 10, 10, 0};
  double oldP = OldProbabilityOfUnseen(40, 100, 100, 10, 30, 2);
  double newP = LWEProbabilityOfUnseenCard(40, 100, 100, 10, 30, 2);
  printf("Medium, 40 seen / pool 30: old p_unseen = %.1f (1 - p = %.1f), new p_unseen = %.4f\n", oldP, 1 - oldP, newP);
  CHECK(oldP > 1.0, "old formula should reproduce the wrap-around (got %f)", oldP);
  CHECK(fabs(newP - 0.140625) < 1e-9, "new p_unseen should be ((2.5-1)/4)^2 = 0.140625, got %f", newP);

  double dist[6];
  Distribution(counts, 5, oldP, dist);
  printf("  old picks: unseen %.1f%%, seen %.1f%%\n", 100 * dist[0], 100 * (1 - dist[0]));
  CHECK(dist[0] > 0.999, "old math should (wrongly) always pick unseen");
  Distribution(counts, 5, newP, dist);
  printf("  new picks: unseen %.1f%%, L1 %.1f%%, L2 %.1f%%, L3 %.1f%%, L4 %.1f%%\n",
         100 * dist[0], 100 * dist[1], 100 * dist[2], 100 * dist[3], 100 * dist[4]);
  CHECK(fabs(dist[0] - newP) < 0.001, "unseen share should equal p_unseen");
  CHECK(dist[1] > dist[2] && dist[2] > dist[3] && dist[3] > dist[4], "less-known levels should come up more often");

  // Right at the boundary and just past it (30 / 31 seen) -- old code is fine at 30, explodes at 31
  // 30 seen = 10 Studying + 20 Right 1x (numerator 50); 31 seen = 10 + 21 (numerator 52)
  printf("Boundary: old(30 seen) = %.4f, old(31 seen) = %.1f; new(30) = %.4f, new(31) = %.4f\n",
         OldProbabilityOfUnseen(30, 100, 50, 10, 30, 2), OldProbabilityOfUnseen(31, 100, 52, 10, 30, 2),
         LWEProbabilityOfUnseenCard(30, 100, 50, 10, 30, 2), LWEProbabilityOfUnseenCard(31, 100, 52, 10, 30, 2));
  CHECK(fabs(OldProbabilityOfUnseen(30, 100, 50, 10, 30, 2) - LWEProbabilityOfUnseenCard(30, 100, 50, 10, 30, 2)) < 1e-9,
        "below/at the pool size the Medium result must be unchanged");

  // --- p_unseen always in [0,1] over a sweep of states and settings ---
  for (long maxCards = 5; maxCards <= 50; maxCards++)
    for (long freq = 1; freq <= 4; freq++)
      for (long seen = 0; seen <= 120; seen++)
        for (long l1 = 0; l1 <= seen && l1 <= 60; l1 += 3)
        {
          // numerator between all-at-level-1 and all-at-level-5 (others at 5)
          long num = l1 + (seen - l1) * 5;
          double p = LWEProbabilityOfUnseenCard(seen, 150, num, l1, maxCards, freq);
          if (!(p >= 0.0 && p <= 1.0)) { CHECK(0, "p out of range: %f (seen %ld l1 %ld max %ld freq %ld)", p, seen, l1, maxCards, freq); }
        }

  // --- Edge cases / divide-by-zero ---
  CHECK(LWEProbabilityOfUnseenCard(0, 10, 0, 0, 30, 2) == 1.0, "nothing seen -> must pick unseen (and no 0/0)");
  CHECK(LWEProbabilityOfUnseenCard(10, 10, 30, 0, 30, 2) == 0.0, "all seen -> no unseen");
  CHECK(LWEProbabilityOfUnseenCard(12, 10, 30, 0, 30, 2) == 0.0, "inconsistent counts -> no unseen, no assert");
  CHECK(LWEProbabilityOfUnseenCard(40, 100, 40, 30, 30, 2) == 0.0, "studying pile full -> no unseen");
  CHECK(LWEProbabilityOfUnseenCard(5, 100, 5, 1, 0, 2) == 0.0, "pool size 0 -> no divide by zero");
  {
    long allUnseen[6] = {10, 0, 0, 0, 0, 0};
    CHECK(LWEPickCardLevel(allUnseen, 5, 1.0, 0.3) == 0, "only unseen cards -> unseen");
    CHECK(LWEPickCardLevel(allUnseen, 5, NAN, 0.3) == 0, "NaN p_unseen must not break the pick");
    long noUnseen[6] = {0, 3, 0, 2, 0, 0};
    CHECK(LWEPickCardLevel(noUnseen, 5, 0.0, 0.9999999999) == 3, "rounding at r~1 must not return an empty unseen level");
    CHECK(LWEPickCardLevel(noUnseen, 5, 0.5, 0.9) == 3, "bogus p_unseen with no unseen cards -> highest non-empty seen level");
    for (int i = 0; i < 1000; i++)
    {
      long lvl = LWEPickCardLevel(noUnseen, 5, 0.0, i / 1000.0);
      CHECK(lvl == 1 || lvl == 3, "picked empty level %ld", lvl);
    }
    long hidden[6] = {0, 1, 1, 1, 1, 50};   // Hide Learned: level 5 never picked
    for (int i = 0; i < 1000; i++)
      CHECK(LWEPickCardLevel(hidden, 4, 0.0, i / 1000.0) <= 4, "level 5 picked while hidden");
    long empty[6] = {0, 0, 0, 0, 0, 0};
    CHECK(LWEPickCardLevel(empty, 5, 0.0, 0.5) == -1, "everything empty -> -1");
  }

  // --- Frequency slider: higher ("More Often") must give at least as many new cards ---
  printf("Frequency slider (pool 30; over pool = 40 seen, mean 2.5; under pool = 25 seen, mean 2.48):\n");
  double prev = -1;
  for (long f = 1; f <= 4; f++)
  {
    double pOld = OldProbabilityOfUnseen(25, 100, 62, 10, 30, f);   // 25 seen (under the pool), mean 2.48
    double p = LWEProbabilityOfUnseenCard(40, 100, 100, 10, 30, f);
    double pUnder = LWEProbabilityOfUnseenCard(25, 100, 62, 10, 30, f);
    printf("  freq %ld: exponent %.2f  new p_unseen = %.4f (over pool), %.4f (25 seen); old (25 seen) = %.4f\n",
           f, LWEUnseenExponentForFrequency(f), p, pUnder, pOld);
    CHECK(p > prev, "p_unseen should increase with the slider (freq %ld)", f);
    prev = p;
  }
  CHECK(OldProbabilityOfUnseen(25, 100, 62, 10, 30, 1) > OldProbabilityOfUnseen(25, 100, 62, 10, 30, 4),
        "confirms the old direction was inverted");
  CHECK(fabs(LWEProbabilityOfUnseenCard(25, 100, 62, 10, 30, 2) - OldProbabilityOfUnseen(25, 100, 62, 10, 30, 2)) < 1e-9,
        "Medium preset (freq 2) unchanged when under the pool");

  printf(failures ? "\n%d FAILURE(S)\n" : "\nALL CHECKS PASSED\n", failures);
  return failures ? 1 : 0;
}
