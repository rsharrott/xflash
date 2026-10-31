#!/usr/bin/env python3
"""CEDICT parsing and the meaning HTML / search text the app displays."""

import unittest

import cedict


def card(line, *more):
    entries = [cedict.parse_line(item) for item in (line,) + more]
    cards = cedict.cross_link(entries)
    return cards


class ParseTest(unittest.TestCase):

    def test_comments_are_skipped(self):
        self.assertIsNone(cedict.parse_line('# CC-CEDICT'))
        self.assertIsNone(cedict.parse_line('#! entries=1'))
        self.assertIsNone(cedict.parse_line(''))

    def test_headwords_and_reading(self):
        entry = cedict.parse_line('播放機 播放机 [bo1 fang4 ji1] /player (e.g. CD player)/')
        self.assertEqual(entry.trad, '播放機')
        self.assertEqual(entry.simp, '播放机')
        self.assertEqual(entry.pinyin, 'bo1 fang4 ji1')
        self.assertEqual(entry.glosses, ['player (e.g. CD player)'])
        self.assertEqual(cedict.headword_en(entry), 'player (e.g. CD player)')

    def test_single_meaning_has_no_list(self):
        entry = cedict.parse_line('明天見 明天见 [ming2 tian1 jian4] /see you tomorrow/')
        cedict.cross_link([entry])
        self.assertEqual(cedict.meaning_html(entry), 'see you tomorrow')
        self.assertEqual(cedict.meaning_fts(entry), 'see you tomorrow')

    def test_several_meanings_are_a_list_and_see_also_is_not_one(self):
        entry = cedict.parse_line(
            '人字拖鞋 人字拖鞋 [ren2 zi4 tuo1 xie2] /flip flops/flip-flop sandals/thongs/see also 人字拖/')
        self.assertEqual(entry.refs, ['人字拖'])
        self.assertFalse(entry.redirect_only)
        self.assertEqual(
            cedict.meaning_html(entry),
            '<ol><li>flip flops</li><li>flip-flop sandals</li><li>thongs</li></ol>')

    def test_full_match_tags_are_removed_from_the_gloss(self):
        entry = cedict.parse_line(
            '方 方 [fang1] /square/power or involution (mathematics)/prescription (med.)/')
        self.assertEqual(entry.glosses[1], 'power or involution')
        self.assertEqual(entry.glosses[2], 'prescription')

    def test_classifier_becomes_a_counter_and_is_searched_without_the_word(self):
        entry = cedict.parse_line('攝像機 摄像机 [she4 xiang4 ji1] /video camera/CL:部[bu4]/')
        cedict.cross_link([entry])
        self.assertEqual(entry.classifiers, ['部[bu4]'])
        self.assertIn('<li>Counter: 部[bu4]</li>', cedict.meaning_html(entry))
        self.assertIn('部[bu4]', cedict.meaning_fts(entry))
        self.assertNotIn('Counter', cedict.meaning_fts(entry))

    def test_several_classifiers(self):
        entry = cedict.parse_line('書 书 [shu1] /book/CL:本[ben3],冊|册[ce4]/')
        self.assertEqual(entry.classifiers, ['本[ben3]', '冊|册[ce4]'])

    def test_stop_words_and_erhua_glosses(self):
        entry = cedict.parse_line(
            '旁邊兒 旁边儿 [pang2 bian1 r5] /erhua variant of 旁邊|旁边, lateral/side/to the side/beside/')
        self.assertEqual(entry.variant_kind, 'erhua')
        self.assertEqual(entry.glosses, ['lateral', 'side', 'to the side', 'beside'])
        self.assertEqual(cedict.headword_en(entry), 'lateral')
        # "to" and "the" drop; the second "side" is not repeated.
        self.assertEqual(cedict.meaning_fts(entry), 'lateral side beside')

    def test_see_you_is_not_a_cross_reference(self):
        entry = cedict.parse_line('回見 回见 [hui2 jian4] /See you later!/')
        self.assertEqual(entry.glosses, ['See you later!'])
        self.assertEqual(entry.refs, [])

    def test_pure_see_is_not_its_own_card(self):
        base = cedict.parse_line('旮旯 旮旯 [ga1 la2] /corner/')
        see = cedict.parse_line('旮 旮 [ga1] /see 旮旯[ga1 la2]/')
        cards = cedict.cross_link([base, see])
        self.assertEqual(cards, [base])
        self.assertIn('Also: 旮|旮 [ga1]', base.extra)

    def test_erhua_with_no_gloss_is_still_a_card(self):
        base = cedict.parse_line('一點 一点 [yi1 dian3] /a bit/')
        erhua = cedict.parse_line('一點兒 一点儿 [yi1 dian3 r5] /erhua variant of 一點|一点[yi1 dian3]/')
        cards = cedict.cross_link([base, erhua])
        self.assertEqual([item.simp for item in cards], ['一点', '一点儿'])
        self.assertIn('Has Erhua variant: 一點兒|一点儿 [yi1 dian3 r5]', base.extra)
        self.assertEqual(erhua.extra, ['Erhua variant of: 一點|一点 [yi1 dian3]'])
        self.assertEqual(cedict.meaning_html(erhua), 'Erhua variant of: 一點|一点 [yi1 dian3]')
        self.assertEqual(erhua.pinyin, 'yi1 dian3 r5')

    def test_variant_with_a_gloss_links_both_ways(self):
        base = cedict.parse_line('旆 旆 [pei4] /pennant/')
        variant = cedict.parse_line('斾 斾 [pei4] /variant of 旆, banner/')
        cedict.cross_link([base, variant])
        self.assertTrue(variant.include)
        self.assertIn('Has variant: 斾|斾 [pei4]', base.extra)
        self.assertIn('Variant of: 旆|旆 [pei4]', variant.extra)
        self.assertIn('banner', variant.glosses)

    def test_old_variant_with_no_gloss_is_only_an_also_note(self):
        base = cedict.parse_line('五 五 [wu3] /five/')
        old = cedict.parse_line('㐅 㐅 [wu3] /old variant of 五[wu3]/')
        cards = cedict.cross_link([base, old])
        self.assertEqual(cards, [base])
        self.assertEqual(base.extra, ['Also: 㐅|㐅 [wu3]'])

    def test_u_colon_in_the_stored_reading(self):
        entry = cedict.parse_line('一律 一律 [yi1 lu:4] /same/')
        self.assertEqual(entry.pinyin, 'yi1 lü4')

    def test_capital_pinyin_is_kept(self):
        entry = cedict.parse_line('微信 微信 [Wei1 xin4] /Weixin or WeChat/')
        self.assertEqual(entry.pinyin, 'Wei1 xin4')
        self.assertEqual(cedict.fts_headword(entry), '微信 微信')

    def test_ampersand_is_escaped_for_the_meaning_webview(self):
        entry = cedict.parse_line('寶潔 宝洁 [Bao3 jie2] /Procter & Gamble/')
        cedict.cross_link([entry])
        self.assertEqual(cedict.meaning_html(entry), 'Procter &amp; Gamble')

    def test_modern_semicolon_gloss_stays_one_sense(self):
        entry = cedict.parse_line('網紅 网红 [wang3 hong2] /Internet celebrity; influencer/')
        self.assertEqual(entry.glosses, ['Internet celebrity; influencer'])
        self.assertEqual(cedict.meaning_html(entry), 'Internet celebrity; influencer')


if __name__ == '__main__':
    unittest.main()
