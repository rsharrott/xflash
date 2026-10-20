#!/usr/bin/env python3
"""Build the jFlash CARD, FTS and EX SQLite databases from current sources.

  python3 fetch_sources.py            # -> sources/ (JMdict_e, Tatoeba), checked against sources.lock.json
  python3 build.py                    # -> jFlash/sql/jFlash-CARD-2.0.db,
                                      #    jFlash/sql/plugins/jFlash-FTS-2.0.db,
                                      #    jFlash/sql/plugins/jFlash-EX-2.0.db
                                      #    + refreshes tags.count in the user DB template
                                      #      (jFlash.db, if it exists)

Inputs kept in the repo (see migrate_legacy.py for how they were made):
  data/curated_cards.jsonl  hand-made kana / word / phrase cards, copied verbatim
  data/system_sets.tsv      built-in study set membership (tag_id, card_id)

Schemas are the ones the 1.x app reads (see SCHEMA_* below).  The one change is
the FTS table: FTS4 with card_id/ptag stored but not indexed (the app only
MATCHes text and reads card_id/ptag back), which keeps the file under 50 MB.
Dictionary card_id = JMdict ent_seq, so ids are stable across rebuilds.
"""

import argparse
import collections
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

import fetch_sources
import jmdict
import tatoeba
from cards import build_card, is_kana, CARD_TYPE_DICTIONARY

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
VERSION = '2.0'
SHOWN_PER_CARD = 10      # the app shows at most 10 sentences per card (should_show = 1)
LINKS_PER_CARD = 20      # each card picks its best 20 sentences (the first 10 shown); only these ship

# Words that never get the extra (should_show = 0) links that list a sentence's other words:
# tatoeba.STOP_WORDS (particles and function words, matched there on the B-line surface form)
# plus the conjunctive particle のに.  The B-lines often write a stop word differently from the
# list (の resolves to the 乃 card; 仕舞う, 彼の(あの), 何の(どの) vs しまう, あの, どの), so the check
# is on the resolved card: its headword, or its reading when the card is written in kana.  The cards still keep their own
# top LINKS_PER_CARD sentences, as in the original build.
EXTRA_LINK_STOP_WORDS = frozenset(tatoeba.STOP_WORDS | {'のに'})


def card_readings(card):
    return {x.strip() for x in (card.get('reading') or '').replace(',', ';').split(';') if x.strip()}


def is_stop_card(card):
    """True for a particle / function-word card (乃 の, な, のに, 彼の あの ...)."""
    if card['headword'] in EXTRA_LINK_STOP_WORDS:
        return True
    return bool(card.get('kana_only')) and bool(card_readings(card) & EXTRA_LINK_STOP_WORDS)


SCHEMA_CARD = [
    "CREATE TABLE cards (card_id INTEGER PRIMARY KEY, card_type TEXT, headword TEXT, headword_en TEXT, reading TEXT, romaji TEXT, kana_only integer(1))",
    "CREATE TABLE cards_html (card_id INTEGER PRIMARY KEY, meaning TEXT)",
    "CREATE TABLE version (plugin_key TEXT PRIMARY KEY NOT NULL, version TEXT, plugin_name TEXT)",
    'CREATE TABLE "system_card_tag_link" (tag_id INTEGER,\tcard_id INTEGER, id INTEGER)',
]
INDEX_CARD = [
    "CREATE INDEX cards_card_id ON cards (card_id ASC)",
    "CREATE INDEX system_card_tag_link_card_id ON system_card_tag_link (card_id)",
    "CREATE INDEX system_card_tag_link_tag_id ON system_card_tag_link (tag_id)",
]
SCHEMA_FTS = [
    # Same columns as the 1.x FTS3 table.  FTS4 lets card_id and ptag be stored without
    # being full-text indexed (in FTS3 every column is indexed: 220k one-off card_id
    # terms plus 0/1 ptag doclists covering every row).  matchinfo=fts3 skips the
    # %_docsize table, which only matchinfo()/ranking would need.
    "CREATE VIRTUAL TABLE cards_search_content USING fts4(card_id, content, ptag INTEGER NOT NULL DEFAULT 0, "
    "notindexed=card_id, notindexed=ptag, matchinfo=fts3)",
    "CREATE TABLE version (plugin_key TEXT PRIMARY KEY NOT NULL, version TEXT, plugin_name TEXT)",
]
SCHEMA_EX = [
    "CREATE TABLE sentences (sentence_id INTEGER PRIMARY KEY  NOT NULL , sentence_ja TEXT, sentence_en TEXT, checked BOOL)",
    "CREATE TABLE card_sentence_link (card_id NOT NULL, sentence_id INTEGER NOT NULL, should_show INTEGER, sense_number INTEGER)",
    "CREATE TABLE version (plugin_key TEXT PRIMARY KEY NOT NULL, version TEXT, plugin_name TEXT)",
]
INDEX_EX = [
    "CREATE INDEX card_sentence_link_sentence_id ON card_sentence_link(sentence_id ASC)",
    "CREATE INDEX card_sentence_link_card_should_show ON card_sentence_link(card_id ASC, should_show ASC)",
]


def log(*a):
    print(time.strftime('%H:%M:%S'), *a, file=sys.stderr)


def new_db(path):
    if os.path.exists(path):
        os.remove(path)
    db = sqlite3.connect(path)
    db.execute('PRAGMA page_size = 4096')
    db.execute('PRAGMA journal_mode = DELETE')
    db.execute('PRAGMA synchronous = OFF')
    return db


def finish_db(db):
    db.commit()
    db.execute('ANALYZE')
    db.commit()
    db.execute('VACUUM')
    db.close()


def choose_links(card_links, usable, length, is_stop=lambda card_id: False):
    """Pick the card_sentence_link rows and the sentences that ship.

    card_links: {card_id: {sentence_id: (checked, sense_number)}}, every resolved B-line word.
    usable(sentence_id): the sentence and its English translation both exist.
    length(sentence_id): length of the Japanese text, used for ranking.
    is_stop(card_id): the card is a particle / function word (see is_stop_card).

    1. Per card, rank its usable sentences (checked words first, then shorter sentences,
       then id) and keep the best LINKS_PER_CARD; the first SHOWN_PER_CARD get
       should_show = 1.  Those sentences are the ones that ship; no others are added.
    2. Every shipped sentence then also links to each of its other resolved words
       (should_show = 0), so the expanded sentence can list all its words (母, 忙しい ...)
       while each card's own sentence list stays at its best SHOWN_PER_CARD.  Stop cards
       (is_stop) get none of these extra links.

    Returns (sorted rows of (card_id, sentence_id, should_show, sense_number), set of sentence ids).
    """
    rows, used = {}, set()
    for cid, d in card_links.items():
        ranked = sorted((jid for jid in d if usable(jid)), key=lambda j: (not d[j][0], length(j), j))
        for n, jid in enumerate(ranked[:LINKS_PER_CARD]):
            rows[(cid, jid)] = (1 if n < SHOWN_PER_CARD else 0, d[jid][1])
            used.add(jid)
    for cid, d in card_links.items():
        if is_stop(cid):
            continue
        for jid, (_, sense) in d.items():
            if jid in used and (cid, jid) not in rows:
                rows[(cid, jid)] = (0, sense)
    return sorted((cid, jid, show, sense) for (cid, jid), (show, sense) in rows.items()), used


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sources', default=os.path.join(HERE, 'sources'))
    ap.add_argument('--sql-dir', default=os.path.join(REPO, 'jFlash', 'sql'))
    a = ap.parse_args()
    src = lambda n: os.path.join(a.sources, n)
    card_path = os.path.join(a.sql_dir, 'jFlash-CARD-%s.db' % VERSION)
    fts_path = os.path.join(a.sql_dir, 'plugins', 'jFlash-FTS-%s.db' % VERSION)
    ex_path = os.path.join(a.sql_dir, 'plugins', 'jFlash-EX-%s.db' % VERSION)
    # User DB templates whose cached tags.count is refreshed; only touch templates that exist.
    user_dbs = [p for p in (os.path.join(a.sql_dir, n) for n in ('jFlash.db',))
                if os.path.exists(p)]
    report = collections.OrderedDict()
    lock = fetch_sources.verify(a.sources)      # exits unless sources match sources.lock.json

    # ---- cards ------------------------------------------------------------
    created, _ = jmdict.read_header(src('JMdict_e.gz'))
    log('JMdict created', created)
    entries = {}
    cards = {}
    for e in jmdict.iter_entries(src('JMdict_e.gz')):
        entries[e['seq']] = e
        cards[e['seq']] = build_card(e)
    report['jmdict_created'] = created
    report['jmdict_entries'] = len(entries)
    curated = [json.loads(l) for l in open(os.path.join(HERE, 'data', 'curated_cards.jsonl'), encoding='utf-8')]
    for c in curated:
        assert c['card_id'] not in cards, 'curated card_id collides with JMdict seq: %s' % c['card_id']
        cards[c['card_id']] = c
    report['curated_cards'] = collections.Counter(c['card_type'] for c in curated)
    log('cards:', len(cards))

    # ---- set membership ----------------------------------------------------
    links, missing = [], collections.Counter()
    for line in open(os.path.join(HERE, 'data', 'system_sets.tsv'), encoding='utf-8'):
        if line.startswith('#') or not line.strip():
            continue
        tag_id, card_id = map(int, line.split('\t'))
        if card_id in cards:
            links.append((tag_id, card_id))
        else:
            missing[tag_id] += 1   # entry deleted from JMdict since the set was made
    report['set_links'] = len(links)
    report['set_links_missing_card'] = sum(missing.values())

    # ---- CARD db -----------------------------------------------------------
    log('writing', card_path)
    db = new_db(card_path)
    for s in SCHEMA_CARD:
        db.execute(s)
    db.execute("INSERT INTO version VALUES ('CARD_DB', ?, 'Cards Database (READ ONLY)')", (VERSION,))
    ids = sorted(cards)
    db.executemany('INSERT INTO cards VALUES (?,?,?,?,?,?,?)',
                   ((i, str(cards[i]['card_type']), cards[i]['headword'], cards[i]['headword_en'],
                     cards[i]['reading'], cards[i]['romaji'], int(cards[i]['kana_only'] or 0)) for i in ids))
    db.executemany('INSERT INTO cards_html VALUES (?,?)', ((i, cards[i]['meaning']) for i in ids))
    db.executemany('INSERT INTO system_card_tag_link (tag_id, card_id) VALUES (?,?)', sorted(links))
    for s in INDEX_CARD:
        db.execute(s)
    finish_db(db)

    # ---- FTS db ------------------------------------------------------------
    log('writing', fts_path)
    db = new_db(fts_path)
    for s in SCHEMA_FTS:
        db.execute(s)
    db.execute("INSERT INTO version VALUES ('FTS_DB', ?, 'Full Text Search Database (READ ONLY)')", (VERSION,))
    # Hand-made 1.x cards are kept verbatim for the built-in sets, but many are the same word as a
    # JMdict entry (same headword and readings).  Those stay out of the search index so search
    # doesn't list every such word twice; studying the set still shows the hand-made card.
    def norm_readings(r):
        return frozenset(x.strip() for x in (r or '').replace(',', ';').split(';') if x.strip())
    jm_keys = {(c['headword'], norm_readings(c['reading'])) for i, c in cards.items() if i in entries}
    search_dupes = {c['card_id'] for c in curated if int(c['card_type']) == CARD_TYPE_DICTIONARY and
                    (c['headword'], norm_readings(c['reading'])) in jm_keys}
    report['handmade_cards_hidden_from_search_as_jmdict_duplicates'] = len(search_dupes)
    db.executemany('INSERT INTO cards_search_content (card_id, content, ptag) VALUES (?,?,?)',
                   ((i, cards[i]['content'], int(cards[i]['ptag'] or 0)) for i in ids if i not in search_dupes))
    db.execute("INSERT INTO cards_search_content(cards_search_content) VALUES('optimize')")
    finish_db(db)

    # ---- EX db -------------------------------------------------------------
    log('indexing card forms for sentence linking')
    kanji_forms = collections.defaultdict(set)
    kana_forms = collections.defaultdict(set)
    readings_of = {}
    for seq, e in entries.items():
        readings_of[seq] = {r['text'] for r in e['r']}
        for k in e['k']:
            kanji_forms[k['text']].add(seq)
        kana_ok = not e['k'] or cards[seq]['kana_only']
        for r in e['r']:
            if kana_ok:
                kana_forms[r['text']].add(seq)
    for c in curated:
        if int(c['card_type']) == CARD_TYPE_DICTIONARY:   # hand-made phrases, like the 1.x importer
            kanji_forms[c['headword']].add(c['card_id'])
            readings_of[c['card_id']] = set(x.strip() for x in c['reading'].replace(',', ';').split(';'))

    def resolve(word, reading):
        if reading.startswith('#'):   # Tatoeba disambiguates some words by JMdict seq: 前(#1392580)
            seq = int(reading[1:]) if reading[1:].isdigit() else None
            return {seq} if seq in cards else set()
        cands = kanji_forms.get(word) or kana_forms.get(word) or set()
        if reading:
            cands = {s for s in cands if reading in readings_of.get(s, ())}
        if len(cands) > 1:
            exact = {s for s in cands if cards[s]['headword'] == word}
            cands = exact or cands
        if len(cands) > 1:
            common = {s for s in cands if cards[s]['ptag']}
            cands = common or cands
        return cands if len(cands) <= 3 else set()

    log('reading Tatoeba jpn_indices')
    pairs = {}          # jpn_id -> (eng_id, checked)
    card_links = collections.defaultdict(dict)   # card_id -> {jpn_id: (checked, sense)}
    unresolved = 0
    for jid, eid, refs, checked in tatoeba.read_indices(src('jpn_indices.tar.bz2')):
        if jid in pairs or eid <= 0:
            continue
        pairs[jid] = (eid, checked)
        for w, r, sense, good in refs:
            hit = resolve(w, r)
            if not hit:
                unresolved += 1
            for cid in hit:
                prev = card_links[cid].get(jid)
                if prev is None or (good and not prev[0]):
                    card_links[cid][jid] = (good, sense)
    log('reading Tatoeba sentences (jpn/eng)')
    wanted = set(pairs) | {e for e, _ in pairs.values()}
    text = tatoeba.read_sentences(src('sentences.tar.bz2'), wanted)

    link_rows, used = choose_links(card_links,
                                   usable=lambda j: j in text and pairs[j][0] in text,
                                   length=lambda j: len(text[j]),
                                   is_stop=lambda cid: is_stop_card(cards[cid]))
    log('writing', ex_path)
    db = new_db(ex_path)
    for s in SCHEMA_EX:
        db.execute(s)
    db.execute("INSERT INTO version VALUES ('EX_DB', ?, 'Example Sentence Data')", (VERSION,))
    db.executemany('INSERT INTO sentences VALUES (?,?,?,?)',
                   ((j, text[j], text[pairs[j][0]], 1 if pairs[j][1] else 0) for j in sorted(used)))
    db.executemany('INSERT INTO card_sentence_link VALUES (?,?,?,?)', link_rows)
    for s in INDEX_EX:
        db.execute(s)
    finish_db(db)
    report['tatoeba_indexed_pairs'] = len(pairs)
    report['sentences'] = len(used)
    report['card_sentence_links'] = len(link_rows)
    report['card_sentence_links_shown'] = sum(1 for r in link_rows if r[2])
    stop_ids = {i for i in cards if is_stop_card(cards[i])}
    report['card_sentence_links_to_stop_cards'] = sum(1 for r in link_rows if r[0] in stop_ids)
    report['cards_with_sentences'] = len({r[0] for r in link_rows})
    report['unresolved_index_words'] = unresolved

    # ---- user DB templates: refresh cached set sizes, check card ids ----------
    # Deterministic: a template is only written when a count actually changes, and never
    # VACUUMed/ANALYZEd, so re-running the build leaves the committed files byte-identical.
    sys_counts = collections.Counter(t for t, _ in links)
    report['user_db_templates'] = {}
    for path in user_dbs:
        # mode=rw: fail rather than create an empty database if the file vanished meanwhile
        u = sqlite3.connect(Path(path).resolve().as_uri() + '?mode=rw', uri=True)
        bad = [r for r in u.execute('SELECT tag_id, card_id FROM card_tag_link') if r[1] not in cards]
        bad += [('last_state', r[0]) for r in u.execute('SELECT card_id FROM last_state') if r[0] not in cards]
        assert not bad, '%s references cards that no longer exist: %s' % (path, bad[:10])
        user_counts = collections.Counter(t for (t,) in u.execute('SELECT tag_id FROM card_tag_link'))
        changed = 0
        for tag_id, editable, count in u.execute('SELECT tag_id, editable, count FROM tags').fetchall():
            n = user_counts[tag_id] if (editable or tag_id == 0) else sys_counts[tag_id]
            if n != count:
                u.execute('UPDATE tags SET count = ? WHERE tag_id = ?', (n, tag_id))
                changed += 1
        if changed:
            u.commit()
        u.close()
        report['user_db_templates'][os.path.basename(path)] = '%d tag counts updated' % changed

    # ---- report --------------------------------------------------------------
    for p in (card_path, fts_path, ex_path):
        report['bytes ' + os.path.relpath(p, REPO)] = os.path.getsize(p)
    report['card_types'] = collections.Counter(str(c['card_type']) for c in cards.values())
    report['common (ptag)'] = sum(1 for c in cards.values() if c['ptag'])
    report['sources'] = lock
    out = os.path.join(HERE, 'reports', 'build_report.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w') as f:
        json.dump(report, f, indent=2, ensure_ascii=False, default=dict)
    print(json.dumps(report, indent=2, ensure_ascii=False, default=dict))


if __name__ == '__main__':
    main()
