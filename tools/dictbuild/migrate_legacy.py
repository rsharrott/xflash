#!/usr/bin/env python3
"""One-off migration from the 2010-era 1.x databases to the JMdict-based 2.0 data.

Reads the legacy jFlash-CARD-1.1.db / jFlash-FTS-1.1.db (e.g. extracted from git
history) and the current JMdict_e, and writes the hand-curated inputs that
build.py needs from then on:

  data/curated_cards.jsonl  - the hand-made kana (type 1) and word (type 0) cards,
                              copied verbatim with their 1.x card_ids
  data/system_sets.tsv      - built-in study set membership (tag_id, card_id),
                              re-mapped to JMdict ent_seq card_ids by headword+reading
  reports/legacy_unmatched.tsv, reports/legacy_match.md

It also re-maps card_ids inside the bundled user DB templates (jFlash.db,
jFlashJr.db: card_tag_link and last_state) in place.  Run it once; afterwards
card_ids are JMdict sequence numbers, which are stable across JMdict releases.

Usage:
  git show a82bfa3c:jFlash/sql/jFlash-CARD-1.1.db > /tmp/legacy-card.db
  git show a82bfa3c:jFlash/sql/plugins/jFlash-FTS-1.1.db > /tmp/legacy-fts.db
  python3 migrate_legacy.py --legacy-card /tmp/legacy-card.db --legacy-fts /tmp/legacy-fts.db \
      --jmdict sources/JMdict_e.gz --user-db ../../jFlash/sql/jFlash.db --user-db ../../jFlash/sql/jFlashJr.db
"""

import argparse
import collections
import json
import os
import re
import sqlite3
import sys

import jmdict
from cards import build_card, CARD_TYPE_DICTIONARY

HERE = os.path.dirname(os.path.abspath(__file__))

# Legacy card_ids from 145383 up were added by Long Weekend by hand (the
# ManuallyCompiledWords*/KanaLists imports and later additions: phrases such as
# 助けて下さい or masu-form verbs for the Survival Japanese sets).  When one of
# these has no JMdict counterpart it is carried over verbatim like the kana/word
# cards, so the hand-made sets stay complete.
LWE_HANDMADE_MIN_ID = 145383


def split_readings(s):
    return [x.strip() for x in re.split(r'[;,、]', s or '') if x.strip()]


def kata_to_hira(s):
    return ''.join(chr(ord(c) - 0x60) if 0x30A1 <= ord(c) <= 0x30F6 else c for c in s)


class Matcher:
    def __init__(self, entries):
        self.cards = {}
        self.forms = collections.defaultdict(set)   # any keb/reb -> seqs
        self.hira_forms = collections.defaultdict(set)
        self.kebs = {}
        self.rebs = {}
        for e in entries:
            c = build_card(e)
            self.cards[e['seq']] = c
            kebs = [k['text'] for k in e['k']]
            rebs = [r['text'] for r in e['r']]
            self.kebs[e['seq']] = set(kebs)
            self.rebs[e['seq']] = set(rebs)
            for f in kebs + rebs:
                self.forms[f].add(e['seq'])
                self.hira_forms[kata_to_hira(f)].add(e['seq'])

    def _rank(self, seqs, hw):
        return sorted(seqs, key=lambda s: (self.cards[s]['headword'] != hw,
                                           -self.cards[s]['ptag'], s))

    def match(self, hw, reading, en=None):
        """Return (seq or None, tier)."""
        olds = split_readings(reading)
        cands = self.forms.get(hw, set())
        if not cands and is_kana_text(hw):
            # hiragana/katakana spelling variants
            alt = kata_to_hira(hw)
            cands = set(self.hira_forms.get(alt, set()))
        if not cands:
            # The legacy kanji spelling is gone from JMdict (typically rare ateji such as
            # 打つかる for ぶつかる): fall back to a usually-kana entry with the same reading
            # and the same first English gloss.
            if olds:
                by_reading = [s for s in self.forms.get(olds[0], set())
                              if self.cards[s]['kana_only'] or not self.kebs[s]]
                same_en = [s for s in by_reading if self.cards[s]['headword_en'].lower() == (en or '').lower()]
                pick = same_en or (by_reading if len(by_reading) == 1 else [])
                if pick:
                    return self._rank(pick, olds[0])[0], 'reading-only (legacy kanji form gone)'
            return None, 'unmatched'
        t1 = [s for s in cands if self.cards[s]['headword'] == hw and
              split_readings(self.cards[s]['reading']) == olds]
        if t1:
            return self._rank(t1, hw)[0], 'exact'
        if olds:
            t2 = [s for s in cands if olds[0] in self.rebs[s] or
                  kata_to_hira(olds[0]) in {kata_to_hira(r) for r in self.rebs[s]}]
            if t2:
                return self._rank(t2, hw)[0], 'headword+reading'
            t3 = [s for s in cands if any(r in self.rebs[s] for r in olds)]
            if t3:
                return self._rank(t3, hw)[0], 'headword+other-reading'
        if len(cands) == 1:
            return next(iter(cands)), 'headword-only'
        return None, 'ambiguous'


def is_kana_text(s):
    return all(0x3040 <= ord(c) <= 0x30FF or c == 'ー' for c in s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--legacy-card', required=True)
    ap.add_argument('--legacy-fts', required=True)
    ap.add_argument('--jmdict', required=True)
    ap.add_argument('--user-db', action='append', default=[])
    a = ap.parse_args()

    os.makedirs(os.path.join(HERE, 'data'), exist_ok=True)
    os.makedirs(os.path.join(HERE, 'reports'), exist_ok=True)

    print('Parsing JMdict ...', file=sys.stderr)
    m = Matcher(jmdict.iter_entries(a.jmdict))

    old = sqlite3.connect('file:%s?mode=ro' % a.legacy_card, uri=True)
    old.execute("ATTACH 'file:%s?mode=ro' AS f" % a.legacy_fts)
    tagnames = {}
    for udb in a.user_db:
        u = sqlite3.connect('file:%s?mode=ro' % udb, uri=True)
        tagnames.update(dict(u.execute('SELECT tag_id, tag_name FROM tags')))
        u.close()

    # 1. curated kana / word cards, verbatim
    curated = []
    keys = ['card_id', 'card_type', 'headword', 'headword_en', 'reading', 'romaji',
            'kana_only', 'meaning', 'content', 'ptag']
    curated_sql = """SELECT c.card_id, c.card_type, c.headword, c.headword_en, c.reading,
                                     c.romaji, c.kana_only, h.meaning, f.c1content, f.c2ptag
                              FROM cards c JOIN cards_html h USING(card_id)
                              LEFT JOIN f.cards_search_content_content f ON f.c0card_id = c.card_id
                              WHERE c.card_type <> ? ORDER BY c.card_id"""
    for row in old.execute("""SELECT c.card_id, c.card_type, c.headword, c.headword_en, c.reading,
                                     c.romaji, c.kana_only, h.meaning, f.c1content, f.c2ptag
                              FROM cards c JOIN cards_html h USING(card_id)
                              LEFT JOIN f.cards_search_content_content f ON f.c0card_id = c.card_id
                              WHERE c.card_type <> ? ORDER BY c.card_id""", (str(CARD_TYPE_DICTIONARY),)):
        curated.append(dict(zip(keys, row)))
    curated_ids = {c['card_id'] for c in curated}

    # 2. map every legacy dictionary card that is used by a set or a user DB
    used = set(r[0] for r in old.execute('SELECT DISTINCT card_id FROM system_card_tag_link'))
    user_links = {}
    for udb in a.user_db:
        u = sqlite3.connect('file:%s?mode=ro' % udb, uri=True)
        user_links[udb] = (u.execute('SELECT tag_id, card_id FROM card_tag_link').fetchall(),
                           u.execute('SELECT card_id FROM last_state').fetchall())
        for _, cid in user_links[udb][0]:
            used.add(cid)
        for (cid,) in user_links[udb][1]:
            used.add(cid)
        u.close()

    mapping, tiers, unmatched = {}, collections.Counter(), {}
    keep_verbatim = set()
    oldcards = {r[0]: r[1:] for r in old.execute('SELECT card_id, card_type, headword, reading, headword_en FROM cards')}
    for cid in sorted(used):
        if cid in curated_ids:
            mapping[cid] = cid
            tiers['curated (kept)'] += 1
            continue
        ctype, hw, reading, en = oldcards[cid]
        seq, tier = m.match(hw, reading, en)
        if seq is None and cid >= LWE_HANDMADE_MIN_ID:
            tier = 'hand-made, no JMdict match (kept verbatim)'
            keep_verbatim.add(cid)
            mapping[cid] = cid
            tiers[tier] += 1
            continue
        tiers[tier] += 1
        if seq is None:
            unmatched[cid] = (hw, reading, en, tier)
        else:
            mapping[cid] = seq
            if tier.startswith('headword-only') or tier.startswith('reading-only'):
                unmatched[cid] = (hw, reading, en, tier + ' (mapped to %s %s)' % (
                    m.cards[seq]['headword'], m.cards[seq]['reading']))

    for row in old.execute(curated_sql.replace('c.card_type <> ?', 'c.card_id IN (%s)' % ','.join(
            str(i) for i in sorted(keep_verbatim)) if keep_verbatim else '0')):
        curated.append(dict(zip(keys, row)))
    curated.sort(key=lambda c: c['card_id'])
    with open(os.path.join(HERE, 'data', 'curated_cards.jsonl'), 'w', encoding='utf-8') as fo:
        for c in curated:
            fo.write(json.dumps(c, ensure_ascii=False) + '\n')

    # 3. system set membership
    links = set()
    per_tag = collections.defaultdict(lambda: [0, 0, 0])  # old, new, unmatched
    unmatched_rows = []
    for tag_id, cid in old.execute('SELECT tag_id, card_id FROM system_card_tag_link ORDER BY tag_id, card_id'):
        per_tag[tag_id][0] += 1
        new = mapping.get(cid)
        if new is None:
            per_tag[tag_id][2] += 1
            hw, reading, en, tier = unmatched[cid]
            unmatched_rows.append((tag_id, tagnames.get(tag_id, ''), cid, hw, reading, en, tier))
        else:
            links.add((tag_id, new))
    for tag_id, new in links:
        per_tag[tag_id][1] += 1
    with open(os.path.join(HERE, 'data', 'system_sets.tsv'), 'w', encoding='utf-8') as fo:
        fo.write('# tag_id\tcard_id  (card_id = JMdict ent_seq, or a curated card_id < 1000000)\n')
        for tag_id, new in sorted(links):
            fo.write('%d\t%d\n' % (tag_id, new))

    # 4. user DB templates, in place
    user_report = []
    for udb, (ctl, last) in user_links.items():
        u = sqlite3.connect(udb)
        dropped = [(t, c) for t, c in ctl if c not in mapping]
        u.execute('DELETE FROM card_tag_link')
        u.executemany('INSERT INTO card_tag_link (tag_id, card_id) VALUES (?, ?)',
                      sorted({(t, mapping[c]) for t, c in ctl if c in mapping}))
        for (cid,) in last:
            if cid in mapping:
                u.execute('UPDATE last_state SET card_id = ? WHERE card_id = ?', (mapping[cid], cid))
        u.commit()
        u.close()
        user_report.append((os.path.basename(udb), len(ctl), len(dropped), dropped))
        for t, c in dropped:
            hw, reading, en, tier = unmatched[c]
            unmatched_rows.append((t, tagnames.get(t, '') + ' [%s card_tag_link]' % os.path.basename(udb),
                                   c, hw, reading, en, tier))

    # headword-only matches are mapped but worth eyeballing
    for cid, (hw, reading, en, tier) in sorted(unmatched.items()):
        if tier.startswith('headword-only') or tier.startswith('reading-only'):
            for (tag_id,) in old.execute('SELECT tag_id FROM system_card_tag_link WHERE card_id = ?', (cid,)):
                unmatched_rows.append((tag_id, tagnames.get(tag_id, ''), cid, hw, reading, en, tier))

    with open(os.path.join(HERE, 'reports', 'legacy_unmatched.tsv'), 'w', encoding='utf-8') as fo:
        fo.write('tag_id\ttag_name\told_card_id\theadword\treading\theadword_en\tresult\n')
        for r in sorted(unmatched_rows, key=lambda r: (r[0], r[2])):
            fo.write('\t'.join(str(x) for x in r) + '\n')

    hard = [r for r in unmatched_rows if not (r[6].startswith('headword-only') or r[6].startswith('reading-only'))]
    with open(os.path.join(HERE, 'reports', 'legacy_match.md'), 'w', encoding='utf-8') as fo:
        fo.write('# Legacy (1.1) -> JMdict card mapping\n\n')
        fo.write('Legacy cards referenced by built-in sets or user DB templates: %d\n\n' % len(used))
        fo.write('| match tier | cards |\n|---|---|\n')
        for k, v in tiers.most_common():
            fo.write('| %s | %d |\n' % (k, v))
        fo.write('\nSystem set links: %d legacy -> %d re-mapped (after de-duplication), '
                 '%d memberships dropped (no match)\n\n' % (
                     sum(v[0] for v in per_tag.values()), len(links), sum(v[2] for v in per_tag.values())))
        fo.write('| tag_id | set | legacy | new | dropped |\n|---|---|---|---|---|\n')
        for tag_id in sorted(per_tag):
            o, n, d = per_tag[tag_id]
            fo.write('| %d | %s | %d | %d | %d |\n' % (tag_id, tagnames.get(tag_id, ''), o, n, d))
        for name, total, ndrop, _ in user_report:
            fo.write('\n%s card_tag_link: %d rows, %d dropped\n' % (name, total, ndrop))
        fo.write('\nUnmatched memberships (dropped): %d; headword-only / reading-only matches (kept, review): %d.\n'
                 'Details: reports/legacy_unmatched.tsv\n' % (len(hard), len(unmatched_rows) - len(hard)))
    print(open(os.path.join(HERE, 'reports', 'legacy_match.md'), encoding='utf-8').read())


if __name__ == '__main__':
    main()
