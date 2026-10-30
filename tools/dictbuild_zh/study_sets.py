"""Built-in cFlash study sets.

Membership lives in data/system_sets.tsv (tag_id, card_id), in the order of
the 2011 link table. A link whose card is gone is remapped before it is
dropped: first to that entry's variant / see target, then to the card with
the same simplified characters and pinyin (case and ü ignored), then to the
same traditional + simplified when that is unique or the pinyin is clearly
closer, then to the same traditional + pinyin. A link is dropped only when
nothing matches, or the replacement is already in the set. tags.count in
the user template is rewritten from the links that remain.

A later PR can drop data/hsk30_sets.tsv beside it (same two columns). Those
rows are appended. Removing the HSK 2.0 sets is deleting their rows from
system_sets.tsv and the matching tag rows; this module does not do that.

ptag (the search rank) is 1 for a card in any set the 2011 importer flagged
contains_priority_words: HSK, TOCFL, the Jun Da character lists, and the
news/fiction bigram lists. Add a new HSK 3.0 tag id to PRIORITY_TAG_IDS when
that set should rank the same way.
"""

import os
import re

import cedict

HERE = os.path.dirname(os.path.abspath(__file__))
SETS_PATH = os.path.join(HERE, 'data', 'system_sets.tsv')
# Same columns as SETS_PATH. Absent until the HSK 3.0 PR adds it.
HSK30_SETS_PATH = os.path.join(HERE, 'data', 'hsk30_sets.tsv')

# importer/config/tags_config/{hsk,file_800,frequency,frequency_bigram,
# bigram_fict,bigram_news}_config.yml all set contains_priority_words.
PRIORITY_TAG_IDS = frozenset(
    list(range(105, 152)) +  # Common Hànzì, fiction bigrams, news bigrams
    list(range(152, 158)) +  # HSK 2.0 levels 1-6
    list(range(170, 173))    # TOCFL
)


def link_paths():
    paths = [SETS_PATH]
    if os.path.exists(HSK30_SETS_PATH):
        paths.append(HSK30_SETS_PATH)
    return paths


def load_links(paths=None):
    """(tag_id, card_id) in file order. Blank lines and # comments are skipped."""
    rows = []
    for path in (paths if paths is not None else link_paths()):
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8') as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                tag_id, card_id = line.split('\t')
                rows.append((int(tag_id), int(card_id)))
    return rows


def write_links(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    body = ['# tag_id<TAB>card_id, study order. HSK 3.0 membership is data/hsk30_sets.tsv.']
    body.extend('%d\t%d' % row for row in rows)
    text = '\n'.join(body) + '\n'
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(text)


def kept_links(rows, card_ids):
    """Drop links to cards that are not in this dictionary. Order is kept.

    Prefer resolve_links, which remaps a missing card before dropping it.
    """
    kept, _records = resolve_links(rows, card_ids, {})
    return kept


def loose_pinyin(reading):
    return (reading or '').replace('ü', 'v').replace('Ü', 'v').lower()


def index_replacements(legacy_of, cards, redirects):
    """legacy_of: {old card_id: (trad, simp, pinyin)}.

    Returns {old card_id: (new card_id, how)} for ids that have a live card
    to stand in for them. how is 'redirect', 'simp+pinyin', 'trad+simp', or
    'trad+pinyin'.
    """
    by_key = {}
    by_chars = {}
    for entry in redirects:
        if entry.include or not (entry.variant_target or entry.refs):
            continue
        by_key.setdefault((entry.trad, entry.simp, entry.pinyin), []).append(entry)
        by_chars.setdefault((entry.trad, entry.simp), []).append(entry)
    simp_py = {}
    trad_simp = {}
    trad_py = {}
    simp_cards = {}
    for card in cards:
        simp_py.setdefault((card.simp, loose_pinyin(card.pinyin)), []).append(card)
        trad_simp.setdefault((card.trad, card.simp), []).append(card)
        trad_py.setdefault((card.trad, loose_pinyin(card.pinyin)), []).append(card)
        simp_cards.setdefault(card.simp, []).append(card)

    out = {}
    for old_id, (trad, simp, py) in legacy_of.items():
        hit, how = _replacement(
            trad, simp, py, by_key, by_chars, simp_py, trad_simp, trad_py, simp_cards, cards)
        if hit is not None:
            out[old_id] = (hit, how)
    return out


def _unique(cards):
    found = {}
    for card in cards:
        found[card.card_id] = card
    return list(found.values())


def _replacement(trad, simp, py, by_key, by_chars, simp_py, trad_simp, trad_py, simp_cards, cards):
    redirect = _matching_redirect(trad, simp, py, by_key, by_chars)
    if redirect is not None:
        target = redirect.variant_target or (redirect.refs[0] if redirect.refs else None)
        hit = cedict.card_for_reference(target, cards)
        if hit is not None and _prefer_redirect(simp, hit, simp_cards):
            return hit.card_id, 'redirect'
    same = _unique(simp_py.get((simp, loose_pinyin(py)), []))
    if len(same) == 1:
        return same[0].card_id, 'simp+pinyin'
    chars = _unique(trad_simp.get((trad, simp), []))
    if len(chars) == 1:
        return chars[0].card_id, 'trad+simp'
    if len(chars) > 1:
        closest = _closest_pinyin(py, chars)
        if closest is not None:
            return closest.card_id, 'trad+simp'
    trad_same = _unique(trad_py.get((trad, loose_pinyin(py)), []))
    if len(trad_same) == 1:
        return trad_same[0].card_id, 'trad+pinyin'
    return None, None


def _matching_redirect(trad, simp, py, by_key, by_chars):
    exact = by_key.get((trad, simp, py), [])
    if len(exact) == 1:
        return exact[0]
    same = by_chars.get((trad, simp), [])
    loose = [entry for entry in same if loose_pinyin(entry.pinyin) == loose_pinyin(py)]
    if len(loose) == 1:
        return loose[0]
    if len(same) == 1:
        return same[0]
    return None


def _prefer_redirect(old_simp, hit, simp_cards):
    """Use the see/variant card unless it is a different word and the old
    simplified headword still has a card of its own (与 yu2 points at 欤,
    but 与 yu3 is the word the set should keep). A longer place name
    (广东 → 广东省) is still the see target.
    """
    if hit.simp == old_simp or (hit.simp or '').startswith(old_simp):
        return True
    return old_simp not in simp_cards


def _closest_pinyin(old, cards):
    """The one card whose pinyin is strictly closer to old, if there is one."""
    def distance(card):
        left, right = old.split(' '), card.pinyin.split(' ')
        if len(left) != len(right):
            return 100
        score = 0
        for a, b in zip(left, right):
            ma = re.match(r'(.+?)([1-5])$', a)
            mb = re.match(r'(.+?)([1-5])$', b)
            if not ma or not mb:
                score += 0 if loose_pinyin(a) == loose_pinyin(b) else 10
                continue
            if loose_pinyin(ma.group(1)) != loose_pinyin(mb.group(1)):
                score += 10
            else:
                score += abs(int(ma.group(2)) - int(mb.group(2)))
            if a[:1].isupper() != b[:1].isupper():
                score += 0.1
        return score
    ranked = sorted(cards, key=distance)
    if distance(ranked[0]) < distance(ranked[1]):
        return ranked[0]
    return None


def resolve_links(rows, live_ids, replacement):
    """rows are (tag_id, card_id) in study order.

    live_ids: card ids in this dictionary.
    replacement: {missing card_id: new card_id}.

    Returns (kept rows, records). A record is
    (tag_id, old_id, action, new_id) with action 'kept', 'remapped', or
    'dropped'. Dropped new_id is the duplicate that was already in the set,
    or None when nothing matched. Order of kept rows is the input order.
    """
    seen = {}
    kept = []
    records = []
    for tag_id, card_id in rows:
        chosen = card_id if card_id in live_ids else replacement.get(card_id)
        action = 'kept' if card_id in live_ids else ('remapped' if chosen is not None else 'dropped')
        if chosen is None or chosen in seen.get(tag_id, ()):
            # chosen is None when nothing matched. When it is set, this row
            # repeated a card already placed in the set (a remap or the card itself).
            records.append((tag_id, card_id, 'dropped', chosen))
            continue
        if action == 'remapped':
            records.append((tag_id, card_id, 'remapped', chosen))
        seen.setdefault(tag_id, set()).add(chosen)
        kept.append((tag_id, chosen))
    return kept, records


def refresh_user_counts(connection, system_links):
    """Rewrite tags.count from system links (built-in sets) or card_tag_link
    (editable sets, including My Starred Words and Long Weekend Favorites).

    Returns how many tag rows changed. The caller commits only then, so a
    second build leaves the template byte-identical.
    """
    import collections
    system = collections.Counter(tag_id for tag_id, _card_id in system_links)
    user = collections.Counter(tag_id for (tag_id,) in connection.execute('SELECT tag_id FROM card_tag_link'))
    changed = 0
    for tag_id, editable, count in connection.execute('SELECT tag_id, editable, count FROM tags'):
        fresh = user[tag_id] if (editable or tag_id == 0) else system[tag_id]
        if fresh != count:
            connection.execute('UPDATE tags SET count = ? WHERE tag_id = ?', (fresh, tag_id))
            changed += 1
    return changed
