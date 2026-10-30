#!/usr/bin/env python3
"""Build the cFlash CARD and FTS databases from the pinned CC-CEDICT file.

  python3 fetch_sources.py
  python3 build.py

Writes:
  jFlash/sql/cFlash-CARD-2.0.db
  jFlash/sql/plugins/cFlash-FTS-2.0.db
  tools/dictbuild_zh/data/id_map.tsv          (stable card ids)
  tools/dictbuild_zh/data/system_sets.tsv     (only if it does not exist yet)
  tools/dictbuild_zh/reports/build_report.json

and refreshes tags.count in jFlash/sql/cFlash.db. The user template's
version stays 1.0: the table layout did not change, and the revived app
has no old installs to migrate.

Version 2.0 is the dictionary generation, the same step jFlash took from
the 2010 EDICT build to JMdict. The app compares that version when it
decides a bundled plugin is newer than one it already registered.

Not built here, on purpose:
  HSK 3.0 sets   data/hsk30_sets.tsv, read by study_sets.py if present
  Tatoeba        a later EX database keyed by these card ids (see README)
"""

import argparse
import collections
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

import cedict
import fetch_sources
import ids
import pinyin
import study_sets

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
VERSION = '2.0'
MAP_PATH = os.path.join(HERE, 'data', 'id_map.tsv')
BOOTSTRAP_STATS = os.path.join(HERE, 'reports', 'id_bootstrap.json')
LEGACY_CARD = os.path.join(REPO, 'jFlash', 'sql', 'cFlash-CARD-1.0.db')
CARD_NAME = 'cFlash-CARD-%s.db' % VERSION
FTS_NAME = 'cFlash-FTS-%s.db' % VERSION

SCHEMA_CARD = [
    "CREATE TABLE cards (card_id INTEGER PRIMARY KEY, headword_trad TEXT, headword_simp TEXT, headword_en TEXT, reading TEXT)",
    "CREATE TABLE cards_html (card_id INTEGER PRIMARY KEY, meaning TEXT)",
    'CREATE TABLE "system_card_tag_link" (tag_id INTEGER, card_id INTEGER, id INTEGER)',
    "CREATE TABLE version (plugin_key TEXT PRIMARY KEY NOT NULL, version TEXT, plugin_name TEXT)",
]
INDEX_CARD = [
    "CREATE INDEX cards_card_id ON cards (card_id ASC)",
    'CREATE INDEX system_card_tag_link_tag_id ON system_card_tag_link (tag_id ASC)',
    'CREATE INDEX system_card_tag_link_card_id ON system_card_tag_link (card_id ASC)',
]
# Same columns the app MATCHes (headword, reading, content) and reads back
# (card_id, ptag). card_id and ptag are stored but not full-text indexed.
SCHEMA_FTS = [
    "CREATE VIRTUAL TABLE cards_search_content USING fts4("
    "card_id INTEGER, headword, reading, content, ptag INTEGER, "
    "notindexed=card_id, notindexed=ptag)",
    "CREATE TABLE version (plugin_key TEXT PRIMARY KEY NOT NULL, version TEXT, plugin_name TEXT)",
]


def log(*args):
    print(time.strftime('%H:%M:%S'), *args, file=sys.stderr)


def new_db(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        os.remove(path)
    database = sqlite3.connect(path)
    database.execute('PRAGMA page_size = 4096')
    database.execute('PRAGMA journal_mode = DELETE')
    database.execute('PRAGMA synchronous = OFF')
    return database


def finish_db(database):
    database.commit()
    database.execute('ANALYZE')
    database.commit()
    database.execute('VACUUM')
    database.close()


def legacy_cards(path):
    database = sqlite3.connect(path)
    rows = [
        (card_id, trad, simp, pinyin.normalize_reading(reading))
        for card_id, trad, simp, reading in database.execute(
            'SELECT card_id, headword_trad, headword_simp, reading FROM cards ORDER BY card_id')
    ]
    database.close()
    return rows


def legacy_links(path):
    database = sqlite3.connect(path)
    rows = list(database.execute(
        'SELECT tag_id, card_id FROM system_card_tag_link ORDER BY rowid'))
    database.close()
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sources', default=os.path.join(HERE, 'sources'))
    parser.add_argument('--sql-dir', default=os.path.join(REPO, 'jFlash', 'sql'))
    parser.add_argument('--legacy-card', default=LEGACY_CARD,
                        help='2011 CARD db, used only when data/id_map.tsv does not exist yet')
    args = parser.parse_args()
    lock = fetch_sources.verify(args.sources)
    source = cedict.source_path(args.sources)
    card_path = os.path.join(args.sql_dir, CARD_NAME)
    fts_path = os.path.join(args.sql_dir, 'plugins', FTS_NAME)
    user_path = os.path.join(args.sql_dir, 'cFlash.db')
    legacy_path = args.legacy_card if os.path.exists(args.legacy_card) else None

    report = collections.OrderedDict()
    report['version'] = VERSION
    report['bytes_before'] = {}
    for label, path in (('card', os.path.join(args.sql_dir, 'cFlash-CARD-1.0.db')),
                        ('fts', os.path.join(args.sql_dir, 'plugins', 'cFlash-FTS-1.0.db')),
                        ('user', user_path)):
        if os.path.exists(path):
            report['bytes_before'][label] = os.path.getsize(path)

    log('reading', source)
    meta, entries = cedict.iter_file(source)
    report['cedict_date'] = meta.get('date')
    report['cedict_entries_header'] = int(meta['entries']) if meta.get('entries', '').isdigit() else None
    report['cedict_lines'] = len(entries)
    if report['cedict_entries_header'] is not None and report['cedict_entries_header'] != len(entries):
        raise SystemExit('CEDICT header says %s entries, parsed %s' % (
            report['cedict_entries_header'], len(entries)))
    cards = cedict.cross_link(entries)
    report['cards'] = len(cards)
    report['not_a_card'] = len(entries) - len(cards)
    report['erhua_cards'] = sum(1 for entry in cards if entry.variant_kind == 'erhua')
    log('cards', len(cards), 'of', len(entries), 'lines')

    existing = ids.load_map(MAP_PATH)
    map_existed = bool(existing)
    legacy_rows = []
    if not existing:
        if legacy_path is None:
            raise SystemExit('No data/id_map.tsv and no legacy CARD database at %s' % args.legacy_card)
        log('bootstrapping ids from', legacy_path)
        legacy_rows = legacy_cards(legacy_path)
    stats = ids.assign_ids(cards, legacy_rows, existing)
    ids.write_map(MAP_PATH, existing)
    if not map_existed:
        os.makedirs(os.path.dirname(BOOTSTRAP_STATS), exist_ok=True)
        with open(BOOTSTRAP_STATS, 'w', encoding='utf-8') as handle:
            json.dump(stats, handle, indent=2)
            handle.write('\n')
    report['ids'] = stats
    if os.path.exists(BOOTSTRAP_STATS):
        with open(BOOTSTRAP_STATS, encoding='utf-8') as handle:
            report['id_bootstrap'] = json.load(handle)
    log('ids', stats)

    if not os.path.exists(study_sets.SETS_PATH):
        if legacy_path is None:
            raise SystemExit('No data/system_sets.tsv and no legacy CARD database')
        study_sets.write_links(study_sets.SETS_PATH, legacy_links(legacy_path))
        log('wrote', study_sets.SETS_PATH)

    card_ids = {entry.card_id for entry in cards}
    all_links = study_sets.load_links()
    links = study_sets.kept_links(all_links, card_ids)
    before = collections.Counter(tag_id for tag_id, _card in all_links)
    after = collections.Counter(tag_id for tag_id, _card in links)
    priority = {card_id for tag_id, card_id in links if tag_id in study_sets.PRIORITY_TAG_IDS}
    for entry in cards:
        entry.ptag = 1 if entry.card_id in priority else 0
    report['set_links_before'] = len(all_links)
    report['set_links_after'] = len(links)
    report['set_links_dropped'] = len(all_links) - len(links)
    report['ptag'] = sum(entry.ptag for entry in cards)

    log('writing', card_path)
    database = new_db(card_path)
    for statement in SCHEMA_CARD:
        database.execute(statement)
    database.execute(
        "INSERT INTO version VALUES ('CF_CARD_DB', ?, 'Chinese Flash Cards Database (READ ONLY)')",
        (VERSION,))
    ordered = sorted(cards, key=lambda entry: entry.card_id)
    database.executemany(
        'INSERT INTO cards VALUES (?,?,?,?,?)',
        ((entry.card_id, entry.trad, entry.simp, cedict.headword_en(entry), entry.pinyin)
         for entry in ordered))
    database.executemany(
        'INSERT INTO cards_html VALUES (?,?)',
        ((entry.card_id, cedict.meaning_html(entry)) for entry in ordered))
    # Study order is the link-table order. Do not sort.
    database.executemany(
        'INSERT INTO system_card_tag_link (tag_id, card_id) VALUES (?,?)', links)
    for statement in INDEX_CARD:
        database.execute(statement)
    finish_db(database)

    log('writing', fts_path)
    database = new_db(fts_path)
    for statement in SCHEMA_FTS:
        database.execute(statement)
    database.execute(
        "INSERT INTO version VALUES ('FTS_DB', ?, 'Full Text Search Database (READ ONLY)')",
        (VERSION,))
    database.executemany(
        'INSERT INTO cards_search_content (card_id, headword, reading, content, ptag) VALUES (?,?,?,?,?)',
        ((entry.card_id, cedict.fts_headword(entry), pinyin.fts_reading(entry.pinyin),
          cedict.meaning_fts(entry), entry.ptag) for entry in ordered))
    database.execute("INSERT INTO cards_search_content(cards_search_content) VALUES('optimize')")
    finish_db(database)

    names = {}
    favorites_dropped = 0
    counts_changed = None
    if os.path.exists(user_path):
        user = sqlite3.connect(user_path)
        names = dict(user.execute('SELECT tag_id, tag_name FROM tags'))
        before_fav = user.execute('SELECT COUNT(*) FROM card_tag_link').fetchone()[0]
        user.execute('ATTACH DATABASE ? AS carddb', (card_path,))
        user.execute('DELETE FROM main.card_tag_link WHERE card_id NOT IN (SELECT card_id FROM carddb.cards)')
        after_fav = user.execute('SELECT COUNT(*) FROM card_tag_link').fetchone()[0]
        favorites_dropped = before_fav - after_fav
        counts_changed = study_sets.refresh_user_counts(user, links)
        if counts_changed or favorites_dropped:
            user.commit()
        else:
            user.rollback()
        user.close()
    report['user_tag_counts_updated'] = counts_changed
    report['user_card_tag_link_dropped'] = favorites_dropped
    report['sets'] = [
        {
            'tag_id': tag_id,
            'name': names.get(tag_id, ''),
            'before': before[tag_id],
            'after': after[tag_id],
            'dropped': before[tag_id] - after[tag_id],
        }
        for tag_id in sorted(before)
    ]
    report['bytes_after'] = {
        'card': os.path.getsize(card_path),
        'fts': os.path.getsize(fts_path),
        'user': os.path.getsize(user_path) if os.path.exists(user_path) else None,
    }
    report['sources'] = lock
    out = os.path.join(HERE, 'reports', 'build_report.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False)
        handle.write('\n')
    print(json.dumps({k: report[k] for k in report if k != 'sets'}, indent=2, ensure_ascii=False))
    dropped = [row for row in report['sets'] if row['dropped']]
    print('sets with dropped links: %d' % len(dropped))
    for row in dropped:
        print('  %s %s %d -> %d (-%d)' % (row['tag_id'], row['name'], row['before'], row['after'], row['dropped']))


if __name__ == '__main__':
    main()
