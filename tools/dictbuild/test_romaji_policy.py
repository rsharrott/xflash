#!/usr/bin/env python3
"""Romaji policy checks.  The headline cases use a tiny hand-built lexicon so
they do not need the bundled database; the database cases run when it is there.

  cd tools/dictbuild && python3 -m unittest -v test_romaji_policy
"""

import os
import sqlite3
import unittest

import romaji_policy as rp

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CARD_DB = os.path.join(REPO, 'jFlash', 'sql', 'jFlash-CARD-2.0.db')


def card(reading, meaning, headword, ptag=0, card_id=2000000, card_type='3', romaji=None):
    stored = romaji if romaji is not None else rp.mechanical_romaji(reading)
    return {
        'card_id': card_id, 'card_type': card_type, 'headword': headword,
        'reading': reading, 'romaji': stored, 'meaning': meaning, 'ptag': ptag,
    }


def lexicon():
    samples = [
        card('それ', 'that<dfn>pronoun</dfn>', '其れ', ptag=1),
        card('どうも', 'thanks<dfn>adverb</dfn>', 'どうも', ptag=1),
        card('はいる', 'to enter<dfn>~る verb L5</dfn>', '入る', ptag=1),
        card('はな', 'flower<dfn>noun</dfn>', '花', ptag=1),
        card('さくらぎ', 'cherry<dfn>noun</dfn>', '桜木', ptag=0),
        card('ひと', 'person<dfn>noun</dfn>', '人', ptag=1),
        card('ぶし', 'warrior<dfn>noun</dfn>', '武士', ptag=0),
        card('ごはん', 'rice<dfn>noun</dfn>', 'ご飯', ptag=1),
        card('たべる', 'to eat<dfn>~る verb L1</dfn>', '食べる', ptag=1),
        card('このは', 'leaf<dfn>expression</dfn><dfn>noun</dfn>', '木の葉', ptag=0),
        card('きのは', 'leaf<dfn>expression</dfn><dfn>noun</dfn>', '木の葉', ptag=0),
        card('はは', 'mother<dfn>noun</dfn>', '母', ptag=1),
        card('なる', 'to become<dfn>verb</dfn>', '成る', ptag=1),
        card('しぜん', 'nature<dfn>noun</dfn>', '自然', ptag=1),
        card('ねほりはほり', 'nosily<dfn>expression</dfn><dfn>adverb</dfn>', '根掘り葉掘り', ptag=0),
        card('はせる', 'to rush<dfn>verb</dfn>', '馳せる', ptag=0),
        card('なまえ', 'name<dfn>noun</dfn>', '名前', ptag=1),
        card('げんき', 'fine<dfn>adj</dfn>', '元気', ptag=1),
        card('です', 'copula<dfn>copula</dfn>', 'です', ptag=1),
        card('はい', 'yes<dfn>interjection</dfn>', 'はい', ptag=1),
        card('しゃしん', 'photo<dfn>noun</dfn>', '写真', ptag=1),
        card('とります', 'take<dfn>verb</dfn>', '撮ります', ptag=0, card_id=50, card_type='3'),
        card('みちづれ', 'companion<dfn>noun</dfn>', '道連れ', ptag=0),
        card('なさけ', 'kindness<dfn>noun</dfn>', '情け', ptag=0),
        card('たび', 'travel<dfn>noun</dfn>', '旅', ptag=1),
        card('こわい', 'scary<dfn>い adj</dfn>', '怖い', ptag=1),
        card('かえり', 'return<dfn>noun</dfn>', '帰り', ptag=1),
        card('よいよい', 'fine<dfn>adverb</dfn>', 'よいよい', ptag=0),
        card('いき', 'going<dfn>noun</dfn>', '行き', ptag=0),
        card('おふろ', 'bath<dfn>noun</dfn>', 'お風呂', ptag=1),
        card('いります', 'to need<dfn>verb</dfn>', '要ります', ptag=1),
        card('わく', 'frame<dfn>noun</dfn>', '枠', ptag=1),
        card('まる', 'circle<dfn>noun</dfn>', '丸', ptag=1),
        card('はまる', 'to fit<dfn>verb</dfn>', '嵌まる', ptag=0),
        card('かじん', 'beauty<dfn>noun</dfn>', '佳人', ptag=0),
        card('くめい', 'short life<dfn>noun</dfn>', 'くめい', ptag=0),
        card('はくめい', 'short life<dfn>noun</dfn>', '薄命', ptag=0),
        card('あり', 'existing<dfn>verb</dfn>', 'あり', ptag=1),
        card('しない', 'does not<dfn>verb</dfn>', 'しない', ptag=1),
        card('それどころ', 'hardly<dfn>adverb</dfn>', 'それどころ', ptag=0),
        card('ない', 'not<dfn>suffix</dfn>', 'ない', ptag=1),
        card('じゃない', 'is not<dfn>expression</dfn>', 'じゃない', ptag=1),
        card('あてはまる', 'to apply<dfn>verb</dfn>', '当てはまる', ptag=1),
    ]
    return rp.build_lexicon(samples)


class PhraseRomajiTest(unittest.TestCase):

    def setUp(self):
        self.lex = lexicon()

    def romaji(self, reading, headword, meaning='<dfn>expression</dfn>', **kw):
        c = card(reading, meaning, headword, **kw)
        new, _ = rp.romaji_for_card(c, self.lex)
        return new

    def test_topic_particle_and_lexical_ha(self):
        self.assertEqual(self.romaji('それはどうも', 'それはどうも'), 'sorewadoumo')
        self.assertEqual(self.romaji('では', 'では'), 'dewa')
        self.assertEqual(self.romaji('おふろにはいる', 'お風呂に入る'), 'ofuronihairu')
        self.assertEqual(self.romaji('ごはんをたべる', 'ご飯を食べる'), 'gohanotaberu')
        self.assertEqual(self.romaji('はなはさくらぎ', '花は桜木'), 'hanawasakuragi')
        self.assertEqual(self.romaji('このは', '木の葉'), 'konoha')
        self.assertEqual(self.romaji('ねほりはほり', '根掘り葉掘り'), 'nehorihahori')
        self.assertEqual(self.romaji('ははなるしぜん', '母なる自然'), 'hahanarushizen')
        self.assertEqual(self.romaji('なまえをはせる', '名前を馳せる'), 'namaeohaseru')
        self.assertEqual(
            self.romaji('たびはみちづれよはなさけ', '旅は道連れ世は情け'),
            'tabiwamichizureyowanasake')

    def test_greetings_comma_and_phrase_wo(self):
        self.assertEqual(self.romaji('こんにちは', '今日は', meaning='<dfn>interjection</dfn>'), 'konnichiwa')
        self.assertEqual(self.romaji('こんばんは', '今晩は', meaning='<dfn>interjection</dfn>'), 'konbanwa')
        self.assertEqual(
            self.romaji('はい、げんきです', 'はい、元気です', card_id=145895, card_type='3'),
            'hai genkidesu')
        self.assertEqual(
            self.romaji('しゃしんをとります', '写真を撮ります', card_id=145535, card_type='3'),
            'shashinotorimasu')

    def test_particles_and_kana_chart_are_different_cards(self):
        self.assertEqual(self.romaji('は', 'は', meaning='topic<dfn>particle</dfn>'), 'wa')
        self.assertEqual(self.romaji('を', 'を', meaning='object<dfn>particle</dfn>'), 'o')
        # The kana-chart cards are the mora names, not the particles.
        chart = card('は', 'HA', 'は', card_id=146071, card_type='0', romaji='ha')
        self.assertEqual(rp.romaji_for_card(chart, self.lex), ('ha', 'unchanged'))
        chart = card('を', 'WO', 'を', card_id=145982, card_type='0', romaji='wo')
        self.assertEqual(rp.romaji_for_card(chart, self.lex), ('wo', 'unchanged'))

    def test_leading_ha_and_geminate_stay(self):
        # 歯が浮く: the は is the kanji, and it is the first mora.
        self.assertTrue(self.romaji('はがうく', '歯が浮く').startswith('ha'))
        # 張っている: は before っ is "ha" even when the verb is not in the lexicon.
        self.assertIn('ha', self.romaji('くいいじがはっている', '食い意地が張っている'))
        self.assertNotIn('wa', self.romaji('くいいじがはっている', '食い意地が張っている'))

    def test_ha_inside_a_word_is_not_a_particle(self):
        # いります is longer than はいる, so the segmenter drops はいる and the
        # leftover は used to become "wa".  The headword writes no kana は.
        self.assertEqual(self.romaji('おふろにはいります', 'お風呂に入ります'), 'ofuronihairimasu')
        self.assertEqual(self.romaji('かじんはくめい', '佳人薄命'), 'kajinhakumei')
        # 枠にはまる writes は, and that は is the verb はまる, not the particle.
        self.assertEqual(self.romaji('わくにはまる', '枠にはまる'), 'wakunihamaru')
        # 当てはまる's は is the same verb, written in the headword.
        self.assertEqual(self.romaji('あてはまる', '当てはまる', meaning='<dfn>verb</dfn>'), 'atehamaru')

    def test_grammatical_ha_without_kana_in_the_headword(self):
        # The other spelling of the headword is the one that writes は.
        self.assertEqual(
            self.romaji('ありはしない', 'ありゃしない'), 'ariwashinai')
        self.assertEqual(
            self.romaji('それどころではない', 'それどころじゃない'), 'soredokorodewanai')

    def test_previously_adjusted_romaji_is_recomputed(self):
        c = card('おふろにはいります', '<dfn>expression</dfn>', 'お風呂に入ります',
                 romaji='ofuroniwairimasu')
        self.assertEqual(rp.romaji_for_card(c, self.lex), ('ofuronihairimasu', 'adjusted'))
        kept = card('ないせんXXをおねがいします', '<dfn>expression</dfn>',
                    '内線番号XXをお願いします', card_id=145429, card_type='3',
                    romaji='naisenXXoonegaishimasu')
        self.assertEqual(rp.romaji_for_card(kept, self.lex)[0], 'naisenXXoonegaishimasu')

    def test_search_bracket_keeps_literal_spelling(self):
        content = '今日は [ こんにちは / konnichiwa ] hello'
        rebuilt = rp.rebuild_search_bracket(content, 'こんにちは', 'konnichiwa', 'konnichiha')
        self.assertIn('konnichiwa', rebuilt)
        self.assertIn('konnichiha', rebuilt)
        same = rp.rebuild_search_bracket(
            'お風呂に入ります [ おふろにはいります / ofuronihairimasu ] enter',
            'おふろにはいります', 'ofuronihairimasu', 'ofuronihairimasu')
        self.assertEqual(same.count('ofuronihairimasu'), 1)

    def test_hand_tuned_romaji_is_left_alone(self):
        # Stored romaji has a space the literal converter does not produce.
        c = card('たいいんする', 'leave hospital<dfn>expression</dfn>', '退院する',
                 card_id=145800, card_type='3', romaji='taiin suru')
        self.assertEqual(rp.romaji_for_card(c, self.lex), ('taiin suru', 'left-alone'))

    def test_case_is_preserved_when_only_the_particle_changes(self):
        c = card('ないせんXXをおねがいします', "I'd like extension XX<dfn>expression</dfn>",
                 '内線番号XXをお願いします', card_id=145429, card_type='3',
                 romaji='naisenXXwoonegaishimasu')
        new, status = rp.romaji_for_card(c, self.lex)
        self.assertEqual(status, 'adjusted')
        self.assertIn('XX', new)
        self.assertNotIn('wo', new)
        self.assertIn('o', new)


@unittest.skipUnless(os.path.exists(CARD_DB), 'bundled card database is not present')
class BundledRomajiTest(unittest.TestCase):
    """The shipped database, after apply_study_data.py."""

    @classmethod
    def setUpClass(cls):
        cls.db = sqlite3.connect(CARD_DB)
        cls.rows = {
            hw: (reading, romaji)
            for hw, reading, romaji in cls.db.execute('SELECT headword, reading, romaji FROM cards')
            if hw in {
                'それはどうも', '今日は', '今晩は', 'はい、元気です', '木の葉', 'お風呂に入る',
                'では', 'を', 'は', '歯が浮く', '名前を馳せる', '根掘り葉掘り', '写真を撮ります',
                '母なる自然', '蝶よ花よ', '出端', '天爾遠波', '都をどり',
            }
        }

    def romaji_of(self, headword):
        matches = [v for k, v in self.rows.items() if k == headword]
        self.assertTrue(matches, headword)
        return matches

    def test_shipped_examples(self):
        self.assertIn(('それはどうも', 'sorewadoumo'), self.romaji_of('それはどうも'))
        self.assertIn(('こんにちは; こんにちわ', 'konnichiwa; konnichiwa'), self.romaji_of('今日は'))
        self.assertIn(('こんばんは; こんばんわ', 'konbanwa; konbanwa'), self.romaji_of('今晩は'))
        self.assertIn(('はい、げんきです', 'hai genkidesu'), self.romaji_of('はい、元気です'))
        self.assertIn(('このは; きのは', 'konoha; kinoha'), self.romaji_of('木の葉'))
        self.assertIn(('おふろにはいる', 'ofuronihairu'), self.romaji_of('お風呂に入る'))
        self.assertIn(('はがうく', 'hagauku'), self.romaji_of('歯が浮く'))
        self.assertIn(('ねほりはほり', 'nehorihahori'), self.romaji_of('根掘り葉掘り'))
        self.assertIn(('ははなるしぜん', 'hahanarushizen'), self.romaji_of('母なる自然'))
        self.assertIn(('ちょうよはなよ', 'chouyohanayo'), self.romaji_of('蝶よ花よ'))
        self.assertIn(('では', 'deha'), self.romaji_of('出端'))
        self.assertIn(('てにをは; テニヲハ', 'teniwoha; teniwoha'), self.romaji_of('天爾遠波'))
        self.assertIn(('みやこをどり', 'miyakowodori'), self.romaji_of('都をどり'))

    def test_lexical_ha_was_put_back(self):
        """The 23 cards whose は is part of a word, not the topic particle."""
        expected = {
            145488: 'ofuronihairimasu',
            1189820: 'kajinhakumei',
            1917360: 'wakunihamaru',
            2006850: 'omoutsubonihamaru',
            2032340: 'bijinhakumei',
            2034920: 'anihakaranya',
            2188810: 'yurikagokarahakabamade',
            2213430: 'torihadagatatsu',
            2238790: 'kakehashitonaru',
            2256570: 'anagaattarahairitai',
            2417340: 'kuchinimitsuariharanikenari',
            2596080: 'takakashitehatotonaru; takakeshitehatotonaru',
            2603950: 'katanihamaru',
            2655400: 'shinzounikegahaeteiru',
            2655420: 'shinzounikegahaeta',
            2727860: 'tsubonihamaru',
            2730840: 'kenohaeta',
            2730850: 'dotsubonihamaru; dotsubonihamaru',
            2795820: 'yokinihakarae',
            2833702: 'yubikirigenman usotsuitaraharisenbonnomasu',
            2835778: 'imahayari',
            2842414: 'nanihajinai',
            2842631: 'kegahaeta',
        }
        self.assertEqual(len(expected), 23)
        for card_id, romaji in expected.items():
            row = self.db.execute('SELECT romaji FROM cards WHERE card_id = ?', (card_id,)).fetchone()
            self.assertEqual(row[0], romaji, card_id)

    def test_real_particles_stay_wa(self):
        kept = {
            2062980: 'aryashinai; ariwashinai',
            2775790: 'soredokorojanai; soredokorodewanai',
        }
        for card_id, romaji in kept.items():
            row = self.db.execute('SELECT romaji FROM cards WHERE card_id = ?', (card_id,)).fetchone()
            self.assertEqual(row[0], romaji, card_id)

    def test_literal_spelling_is_in_the_search_index(self):
        fts_path = os.path.join(REPO, 'jFlash', 'sql', 'plugins', 'jFlash-FTS-2.0.db')
        fts = sqlite3.connect(fts_path)
        try:
            greeting = fts.execute(
                "SELECT content FROM cards_search_content WHERE content LIKE '%konnichiha%'").fetchone()
            self.assertIsNotNone(greeting)
            topic = fts.execute(
                "SELECT content FROM cards_search_content WHERE content LIKE '%sorehadoumo%'").fetchone()
            self.assertIsNotNone(topic)
            bath = fts.execute(
                "SELECT content FROM cards_search_content WHERE card_id = 145488").fetchone()[0]
            self.assertIn('ofuronihairimasu', bath)
            self.assertNotIn('ofuroniwairimasu', bath)
        finally:
            fts.close()


if __name__ == '__main__':
    unittest.main()
