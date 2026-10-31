#!/usr/bin/env python3
"""Stable ids: exact, one-to-one pinyin/character changes, then ids >= 1_000_000."""

import os
import tempfile
import unittest

import ids


class Entry:
    def __init__(self, trad, simp, pinyin):
        self.trad = trad
        self.simp = simp
        self.pinyin = pinyin
        self.card_id = None


class AssignTest(unittest.TestCase):

    def assign(self, entries, legacy, existing=None):
        mapping = {} if existing is None else existing
        stats = ids.assign_ids(entries, legacy, mapping)
        return entries, stats, mapping

    def test_exact_match_keeps_the_old_id(self):
        entries, stats, mapping = self.assign(
            [Entry('愛', '爱', 'ai4')],
            [(42, '愛', '爱', 'ai4')])
        self.assertEqual(entries[0].card_id, 42)
        self.assertEqual(stats['exact'], 1)
        self.assertEqual(stats['new'], 0)
        self.assertEqual(mapping[('愛', '爱', 'ai4')], 42)

    def test_unique_pinyin_change_keeps_the_id(self):
        entries, stats, _mapping = self.assign(
            [Entry('愛', '爱', 'ai4')],
            [(7, '愛', '爱', 'ai3')])
        self.assertEqual(entries[0].card_id, 7)
        self.assertEqual(stats['pinyin_changed'], 1)

    def test_two_readings_are_not_guessed(self):
        # One old card, two new pronunciations, neither exact: do not pick.
        entries, stats, _mapping = self.assign(
            [Entry('行', '行', 'xing2'), Entry('行', '行', 'hang2')],
            [(9, '行', '行', 'xing4')])
        self.assertEqual(stats['pinyin_changed'], 0)
        self.assertEqual(stats['ambiguous_same_chars'], 2)
        self.assertTrue(all(entry.card_id >= ids.NEW_ID_START for entry in entries))
        self.assertNotEqual(entries[0].card_id, entries[1].card_id)

    def test_exact_reading_is_kept_and_the_leftover_pair_follows(self):
        # xing2 is exact. One old reading and one new reading of 行 remain,
        # so the leftover pair is the unique pinyin change, not a guess.
        entries, stats, _mapping = self.assign(
            [Entry('行', '行', 'xing2'), Entry('行', '行', 'hang2')],
            [(9, '行', '行', 'xing2'), (10, '行', '行', 'heng2')])
        self.assertEqual(entries[0].card_id, 9)
        self.assertEqual(entries[1].card_id, 10)
        self.assertEqual(stats['exact'], 1)
        self.assertEqual(stats['pinyin_changed'], 1)
        self.assertEqual(stats['legacy_dropped'], 0)

    def test_unique_traditional_change_keeps_the_id(self):
        entries, stats, _mapping = self.assign(
            [Entry('裡', '里', 'li3')],
            [(15, '裏', '里', 'li3')])
        self.assertEqual(entries[0].card_id, 15)
        self.assertEqual(stats['traditional_changed'], 1)

    def test_unique_simplified_change_keeps_the_id(self):
        entries, stats, _mapping = self.assign(
            [Entry('後', '后', 'hou4')],
            [(16, '後', '後', 'hou4')])
        self.assertEqual(entries[0].card_id, 16)
        self.assertEqual(stats['simplified_changed'], 1)

    def test_new_ids_follow_file_order_from_one_million(self):
        entries, _stats, mapping = self.assign(
            [Entry('微', '微', 'wei1'), Entry('信', '信', 'xin4')],
            [])
        self.assertEqual([entry.card_id for entry in entries], [1000000, 1000001])
        self.assertEqual(mapping[('微', '微', 'wei1')], 1000000)

    def test_a_dropped_key_is_remembered(self):
        _entries, _stats, mapping = self.assign(
            [Entry('新', '新', 'xin1')],
            [(3, '舊', '旧', 'jiu4')])
        self.assertEqual(mapping[('舊', '旧', 'jiu4')], 3)
        # It comes back in a later refresh.
        again = [Entry('新', '新', 'xin1'), Entry('舊', '旧', 'jiu4')]
        stats = ids.assign_ids(again, [], mapping)
        self.assertEqual(again[1].card_id, 3)
        self.assertEqual(again[0].card_id, 1000000)
        self.assertEqual(stats['exact'], 2)
        self.assertEqual(stats['new'], 0)

    def test_later_build_keeps_ids_when_pinyin_or_traditional_changes(self):
        # A refresh edits the pinyin (including a capitalisation) and the
        # traditional form. The committed map, not a new id, wins.
        first = [Entry('愛', '爱', 'ai4'), Entry('裏', '里', 'li3'), Entry('先生', '先生', 'xian1 sheng5')]
        _first, _stats, mapping = self.assign(
            first, [(7, '愛', '爱', 'ai4'), (15, '裏', '里', 'li3'), (20, '先生', '先生', 'xian1 sheng5')])
        edited = [Entry('愛', '爱', 'ai3'), Entry('裡', '里', 'li3'), Entry('先生', '先生', 'Xian1 sheng5')]
        stats = ids.assign_ids(edited, [], mapping)
        self.assertEqual([entry.card_id for entry in edited], [7, 15, 20])
        self.assertEqual(stats['pinyin_changed'], 2)
        self.assertEqual(stats['traditional_changed'], 1)
        self.assertEqual(stats['new'], 0)
        self.assertNotIn(('愛', '爱', 'ai4'), mapping)
        self.assertEqual(mapping[('愛', '爱', 'ai3')], 7)
        self.assertEqual(mapping[('裡', '里', 'li3')], 15)
        # The old spelling of 先生 coming back beside the edited one is a
        # second entry, so it does not take 20.
        both = [Entry('先生', '先生', 'Xian1 sheng5'), Entry('先生', '先生', 'xian1 sheng5')]
        ids.assign_ids(both, [], mapping)
        self.assertEqual(both[0].card_id, 20)
        self.assertGreaterEqual(both[1].card_id, ids.NEW_ID_START)
        self.assertNotEqual(both[0].card_id, both[1].card_id)

    def test_refresh_covers_exact_pinyin_traditional_simplified_and_a_second_edit(self):
        first = [
            Entry('你', '你', 'ni3'),
            Entry('愛', '爱', 'ai4'),
            Entry('裏', '里', 'li3'),
            Entry('後', '後', 'hou4'),
            Entry('先生', '先生', 'xian1 sheng5'),
            Entry('行', '行', 'xing2'),
            Entry('行', '行', 'hang2'),
        ]
        _entries, stats, mapping = self.assign(first, [
            (1, '你', '你', 'ni3'),
            (7, '愛', '爱', 'ai4'),
            (15, '裏', '里', 'li3'),
            (16, '後', '後', 'hou4'),
            (20, '先生', '先生', 'xian1 sheng5'),
            (9, '行', '行', 'xing2'),
            (10, '行', '行', 'hang2'),
        ])
        self.assertEqual(stats['exact'], 7)
        edited = [
            Entry('你', '你', 'ni3'),
            Entry('愛', '爱', 'ai3'),
            Entry('裡', '里', 'li3'),
            Entry('後', '后', 'hou4'),
            Entry('先生', '先生', 'Xian1 sheng5'),
            Entry('行', '行', 'xing2'),
            Entry('行', '行', 'hang2'),
            Entry('微', '微', 'Wei1'),
        ]
        stats = ids.assign_ids(edited, [], mapping)
        self.assertEqual([entry.card_id for entry in edited[:7]], [1, 7, 15, 16, 20, 9, 10])
        self.assertGreaterEqual(edited[7].card_id, ids.NEW_ID_START)
        self.assertEqual(stats['exact'], 3)
        self.assertEqual(stats['pinyin_changed'], 2)
        self.assertEqual(stats['traditional_changed'], 1)
        self.assertEqual(stats['simplified_changed'], 1)
        self.assertEqual(stats['new'], 1)
        # A second refresh moves 愛 again and still keeps 7.
        again = [Entry('愛', '爱', 'ai1'), Entry('你', '你', 'ni3')]
        ids.assign_ids(again, [], mapping)
        self.assertEqual(again[0].card_id, 7)
        self.assertEqual(again[1].card_id, 1)
        # Two new readings against one old card are not guessed.
        mapping[('中', '中', 'zhong3')] = 99
        ambiguous = [Entry('中', '中', 'zhong1'), Entry('中', '中', 'zhong4')]
        stats = ids.assign_ids(ambiguous, [], mapping)
        self.assertEqual(stats['pinyin_changed'], 0)
        self.assertEqual(stats['ambiguous_same_chars'], 2)
        self.assertGreaterEqual(ambiguous[0].card_id, ids.NEW_ID_START)
        self.assertGreaterEqual(ambiguous[1].card_id, ids.NEW_ID_START)
        self.assertNotEqual(ambiguous[0].card_id, ambiguous[1].card_id)
        self.assertNotEqual(ambiguous[0].card_id, edited[7].card_id)

    def test_map_round_trip_is_stable(self):
        entries = [Entry('愛', '爱', 'ai4'), Entry('微', '微', 'Wei1')]
        _entries, _stats, mapping = self.assign(entries, [(5, '愛', '爱', 'ai4')])
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, 'id_map.tsv')
            self.assertTrue(ids.write_map(path, mapping))
            self.assertFalse(ids.write_map(path, mapping))
            loaded = ids.load_map(path)
        fresh = [Entry('微', '微', 'Wei1'), Entry('愛', '爱', 'ai4')]
        ids.assign_ids(fresh, [], loaded)
        self.assertEqual(fresh[0].card_id, entries[1].card_id)
        self.assertEqual(fresh[1].card_id, 5)

    def test_duplicate_key_is_rejected(self):
        with self.assertRaises(SystemExit):
            ids.assign_ids([Entry('愛', '爱', 'ai4'), Entry('愛', '爱', 'ai4')], [], {})


if __name__ == '__main__':
    unittest.main()
