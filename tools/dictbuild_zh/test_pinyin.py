#!/usr/bin/env python3
"""Pinyin conversion. The cases are the 2011 importer's EntryTest expectations."""

import unittest

import pinyin


class DiacriticTest(unittest.TestCase):

    def test_empty(self):
        self.assertEqual(pinyin.diacritic(''), '')
        self.assertEqual(pinyin.diacritic('   '), '')

    def test_tones_and_spaces(self):
        self.assertEqual(pinyin.diacritic('da1 pei4', spaces=True), 'dā pèi')
        self.assertEqual(pinyin.diacritic('da1 pei4', spaces=False), 'dāpèi')
        self.assertEqual(pinyin.diacritic('e2 wai4', spaces=False), 'éwài')
        self.assertEqual(pinyin.diacritic('gai3 bian1', spaces=False), 'gǎibiān')
        self.assertEqual(pinyin.diacritic('ai4 dai4', spaces=False), 'àidài')

    def test_capital_and_single_letters(self):
        self.assertEqual(pinyin.diacritic('Bai4', spaces=False), 'Bài')
        self.assertEqual(pinyin.diacritic('ka3 la1 O K', spaces=False), 'kǎlāOK')
        self.assertEqual(pinyin.diacritic('D N A jian4 ding4', spaces=False), 'DNAjiàndìng')
        self.assertEqual(pinyin.diacritic('U S B ji4 yi4 bang4', spaces=False), 'USBjìyìbàng')
        self.assertEqual(pinyin.diacritic('G dian3', spaces=False), 'Gdiǎn')
        self.assertEqual(pinyin.diacritic('T xu4', spaces=False), 'Txù')
        self.assertEqual(pinyin.diacritic('n xu4', spaces=False), 'nxù')

    def test_u_umlaut(self):
        self.assertEqual(pinyin.normalize_reading('qi1 lu:4'), 'qi1 lü4')
        self.assertEqual(pinyin.diacritic('qi1 lü4', spaces=False), 'qīlǜ')
        self.assertEqual(pinyin.diacritic(pinyin.normalize_reading('qi1 lv4'), spaces=False), 'qīlǜ')
        self.assertEqual(pinyin.diacritic(pinyin.normalize_reading('San1 Lu:e4'), spaces=False), 'SānLüè')
        self.assertEqual(pinyin.diacritic(pinyin.normalize_reading('shi4 lu:e4'), spaces=False), 'shìlüè')
        self.assertEqual(pinyin.diacritic(pinyin.normalize_reading('U:5'), spaces=False), 'ü')
        self.assertEqual(pinyin.diacritic(pinyin.normalize_reading('lu:4 se4 tong1 dao4'), spaces=False), 'lǜsètōngdào')
        self.assertEqual(pinyin.normalize_reading('nü3'), 'nü3')

    def test_neutral_tone_and_quirks(self):
        self.assertEqual(pinyin.diacritic('a5 i5 u5 e5 o5 ü5 ü5', spaces=False), 'aiueoüü')
        self.assertEqual(pinyin.syllable_diacritic('r5'), 'r')
        self.assertEqual(pinyin.syllable_diacritic('xx5'), '')
        self.assertEqual(pinyin.diacritic('yi1 dian3 r5'), 'yī diǎn r')
        # 2011 kept the digit on these two.
        self.assertEqual(pinyin.syllable_diacritic('m2'), 'm2')
        self.assertEqual(pinyin.syllable_diacritic('m4'), 'm4')

    def test_vowel_placement(self):
        self.assertEqual(pinyin.diacritic('ni3 hao3'), 'nǐ hǎo')
        self.assertEqual(pinyin.diacritic('hui4'), 'huì')
        self.assertEqual(pinyin.diacritic('liu3'), 'liǔ')
        self.assertEqual(pinyin.diacritic('cuo4'), 'cuò')
        self.assertEqual(pinyin.diacritic('lüe4'), 'lüè')
        self.assertEqual(pinyin.diacritic('Wei1 xin4'), 'Wēi xìn')

    def test_fused_syllable_is_split(self):
        self.assertEqual(pinyin.normalize_reading('shi2ke4'), 'shi2 ke4')
        self.assertEqual(pinyin.diacritic('shi2 ke4'), 'shí kè')
        self.assertEqual(pinyin.normalize_reading('shi2 ke4'), 'shi2 ke4')

    def test_digit_token_and_letter_names_stay(self):
        self.assertEqual(pinyin.normalize_reading('11 Qu1'), '11 Qu1')
        self.assertEqual(pinyin.diacritic('11 Qu1'), '11 Qū')
        self.assertEqual(pinyin.diacritic('OK beng1'), 'OK bēng')
        self.assertEqual(pinyin.syllable_diacritic('V'), 'V')

    def test_middle_dot(self):
        reading = pinyin.normalize_reading('Ya4 dang1 · Si1 mi4')
        self.assertEqual(pinyin.diacritic(reading), 'Yà dāng · Sī mì')


class SearchReadingTest(unittest.TestCase):

    def test_numbered_marked_and_toneless(self):
        text = pinyin.fts_reading('wei2 xin4')
        self.assertIn('wei2 xin4', text)
        # wei takes the mark on e: wei2 is wéi, not wēi (that is wei1).
        self.assertIn('wéi xìn', text)
        self.assertIn('wei xin', text)
        self.assertIn('weixin', text)

    def test_proper_noun_keeps_capitals_and_a_lowercase_squash(self):
        text = pinyin.fts_reading('Wei1 xin4')
        self.assertIn('Wei1 xin4', text)
        self.assertIn('Wēi xìn', text)
        self.assertIn('weixin', text)

    def test_single_syllable_has_no_duplicate_squash(self):
        text = pinyin.fts_reading('gong1')
        self.assertEqual(text, 'gong1 gōng gong')

    def test_erhua(self):
        text = pinyin.fts_reading('yi1 dian3 r5')
        self.assertIn('yi1 dian3 r5', text)
        self.assertIn('yī diǎn r', text)
        self.assertIn('yidianr', text)


if __name__ == '__main__':
    unittest.main()
