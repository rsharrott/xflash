#!/usr/bin/env python3
"""A 2.0 user database, updated in place, keeps study data and gains the new sets.

  cd tools/dictbuild && python3 -m unittest -v test_user_migration
"""

import os
import shutil
import sqlite3
import tempfile
import unittest

import user_db_migration

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TEMPLATE = os.path.join(REPO, 'jFlash', 'sql', 'jFlash.db')

# What jFlash.db looked like at data version 2.0 (master before this branch).
LEGACY_LEVELS = (
    (92, 'JLPT Level N1'),
    (93, 'JLPT Level N2'),
    (94, 'JLPT Level N3'),
    (95, 'JLPT Level N4'),
)
HIDDEN_IN_EXPRESSIONS = (15, 51, 135, 136, 161, 168)
RECOMMENDED_LEGACY = (80, 91, 170)
RECOMMENDED_NEW = (73, 95, 200, 208)


def rewind_to_20(path):
    """Turn a copy of the current template back into a 2.0 user database."""
    conn = sqlite3.connect(path)
    conn.execute('DELETE FROM group_tag_link WHERE tag_id >= 644 OR group_id >= 24')
    conn.execute('DELETE FROM tags WHERE tag_id >= 644')
    conn.execute('DELETE FROM groups WHERE group_id >= 24')
    for tag_id, name in LEGACY_LEVELS:
        conn.execute('UPDATE tags SET tag_name = ? WHERE tag_id = ?', (name, tag_id))
    conn.execute("UPDATE groups SET group_name = 'JLPT N1~N4' WHERE group_id = 10")
    conn.execute('DELETE FROM group_tag_link WHERE group_id = 10')
    conn.executemany(
        'INSERT INTO group_tag_link (group_id, tag_id) VALUES (10, ?)',
        [(tag_id,) for tag_id, _ in LEGACY_LEVELS])
    conn.executemany(
        'INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (13, ?)',
        [(tag_id,) for tag_id in HIDDEN_IN_EXPRESSIONS])
    conn.execute('DELETE FROM group_tag_link WHERE group_id = 23 AND tag_id IN (73, 95, 200, 208)')
    conn.executemany(
        'INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (23, ?)',
        [(tag_id,) for tag_id in RECOMMENDED_LEGACY])
    conn.executemany(
        'INSERT OR IGNORE INTO group_tag_link (group_id, tag_id) VALUES (1, ?)',
        [(tag_id,) for tag_id in (7, 8, 9)])
    conn.execute("UPDATE tags SET description = 'Rude or X-Rated' WHERE tag_id = 161")
    conn.execute(
        "UPDATE tags SET description = replace(description, '普通名詞', '副名詞') "
        "WHERE tag_id = 133 OR tag_id BETWEEN 620 AND 631")
    conn.execute(
        "UPDATE tags SET description = replace(description, 'futsuumeishi', 'fukumeishi') "
        "WHERE tag_id = 133 OR tag_id BETWEEN 620 AND 631")
    conn.execute("UPDATE sqlite_sequence SET seq = 643 WHERE name = 'tags'")
    # A 2.0 file has no Japanese columns.  The migration has to add them.
    for table, column in (
            ('tags', 'tag_name_ja'), ('tags', 'description_ja'), ('groups', 'group_name_ja')):
        have = {row[1] for row in conn.execute('PRAGMA table_info(%s)' % table)}
        if column in have:
            conn.execute('ALTER TABLE %s DROP COLUMN %s' % (table, column))
    conn.commit()
    conn.close()


class MigrateFrom20Test(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.template = os.path.join(self.tmp.name, 'template.db')
        self.user = os.path.join(self.tmp.name, 'user.db')
        shutil.copy(TEMPLATE, self.template)
        shutil.copy(TEMPLATE, self.user)
        rewind_to_20(self.user)
        self.conn = sqlite3.connect(self.user)
        # Study progress, a starred card, and a user set sitting on a new system id.
        self.conn.execute(
            'INSERT INTO user_history (card_id, timestamp, user_id, right_count, wrong_count, '
            'created_on, card_level) VALUES (2065830, 100, 1, 3, 1, 100, 2)')
        self.conn.execute('INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (0, 150089, 1)')
        self.conn.execute(
            'INSERT INTO tags (tag_id, tag_name, description, editable, count) '
            "VALUES (644, 'My Travel Words', 'kept', 1, 1)")
        self.conn.execute('INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (644, 145536, 2)')
        self.conn.execute('INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 644)')
        self.conn.execute('UPDATE last_state SET tag_id = 644 WHERE user_id = 1')
        self.conn.execute(
            'INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (644, 1, 4)')
        self.conn.execute(
            'INSERT INTO tags (tag_id, tag_name, description, editable, count) '
            "VALUES (700, 'My Cooking Words', 'kept', 1, 1)")
        self.conn.execute('INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (700, 145535, 3)')
        self.conn.execute('INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 700)')
        self.conn.execute(
            'INSERT INTO tag_user_card_levels (tag_id, user_id, card_level_1_count) VALUES (700, 1, 2)')
        # 717 is a combined level set in the new template.
        self.conn.execute(
            'INSERT INTO tags (tag_id, tag_name, description, editable, count) '
            "VALUES (717, 'My Whole Level', 'kept', 1, 1)")
        self.conn.execute('INSERT INTO card_tag_link (tag_id, card_id, id) VALUES (717, 145580, 4)')
        self.conn.execute('INSERT INTO group_tag_link (group_id, tag_id) VALUES (0, 717)')
        # The 2.0 template links these tag ids even though the tag rows are gone.
        self.conn.executemany(
            'INSERT INTO group_tag_link (group_id, tag_id) VALUES (?, ?)',
            [(18, 3), (18, 10), (7, 17), (6, 28)])
        self.conn.execute("UPDATE sqlite_sequence SET seq = 643 WHERE name = 'tags'")
        self.conn.commit()

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    def test_legacy_fixture_is_actually_legacy(self):
        names = dict(self.conn.execute('SELECT tag_id, tag_name FROM tags WHERE tag_id BETWEEN 92 AND 95'))
        self.assertEqual(names[95], 'JLPT Level N4')
        self.assertIsNone(self.conn.execute('SELECT 1 FROM tags WHERE tag_id = 645').fetchone())
        seq = self.conn.execute("SELECT seq FROM sqlite_sequence WHERE name = 'tags'").fetchone()[0]
        self.assertEqual(seq, 643)
        linked = self.conn.execute('SELECT 1 FROM group_tag_link WHERE tag_id = 15').fetchone()
        self.assertIsNotNone(linked)
        columns = {row[1] for row in self.conn.execute('PRAGMA table_info(tags)')}
        self.assertNotIn('tag_name_ja', columns)

    def test_migration_updates_catalog_and_keeps_user_data(self):
        before_users = self.conn.execute('SELECT user_id, nickname FROM users ORDER BY user_id').fetchall()
        before_history = self.conn.execute(
            'SELECT card_id, user_id, right_count, wrong_count, card_level FROM user_history').fetchall()
        before_state_card = self.conn.execute('SELECT card_id, user_id FROM last_state').fetchall()
        favorites = self.conn.execute(
            'SELECT card_id FROM card_tag_link WHERE tag_id = 124 ORDER BY card_id').fetchall()
        self.conn.close()

        mapping = user_db_migration.migrate(self.user, self.template)
        # Colliding user sets move to just past the higher of the user max
        # and the template max, in tag_id order.  The template max grew when
        # Nouns, Common Words and Core 1000 were cut, so this is not 721.
        template = sqlite3.connect(self.template)
        template_max = template.execute('SELECT MAX(tag_id) FROM tags').fetchone()[0]
        template.close()
        first_free = max(717, template_max) + 1
        self.assertEqual(mapping, {644: first_free, 700: first_free + 1, 717: first_free + 2})
        travel_id = mapping[644]
        cooking_id = mapping[700]
        whole_id = mapping[717]

        self.conn = sqlite3.connect(self.user)
        self.assertEqual(
            self.conn.execute('SELECT tag_name FROM tags WHERE tag_id = 95').fetchone()[0],
            'Beginner 1 (≈N5) 01')
        self.assertEqual(
            self.conn.execute('SELECT group_name, tag_count FROM groups WHERE group_id = 10').fetchone(),
            ('Vocabulary Levels', 0))
        for group_id in (24, 25, 26, 27):
            self.assertIsNotNone(
                self.conn.execute('SELECT 1 FROM groups WHERE group_id = ?', (group_id,)).fetchone(),
                group_id)
        self.assertIsNotNone(self.conn.execute('SELECT 1 FROM tags WHERE tag_id = 716').fetchone())
        for tag_id in (15, 51, 135, 136, 161, 168):
            self.assertIsNone(
                self.conn.execute('SELECT 1 FROM group_tag_link WHERE tag_id = ?', (tag_id,)).fetchone(),
                tag_id)
        recommended = {row[0] for row in self.conn.execute(
            'SELECT tag_id FROM group_tag_link WHERE group_id = 23')}
        self.assertTrue(set(RECOMMENDED_NEW) <= recommended)
        self.assertTrue(recommended.isdisjoint(RECOMMENDED_LEGACY))
        verbs = {row[0] for row in self.conn.execute(
            'SELECT tag_id FROM group_tag_link WHERE group_id = 1')}
        self.assertTrue(verbs.isdisjoint({7, 8, 9}))

        moved = self.conn.execute(
            'SELECT tag_id, tag_name, description, editable FROM tags WHERE tag_name = ?',
            ('My Travel Words',)).fetchone()
        self.assertEqual(moved, (travel_id, 'My Travel Words', 'kept', 1))
        self.assertIsNone(self.conn.execute(
            'SELECT tag_name_ja FROM tags WHERE tag_id = ?', (travel_id,)).fetchone()[0])
        self.assertEqual(
            self.conn.execute('SELECT card_id FROM card_tag_link WHERE tag_id = ?', (travel_id,)).fetchone()[0],
            145536)
        self.assertEqual(
            self.conn.execute('SELECT group_id FROM group_tag_link WHERE tag_id = ?', (travel_id,)).fetchone()[0],
            0)
        self.assertEqual(
            self.conn.execute(
                'SELECT card_level_1_count FROM tag_user_card_levels WHERE tag_id = ?',
                (travel_id,)).fetchone()[0],
            4)
        # 644 is the system set, not the user's set.
        self.assertEqual(
            self.conn.execute('SELECT editable FROM tags WHERE tag_id = 644').fetchone()[0], 0)
        cooking = self.conn.execute(
            'SELECT tag_id, tag_name, editable FROM tags WHERE tag_name = ?',
            ('My Cooking Words',)).fetchone()
        self.assertEqual(cooking, (cooking_id, 'My Cooking Words', 1))
        self.assertEqual(
            self.conn.execute('SELECT card_id FROM card_tag_link WHERE tag_id = ?', (cooking_id,)).fetchone()[0],
            145535)
        whole = self.conn.execute(
            'SELECT tag_id, tag_name, editable FROM tags WHERE tag_name = ?',
            ('My Whole Level',)).fetchone()
        self.assertEqual(whole, (whole_id, 'My Whole Level', 1))
        self.assertEqual(
            self.conn.execute('SELECT card_id FROM card_tag_link WHERE tag_id = ?', (whole_id,)).fetchone()[0],
            145580)
        # 717 is the combined Beginner 1 set, not the user's set.
        self.assertEqual(
            self.conn.execute('SELECT tag_name, editable, count FROM tags WHERE tag_id = 717').fetchone(),
            ('Beginner 1 (≈N5) Full Set', 0, 626))
        self.assertEqual(
            self.conn.execute('SELECT count FROM tags WHERE tag_id = 718').fetchone()[0], 585)
        self.assertEqual(
            self.conn.execute('SELECT count FROM tags WHERE tag_id = 719').fetchone()[0], 3478)
        self.assertEqual(
            self.conn.execute('SELECT tag_name, count FROM tags WHERE tag_id = 720').fetchone(),
            ('Advanced (≈N1) Full Set', 2857))
        self.assertEqual(
            self.conn.execute('SELECT tag_count FROM groups WHERE group_id = 24').fetchone()[0], 8)
        self.assertEqual(
            self.conn.execute('SELECT editable FROM tags WHERE tag_id = 700').fetchone()[0], 0)
        dangling = self.conn.execute(
            'SELECT count(*) FROM group_tag_link g WHERE NOT EXISTS '
            '(SELECT 1 FROM tags t WHERE t.tag_id = g.tag_id)').fetchone()[0]
        self.assertEqual(dangling, 0)

        self.assertEqual(
            self.conn.execute('SELECT card_id FROM card_tag_link WHERE tag_id = 0').fetchone()[0],
            150089)
        self.assertEqual(
            self.conn.execute('SELECT count FROM tags WHERE tag_id = 0').fetchone()[0], 1)
        self.assertEqual(
            self.conn.execute('SELECT card_id FROM card_tag_link WHERE tag_id = 124 ORDER BY card_id').fetchall(),
            favorites)
        self.assertEqual(
            self.conn.execute(
                'SELECT card_id, user_id, right_count, wrong_count, card_level FROM user_history').fetchall(),
            before_history)
        self.assertEqual(
            self.conn.execute('SELECT card_id, user_id FROM last_state').fetchall(),
            before_state_card)
        self.assertEqual(
            self.conn.execute('SELECT tag_id FROM last_state WHERE user_id = 1').fetchone()[0], travel_id)
        self.assertEqual(
            self.conn.execute('SELECT user_id, nickname FROM users ORDER BY user_id').fetchall(),
            before_users)

        seq = self.conn.execute("SELECT seq FROM sqlite_sequence WHERE name = 'tags'").fetchone()[0]
        self.assertGreaterEqual(seq, whole_id)
        self.conn.execute("INSERT INTO tags (tag_name, description, editable) VALUES ('Next', '', 1)")
        new_id = self.conn.execute('SELECT last_insert_rowid()').fetchone()[0]
        self.assertGreater(new_id, template_max)
        self.assertNotEqual(new_id, 644)
        self.assertNotEqual(new_id, 717)
        self.assertEqual(
            self.conn.execute('SELECT tag_name_ja FROM tags WHERE tag_id = 95').fetchone()[0],
            '初級1（≈N5）01')
        self.assertEqual(
            self.conn.execute('SELECT tag_name_ja FROM tags WHERE tag_id = 0').fetchone()[0],
            'スターを付けた単語')
        self.assertEqual(
            self.conn.execute(
                "SELECT tag_name_ja FROM tags WHERE tag_name = 'Long Weekend Favorites'").fetchone()[0],
            'ロングウィークエンドのお気に入り')
        self.assertEqual(
            self.conn.execute('SELECT group_name, group_name_ja FROM groups WHERE group_id = 28').fetchone(),
            ('Core 1000', '基本1000語'))

        desc = self.conn.execute('SELECT description FROM tags WHERE tag_id = 133').fetchone()[0]
        self.assertIn('普通名詞', desc)
        self.assertIn('futsuumeishi', desc)
        self.assertNotIn('fukumeishi', desc)
        rude = self.conn.execute('SELECT description FROM tags WHERE tag_id = 161').fetchone()[0]
        self.assertEqual(rude, 'Rude or impolite')

    def test_renamed_favorites_and_user_sets_are_not_translated(self):
        self.conn.execute("UPDATE tags SET tag_name = 'My Favorites' WHERE tag_id = 124")
        self.conn.execute(
            'INSERT INTO tags (tag_id, tag_name, description, editable, count) '
            "VALUES (500000, 'マイセット', 'mine', 1, 0)")
        self.conn.commit()
        self.conn.close()
        user_db_migration.migrate(self.user, self.template)
        self.conn = sqlite3.connect(self.user)
        self.assertEqual(
            self.conn.execute('SELECT tag_name, tag_name_ja, description_ja FROM tags WHERE tag_id = 124').fetchone(),
            ('My Favorites', None, None))
        self.assertEqual(
            self.conn.execute(
                'SELECT tag_name, tag_name_ja, description_ja FROM tags WHERE tag_id = 500000').fetchone(),
            ('マイセット', None, None))
        # A built-in set still gets its Japanese name on the same run.
        self.assertEqual(
            self.conn.execute('SELECT tag_name, tag_name_ja FROM tags WHERE tag_id = 717').fetchone(),
            ('Beginner 1 (≈N5) Full Set', '初級1（≈N5）全部'))

    def test_second_run_changes_nothing(self):
        self.conn.close()
        user_db_migration.migrate(self.user, self.template)
        snap = _snapshot(self.user)
        again = user_db_migration.migrate(self.user, self.template)
        self.assertEqual(again, {})
        self.assertEqual(_snapshot(self.user), snap)
        self.conn = sqlite3.connect(self.user)


def _snapshot(path):
    conn = sqlite3.connect(path)
    try:
        return {
            'tags': conn.execute(
                'SELECT tag_id, tag_name, description, tag_name_ja, description_ja, editable, count '
                'FROM tags ORDER BY tag_id').fetchall(),
            'groups': conn.execute(
                'SELECT group_id, group_name, group_name_ja, owner_id, tag_count, recommended '
                'FROM groups ORDER BY group_id').fetchall(),
            'links': conn.execute(
                'SELECT group_id, tag_id FROM group_tag_link ORDER BY group_id, tag_id').fetchall(),
            'cards': conn.execute(
                'SELECT tag_id, card_id FROM card_tag_link ORDER BY tag_id, card_id').fetchall(),
            'state': conn.execute('SELECT card_id, user_id, tag_id FROM last_state').fetchall(),
            'history': conn.execute(
                'SELECT card_id, user_id, right_count, wrong_count, card_level FROM user_history').fetchall(),
        }
    finally:
        conn.close()


if __name__ == '__main__':
    unittest.main()
