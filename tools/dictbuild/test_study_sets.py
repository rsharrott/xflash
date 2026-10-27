#!/usr/bin/env python3
"""Study-set cleanup checks.

  cd tools/dictbuild && python3 -m unittest -v test_study_sets
"""

import os
import sqlite3
import tempfile
import unittest

import apply_study_data
import builtin_ja
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
        for n in (626, 585, 3478, 2857, 122197, 22325, 993):
            sizes = study_sets.chunk_sizes(n)
            self.assertEqual(sum(sizes), n)
            self.assertTrue(all(50 <= s <= 100 for s in sizes))
            self.assertLessEqual(max(sizes) - min(sizes), 1)
            # One fewer piece would push a piece past 100.
            self.assertGreater(n / (len(sizes) - 1), 100)

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
            self.assertTrue(combined[0]['name'].endswith(' Full Set'))
            self.assertNotIn('00', combined[0]['name'])
            # Plain name order puts Full Set after 01.  The browse query lists it first.
            self.assertGreater(combined[0]['name'], chunks[0]['name'])
            self.assertIn('Not a JLPT exam list', combined[0]['description'])
            self.assertIn('unofficial', combined[0]['description'].lower())
            self.assertTrue(all(50 <= s['count'] <= 100 for s in chunks))
            combined_ids.append(combined[0]['tag_id'])
        self.assertEqual(combined_ids, [717, 718, 719, 720])
        self.assertEqual(
            [s['name'] for g in catalog['groups'] for s in g['sets']
             if study_sets.is_combined_name(s['name'])],
            [
                'Beginner 1 (≈N5) Full Set',
                'Beginner 2 (≈N4) Full Set',
                'Intermediate (≈N3–N2) Full Set',
                'Advanced (≈N1) Full Set',
            ])
        self.assertTrue(set(combined_ids).isdisjoint(study_sets.RECOMMENDED_ADD))
        self.assertNotIn(study_sets.DEFAULT_TAG_ID, combined_ids)
        self.assertTrue(all(tag not in combined_ids for _group, tag in study_sets.STARTER_SETS))

    def test_previous_all_name_is_renamed_without_a_new_id(self):
        levels = ([1, 2], [3], [4], [5])
        assigned = study_sets.assign_tag_ids(levels)
        catalog = study_sets.catalog_from_assignment(assigned)
        members = {}
        old_ids = []
        for group in catalog['groups']:
            for s in group['sets']:
                members[s['tag_id']] = list(s['card_ids'])
                if s['name'].endswith(' Full Set'):
                    s['name'] = s['name'].replace(' Full Set', ' 00 All')
                    old_ids.append(s['tag_id'])
        changed, written = study_sets.ensure_combined_membership(members, catalog)
        self.assertTrue(changed)
        self.assertEqual(written, [])
        names = []
        ids = []
        for group in catalog['groups']:
            combined = [s for s in group['sets'] if s['name'].endswith(' Full Set')]
            self.assertEqual(len(combined), 1)
            names.append(combined[0]['name'])
            ids.append(combined[0]['tag_id'])
            self.assertEqual(len(group['sets']), 2)
        self.assertEqual(ids, old_ids)
        self.assertEqual(names, [
            'Beginner 1 (≈N5) Full Set',
            'Beginner 2 (≈N4) Full Set',
            'Intermediate (≈N3–N2) Full Set',
            'Advanced (≈N1) Full Set',
        ])
        again, written_again = study_sets.ensure_combined_membership(members, catalog)
        self.assertFalse(again)
        self.assertEqual(written_again, [])

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
        # The level list shows Full Set first.  Sorting on the name alone would
        # put it after the numbered chunks.
        full_names = {
            24: 'Beginner 1 (≈N5) Full Set',
            25: 'Beginner 2 (≈N4) Full Set',
            26: 'Intermediate (≈N3–N2) Full Set',
            27: 'Advanced (≈N1) Full Set',
        }
        order_sql = (
            "SELECT t.tag_name FROM tags t, group_tag_link l "
            "WHERE t.tag_id = l.tag_id AND l.group_id = ? "
            "ORDER BY CASE WHEN t.tag_name LIKE '% Full Set' THEN 0 ELSE 1 END, "
            "t.tag_name ASC"
        )
        for group_id, full_name in full_names.items():
            first = self.user.execute(order_sql, (group_id,)).fetchone()[0]
            self.assertEqual(first, full_name)
            by_name = self.user.execute(
                "SELECT t.tag_name FROM tags t, group_tag_link l "
                "WHERE t.tag_id = l.tag_id AND l.group_id = ? ORDER BY t.tag_name ASC",
                (group_id,)).fetchone()[0]
            self.assertNotEqual(by_name, full_name)
            self.assertTrue(by_name.endswith(' 01'))
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


class JapaneseNameTest(unittest.TestCase):

    def test_level_and_chunk_names(self):
        name, desc = builtin_ja.level_japanese('b1', 'Beginner 1 (≈N5) 01', 90, 7)
        self.assertEqual(name, '初級1（≈N5）01')
        self.assertNotIn(' ', name)
        self.assertIn('非公式', desc)
        self.assertIn('JLPTの出題範囲そのものではありません', desc)
        full, full_desc = builtin_ja.level_japanese('b1', 'Beginner 1 (≈N5) Full Set', 626, 7)
        self.assertEqual(full, '初級1（≈N5）全部')
        self.assertIn('626', full_desc)
        mid, _ = builtin_ja.level_japanese('mid', 'Intermediate (≈N3–N2) 10', 99, 35)
        self.assertEqual(mid, '中級（≈N3–N2）10')
        noun, _ = builtin_ja.chunk_japanese('Common Nouns', 'Common Nouns 001', 100, 182, 3)
        self.assertEqual(noun, 'よく使う名詞001')
        noun_full, noun_desc = builtin_ja.chunk_japanese(
            'Common Nouns', 'Common Nouns Full Set', 18142, 182, 3)
        self.assertEqual(noun_full, 'よく使う名詞全部')
        self.assertIn('18142', noun_desc)
        self.assertNotIn(' ', noun_full)
        common, _ = builtin_ja.chunk_japanese('Common Words', 'Common Words 001', 100, 224, 3)
        self.assertEqual(common, 'よく使う単語001')
        common_full, _ = builtin_ja.chunk_japanese('Common Words', 'Common Words Full Set', 22325, 224, 3)
        self.assertEqual(common_full, 'よく使う単語全部')
        core, _ = builtin_ja.chunk_japanese('Core 1000', 'Core 1000 01', 100, 10, 2)
        self.assertEqual(core, '基本1000語01')
        core_full, core_desc = builtin_ja.chunk_japanese('Core 1000', 'Core 1000 Full Set', 993, 10, 2)
        self.assertEqual(core_full, '基本1000語全部')
        self.assertIn('993', core_desc)
        self.assertIn('nf01', core_desc)
        self.assertIn('JLPTの出題範囲そのものではありません', core_desc)

    def test_hand_names_do_not_use_a_generated_id(self):
        generated = {42, 617, 618} | set(range(620, 632)) | set(range(92, 96)) | set(range(644, 721))
        self.assertTrue(generated.isdisjoint(builtin_ja.TAG_JA))
        self.assertEqual(builtin_ja.TAG_JA[133][0], '名詞')


class BundledChunkedListsTest(unittest.TestCase):
    """Common Nouns, Common Words and Core 1000, after apply_sets().  Nouns is one set."""

    @classmethod
    def setUpClass(cls):
        cls.user = sqlite3.connect(USER_DB)
        cls.card = sqlite3.connect(CARD_DB)
        cls.chunked = study_sets.load_chunked()

    def test_lists_are_chunked_with_a_full_set_first(self):
        if self.chunked is None:
            self.skipTest('chunked_lists.json is written by apply_sets()')
        common = study_sets.load_common_ids()
        core_ids = study_sets.load_core_ids()
        self.assertEqual(len(core_ids), 993)
        self.assertEqual(len(core_ids), len(set(core_ids)))
        order_sql = (
            "SELECT t.tag_id, t.tag_name, t.tag_name_ja, t.count FROM tags t, group_tag_link l "
            "WHERE t.tag_id = l.tag_id AND l.group_id = ? "
            "ORDER BY CASE WHEN t.tag_name LIKE '% Full Set' THEN 0 ELSE 1 END, t.tag_name ASC"
        )
        for group in self.chunked['groups']:
            rows = self.user.execute(order_sql, (group['group_id'],)).fetchall()
            names = [row[1] for row in rows]
            self.assertTrue(names[0].endswith(' Full Set'), group['base_name'])
            plain = self.user.execute(
                "SELECT t.tag_name FROM tags t, group_tag_link l "
                "WHERE t.tag_id = l.tag_id AND l.group_id = ? ORDER BY t.tag_name ASC",
                (group['group_id'],)).fetchone()[0]
            self.assertFalse(plain.endswith(' Full Set'), group['base_name'])
            chunks = [s for s in group['sets'] if not study_sets.is_combined_name(s['name'])]
            combined = [s for s in group['sets'] if study_sets.is_combined_name(s['name'])]
            self.assertEqual(len(combined), 1)
            width = max(2, len(str(len(chunks))))
            chunk_lists = []
            for index, entry in enumerate(chunks, start=1):
                self.assertGreaterEqual(entry['count'], 50)
                self.assertLessEqual(entry['count'], 100)
                self.assertTrue(entry['name'].endswith(' ' + ('%0*d' % (width, index))))
                cards = self._cards(entry['tag_id'])
                self.assertEqual(len(cards), entry['count'])
                self.assertEqual(cards, self._cards_as_the_app_reads_them(entry['tag_id']))
                chunk_lists.append(cards)
                ja_name, ja_desc = builtin_ja.chunk_japanese(
                    group['base_name'], entry['name'], entry['count'], len(chunks), width)
                stored = self.user.execute(
                    'SELECT tag_name_ja, description_ja, editable FROM tags WHERE tag_id = ?',
                    (entry['tag_id'],)).fetchone()
                self.assertEqual(stored, (ja_name, ja_desc, 0))
            flat = [card for cards in chunk_lists for card in cards]
            self.assertEqual(len(flat), len(set(flat)), group['base_name'])
            full_cards = self._cards(combined[0]['tag_id'])
            self.assertEqual(full_cards, flat)
            self.assertEqual(combined[0]['count'], len(flat))
            ja_name, ja_desc = builtin_ja.chunk_japanese(
                group['base_name'], combined[0]['name'], combined[0]['count'], len(chunks), width)
            stored = self.user.execute(
                'SELECT tag_name_ja, description_ja FROM tags WHERE tag_id = ?',
                (combined[0]['tag_id'],)).fetchone()
            self.assertEqual(stored, (ja_name, ja_desc))
            if group['base_name'] == 'Core 1000':
                self.assertEqual(full_cards, core_ids)
                self.assertEqual(len(full_cards), 993)
                owner = self.user.execute(
                    'SELECT owner_id, group_name, group_name_ja FROM groups WHERE group_id = ?',
                    (group['group_id'],)).fetchone()
                self.assertEqual(owner, (0, 'Core 1000', '基本1000語'))
                self.assertIsNone(self.user.execute(
                    'SELECT 1 FROM group_tag_link WHERE group_id = 23 AND tag_id = ?',
                    (combined[0]['tag_id'],)).fetchone())
            elif group['base_name'] == 'Common Nouns':
                self.assertEqual(group['group_id'], 2)
                self.assertNotIn('group_name', group)
                self.assertEqual(full_cards, sorted(full_cards))
                self.assertTrue(set(full_cards) <= common)
                self.assertEqual(len(chunks), 182)
                self.assertEqual(combined[0]['count'], 18142)
                self.assertEqual(chunks[0]['tag_id'], 2164)
                self.assertEqual(combined[0]['tag_id'], 2346)
                self.assertEqual(chunks[0]['count'], 100)
                self.assertEqual(chunks[123]['count'], 100)
                self.assertEqual(chunks[124]['count'], 99)
                self.assertEqual(chunks[-1]['name'], 'Common Nouns 182')
            else:
                self.assertIn(full_cards[0], common, group['base_name'])
                seen_other = False
                for card_id in full_cards:
                    if card_id not in common:
                        seen_other = True
                    elif seen_other:
                        self.fail('%s has a common-priority card after the others' % group['base_name'])

    def test_nouns_stay_one_set(self):
        row = self.user.execute(
            'SELECT tag_name, tag_name_ja, description_ja, count, editable FROM tags WHERE tag_id = 133'
        ).fetchone()
        self.assertEqual(row[0], 'Nouns')
        self.assertEqual(row[1], '名詞')
        self.assertIn('よく使う名詞', row[2])
        self.assertEqual(row[3], 122197)
        self.assertEqual(row[4], 0)
        self.assertIsNone(self.user.execute(
            "SELECT tag_id, tag_name FROM tags WHERE tag_name IN "
            "('Nouns Full Set', 'Nouns 0001', 'Nouns 02') "
            "OR tag_name LIKE 'Nouns %'").fetchone())
        self.assertEqual(
            self.user.execute(
                'SELECT count(*) FROM tags WHERE tag_id BETWEEN 620 AND 631').fetchone()[0], 0)
        self.assertEqual(
            self.card.execute(
                'SELECT count(*) FROM system_card_tag_link WHERE tag_id BETWEEN 620 AND 631'
            ).fetchone()[0], 0)
        cards = self._cards(133)
        self.assertEqual(len(cards), 122197)
        self.assertEqual(len(set(cards)), 122197)
        self.assertIn(
            (2,),
            self.user.execute('SELECT group_id FROM group_tag_link WHERE tag_id = 133').fetchall())
        # The Nouns group still holds the other noun lists, with Common Nouns sorted first.
        first = self.user.execute(
            "SELECT t.tag_name FROM tags t, group_tag_link l "
            "WHERE t.tag_id = l.tag_id AND l.group_id = 2 "
            "ORDER BY CASE WHEN t.tag_name LIKE '% Full Set' THEN 0 ELSE 1 END, t.tag_name ASC"
        ).fetchone()[0]
        self.assertEqual(first, 'Common Nouns Full Set')

    def test_every_builtin_has_a_japanese_name_and_user_columns_stay_empty(self):
        if self.chunked is None:
            self.skipTest('chunked_lists.json is written by apply_sets()')
        catalog = study_sets.load_catalog()
        expected = study_sets._japanese_by_tag(catalog, self.chunked)
        missing = self.user.execute(
            "SELECT tag_id, tag_name FROM tags WHERE editable = 0 "
            "AND (tag_name_ja IS NULL OR tag_name_ja = '')").fetchall()
        self.assertEqual(missing, [])
        for tag_id, (ja_name, ja_desc) in expected.items():
            row = self.user.execute(
                'SELECT tag_name_ja, description_ja FROM tags WHERE tag_id = ?', (tag_id,)).fetchone()
            self.assertEqual(row, (ja_name, ja_desc), tag_id)
        for group_id, ja_name in builtin_ja.GROUP_JA.items():
            stored = self.user.execute(
                'SELECT group_name_ja FROM groups WHERE group_id = ?', (group_id,)).fetchone()
            self.assertEqual(stored[0], ja_name, group_id)
        # The English group name, including the "1. Beginner" prefix, is what sorts.
        beginner = self.user.execute(
            'SELECT group_name, group_name_ja FROM groups WHERE group_id = 24').fetchone()
        self.assertEqual(beginner, ('1. Beginner 1 (≈N5)', '初級1（≈N5）'))
        favorites = self.user.execute(
            'SELECT tag_name, tag_name_ja, editable FROM tags WHERE tag_id = 124').fetchone()
        self.assertEqual(favorites[0], 'Long Weekend Favorites')
        self.assertEqual(favorites[1], 'ロングウィークエンドのお気に入り')
        self.assertEqual(favorites[2], 1)

    def _cards(self, tag_id):
        return [row[0] for row in self.card.execute(
            'SELECT card_id FROM system_card_tag_link WHERE tag_id = ? ORDER BY rowid', (tag_id,))]

    def _cards_as_the_app_reads_them(self, tag_id):
        # CardPeer selects with no ORDER BY.  The tag_id index returns rowid order.
        return [row[0] for row in self.card.execute(
            'SELECT card_id FROM system_card_tag_link WHERE tag_id = ?', (tag_id,))]


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
