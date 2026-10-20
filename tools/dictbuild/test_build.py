#!/usr/bin/env python3
"""Unit tests for the sentence-link selection in build.py (stdlib only, no sources needed).

  cd tools/dictbuild && python3 -m unittest -v test_build
"""

import unittest

import build


def links(*sentence_ids, checked=False, sense=0):
    return {j: (checked, sense) for j in sentence_ids}


class ChooseLinksTest(unittest.TestCase):

    def choose(self, card_links, unusable=()):
        return build.choose_links(card_links, usable=lambda j: j not in unusable, length=lambda j: j)

    def shown(self, rows, card_id):
        return [j for c, j, s, _ in rows if c == card_id and s == 1]

    def test_card_keeps_best_ten_shown_and_twenty_shipped(self):
        rows, used = self.choose({1: links(*range(100, 130))})
        self.assertEqual(self.shown(rows, 1), list(range(100, 110)))
        self.assertEqual(len(rows), build.LINKS_PER_CARD)
        self.assertEqual(used, set(range(100, 120)))

    def test_checked_sentences_rank_first(self):
        d = links(*range(100, 125))
        d[124] = (True, 0)
        rows, _ = self.choose({1: d})
        self.assertIn(124, self.shown(rows, 1), 'the one checked sentence is shown although it is the longest')
        self.assertNotIn(109, self.shown(rows, 1), 'it takes the place of the 10th shortest')

    def test_shipped_sentence_links_all_its_words(self):
        # Sentence 500 is one of 家事's few sentences, but 母 has 30 shorter ones, so 500
        # falls outside 母's own top 20.  It must still link back to 母 (hidden).
        kaji, haha, isogashii = 1191980, 1514990, 1519290
        card_links = {kaji: links(500), haha: links(500, *range(1, 31)), isogashii: links(500)}
        rows, used = self.choose(card_links)
        words_of_500 = {(c, s) for c, j, s, _ in rows if j == 500}
        self.assertEqual(words_of_500, {(kaji, 1), (haha, 0), (isogashii, 1)})
        self.assertEqual(len(self.shown(rows, haha)), build.SHOWN_PER_CARD)
        self.assertNotIn(500, self.shown(rows, haha))
        self.assertEqual(used, {500} | set(range(1, 21)), 'no sentences are added for the extra links')

    def test_extra_links_never_add_sentences(self):
        # 21..30 are outside 母's top 20 and no other card picked them: they don't ship.
        # Both cards have 20+ shorter sentences, so neither card's top 20 has sentence 200.
        rows, used = self.choose({1: links(200, *range(1, 31)), 2: links(200, *range(100, 125))})
        self.assertNotIn(200, used)
        self.assertNotIn(200, {j for _, j, _, _ in rows})


    def test_sense_number_is_kept_and_rows_are_unique_and_sorted(self):
        rows, _ = self.choose({1: links(*range(1, 31)), 2: links(25, sense=3), 3: links(25)})
        self.assertIn((1, 25, 0, 0), rows)
        self.assertIn((2, 25, 1, 3), rows)
        self.assertEqual(rows, sorted(set(rows)))

    def test_unusable_sentences_are_skipped(self):
        rows, used = self.choose({1: links(1, 2), 2: links(2)}, unusable={2})
        self.assertEqual(rows, [(1, 1, 1, 0)])
        self.assertEqual(used, {1})

    def test_stop_cards_keep_their_own_links_but_get_no_extra_ones(self):
        # 乃 (B-line の) and な appear in sentences other cards picked: no hidden links to them.
        kaji, no, na = 1191980, 1469800, 2029110
        card_links = {kaji: links(500, 501), no: links(500, 501, *range(1, 31)), na: links(500, 7)}
        stop = {no, na}
        rows, used = build.choose_links(card_links, usable=lambda j: True, length=lambda j: j,
                                        is_stop=lambda c: c in stop)
        pairs = {(c, j) for c, j, _, _ in rows}
        self.assertNotIn((no, 500), pairs)
        self.assertNotIn((no, 501), pairs)
        self.assertIn((na, 500), pairs, "な's own top 20 (it has only 2 sentences) is kept")
        self.assertEqual(len([1 for c, _, _, _ in rows if c == no]), build.LINKS_PER_CARD)
        self.assertEqual(len(self.shown(rows, no)), build.SHOWN_PER_CARD)
        self.assertEqual(used, {500, 501, 7} | set(range(1, 21)))


class StopCardTest(unittest.TestCase):

    def card(self, headword, reading, kana_only=0):
        return {'headword': headword, 'reading': reading, 'kana_only': kana_only}

    def test_particles_and_function_words(self):
        for c in (self.card('乃', 'の'), self.card('な', 'な; なあ; なー; なぁ'), self.card('のに', 'のに'),
                  self.card('彼の', 'あの', 1), self.card('何の', 'どの', 1), self.card('仕舞う', 'しまう', 1),
                  self.card('為る', 'する', 1)):
            self.assertTrue(build.is_stop_card(c), c)

    def test_words_that_only_sound_like_one(self):
        # 夜 (よる; よ), 名 (な), 歯 (は) are written in kanji, so their readings don't count.
        for c in (self.card('夜', 'よる; よ'), self.card('名', 'な'), self.card('歯', 'は'),
                  self.card('母', 'はは'), self.card('忙しい', 'いそがしい')):
            self.assertFalse(build.is_stop_card(c), c)

    def test_noni_is_a_stop_word_for_extra_links(self):
        self.assertIn('のに', build.EXTRA_LINK_STOP_WORDS)
        self.assertTrue(set(build.tatoeba.STOP_WORDS) <= build.EXTRA_LINK_STOP_WORDS)


if __name__ == '__main__':
    unittest.main()
