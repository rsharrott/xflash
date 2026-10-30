#!/usr/bin/env python3
"""Study-set links: drop missing cards, keep order, refresh counts, HSK 3.0 slot."""

import os
import sqlite3
import tempfile
import unittest

import study_sets


class LinkTest(unittest.TestCase):

    def test_missing_hsk30_file_adds_nothing(self):
        self.assertFalse(os.path.exists(study_sets.HSK30_SETS_PATH))
        paths = study_sets.link_paths()
        self.assertNotIn(study_sets.HSK30_SETS_PATH, paths)

    def test_hsk30_rows_append_in_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = os.path.join(tmp, 'system_sets.tsv')
            extra = os.path.join(tmp, 'hsk30_sets.tsv')
            study_sets.write_links(base, [(152, 10), (152, 11)])
            with open(extra, 'w', encoding='utf-8') as handle:
                handle.write('# later\n900\t1000000\n900\t1000001\n')
            rows = study_sets.load_links([base, extra])
        self.assertEqual(rows, [(152, 10), (152, 11), (900, 1000000), (900, 1000001)])

    def test_dropped_card_keeps_the_other_rows_in_order(self):
        rows = [(1, 10), (1, 11), (1, 12), (2, 11)]
        self.assertEqual(study_sets.kept_links(rows, {10, 12}), [(1, 10), (1, 12)])

    def test_remap_redirect_same_pinyin_and_duplicate(self):
        guangdong = _Card(1, '廣東省', '广东省', 'Guang3 dong1 Sheng3')
        inside = _Card(2, '裡', '里', 'li3')
        measure = _Card(3, '里', '里', 'li3')
        yu3 = _Card(4, '與', '与', 'yu3')
        yu4 = _Card(5, '與', '与', 'yu4')
        why = _Card(6, '為什麼', '为什么', 'wei4 shen2 me5')
        mister = _Card(7, '先生', '先生', 'xian1 sheng5')
        particle = _Card(8, '歟', '欤', 'yu2')
        cards = [guangdong, inside, measure, yu3, yu4, why, mister, particle]
        redirects = [
            _Card(0, '廣東', '广东', 'Guang3 dong1', False, refs=['廣東省|广东省[Guang3 dong1 Sheng3]']),
            _Card(0, '裏', '里', 'li3', False, variant_target='裡|里[li3]'),
            _Card(0, '與', '与', 'yu2', False, variant_target='歟|欤[yu2]'),
        ]
        legacy = {
            100: ('廣東', '广东', 'Guang3 dong1'),
            200: ('裏', '里', 'li3'),
            300: ('與', '与', 'yu2'),
            400: ('為什麼', '為什麼', 'wei4 shen2 me5'),
            500: ('先生', '先生', 'Xian1 sheng5'),
            600: ('一步', '一步', 'yi1 bu4'),
        }
        found = study_sets.index_replacements(legacy, cards, redirects)
        self.assertEqual(found[100][0], 1)          # 广东 → 广东省
        self.assertEqual(found[200][0], 2)          # 裏 → 裡, not the measure word 里
        self.assertEqual(found[300][0], 4)          # 与 stays 与 (yu3), not 欤
        self.assertEqual(found[400][0], 6)          # 為什麼 → 为什么
        self.assertEqual(found[500][0], 7)          # Xian1 sheng5 → xian1 sheng5
        self.assertNotIn(600, found)
        replacement = {old: new for old, (new, _how) in found.items()}
        # 里 is already in the set, so the second link is a duplicate.
        rows = [(9, 100), (9, 2), (9, 200), (9, 600), (9, 300)]
        kept, records = study_sets.resolve_links(rows, {1, 2, 3, 4, 5, 6, 7, 8}, replacement)
        self.assertEqual(kept, [(9, 1), (9, 2), (9, 4)])
        dropped = [(old, new) for _tag, old, action, new in records if action == 'dropped']
        self.assertEqual(dropped, [(200, 2), (600, None)])

    def test_priority_ids_cover_the_2011_lists_and_not_textbooks(self):
        self.assertIn(152, study_sets.PRIORITY_TAG_IDS)   # HSK 1
        self.assertIn(170, study_sets.PRIORITY_TAG_IDS)   # TOCFL
        self.assertIn(105, study_sets.PRIORITY_TAG_IDS)   # Jun Da characters
        self.assertIn(132, study_sets.PRIORITY_TAG_IDS)   # news bigrams
        self.assertNotIn(1, study_sets.PRIORITY_TAG_IDS)  # a textbook lesson
        self.assertNotIn(158, study_sets.PRIORITY_TAG_IDS)  # Favorites
        self.assertNotIn(159, study_sets.PRIORITY_TAG_IDS)  # parts of speech

    def test_counts_follow_system_links_except_editable_sets(self):
        database = sqlite3.connect(':memory:')
        database.execute('CREATE TABLE tags (tag_id INTEGER, editable INTEGER, count INTEGER)')
        database.execute('CREATE TABLE card_tag_link (tag_id INTEGER, card_id INTEGER)')
        database.executemany('INSERT INTO tags VALUES (?,?,?)', [(0, 1, 9), (152, 0, 2), (158, 1, 5)])
        database.execute('INSERT INTO card_tag_link VALUES (158, 1)')
        changed = study_sets.refresh_user_counts(database, [(152, 1), (152, 2), (152, 3)])
        self.assertEqual(changed, 3)
        counts = dict(database.execute('SELECT tag_id, count FROM tags'))
        self.assertEqual(counts[152], 3)
        self.assertEqual(counts[158], 1)
        self.assertEqual(counts[0], 0)
        self.assertEqual(study_sets.refresh_user_counts(database, [(152, 1), (152, 2), (152, 3)]), 0)


class _Card:
    def __init__(self, card_id, trad, simp, pinyin, include=True, variant_target=None, refs=None):
        self.card_id = card_id
        self.trad = trad
        self.simp = simp
        self.pinyin = pinyin
        self.include = include
        self.variant_target = variant_target
        self.refs = refs or []


if __name__ == '__main__':
    unittest.main()
