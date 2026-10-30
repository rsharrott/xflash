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


if __name__ == '__main__':
    unittest.main()
