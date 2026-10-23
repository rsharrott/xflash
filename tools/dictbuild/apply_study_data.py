#!/usr/bin/env python3
"""Apply the study-set cleanup and the romaji policy to the bundled databases.

build.py cannot be re-run for this change: sources.lock.json pins a JMdict
release that EDRDG has already replaced, and sources/ is not in the repo.
The same functions build.py calls (romaji_policy, study_sets.ensure_user_catalog)
are applied here onto the databases that release already produced.  A later
locked rebuild runs the same romaji policy while it writes the cards.

Does not touch the example-sentence database.
"""

import hashlib
import json
import os
import sqlite3
import sys

import jmdict
import romaji_policy
import study_sets

HERE = os.path.dirname(os.path.abspath(__file__))
VULG_PATH = os.path.join(HERE, 'data', 'sense1_vulg_x.txt')
JMDICT_FOR_FLAGS = os.environ.get('JMDICT_FOR_FLAGS', '/tmp/JMdict_e.gz')

# The sense-1 vulg/X list is not the locked 2026-10-18 JMdict (that file is gone
# from the upstream URL).  It is this later daily file.  A mismatch or a missing
# file refuses the whole run before any database is opened.
JMDICT_SHA256 = '91037607250dcc60b0f0723d229d77553d8be512a3d0ab152e4760bc1a418120'
JMDICT_CREATED = '2026-10-22'


def jmdict_pin_error(path):
    """None when path is the pinned JMdict, otherwise a message.

    Does not open the card databases.  main() exits on a message before it
    patches anything.
    """
    if not path or not os.path.isfile(path):
        return ('JMdict file is missing (%s). Expected sha256 %s (%s). '
                'Refusing to patch databases.' % (path, JMDICT_SHA256, JMDICT_CREATED))
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    got = digest.hexdigest()
    if got != JMDICT_SHA256:
        return ('JMdict sha256 %s does not match pinned %s. '
                'Refusing to patch databases.' % (got, JMDICT_SHA256))
    created, _ = jmdict.read_header(path)
    if created != JMDICT_CREATED:
        return ('JMdict created date %s does not match pinned %s. '
                'Refusing to patch databases.' % (created, JMDICT_CREATED))
    return None

# Curated cards whose English is wrong.  The full-width digit and the typo are
# not JMdict glosses; they were typed into the 1.x phrase/word cards.
MEANING_FIXES = {
    145704: {
        'meaning': ('twenty-eigth', 'twenty-eighth'),
        'content': ('twenty-eigth', 'twenty-eighth'),
    },
    150089: {
        'headword_en': ('１ person', '1 person'),
        'meaning': ('１ person', '1 person'),
        'content': ('１ person', '1 person'),
    },
}


def write_vulg_list(path=VULG_PATH, jmdict_path=JMDICT_FOR_FLAGS):
    """Sense-1 misc flags vulg and X, one ent_seq per line.

    The bundled cards were built from the locked 2026-10-18 JMdict.  That file
    is no longer at the upstream URL, so the flags come from a later daily
    file.  ent_seq does not move when a sense's misc flag is unchanged.
    """
    pin_error = jmdict_pin_error(jmdict_path)
    if pin_error:
        raise SystemExit(pin_error)
    created, _ = jmdict.read_header(jmdict_path)
    ids = []
    for entry in jmdict.iter_entries(jmdict_path):
        senses = entry['s']
        if not senses:
            continue
        misc = set(senses[0]['misc'])
        if 'vulg' in misc or 'X' in misc:
            ids.append(entry['seq'])
    ids.sort()
    with open(path, 'w', encoding='utf-8') as f:
        f.write('# ent_seq whose sense 1 is marked vulg or X in JMdict_e %s\n' % created)
        f.write('# sha256 %s\n' % JMDICT_SHA256)
        f.write('# Used to check that starter sets do not include those cards.\n')
        for seq in ids:
            f.write('%d\n' % seq)
    return created, ids


def load_cards(card_db, fts_db):
    card = sqlite3.connect(card_db)
    card.row_factory = sqlite3.Row
    fts = sqlite3.connect(fts_db)
    meanings = dict(card.execute('SELECT card_id, meaning FROM cards_html'))
    contents = {cid: (content, ptag) for cid, content, ptag in fts.execute(
        'SELECT card_id, content, ptag FROM cards_search_content')}
    cards = []
    for row in card.execute(
            'SELECT card_id, card_type, headword, headword_en, reading, romaji FROM cards'):
        cid = row['card_id']
        content, ptag = contents.get(cid, (None, 0))
        cards.append({
            'card_id': cid,
            'card_type': row['card_type'],
            'headword': row['headword'],
            'headword_en': row['headword_en'],
            'reading': row['reading'],
            'romaji': row['romaji'],
            'meaning': meanings.get(cid, ''),
            'content': content,
            'ptag': ptag,
        })
    card.close()
    fts.close()
    return cards


def apply_romaji(card_db, fts_db, curated_path):
    cards = load_cards(card_db, fts_db)
    lex = romaji_policy.build_lexicon(cards)
    romaji_rows = []
    fts_rows = []
    curated_romaji = {}
    # Curated rows whose romaji is already right still need the literal token
    # written into the source file.  _patch_curated used to skip them.
    curated_content = set()
    bracket_misses = []
    statuses = {'unchanged': 0, 'adjusted': 0, 'left-alone': 0}
    wa_cards = 0
    o_or_space = 0
    for card in cards:
        new, status = romaji_policy.romaji_for_card(card, lex)
        statuses[status] += 1
        old = card['romaji'] or ''
        # Left-alone cards are hand-tuned.  Everything else keeps the literal
        # ha/wo spelling as an extra FTS token when the policy changed it.
        literal = None
        if status != 'left-alone':
            literal = romaji_policy.mechanical_romaji(card['reading'] or '')
        if card['content']:
            rebuilt = romaji_policy.rebuild_search_bracket(
                card['content'], card['reading'] or '', new, literal)
            if rebuilt is None:
                # Hand-tuned brackets (十時十五分, 退院する) do not match the
                # reading.  Leave them.  Only report a miss when the romaji
                # itself changed and the search row could not follow.
                if new != old:
                    bracket_misses.append(card['card_id'])
            elif rebuilt != card['content']:
                fts_rows.append((rebuilt, card['card_id']))
                if card['card_id'] < 1000000 and new == old:
                    curated_content.add(card['card_id'])
        if new == old:
            continue
        if new.count('wa') > old.count('wa'):
            wa_cards += 1
        else:
            o_or_space += 1
        romaji_rows.append((new, card['card_id']))
        if card['card_id'] < 1000000:
            curated_romaji[card['card_id']] = new
    card = sqlite3.connect(card_db)
    card.executemany('UPDATE cards SET romaji = ? WHERE card_id = ?', romaji_rows)
    card.commit()
    card.close()
    fts = sqlite3.connect(fts_db)
    fts.executemany('UPDATE cards_search_content SET content = ? WHERE card_id = ?', fts_rows)
    fts.commit()
    fts.close()
    _patch_curated(curated_path, curated_romaji, {}, curated_content)
    return {
        'statuses': statuses,
        'romaji_rows': len(romaji_rows),
        'fts_rows': len(fts_rows),
        'bracket_misses': bracket_misses,
        'cards_with_new_wa': wa_cards,
        'cards_with_o_or_space_only': o_or_space,
        'lexical_fragments': len(lex.lexical),
        'lexicon': len(lex),
    }


def _patch_curated(path, romaji_by_id, extra_by_id, content_ids=None):
    """Rewrite curated lines whose romaji or search bracket changed.

    Other lines are copied through so the file does not get a wholesale reformat.
    content_ids are cards whose romaji is already current but whose bracket is
    missing the literal ha/wo token.
    """
    if content_ids is None:
        content_ids = set()
    out = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            if not line.strip():
                out.append(line)
                continue
            card = json.loads(line)
            cid = card['card_id']
            if cid not in romaji_by_id and cid not in extra_by_id and cid not in content_ids:
                out.append(line if line.endswith('\n') else line + '\n')
                continue
            if cid in romaji_by_id or cid in content_ids:
                new = romaji_by_id.get(cid, card.get('romaji') or '')
                content = card.get('content')
                if content:
                    rebuilt = romaji_policy.rebuild_search_bracket(
                        content, card.get('reading') or '', new,
                        romaji_policy.mechanical_romaji(card.get('reading') or ''))
                    if rebuilt is not None:
                        card['content'] = rebuilt
                if cid in romaji_by_id:
                    card['romaji'] = new
            for field, pair in extra_by_id.get(cid, {}).items():
                old, new = pair
                if field in card and isinstance(card[field], str):
                    card[field] = card[field].replace(old, new)
            out.append(json.dumps(card, ensure_ascii=False) + '\n')
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(out)


def apply_meaning_fixes(card_db, fts_db, curated_path):
    card = sqlite3.connect(card_db)
    fts = sqlite3.connect(fts_db)
    changed = []
    for cid, fields in MEANING_FIXES.items():
        if 'meaning' in fields:
            old, new = fields['meaning']
            card.execute(
                'UPDATE cards_html SET meaning = replace(meaning, ?, ?) WHERE card_id = ?',
                (old, new, cid))
        if 'headword_en' in fields:
            old, new = fields['headword_en']
            card.execute(
                'UPDATE cards SET headword_en = replace(headword_en, ?, ?) WHERE card_id = ?',
                (old, new, cid))
        if 'content' in fields:
            old, new = fields['content']
            fts.execute(
                'UPDATE cards_search_content SET content = replace(content, ?, ?) WHERE card_id = ?',
                (old, new, cid))
        changed.append(cid)
    card.commit()
    fts.commit()
    card.close()
    fts.close()
    # Substring replace on the raw jsonl line so the rest of the line stays put
    # when romaji did not already rewrite it.  apply_romaji runs first and may
    # have re-dumped the line; replace still finds the typo.
    with open(curated_path, encoding='utf-8') as f:
        text = f.read()
    for fields in MEANING_FIXES.values():
        for old, new in fields.values():
            text = text.replace(old, new)
    with open(curated_path, 'w', encoding='utf-8') as f:
        f.write(text)
    return changed


def _write_public_catalog(catalog):
    """Names and counts only.  Card ids stay in the TSV."""
    public = {
        'parent_group_id': catalog['parent_group_id'],
        'parent_group_name': catalog['parent_group_name'],
        'groups': [{
            'group_id': g['group_id'],
            'group_name': g['group_name'],
            'sets': [{k: s[k] for k in ('tag_id', 'name', 'description', 'count')}
                     for s in g['sets']],
        } for g in catalog['groups']],
    }
    with open(study_sets.CATALOG_PATH, 'w', encoding='utf-8') as f:
        json.dump(public, f, ensure_ascii=False, indent=2)
        f.write('\n')


def _write_tsv(members, order):
    header = open(study_sets.TSV_PATH, encoding='utf-8').readline()
    if not header.startswith('#'):
        header = '# tag_id\tcard_id  (card_id = JMdict ent_seq, or a curated card_id < 1000000)\n'
    text = study_sets.render_tsv(members, order, header if header.endswith('\n') else header + '\n')
    with open(study_sets.TSV_PATH, 'w', encoding='utf-8') as f:
        f.write(text)


def apply_sets():
    """Refresh study-set membership from the TSV and the level catalog.

    main() checks the JMdict pin and exits before it calls this.  A later
    build.py reads the TSV and vocabulary_levels.json this writes, including
    each level's combined set.
    """
    members, order = study_sets.load_tsv()
    legacy = study_sets.is_legacy(members)
    new_members, new_order, catalog = study_sets.rewrite_members(members, order)
    if catalog is None:
        catalog = study_sets.load_catalog()
    else:
        members, order = new_members, new_order
    changed, written_tags = study_sets.ensure_combined_membership(members, catalog)
    wrote = legacy or changed
    if wrote:
        _write_tsv(members, order)
        _write_public_catalog(catalog)
    card = sqlite3.connect(study_sets.CARD_DB)
    if legacy:
        # The old nested lists were replaced.  Every system link is rewritten.
        nlinks = study_sets.replace_system_links(card, members)
    elif written_tags:
        nlinks = study_sets.upsert_tag_links(card, members, written_tags)
    else:
        nlinks = card.execute('SELECT count(*) FROM system_card_tag_link').fetchone()[0]
    user = sqlite3.connect(study_sets.USER_DB)
    study_sets.ensure_user_catalog(user, catalog)
    # ensure_user_catalog counts the level sets from the catalog.  Refresh every
    # system tag from the link tables so a hidden tag's count stays correct too.
    counts_updated = study_sets.refresh_system_counts(user, card)
    card.close()
    user.close()
    return {
        'legacy_split': legacy and wrote,
        'combined_tags': written_tags,
        'tsv_links': nlinks,
        'counts_updated': counts_updated,
    }


def finish_patched(path, optimize_fts=False):
    """ANALYZE + VACUUM, and an FTS optimize when the search index was rewritten.

    A raw UPDATE of every changed FTS row leaves the index about 20 MB larger
    than a rebuild.  optimize packs it back down before VACUUM.
    """
    db = sqlite3.connect(path)
    if optimize_fts:
        db.execute("INSERT INTO cards_search_content(cards_search_content) VALUES('optimize')")
        db.commit()
    db.execute('ANALYZE')
    db.commit()
    db.execute('VACUUM')
    db.close()


def main():
    pin_error = jmdict_pin_error(JMDICT_FOR_FLAGS)
    if pin_error:
        sys.exit(pin_error)
    print('romaji...', file=sys.stderr)
    romaji_report = apply_romaji(study_sets.CARD_DB, study_sets.FTS_DB, study_sets.CURATED_PATH)
    print(romaji_report, file=sys.stderr)
    print('meanings...', file=sys.stderr)
    meanings = apply_meaning_fixes(study_sets.CARD_DB, study_sets.FTS_DB, study_sets.CURATED_PATH)
    print('sets...', file=sys.stderr)
    sets_report = apply_sets()
    print('vulg flags...', file=sys.stderr)
    created, vulg_ids = write_vulg_list()
    print('vacuum...', file=sys.stderr)
    finish_patched(study_sets.CARD_DB)
    finish_patched(study_sets.FTS_DB, optimize_fts=True)
    finish_patched(study_sets.USER_DB)
    report = {
        'romaji': romaji_report,
        'meaning_cards': meanings,
        'sets': sets_report,
        'vulg_x_source': created,
        'vulg_x_sha256': JMDICT_SHA256,
        'vulg_x_cards': len(vulg_ids),
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
