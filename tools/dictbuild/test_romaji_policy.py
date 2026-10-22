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


if __name__ == '__main__':
    unittest.main()
