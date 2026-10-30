#!/usr/bin/env python3
"""The built CARD and FTS databases: versions, modern words, search, tones.

Skipped when the databases are not in the tree (a unit-test checkout that
has not run build.py). CI has the committed files, so this runs there.
"""

import os
import sqlite3
import unittest

import build
import pinyin

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CARD = os.path.join(REPO, 'jFlash', 'sql', build.CARD_NAME)
FTS = os.path.join(REPO, 'jFlash', 'sql', 'plugins', build.FTS_NAME)
USER = os.path.join(REPO, 'jFlash', 'sql', 'cFlash.db')

HERE = os.path.dirname(os.path.abspath(__file__))


def open_dbs():
    database = sqlite3.connect(CARD)
    database.execute('ATTACH DATABASE ? AS fts', (FTS,))
    return database


@unittest.skipUnless(os.path.exists(CARD) and os.path.exists(FTS), 'built cFlash databases are not in the tree')
class BuiltDictionaryTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.db = open_dbs()

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    def test_versions(self):
        self.assertEqual(
            self.db.execute("SELECT plugin_key, version FROM version").fetchone(),
            ('CF_CARD_DB', '2.0'))
        self.assertEqual(
            self.db.execute("SELECT plugin_key, version FROM fts.version").fetchone(),
            ('FTS_DB', '2.0'))

    def test_modern_words_are_present(self):
        for simp, trad, reading_prefix in (
            ('微信', '微信', 'Wei1 xin4'),
            ('二维码', '二維碼', 'er4 wei2 ma3'),
            ('网红', '網紅', 'wang3 hong2'),
            ('支付宝', '支付寶', 'Zhi1 fu4 bao3'),
            ('点赞', '點贊', 'dian3 zan4'),
            ('一点儿', '一點兒', 'yi1 dian3 r5'),
        ):
            row = self.db.execute(
                'SELECT card_id, headword_trad, reading FROM cards WHERE headword_simp = ?',
                (simp,)).fetchone()
            self.assertIsNotNone(row, simp)
            card_id, got_trad, reading = row
            self.assertEqual(got_trad, trad)
            self.assertEqual(reading, reading_prefix)
            if simp == '一点儿':
                # Kept from the 2011 id space only if it existed; it did not,
                # so this erhua form is a new card.
                self.assertGreaterEqual(card_id, 1000000)
            if simp == '微信':
                self.assertGreaterEqual(card_id, 1000000)

    def test_core_set_words_were_remapped_not_dropped(self):
        # tag id, simplified headword (a longer see-target such as 广东省 counts).
        expect = (
            (153, '里'), (154, '关于'), (155, '与'), (156, '数据'), (157, '发布'),
            (10, '为什么'), (60, '先生'), (6, '广东'),
        )
        for tag_id, simp in expect:
            count = self.db.execute(
                'SELECT COUNT(*) FROM system_card_tag_link l JOIN cards c ON c.card_id = l.card_id '
                'WHERE l.tag_id = ? AND (c.headword_simp = ? OR c.headword_simp LIKE ?)',
                (tag_id, simp, simp + '%')).fetchone()[0]
            self.assertGreater(count, 0, '%s in set %s' % (simp, tag_id))

    def test_lowercase_tone_marks_find_ouzhou(self):
        rows = self.db.execute(
            'SELECT card_id FROM fts.cards_search_content WHERE reading MATCH ?',
            ('"ōu zhōu"',)).fetchall()
        self.assertTrue(rows, 'ōu zhōu should find 欧洲')
        leaked = self.db.execute(
            "SELECT COUNT(*) FROM fts.cards_search_content WHERE reading LIKE '%Ō%'").fetchone()[0]
        self.assertEqual(leaked, 0)

    def test_yidianr_is_searchable_and_links_back(self):
        row = self.db.execute(
            "SELECT meaning FROM cards_html WHERE card_id = "
            "(SELECT card_id FROM cards WHERE headword_simp = '一点儿')").fetchone()
        self.assertIn('Erhua variant of', row[0])
        base = self.db.execute(
            "SELECT meaning FROM cards_html WHERE card_id = "
            "(SELECT card_id FROM cards WHERE headword_simp = '一点' AND reading = 'yi1 dian3')").fetchone()
        self.assertIsNotNone(base)
        self.assertIn('Has Erhua variant', base[0])

    def test_search_by_characters_pinyin_with_and_without_tones(self):
        queries = (
            ('headword', '"微信"'),
            ('reading', '"Wei1 xin4"'),
            ('reading', '"wēi xìn"'),
            ('reading', '"wei xin"'),
            ('reading', '"weixin"'),
            ('reading', '"er4 wei2 ma3"'),
            ('reading', '"er wei ma"'),
            ('reading', '"erweima"'),
            ('content', 'Alipay'),
            ('content', 'influencer'),
            ('headword', '"点赞"'),
            ('reading', '"dian3 zan4"'),
            ('reading', '"dian zan"'),
        )
        for column, query in queries:
            rows = self.db.execute(
                'SELECT card_id FROM fts.cards_search_content WHERE %s MATCH ?' % column,
                (query,)).fetchall()
            self.assertTrue(rows, '%s MATCH %s' % (column, query))

    def test_stored_reading_still_colours_from_the_tone_digit(self):
        # ChineseCard reads cards.reading, not the FTS column. nü3 keeps ü
        # and the digit; the tone-mark form is what the card draws.
        row = self.db.execute(
            "SELECT reading FROM cards WHERE reading LIKE '%lü%' OR reading LIKE '%nü%' LIMIT 1").fetchone()
        self.assertIsNotNone(row)
        self.assertRegex(row[0], r'[nl]ü[1-5]')
        self.assertEqual(pinyin.diacritic('ni3 hao3'), 'nǐ hǎo')
        self.assertEqual(pinyin.diacritic('nü3'), 'nǚ')

    def test_gong1_duo1_gong1_and_nang4_match_the_objc_search_tests(self):
        # CFlashSearchTest: first "gong1" result is the syllable itself,
        # "duo1 gong1" likewise, "nang4" is one card, "keyword" is three.
        first = self._first_reading('reading', '"gong1"')
        self.assertEqual(first, 'gong1')
        self.assertEqual(self._first_reading('reading', '"duo1 gong1"'), 'duo1 gong1')
        nang = self.db.execute(
            "SELECT COUNT(*) FROM fts.cards_search_content WHERE reading MATCH '\"nang4\"'").fetchone()[0]
        self.assertEqual(nang, 1)
        keyword = self.db.execute(
            "SELECT COUNT(*) FROM fts.cards_search_content WHERE cards_search_content MATCH 'keyword'").fetchone()[0]
        self.assertEqual(keyword, 3)
        pinyin_word = self._first_headword('headword', '"拼音"')
        self.assertEqual(pinyin_word, '拼音')

    def test_gong1_ties_sort_by_length_then_ptag_then_card_id(self):
        rows = self.db.execute(
            "SELECT card_id, LENGTH(reading) AS len, ptag FROM fts.cards_search_content "
            "WHERE reading MATCH '\"gong1\"' ORDER BY LENGTH(reading) ASC, ptag DESC, card_id ASC"
        ).fetchall()
        self.assertGreater(len(rows), 1)
        ties = 0
        prev = (-1, 99, 0)
        for card_id, length, ptag in rows:
            self.assertGreaterEqual(length, prev[0])
            if length == prev[0] and ptag == prev[1]:
                ties += 1
                self.assertLess(prev[2], card_id)
            prev = (length, ptag, card_id)
        self.assertGreater(ties, 0)

    def test_sandhi_fixture_words_rank_first_with_their_2011_readings(self):
        # ChineseCardTest searches the headword and asserts the first hit.
        expect = {
            '你好': 'ni3 hao3',
            '好久': 'hao3 jiu3',
            '一半': 'yi1 ban4',
            # 一步 is no longer its own CEDICT entry (only inside compounds
            # such as 进一步). 一下 is the same 一 + 4th-tone sandhi.
            '一下': 'yi1 xia4',
            '一般': 'yi1 ban1',
            '一直': 'yi1 zhi2',
            '一起': 'yi1 qi3',
            '不是': 'bu4 shi4',
            '不会': 'bu4 hui4',
            '不错': 'bu4 cuo4',
        }
        for word, reading in expect.items():
            self.assertEqual(self._first_reading('headword', '"%s"' % word), reading, word)

    def test_every_card_has_html_and_a_search_row(self):
        cards = self.db.execute('SELECT COUNT(*) FROM cards').fetchone()[0]
        html = self.db.execute('SELECT COUNT(*) FROM cards_html').fetchone()[0]
        search = self.db.execute('SELECT COUNT(*) FROM fts.cards_search_content').fetchone()[0]
        self.assertGreater(cards, 98000)
        self.assertEqual(cards, html)
        self.assertEqual(cards, search)
        self.assertEqual(
            self.db.execute('SELECT COUNT(*) FROM cards WHERE card_id IS NULL OR reading = ""').fetchone()[0], 0)

    def test_set_links_point_at_real_cards(self):
        missing = self.db.execute(
            'SELECT COUNT(*) FROM system_card_tag_link l LEFT JOIN cards c ON c.card_id = l.card_id '
            'WHERE c.card_id IS NULL').fetchone()[0]
        self.assertEqual(missing, 0)
        self.assertGreater(self.db.execute('SELECT COUNT(*) FROM system_card_tag_link').fetchone()[0], 0)

    def _first_reading(self, column, query):
        row = self.db.execute(
            'SELECT c.reading FROM fts.cards_search_content s '
            'JOIN cards c ON c.card_id = s.card_id '
            'WHERE s.%s MATCH ? ORDER BY LENGTH(s.%s) ASC, s.ptag DESC, s.card_id ASC LIMIT 1' % (column, column),
            (query,)).fetchone()
        self.assertIsNotNone(row, query)
        return row[0]

    def _first_headword(self, column, query):
        row = self.db.execute(
            'SELECT c.headword_simp FROM fts.cards_search_content s '
            'JOIN cards c ON c.card_id = s.card_id '
            'WHERE s.%s MATCH ? ORDER BY LENGTH(s.%s) ASC, s.ptag DESC, s.card_id ASC LIMIT 1' % (column, column),
            (query,)).fetchone()
        self.assertIsNotNone(row, query)
        return row[0]


if __name__ == '__main__':
    unittest.main()
