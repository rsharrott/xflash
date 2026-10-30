"""Stable card ids for cFlash.

The map is keyed on (traditional, simplified, pinyin) and is the source of
truth after the first build. The first build copies ids out of the 2011
dictionary:

1. exact (traditional, simplified, pinyin)
2. same characters, pinyin changed, only when that pair is one old card and
   one new card
3. same simplified + pinyin, traditional changed, same one-to-one rule
4. same traditional + pinyin, simplified changed, same one-to-one rule

Anything else new gets an id at or above NEW_ID_START, in CEDICT file order.
Ids already handed out are never reused, so a later refresh and any set link
that points at an id stay put. HSK 3.0 and Tatoeba can link these ids.
"""

import os

NEW_ID_START = 1000000


def load_map(path):
    """Return {(trad, simp, pinyin): card_id} or {} if path is missing."""
    if not path or not os.path.exists(path):
        return {}
    out = {}
    with open(path, encoding='utf-8') as handle:
        for line in handle:
            line = line.strip('\n')
            if not line or line.startswith('#'):
                continue
            if line.startswith('card_id\t'):
                continue
            card_id, trad, simp, pinyin = line.split('\t', 3)
            out[(trad, simp, pinyin)] = int(card_id)
    return out


def write_map(path, mapping):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rows = sorted(((cid, trad, simp, py) for (trad, simp, py), cid in mapping.items()),
                  key=lambda row: (row[0], row[1], row[2], row[3]))
    body = ['card_id\ttraditional\tsimplified\tpinyin']
    body.extend('%d\t%s\t%s\t%s' % row for row in rows)
    text = '\n'.join(body) + '\n'
    # Skip the write when the bytes already match, so a rebuild does not
    # touch the committed map.
    if os.path.exists(path):
        with open(path, encoding='utf-8') as handle:
            if handle.read() == text:
                return False
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(text)
    return True


def assign_ids(entries, legacy_rows, existing_map):
    """Set entry.card_id. entries are in CEDICT file order and already have
    trad, simp, pinyin. legacy_rows is an iterable of (card_id, trad, simp,
    pinyin) from the 2011 database, or empty when existing_map is in use.

    Returns a stats dict. Mutates entries and, when assigning new ids,
    existing_map (the caller writes it back).
    """
    _reject_duplicate_keys(entries)
    stats = {
        'exact': 0,
        'pinyin_changed': 0,
        'traditional_changed': 0,
        'simplified_changed': 0,
        'from_map': 0,
        'new': 0,
        'legacy': 0,
        'legacy_reused': 0,
        'legacy_dropped': 0,
        'ambiguous_same_chars': 0,
    }
    if existing_map:
        _assign_from_map(entries, existing_map, stats)
        return stats

    by_key = {}
    for card_id, trad, simp, pinyin in legacy_rows:
        by_key[(trad, simp, pinyin)] = card_id
    stats['legacy'] = len(by_key)
    claimed = set()

    for entry in entries:
        card_id = by_key.get((entry.trad, entry.simp, entry.pinyin))
        if card_id is not None and card_id not in claimed:
            entry.card_id = card_id
            claimed.add(card_id)
            stats['exact'] += 1

    stats['pinyin_changed'] = _claim_unique(
        entries, by_key, claimed, lambda e: (e.trad, e.simp), lambda t, s, p: (t, s))
    # Same-character pairs that still have more than one unmatched card on
    # either side are left alone (行 xing2 / hang2 must not be swapped).
    stats['ambiguous_same_chars'] = _count_ambiguous(
        entries, by_key, claimed, lambda e: (e.trad, e.simp), lambda t, s, p: (t, s))
    stats['traditional_changed'] = _claim_unique(
        entries, by_key, claimed, lambda e: (e.simp, e.pinyin), lambda t, s, p: (s, p))
    stats['simplified_changed'] = _claim_unique(
        entries, by_key, claimed, lambda e: (e.trad, e.pinyin), lambda t, s, p: (t, p))

    next_id = NEW_ID_START
    for entry in entries:
        if entry.card_id is not None:
            continue
        while next_id in claimed:
            next_id += 1
        entry.card_id = next_id
        claimed.add(next_id)
        next_id += 1
        stats['new'] += 1

    # Current keys, then leftover 2011 keys whose ids were not reused. A word
    # that leaves CEDICT and comes back keeps its id. A pinyin change keeps
    # the id on the new spelling and does not also reserve the old spelling.
    for entry in entries:
        existing_map[(entry.trad, entry.simp, entry.pinyin)] = entry.card_id
    for key, card_id in by_key.items():
        if card_id not in claimed and key not in existing_map:
            existing_map[key] = card_id
    stats['legacy_reused'] = stats['exact'] + stats['pinyin_changed'] + stats['traditional_changed'] + stats['simplified_changed']
    stats['legacy_dropped'] = stats['legacy'] - stats['legacy_reused']
    _reject_duplicate_ids(entries)
    return stats


def _assign_from_map(entries, existing_map, stats):
    used = set(existing_map.values())
    next_id = NEW_ID_START
    if used:
        next_id = max(NEW_ID_START, max(used) + 1)
    for entry in entries:
        key = (entry.trad, entry.simp, entry.pinyin)
        card_id = existing_map.get(key)
        if card_id is not None:
            entry.card_id = card_id
            stats['from_map'] += 1
            continue
        while next_id in used:
            next_id += 1
        entry.card_id = next_id
        existing_map[key] = next_id
        used.add(next_id)
        next_id += 1
        stats['new'] += 1
    _reject_duplicate_ids(entries)


def _claim_unique(entries, by_key, claimed, new_key, old_key):
    grouped = {}
    for entry in entries:
        if entry.card_id is not None:
            continue
        grouped.setdefault(new_key(entry), []).append(entry)
    old_grouped = {}
    for (trad, simp, pinyin), card_id in by_key.items():
        if card_id in claimed:
            continue
        old_grouped.setdefault(old_key(trad, simp, pinyin), []).append(card_id)
    taken = 0
    for key, group in grouped.items():
        olds = old_grouped.get(key, [])
        if len(group) == 1 and len(olds) == 1:
            group[0].card_id = olds[0]
            claimed.add(olds[0])
            taken += 1
    return taken


def _count_ambiguous(entries, by_key, claimed, new_key, old_key):
    grouped = {}
    for entry in entries:
        if entry.card_id is not None:
            continue
        grouped.setdefault(new_key(entry), []).append(entry)
    old_grouped = {}
    for (trad, simp, pinyin), card_id in by_key.items():
        if card_id in claimed:
            continue
        old_grouped.setdefault(old_key(trad, simp, pinyin), []).append(card_id)
    count = 0
    for key, group in grouped.items():
        olds = old_grouped.get(key, [])
        if olds and not (len(group) == 1 and len(olds) == 1):
            count += len(group)
    return count


def _reject_duplicate_keys(entries):
    seen = set()
    for entry in entries:
        key = (entry.trad, entry.simp, entry.pinyin)
        if key in seen:
            raise SystemExit('duplicate CEDICT key %s / %s [%s]' % key)
        seen.add(key)


def _reject_duplicate_ids(entries):
    seen = {}
    for entry in entries:
        previous = seen.get(entry.card_id)
        if previous is not None:
            raise SystemExit('card_id %s assigned twice: %s and %s' % (
                entry.card_id, previous, (entry.trad, entry.simp, entry.pinyin)))
        seen[entry.card_id] = (entry.trad, entry.simp, entry.pinyin)
        if entry.card_id is None:
            raise SystemExit('entry left without a card_id: %s' % (entry.trad,))
