#!/usr/bin/env python3
"""Study-set cleanup checks.

  cd tools/dictbuild && python3 -m unittest -v test_study_sets
"""

import os
import sqlite3
import tempfile
import unittest

import apply_study_data
import study_sets

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CARD_DB = study_sets.CARD_DB
USER_DB = study_sets.USER_DB
VULG_PATH = os.path.join(os.path.dirname(__file__), 'data', 'sense1_vulg_x.txt')


class ChunkTest(unittest.TestCase):

    def test_real_level_sizes(self):
        self.assertEqual(study_sets.chunk_sizes(626), [90, 90, 90, 89, 89, 89, 89])
        self.assertEqual(study_sets.chunk_sizes(585), [98, 98, 98, 97, 97, 97])
        self.assertEqual(sum(study_sets.chunk_sizes(3478)), 3478)
        self.assertEqual(len(study_sets.chunk_sizes(3478)), 35)
        self.assertEqual(sum(study_sets.chunk_sizes(2857)), 2857)
        self.assertEqual(len(study_sets.chunk_sizes(2857)), 29)
        for n in (626, 585, 3478, 2857):
            sizes = study_sets.chunk_sizes(n)
            self.assertTrue(all(50 <= s <= 100 for s in sizes))
            self.assertLessEqual(max(sizes) - min(sizes), 1)

    def test_split_is_disjoint_and_covers_the_old_top_level(self):
        members = {
            95: [1, 2, 3],
            94: [1, 2, 3, 4, 5],
            93: [1, 2, 3, 4, 5, 6, 7],
            92: [1, 2, 3, 4, 5, 6, 7, 8],
        }
        levels = study_sets.unique_levels(members)
        self.assertEqual(levels, ([1, 2, 3], [4, 5], [6, 7], [8]))
        flat = [card for level in levels for card in level]
        self.assertEqual(len(flat), len(set(flat)))
        self.assertEqual(set(flat), set(members[92]))
        assigned = study_sets.assign_tag_ids(levels)
        ids = [tag for chunks in assigned for tag, _ in chunks]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual([chunks[0][0] for chunks in assigned], [95, 94, 93, 92])
        # One-card levels have no extra chunk ids, so the combined sets take 644+.
        self.assertTrue(set(study_sets.combined_tag_ids(assigned)).isdisjoint(ids))

    def test_combined_set_is_the_union_and_sorts_first(self):
        levels = (
            list(range(626)),
            list(range(1000, 1000 + 585)),
            list(range(2000, 2000 + 3478)),
            list(range(6000, 6000 + 2857)),
        )
        catalog = study_sets.catalog_from_assignment(study_sets.assign_tag_ids(levels))
        combined_ids = []
        for group, level in zip(catalog['groups'], levels):
            combined = [s for s in group['sets'] if study_sets.is_combined_name(s['name'])]
            chunks = [s for s in group['sets'] if not study_sets.is_combined_name(s['name'])]
            self.assertEqual(len(combined), 1)
            self.assertEqual(combined[0]['card_ids'], level)
            self.assertEqual(combined[0]['count'], len(level))
            self.assertEqual(combined[0]['count'], sum(s['count'] for s in chunks))
            flat = [card for s in chunks for card in s['card_ids']]
            self.assertEqual(sorted(flat), level)
            self.assertEqual(len(flat), len(set(flat)))
            self.assertLess(combined[0]['name'], chunks[0]['name'])
            self.assertIn('Not a JLPT exam list', combined[0]['description'])
            self.assertIn('unofficial', combined[0]['description'].lower())
            self.assertTrue(all(50 <= s['count'] <= 100 for s in chunks))
            combined_ids.append(combined[0]['tag_id'])
        self.assertEqual(combined_ids, [717, 718, 719, 720])
        self.assertTrue(set(combined_ids).isdisjoint(study_sets.RECOMMENDED_ADD))
        self.assertNotIn(study_sets.DEFAULT_TAG_ID, combined_ids)
        self.assertTrue(all(tag not in combined_ids for _group, tag in study_sets.STARTER_SETS))

    def test_descriptions_do_not_call_the_lists_official(self):
        levels = ([1], [2], [3], [4])
        catalog = study_sets.catalog_from_assignment(study_sets.assign_tag_ids(levels))
        for group in catalog['groups']:
            self.assertNotIn('JLPT Level', group['group_name'])
            for s in group['sets']:
                low = s['description'].lower()
                self.assertNotIn('official jlpt', low)
                self.assertIn('unofficial', low)
                self.assertNotIn('JLPT Level', s['name'])
                self.assertIn('Not a JLPT exam list', s['description'])


class KanaOrderTest(unittest.TestCase):

    def test_basic_sorts_before_all(self):
        names = list(study_sets.KANA_RENAMES.values())
        hira = sorted(n for n in names if n.startswith('Hiragana'))
        kata = sorted(n for n in names if n.startswith('Katakana'))
        self.assertEqual(hira, [
            'Hiragana (1 Basic)', 'Hiragana (2 Voiced)', 'Hiragana (3 Compounds)', 'Hiragana (All)',
        ])
        self.assertEqual(kata, [
            'Katakana (1 Basic)', 'Katakana (2 Voiced)', 'Katakana (3 Compounds)', 'Katakana (All)',
        ])


@unittest.skipUnless(os.path.exists(USER_DB) and os.path.exists(CARD_DB), 'bundled databases missing')
class BundledCatalogTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.user = sqlite3.connect(USER_DB)
        cls.card = sqlite3.connect(CARD_DB)
        cls.catalog = study_sets.load_catalog() if os.path.exists(study_sets.CATALOG_PATH) else None

    def test_catalog_matches_the_databases(self):
        if self.catalog is None:
            self.skipTest('vocabulary_levels.json is written by apply_study_data.py')
        seen = []
        for group in self.catalog['groups']:
            name = self.user.execute('SELECT group_name FROM groups WHERE group_id = ?',
                                     (group['group_id'],)).fetchone()[0]
            self.assertEqual(name, group['group_name'])
            parent = self.user.execute('SELECT owner_id FROM groups WHERE group_id = ?',
                                       (group['group_id'],)).fetchone()[0]
            self.assertEqual(parent, study_sets.PARENT_GROUP)
            chunks = []
            combined = []
            for s in group['sets']:
                row = self.user.execute(
                    'SELECT tag_name, description, count, editable FROM tags WHERE tag_id = ?',
                    (s['tag_id'],)).fetchone()
                self.assertEqual(row[0], s['name'])
                self.assertEqual(row[1], s['description'])
                self.assertNotIn('official jlpt', row[1].lower())
                self.assertIn('unofficial', row[1].lower())
                self.assertEqual(row[3], 0)
                live = self.card.execute(
                    'SELECT count(*) FROM system_card_tag_link WHERE tag_id = ?',
                    (s['tag_id'],)).fetchone()[0]
                self.assertEqual(live, s['count'])
                self.assertEqual(row[2], s['count'])
                link = self.user.execute(
                    'SELECT 1 FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
                    (group['group_id'], s['tag_id'])).fetchone()
                self.assertIsNotNone(link)
                cards = [cid for (cid,) in self.card.execute(
                    'SELECT card_id FROM system_card_tag_link WHERE tag_id = ? ORDER BY card_id',
                    (s['tag_id'],))]
                if study_sets.is_combined_name(s['name']):
                    combined.append(cards)
                else:
                    self.assertGreaterEqual(s['count'], 50)
                    self.assertLessEqual(s['count'], 100)
                    chunks.append(cards)
            self.assertEqual(len(combined), 1, group['group_name'])
            chunk_cards = [cid for cards in chunks for cid in cards]
            # Chunks of one level do not overlap.  The combined set is their union,
            # so the same card is in a chunk and in the level set on purpose.
            self.assertEqual(len(chunk_cards), len(set(chunk_cards)), group['group_name'])
            self.assertEqual(combined[0], sorted(set(chunk_cards)))
            self.assertEqual(len(combined[0]), sum(len(cards) for cards in chunks))
            seen.extend(chunk_cards)
        self.assertEqual(len(seen), len(set(seen)), 'levels overlap')

    def test_every_visible_tag_has_a_group_and_hidden_tags_do_not(self):
        hidden = set(study_sets.HIDDEN_TAG_IDS)
        ungrouped = {row[0] for row in self.user.execute('''
            SELECT t.tag_id FROM tags t
            LEFT JOIN group_tag_link g ON g.tag_id = t.tag_id
            WHERE g.tag_id IS NULL
        ''')}
        self.assertEqual(ungrouped, hidden)
        dangling = self.user.execute('''
            SELECT count(*) FROM group_tag_link g
            LEFT JOIN tags t ON t.tag_id = g.tag_id
            WHERE t.tag_id IS NULL
        ''').fetchone()[0]
        self.assertEqual(dangling, 0)
        for tag_id, count in self.user.execute('SELECT tag_id, count FROM tags'):
            editable = self.user.execute('SELECT editable FROM tags WHERE tag_id = ?', (tag_id,)).fetchone()[0]
            if editable or tag_id == 0:
                live = self.user.execute(
                    'SELECT count(*) FROM card_tag_link WHERE tag_id = ?', (tag_id,)).fetchone()[0]
            else:
                live = self.card.execute(
                    'SELECT count(*) FROM system_card_tag_link WHERE tag_id = ?', (tag_id,)).fetchone()[0]
            self.assertEqual(live, count, 'tag %s count' % tag_id)

    def test_browse_cleanup(self):
        parent = self.user.execute(
            'SELECT group_name, tag_count FROM groups WHERE group_id = 10').fetchone()
        self.assertEqual(parent, (study_sets.PARENT_NAME, 0))
        # Adverb sets are not under Verbs.  Tag 7 stays under Nouns and Adverbs.
        for tag_id in study_sets.ADVERBS_OUT_OF_VERBS:
            self.assertIsNone(self.user.execute(
                'SELECT 1 FROM group_tag_link WHERE group_id = 1 AND tag_id = ?', (tag_id,)).fetchone())
            self.assertIsNotNone(self.user.execute(
                'SELECT 1 FROM group_tag_link WHERE group_id = 3 AND tag_id = ?', (tag_id,)).fetchone())
        self.assertIsNotNone(self.user.execute(
            'SELECT 1 FROM group_tag_link WHERE group_id = 8 AND tag_id = 643').fetchone())
        recommended = {row[0] for row in self.user.execute(
            'SELECT tag_id FROM group_tag_link WHERE group_id = 23')}
        self.assertTrue(set(study_sets.RECOMMENDED_REMOVE).isdisjoint(recommended))
        self.assertTrue(set(study_sets.RECOMMENDED_ADD) <= recommended)
        name, desc = self.user.execute(
            'SELECT tag_name, description FROM tags WHERE tag_id = 147').fetchone()
        self.assertEqual(name, study_sets.EXPRESSIONS_NAME)
        self.assertNotIn('副名詞', ''.join(
            d or '' for (d,) in self.user.execute('SELECT description FROM tags')))
        self.assertNotIn('副指摘名詞', ''.join(
            d or '' for (d,) in self.user.execute('SELECT description FROM tags')))
        prenoun = self.user.execute(
            "SELECT tag_name FROM tags WHERE tag_id = 154").fetchone()[0]
        self.assertEqual(prenoun, prenoun.strip())
        self.assertFalse(prenoun.endswith(' '))
        blob = ' '.join((n or '') + ' ' + (d or '') for n, d in self.user.execute(
            'SELECT tag_name, description FROM tags'))
        for typo in ('Intrasitive', 'lanugage', 'Portguese', 'oridnal', 'Idomatic', 'Rude or X-Rated',
                     'fukumeishi'):
            self.assertNotIn(typo, blob)
        self.assertIn('futsuumeishi', blob)

    def test_starters_have_no_vulgar_or_x_rated_cards(self):
        if not os.path.exists(VULG_PATH):
            self.skipTest('sense1_vulg_x.txt is written by apply_study_data.py')
        vulg = set()
        with open(VULG_PATH, encoding='utf-8') as f:
            header = f.read()
        self.assertIn(apply_study_data.JMDICT_SHA256, header)
        for line in header.splitlines():
            line = line.strip()
            if line and not line.startswith('#'):
                vulg.add(int(line))
        starter_tags = {study_sets.DEFAULT_TAG_ID}
        starter_tags.update(tag for _, tag in study_sets.STARTER_SETS)
        for tag_id in starter_tags:
            cards = {row[0] for row in self.card.execute(
                'SELECT card_id FROM system_card_tag_link WHERE tag_id = ?', (tag_id,))}
            self.assertTrue(cards.isdisjoint(vulg), 'tag %s' % tag_id)
        # Japanglish is neither the default nor a starter, and not Recommended.
        self.assertNotIn(91, starter_tags)
        self.assertIsNone(self.user.execute(
            'SELECT 1 FROM group_tag_link WHERE group_id = 23 AND tag_id = 91').fetchone())

    def test_default_set_constant_matches_a_real_beginner_set(self):
        with open(os.path.join(
                REPO, 'jFlash', 'Classes', 'AppSpecific', 'Constants.h'), encoding='utf-8') as f:
            header = f.read()
        self.assertIn('#define DEFAULT_TAG_ID 200', header.split('#elif defined(LWE_CFLASH)')[0])
        self.assertIn('#define DEFAULT_TAG_ID 158', header.split('#elif defined(LWE_CFLASH)')[1])
        count = self.card.execute(
            'SELECT count(*) FROM system_card_tag_link WHERE tag_id = 200').fetchone()[0]
        self.assertGreater(count, 0)
        # Long Weekend Favorites is still the editable sample set.
        row = self.user.execute(
            "SELECT editable, count FROM tags WHERE tag_name = 'Long Weekend Favorites'").fetchone()
        self.assertEqual(row, (1, 14))


class JMdictPinTest(unittest.TestCase):

    def test_missing_file_is_reported_without_patching(self):
        err = apply_study_data.jmdict_pin_error('/tmp/no-such-jmdict-for-xflash.gz')
        self.assertIsNotNone(err)
        self.assertIn('missing', err)
        self.assertIn(apply_study_data.JMDICT_SHA256, err)

    def test_wrong_bytes_do_not_match_the_pin(self):
        handle = tempfile.NamedTemporaryFile(delete=False)
        handle.write(b'not a jmdict file')
        handle.close()
        try:
            err = apply_study_data.jmdict_pin_error(handle.name)
        finally:
            os.remove(handle.name)
        self.assertIsNotNone(err)
        self.assertIn('sha256', err)
        self.assertIn('Refusing to patch', err)


if __name__ == '__main__':
    unittest.main()
