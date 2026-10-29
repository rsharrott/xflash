"""Built-in study-set cleanup for Japanese in a Flash!.

The old tags 92-95 are the pre-2010 four-level community lists, and each level
contains every easier level.  This module splits them into non-overlapping
approximate levels and chunks of 50-100 cards, and it records the browse-list
edits (hidden sets, group fixes, renamed kana, text fixes) so they can be
reapplied to the user-DB template.  Each level also has one combined set, the
union of that level's chunks, so a learner can review the whole level.

Card membership lives in data/system_sets.tsv.  Names and groups live in
jFlash/sql/jFlash.db.  Common Words, Common Nouns and Core 1000 are cut the
same way as the levels (50–100 cards, plus a Full Set).  The full Nouns list
is not a built-in set.  Japanese names are columns on the tag and group rows,
keyed by id.
A future `build.py` reads the TSV as it stands and calls ensure_user_catalog()
so the template keeps these names.  It does not re-nest the levels.

  python3 study_sets.py          # patch the TSV, the bundled DBs, and the catalog
"""

import json
import os
import sqlite3

import builtin_ja

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
TSV_PATH = os.path.join(HERE, 'data', 'system_sets.tsv')
CATALOG_PATH = os.path.join(HERE, 'data', 'vocabulary_levels.json')
CHUNKED_PATH = os.path.join(HERE, 'data', 'chunked_lists.json')
CORE_PATH = os.path.join(HERE, 'data', 'core1000.tsv')
CARD_DB = os.path.join(REPO, 'jFlash', 'sql', 'jFlash-CARD-2.0.db')
FTS_DB = os.path.join(REPO, 'jFlash', 'sql', 'plugins', 'jFlash-FTS-2.0.db')
USER_DB = os.path.join(REPO, 'jFlash', 'sql', 'jFlash.db')
CURATED_PATH = os.path.join(HERE, 'data', 'curated_cards.jsonl')

# Legacy nested tags.  Each one contains every easier tag.
LEGACY_TAGS = (95, 94, 93, 92)   # L4, L3, L2, L1
ANCHORS = (95, 94, 93, 92)       # first chunk of each new level reuses the old id
NEW_TAG_START = 644
# "Full Set" sorts after "01" ('F' > '0').  The browse query lists it first.
COMBINED_NAME_SUFFIX = ' Full Set'
# The first cut of these sets was named "00 All".  A catalog that still has
# that name is renamed in place, same tag id.
PREVIOUS_COMBINED_SUFFIX = ' 00 All'

PARENT_GROUP = 10
PARENT_NAME = 'Vocabulary Levels'

# Roughly the old community level, labelled as an approximation.  The en dash
# in N3–N2 is U+2013.  A numeric prefix keeps the groups in level order
# (group names sort A–Z).
LEVELS = (
    {
        'key': 'b1',
        'anchor': 95,
        'group_id': 24,
        'group_name': '1. Beginner 1 (≈N5)',
        'set_name': 'Beginner 1 (≈N5)',
        'blurb': (
            'Unofficial beginner list, about the range of JLPT N5.  '
            'Split out of the old pre-2010 community L4 list so it does not '
            'repeat inside the harder lists.  Not a JLPT exam list.'
        ),
    },
    {
        'key': 'b2',
        'anchor': 94,
        'group_id': 25,
        'group_name': '2. Beginner 2 (≈N4)',
        'set_name': 'Beginner 2 (≈N4)',
        'blurb': (
            'Unofficial beginner list, about the range of JLPT N4.  '
            'The old pre-2010 community L3 list with the easier L4 cards '
            'removed.  Not a JLPT exam list.'
        ),
    },
    {
        'key': 'mid',
        'anchor': 93,
        'group_id': 26,
        'group_name': '3. Intermediate (≈N3–N2)',
        'set_name': 'Intermediate (≈N3–N2)',
        'blurb': (
            'Unofficial intermediate list, about the range of JLPT N3 and N2.  '
            'The old pre-2010 community L2 list with the easier cards removed.  '
            'Not a JLPT exam list.'
        ),
    },
    {
        'key': 'adv',
        'anchor': 92,
        'group_id': 27,
        'group_name': '4. Advanced (≈N1)',
        'set_name': 'Advanced (≈N1)',
        'blurb': (
            'Unofficial advanced list, about the range of JLPT N1.  '
            'The old pre-2010 community L1 list with the easier cards removed.  '
            'Not a JLPT exam list.'
        ),
    },
)

# Removed from the browse list.  The cards and the tag rows stay, so a card
# detail can still name them.  There is no separate X-rated tag; tag 161's
# old description said "Rude or X-Rated".
HIDDEN_TAG_IDS = (15, 135, 136, 161, 51, 168)  # Archaic, Obscure, Obsolete, Rude, Derogatory, Sensitive

# Adverb sets that were filed under Verbs as well as Adverbs.  Tag 7 also stays in Nouns.
ADVERBS_OUT_OF_VERBS = (7, 8, 9)
VERBS_GROUP = 1
ADVERBS_GROUP = 3

# Recommended: drop Japanglish, Idiomatic, Slang.  Add beginner sets.
RECOMMENDED_GROUP = 23
RECOMMENDED_REMOVE = (91, 80, 170)
RECOMMENDED_ADD = (200, 208, 73, 95)   # Hiragana Basic, Numbers, Greetings, Beginner 1 set 01

PRONOUNS_TAG = 643
PARTS_OF_SPEECH_GROUP = 8

# Welcome sheet, after the current (default) set.  Hiragana Basic is also the
# default, so that row is skipped when it is already the current set.
STARTER_SETS = ((16, 200), (9, 208), (21, 73), (24, 95))
DEFAULT_TAG_ID = 200

KANA_RENAMES = {
    200: 'Hiragana (1 Basic)',
    202: 'Hiragana (2 Voiced)',
    207: 'Hiragana (3 Compounds)',
    201: 'Hiragana (All)',
    203: 'Katakana (1 Basic)',
    205: 'Katakana (2 Voiced)',
    206: 'Katakana (3 Compounds)',
    204: 'Katakana (All)',
}

# Exact description / name edits.  Applied as substring replacements so a
# second run is a no-op.
TEXT_REPLACEMENTS = (
    ('Intrasitive', 'Intransitive'),
    ('lanugage', 'language'),
    ('Portguese', 'Portuguese'),
    ('oridnal', 'ordinal'),
    ('Idomatic', 'Idiomatic'),
    ('副指摘名詞', '副詞的名詞'),
    ('副名詞', '普通名詞'),
    ('fukumeishi', 'futsuumeishi'),
    ('Rude or X-Rated', 'Rude or impolite'),
)

EXPRESSIONS_TAG = 147
EXPRESSIONS_NAME = 'Expressions (set phrases)'
EXPRESSIONS_DESCRIPTION = 'JMdict expressions (set phrases).  Not a frequency list of common phrases.'

# Tag 133 was the full noun list (and, before that, Nouns plus Nouns 02–13 at
# 620–631).  It is not a built-in set.  A 2.0 install still has those rows;
# the 2.1 migration removes the system ones and points the active set at
# Common Nouns Full Set.  Common Nouns is the common-priority slice.
NOUN_ANCHOR = 133
RETIRED_NOUN_TAGS = tuple(range(620, 632))
COMMON_ANCHOR = 42
COMMON_REUSE = (617, 618)
CHUNKED_ID_START = 721
CORE_GROUP_ID = 28
NOUNS_GROUP_ID = 2
FAVORITES_TAG = 124
FAVORITES_NAME = 'Long Weekend Favorites'

# Same priority signal the card build stores as ptag: news1 / ichi1 / spec1 /
# spec2 / gai1.  It is a common-word mark, not a rank inside the list.
COMMON_NOUN_BLURB = (
    'Nouns from the Nouns list that JMdict marks as common-priority '
    '(news1, ichi1, spec1, spec2, or gai1).  '
    'The mark is not a rank inside the list.'
)
COMMON_BLURB = (
    'Common use word.  '
    'Cards JMdict marks as common-priority are in the earlier sets.'
)
CORE_BLURB = (
    'The first two JMdict frequency bands (nf01 and nf02), about the 1,000 most '
    'frequent words in the Mainichi Shimbun list recorded in JMdict.  '
    'Not a JLPT exam list.'
)
CHUNKED_LISTS = (
    {
        'key': 'common',
        'base_name': 'Common Words',
        'blurb': COMMON_BLURB,
        'anchor': COMMON_ANCHOR,
        'reuse': COMMON_REUSE,
        'group_id': 11,
    },
)


def chunk_sizes(n, lo=50, hi=100):
    """Split n into as few pieces as possible, each between lo and hi.

    Pieces differ by at most one.  A level smaller than hi is one piece, even
    when that piece is under lo (the synthetic tests use tiny levels).
    """
    if n <= 0:
        return []
    if n <= hi:
        return [n]
    sets = (n + hi - 1) // hi
    while n // sets < lo:
        sets += 1
        if sets > n:
            break
    base, extra = divmod(n, sets)
    return [base + 1] * extra + [base] * (sets - extra)


def _sets(members):
    return {tag: set(cards) for tag, cards in members.items()}


def is_legacy(members):
    """True when 92 contains 93 contains 94 contains 95 (the old nesting)."""
    have = _sets(members)
    if any(tag not in have for tag in LEGACY_TAGS):
        return False
    return (have[95] <= have[94] <= have[93] <= have[92]
            and len(have[92]) > len(have[93]))


def unique_levels(members):
    """Card ids for the four non-overlapping levels, card_id order.

    Returns None when the TSV is not the nested legacy lists.
    """
    if not is_legacy(members):
        return None
    have = _sets(members)
    return (
        sorted(have[95]),
        sorted(have[94] - have[95]),
        sorted(have[93] - have[94]),
        sorted(have[92] - have[93]),
    )


def assign_tag_ids(level_lists):
    """(list of card-id lists) -> list of (tag_id, [card_ids]) per level.

    Chunk ids only.  The combined set for each level is assigned later, after
    every chunk, so the chunk ids stay 644 and up in the order they were split.
    """
    next_id = NEW_TAG_START
    assigned = []
    for anchor, cards in zip(ANCHORS, level_lists):
        sizes = chunk_sizes(len(cards))
        ids = [anchor]
        for _ in sizes[1:]:
            ids.append(next_id)
            next_id += 1
        chunks = []
        offset = 0
        for tag_id, size in zip(ids, sizes):
            chunks.append((tag_id, cards[offset:offset + size]))
            offset += size
        assigned.append(chunks)
    return assigned


def is_combined_name(name):
    text = name or ''
    return text.endswith(COMBINED_NAME_SUFFIX) or text.endswith(PREVIOUS_COMBINED_SUFFIX)


def combined_name(set_name):
    return set_name + COMBINED_NAME_SUFFIX


def combined_description(blurb, count, n_chunks):
    """The level blurb already says unofficial and not a JLPT exam list."""
    return '%s  All %d cards in this level (sets 01–%02d together).' % (
        blurb, count, n_chunks)


def combined_tag_ids(assigned):
    """One id per level, after the last chunk id.  Empty levels are not expected."""
    new_ids = [tag for chunks in assigned for tag, _cards in chunks if tag >= NEW_TAG_START]
    start = max(new_ids) + 1 if new_ids else NEW_TAG_START
    return [start + index for index in range(len(assigned))]


def union_card_ids(card_lists):
    """Card ids in card_id order, each card once."""
    seen = set()
    for cards in card_lists:
        seen.update(cards)
    return sorted(seen)


def catalog_from_assignment(assigned):
    """Build the JSON-ready catalog.  assigned is the return of assign_tag_ids.

    The first set in each group is the combined set (every card in the level).
    The name ends in "Full Set".  Browse lists that set first; plain name order
    would put it after the numbered chunks.
    """
    groups = []
    all_ids = combined_tag_ids(assigned)
    for level, chunks, combined_id in zip(LEVELS, assigned, all_ids):
        sets = []
        total = len(chunks)
        for index, (tag_id, cards) in enumerate(chunks, start=1):
            sets.append({
                'tag_id': tag_id,
                'name': '%s %02d' % (level['set_name'], index),
                'description': '%s  Set %02d of %02d.' % (level['blurb'], index, total),
                'count': len(cards),
                'card_ids': list(cards),
            })
        every = union_card_ids(cards for _tag, cards in chunks)
        sets.insert(0, {
            'tag_id': combined_id,
            'name': combined_name(level['set_name']),
            'description': combined_description(level['blurb'], len(every), total),
            'count': len(every),
            'card_ids': every,
        })
        groups.append({
            'group_id': level['group_id'],
            'group_name': level['group_name'],
            'sets': sets,
        })
    return {
        'parent_group_id': PARENT_GROUP,
        'parent_group_name': PARENT_NAME,
        'groups': groups,
    }


def _cards_for_set(members, entry):
    if entry.get('card_ids'):
        return entry['card_ids']
    return members.get(entry['tag_id'], [])


def ensure_combined_membership(members, catalog):
    """Give each vocabulary level a set that is the union of its chunks.

    Chunk ids are left alone.  Combined ids continue after the highest chunk
    id (717–720 for the bundled lists).  Returns (changed, tag_ids whose
    membership was written).  Safe to run twice: the second run changes nothing
    when the unions are already stored.
    """
    changed = False
    written = []
    by_group = {group['group_id']: group for group in catalog['groups']}
    next_id = None
    for level in LEVELS:
        group = by_group[level['group_id']]
        chunks = [s for s in group['sets'] if not is_combined_name(s.get('name'))]
        cards = union_card_ids(_cards_for_set(members, s) for s in chunks)
        combined = next((s for s in group['sets'] if is_combined_name(s.get('name'))), None)
        name = combined_name(level['set_name'])
        description = combined_description(level['blurb'], len(cards), len(chunks))
        if combined is None:
            if next_id is None:
                taken = [s['tag_id'] for g in catalog['groups'] for s in g['sets']]
                taken.extend(tag for tag in members if tag >= NEW_TAG_START)
                next_id = max(taken) + 1 if taken else NEW_TAG_START
            tag_id = next_id
            next_id += 1
            combined = {
                'tag_id': tag_id,
                'name': name,
                'description': description,
                'count': len(cards),
            }
            group['sets'].insert(0, combined)
            changed = True
        else:
            tag_id = combined['tag_id']
            if (combined.get('name') != name or combined.get('description') != description
                    or combined.get('count') != len(cards)):
                combined['name'] = name
                combined['description'] = description
                combined['count'] = len(cards)
                changed = True
        if members.get(tag_id) != cards:
            members[tag_id] = list(cards)
            changed = True
            written.append(tag_id)
    return changed, written


def load_tsv(path=TSV_PATH):
    """tag_id -> [card_id, ...] in file order.  Header lines are not returned."""
    members = {}
    order = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            tag_s, card_s = line.split('\t')
            tag_id, card_id = int(tag_s), int(card_s)
            if tag_id not in members:
                members[tag_id] = []
                order.append(tag_id)
            members[tag_id].append(card_id)
    return members, order


def render_tsv(members, order, header):
    lines = [header]
    seen = set()
    for tag_id in order:
        if tag_id in seen or tag_id not in members:
            continue
        seen.add(tag_id)
        for card_id in members[tag_id]:
            lines.append('%d\t%d\n' % (tag_id, card_id))
    for tag_id in sorted(set(members) - seen):
        for card_id in members[tag_id]:
            lines.append('%d\t%d\n' % (tag_id, card_id))
    return ''.join(lines)


def rewrite_members(members, order):
    """Return (members, order, catalog) with the levels split, or (None, None, catalog)
    loaded from the catalog file when the TSV is already split.
    """
    levels = unique_levels(members)
    if levels is None:
        return None, None, None
    assigned = assign_tag_ids(levels)
    catalog = catalog_from_assignment(assigned)
    new_members = dict(members)
    for tag in LEGACY_TAGS:
        del new_members[tag]
    for group in catalog['groups']:
        for s in group['sets']:
            new_members[s['tag_id']] = list(s['card_ids'])
    # Keep the old tag ids in their original place in the file; new ids go at the end.
    return new_members, order, catalog


def load_catalog(path=CATALOG_PATH):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def catalog_tag_ids(catalog):
    ids = []
    for group in catalog['groups']:
        for s in group['sets']:
            ids.append(s['tag_id'])
    return ids


def _replace_text(value):
    if not value:
        return value
    for old, new in TEXT_REPLACEMENTS:
        value = value.replace(old, new)
    return value


def order_card_ids(card_ids, common_ids):
    """Unique cards, common-priority first, then card_id.

    common_ids is the set of cards whose JMdict priority is the common-word
    mark (the same set stored as ptag).  Cards outside that set keep card_id
    order.  Duplicates across the old continuation tags collapse to one card.
    """
    return sorted(set(card_ids), key=lambda card_id: (card_id not in common_ids, card_id))


def _pad(number, width):
    return '%0*d' % (width, number)


def _chunk_records(base_name, blurb, cards, tag_ids):
    """One Full Set plus numbered chunks.  tag_ids has one id per chunk."""
    width = max(2, len(str(len(tag_ids))))
    total = len(tag_ids)
    sets = []
    offset = 0
    sizes = chunk_sizes(len(cards))
    for index, (tag_id, size) in enumerate(zip(tag_ids, sizes), start=1):
        label = _pad(index, width)
        sets.append({
            'tag_id': tag_id,
            'name': '%s %s' % (base_name, label),
            'description': '%s  Set %s of %s.' % (blurb, label, _pad(total, width)),
            'count': size,
            'card_ids': list(cards[offset:offset + size]),
        })
        offset += size
    sets.insert(0, {
        'tag_id': None,  # filled by the caller once the chunk ids are known
        'name': combined_name(base_name),
        'description': '%s  All %d cards in this list (sets %s–%s together).' % (
            blurb, len(cards), _pad(1, width), _pad(total, width)),
        'count': len(cards),
        'card_ids': list(cards),
    })
    return sets


def _take_ids(anchor, reuse, n_chunks, next_id):
    ids = []
    pool = []
    if anchor is not None:
        pool.append(anchor)
    pool.extend(reuse)
    for slot in range(n_chunks):
        if slot < len(pool):
            ids.append(pool[slot])
        else:
            ids.append(next_id)
            next_id += 1
    return ids, next_id


def needs_oversized_recut(members):
    """True while Common Words is still one of the old ~10,000-card continuation tags."""
    return len(members.get(COMMON_ANCHOR, ())) > 100


def needs_noun_collapse(members):
    """True while Nouns 02–13 are still their own lists.

    That is the 2.0 continuation series.  Common Nouns chunks do not use
    those tag ids.  Tag 133, if it is still in the membership, is dropped
    by collapse_nouns along with them.
    """
    return any(tag in members for tag in RETIRED_NOUN_TAGS)


def _unique_in_order(card_ids):
    seen = set()
    ordered = []
    for card_id in card_ids:
        if card_id in seen:
            continue
        seen.add(card_id)
        ordered.append(card_id)
    return ordered


def _noun_cards_from_members(members):
    """Every noun card.

    The old continuation lists are card_id order inside each tag, so walking
    tag 133 and then 620–631 keeps that study order.  The numbered cut stored
    the same cards on a Full Set and on chunk tags; the Full Set is the union.
    """
    if len(members.get(NOUN_ANCHOR, ())) > 1000:
        cards = []
        for tag in (NOUN_ANCHOR,) + RETIRED_NOUN_TAGS:
            cards.extend(members.get(tag, ()))
        return _unique_in_order(cards)
    chunked = load_chunked()
    if chunked:
        for group in chunked['groups']:
            if group.get('base_name') != 'Nouns':
                continue
            full = [s for s in group['sets'] if is_combined_name(s.get('name'))]
            if full and full[0]['tag_id'] in members:
                return list(members[full[0]['tag_id']])
            cards = []
            for entry in group['sets']:
                cards.extend(members.get(entry['tag_id'], ()))
            return _unique_in_order(cards)
    cards = []
    for tag in (NOUN_ANCHOR,) + RETIRED_NOUN_TAGS:
        cards.extend(members.get(tag, ()))
    return _unique_in_order(cards)


def _noun_tags_to_drop(members):
    """Tag ids that belonged to the full noun list.  Tag 133 goes with them."""
    drop = set(tag for tag in RETIRED_NOUN_TAGS if tag in members)
    if NOUN_ANCHOR in members:
        drop.add(NOUN_ANCHOR)
    chunked = load_chunked()
    if chunked:
        for group in chunked['groups']:
            if group.get('base_name') != 'Nouns':
                continue
            for entry in group['sets']:
                drop.add(entry['tag_id'])
    return sorted(drop)


def collapse_nouns(members, order, common_ids, noun_cards=None):
    """Common Nouns chunks for the common-priority cards.  The full list is dropped.

    Returns (members, order, chunked_catalog, dropped_tag_ids).  Common Words
    and Core 1000 groups already in the chunked catalog are kept.  Safe to
    call only when needs_noun_collapse is true.
    """
    cards = list(noun_cards) if noun_cards is not None else _noun_cards_from_members(members)
    if len(cards) != len(set(cards)):
        raise ValueError('Nouns card list repeats a card id')
    have = set(_noun_cards_from_members(members))
    if set(cards) != have:
        raise ValueError('Nouns card list does not match the lists on disk')
    common_cards = sorted(card_id for card_id in cards if card_id in common_ids)
    dropped = _noun_tags_to_drop(members)
    for tag in dropped:
        members.pop(tag, None)
    next_id = max(members) + 1 if members else CHUNKED_ID_START
    n_chunks = len(chunk_sizes(len(common_cards)))
    chunk_ids, next_id = _take_ids(None, (), n_chunks, next_id)
    sets = _chunk_records('Common Nouns', COMMON_NOUN_BLURB, common_cards, chunk_ids)
    sets[0]['tag_id'] = next_id
    for entry in sets:
        members[entry['tag_id']] = list(entry['card_ids'])
    old = load_chunked() or {'groups': []}
    groups = [group for group in old['groups'] if group.get('base_name') != 'Nouns']
    groups.append({
        'group_id': NOUNS_GROUP_ID,
        'base_name': 'Common Nouns',
        'sets': [{k: s[k] for k in ('tag_id', 'name', 'description', 'count')} for s in sets],
    })
    return members, order, {'groups': groups}, dropped


def load_common_ids(path=FTS_DB):
    """card_ids with the JMdict common-priority mark.  Empty if the FTS db is absent."""
    if not os.path.exists(path):
        return set()
    conn = sqlite3.connect(path)
    try:
        return {row[0] for row in conn.execute(
            'SELECT card_id FROM cards_search_content WHERE ptag != 0')}
    finally:
        conn.close()


def load_core_ids(path=CORE_PATH):
    """Card ids in study order: nf01 by card_id, then nf02 by card_id."""
    ids = []
    with open(path, encoding='utf-8') as handle:
        for line in handle:
            if line.startswith('#') or not line.strip():
                continue
            band_s, card_s = line.split('\t')
            band, card_id = int(band_s), int(card_s)
            if band not in (1, 2):
                raise ValueError('core1000.tsv band must be 1 or 2, got %s' % band)
            ids.append(card_id)
    if len(ids) != len(set(ids)):
        raise ValueError('core1000.tsv repeats a card id')
    return ids


def recut_oversized(members, order, common_ids, core_ids):
    """Split Common Words and add Core 1000.

    Returns (members, order, chunked_catalog).  Chunk ids reuse the old
    continuation tags, then continue after 720.  Nouns is not cut here.
    Safe to call only when needs_oversized_recut is true; a second call
    would slice the small chunks.
    """
    next_id = max(CHUNKED_ID_START - 1, max(members) if members else 0) + 1
    groups = []
    for spec in CHUNKED_LISTS:
        source = (spec['anchor'],) + tuple(spec['reuse'])
        cards = order_card_ids(
            (card for tag in source for card in members.get(tag, ())), common_ids)
        n_chunks = len(chunk_sizes(len(cards)))
        chunk_ids, next_id = _take_ids(spec['anchor'], spec['reuse'], n_chunks, next_id)
        sets = _chunk_records(spec['base_name'], spec['blurb'], cards, chunk_ids)
        sets[0]['tag_id'] = next_id
        next_id += 1
        for tag in source:
            members.pop(tag, None)
        for entry in sets:
            members[entry['tag_id']] = list(entry['card_ids'])
        groups.append({
            'group_id': spec['group_id'],
            'base_name': spec['base_name'],
            'sets': [{k: s[k] for k in ('tag_id', 'name', 'description', 'count')} for s in sets],
        })
    core_cards = list(core_ids)
    n_chunks = len(chunk_sizes(len(core_cards)))
    chunk_ids, next_id = _take_ids(None, (), n_chunks, next_id)
    sets = _chunk_records('Core 1000', CORE_BLURB, core_cards, chunk_ids)
    sets[0]['tag_id'] = next_id
    next_id += 1
    for entry in sets:
        members[entry['tag_id']] = list(entry['card_ids'])
    groups.append({
        'group_id': CORE_GROUP_ID,
        'group_name': 'Core 1000',
        'owner_id': 0,
        'base_name': 'Core 1000',
        'sets': [{k: s[k] for k in ('tag_id', 'name', 'description', 'count')} for s in sets],
    })
    # New tag ids are not in `order`.  render_tsv appends those, sorted.
    return members, order, {'groups': groups}


def chunked_tag_ids(chunked):
    return [s['tag_id'] for group in chunked['groups'] for s in group['sets']]


def load_chunked(path=CHUNKED_PATH):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def write_chunked(chunked, path=CHUNKED_PATH):
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(chunked, handle, ensure_ascii=False, indent=2)
        handle.write('\n')


def write_links_in_order(card_conn, members, tag_ids):
    """Replace link rows for these tags, keeping the list order.

    The app reads a set with no ORDER BY, so row order is the study order.
    build.py inserts the TSV in file order for the same reason.
    """
    for tag_id in tag_ids:
        card_conn.execute('DELETE FROM system_card_tag_link WHERE tag_id = ?', (tag_id,))
    rows = []
    for tag_id in tag_ids:
        for card_id in members.get(tag_id, ()):
            rows.append((tag_id, card_id))
    card_conn.executemany(
        'INSERT INTO system_card_tag_link (tag_id, card_id) VALUES (?, ?)', rows)
    card_conn.commit()
    return len(rows)


def _add_column(conn, table, column, declaration):
    have = {row[1] for row in conn.execute('PRAGMA table_info(%s)' % table)}
    if column not in have:
        conn.execute('ALTER TABLE %s ADD COLUMN %s %s' % (table, column, declaration))


def ensure_locale_columns(conn):
    """Japanese name columns.  Absent on a 2.0 file; present on the 2.1 template."""
    _add_column(conn, 'tags', 'tag_name_ja', 'TEXT')
    _add_column(conn, 'tags', 'description_ja', 'TEXT')
    _add_column(conn, 'groups', 'group_name_ja', 'TEXT')


def _apply_chunked(cur, chunked):
    for group in chunked['groups']:
        if group.get('group_name'):
            cur.execute(
                'INSERT OR REPLACE INTO groups (group_id, group_name, owner_id, tag_count, recommended) '
                'VALUES (?, ?, ?, ?, 0)',
                (group['group_id'], group['group_name'], group.get('owner_id', 0), len(group['sets'])))
        for s in group['sets']:
            row = cur.execute('SELECT tag_id FROM tags WHERE tag_id = ?', (s['tag_id'],)).fetchone()
            if row is None:
                cur.execute(
                    'INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (?, ?, ?, 0, ?)',
                    (s['tag_id'], s['name'], s['description'], s['count']))
            else:
                cur.execute(
                    'UPDATE tags SET tag_name = ?, description = ?, editable = 0, count = ? WHERE tag_id = ?',
                    (s['name'], s['description'], s['count'], s['tag_id']))
            linked = cur.execute(
                'SELECT 1 FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
                (group['group_id'], s['tag_id'])).fetchone()
            if linked is None:
                cur.execute('INSERT INTO group_tag_link (group_id, tag_id) VALUES (?, ?)',
                            (group['group_id'], s['tag_id']))


def _japanese_by_tag(catalog, chunked):
    """tag_id -> (ja_name, ja_description).  Hand entries win over a generated name."""
    ja_by_id = {}
    for group, level in zip(catalog['groups'], LEVELS):
        chunks = [s for s in group['sets'] if not is_combined_name(s.get('name'))]
        for s in group['sets']:
            ja_by_id[s['tag_id']] = builtin_ja.level_japanese(
                level['key'], s['name'], s['count'], len(chunks))
    if chunked:
        for group in chunked['groups']:
            chunks = [s for s in group['sets'] if not is_combined_name(s.get('name'))]
            width = max(2, len(str(len(chunks))))
            for s in group['sets']:
                ja_by_id[s['tag_id']] = builtin_ja.chunk_japanese(
                    group['base_name'], s['name'], s['count'], len(chunks), width)
    overlap = set(ja_by_id) & set(builtin_ja.TAG_JA)
    if overlap:
        raise ValueError('hand Japanese names collide with generated sets: %s' % sorted(overlap))
    ja_by_id.update(builtin_ja.TAG_JA)
    return ja_by_id


def _apply_japanese(cur, catalog, chunked):
    ja_by_id = _japanese_by_tag(catalog, chunked)
    for tag_id, (ja_name, ja_desc) in ja_by_id.items():
        if tag_id == FAVORITES_TAG:
            # Editable built-in.  Keep the Japanese columns only while the
            # English name is still the one we shipped.
            cur.execute(
                'UPDATE tags SET tag_name_ja = ?, description_ja = ? '
                'WHERE tag_id = ? AND tag_name = ?',
                (ja_name, ja_desc, tag_id, FAVORITES_NAME))
            continue
        cur.execute(
            'UPDATE tags SET tag_name_ja = ?, description_ja = ? WHERE tag_id = ? AND editable = 0',
            (ja_name, ja_desc, tag_id))
    for group_id, ja_name in builtin_ja.GROUP_JA.items():
        cur.execute('UPDATE groups SET group_name_ja = ? WHERE group_id = ?', (ja_name, group_id))


def ensure_user_catalog(conn, catalog):
    """Make jFlash.db match the browse-list cleanup.  Safe to run twice.

    Does not touch tag 0's cards, user rows, card_tag_link, or last_state.
    Cached tag counts for the level sets are written here; other system tags
    are recounted from system_card_tag_link by the caller when that table changed.
    Japanese columns are filled for built-in sets.  A user-created set has no
    Japanese columns unless it is the untouched Long Weekend Favorites row.
    """
    ensure_locale_columns(conn)
    cur = conn.cursor()
    # Text fixes on every tag, including ones we do not otherwise rename.
    # Fetch first: sqlite3 drops the SELECT if we UPDATE on the same connection.
    tag_rows = cur.execute('SELECT tag_id, tag_name, description FROM tags').fetchall()
    for tag_id, name, description in tag_rows:
        new_name = _replace_text(name)
        new_desc = _replace_text(description)
        if tag_id == 154 and new_name:
            new_name = new_name.strip()
        if tag_id == EXPRESSIONS_TAG:
            new_name = EXPRESSIONS_NAME
            new_desc = EXPRESSIONS_DESCRIPTION
        if tag_id in KANA_RENAMES:
            new_name = KANA_RENAMES[tag_id]
            new_desc = KANA_RENAMES[tag_id]
        if new_name != name or new_desc != description:
            cur.execute('UPDATE tags SET tag_name = ?, description = ? WHERE tag_id = ?',
                        (new_name, new_desc, tag_id))

    cur.execute('UPDATE groups SET group_name = ?, tag_count = 0 WHERE group_id = ?',
                (catalog['parent_group_name'], catalog['parent_group_id']))
    # The old level tags were linked directly under group 10.
    for tag_id in ANCHORS:
        cur.execute('DELETE FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
                    (PARENT_GROUP, tag_id))

    for group in catalog['groups']:
        cur.execute(
            'INSERT OR REPLACE INTO groups (group_id, group_name, owner_id, tag_count, recommended) '
            'VALUES (?, ?, ?, ?, 0)',
            (group['group_id'], group['group_name'], PARENT_GROUP, len(group['sets'])))
        for s in group['sets']:
            row = cur.execute('SELECT tag_id FROM tags WHERE tag_id = ?', (s['tag_id'],)).fetchone()
            if row is None:
                cur.execute(
                    'INSERT INTO tags (tag_id, tag_name, description, editable, count) VALUES (?, ?, ?, 0, ?)',
                    (s['tag_id'], s['name'], s['description'], s['count']))
            else:
                cur.execute(
                    'UPDATE tags SET tag_name = ?, description = ?, editable = 0, count = ? WHERE tag_id = ?',
                    (s['name'], s['description'], s['count'], s['tag_id']))
            cur.execute('DELETE FROM group_tag_link WHERE tag_id = ? AND group_id = ?',
                        (s['tag_id'], PARENT_GROUP))
            linked = cur.execute(
                'SELECT 1 FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
                (group['group_id'], s['tag_id'])).fetchone()
            if linked is None:
                cur.execute('INSERT INTO group_tag_link (group_id, tag_id) VALUES (?, ?)',
                            (group['group_id'], s['tag_id']))

    for tag_id in HIDDEN_TAG_IDS:
        cur.execute('DELETE FROM group_tag_link WHERE tag_id = ?', (tag_id,))
    for tag_id in ADVERBS_OUT_OF_VERBS:
        cur.execute('DELETE FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
                    (VERBS_GROUP, tag_id))
    for tag_id in RECOMMENDED_REMOVE:
        cur.execute('DELETE FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
                    (RECOMMENDED_GROUP, tag_id))
    for tag_id in RECOMMENDED_ADD:
        linked = cur.execute(
            'SELECT 1 FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
            (RECOMMENDED_GROUP, tag_id)).fetchone()
        if linked is None:
            cur.execute('INSERT INTO group_tag_link (group_id, tag_id) VALUES (?, ?)',
                        (RECOMMENDED_GROUP, tag_id))
    linked = cur.execute(
        'SELECT 1 FROM group_tag_link WHERE group_id = ? AND tag_id = ?',
        (PARTS_OF_SPEECH_GROUP, PRONOUNS_TAG)).fetchone()
    if linked is None:
        cur.execute('INSERT INTO group_tag_link (group_id, tag_id) VALUES (?, ?)',
                    (PARTS_OF_SPEECH_GROUP, PRONOUNS_TAG))

    # The full Nouns list (tag 133), Nouns 02–13, and any numbered cut of it.
    # An editable row at tag 133 is a user set and is left alone.
    split_ids = [row[0] for row in cur.execute(
        "SELECT tag_id FROM tags WHERE editable = 0 AND "
        "(tag_id = ? OR tag_id BETWEEN 620 AND 631 OR tag_name LIKE 'Nouns %')",
        (NOUN_ANCHOR,))]
    for tag_id in split_ids:
        cur.execute('DELETE FROM group_tag_link WHERE tag_id = ?', (tag_id,))
        cur.execute('DELETE FROM tags WHERE tag_id = ? AND editable = 0', (tag_id,))

    # Links whose tag was deleted in an earlier import.
    cur.execute('DELETE FROM group_tag_link WHERE tag_id NOT IN (SELECT tag_id FROM tags)')

    chunked = load_chunked()
    if chunked:
        _apply_chunked(cur, chunked)
    # tag_count is the number of real sets, excluding My Starred Words (tag 0).
    # Count after the chunked links exist, or Nouns and Common Words stay on
    # the old totals.
    cur.execute('''
        UPDATE groups SET tag_count = (
            SELECT count(*) FROM group_tag_link g
            JOIN tags t ON t.tag_id = g.tag_id
            WHERE g.group_id = groups.group_id AND g.tag_id != 0
        )
    ''')
    # Vocabulary Levels shows its four child groups, not a set count.
    cur.execute('UPDATE groups SET tag_count = 0 WHERE group_id = ?', (PARENT_GROUP,))
    _apply_japanese(cur, catalog, chunked)

    max_id = cur.execute('SELECT max(tag_id) FROM tags').fetchone()[0] or 0
    cur.execute('UPDATE sqlite_sequence SET seq = ? WHERE name = ? AND seq < ?',
                (max_id, 'tags', max_id))
    conn.commit()


def refresh_system_counts(user_conn, card_conn):
    """Set tags.count from the link table the app actually reads.

    Editable tags and My Starred Words use card_tag_link.  Everything else
    uses system_card_tag_link.  Group tag_count is not touched here.
    """
    sys_counts = dict(card_conn.execute(
        'SELECT tag_id, count(*) FROM system_card_tag_link GROUP BY tag_id'))
    user_counts = dict(user_conn.execute(
        'SELECT tag_id, count(*) FROM card_tag_link GROUP BY tag_id'))
    changed = 0
    for tag_id, editable, count in user_conn.execute('SELECT tag_id, editable, count FROM tags'):
        n = user_counts.get(tag_id, 0) if (editable or tag_id == 0) else sys_counts.get(tag_id, 0)
        if n != count:
            user_conn.execute('UPDATE tags SET count = ? WHERE tag_id = ?', (n, tag_id))
            changed += 1
    user_conn.commit()
    return changed


def replace_system_links(card_conn, members):
    """Rewrite system_card_tag_link from the TSV membership.  Study order follows
    build.py: tag_id, then card_id.
    """
    rows = []
    for tag_id, cards in members.items():
        for card_id in cards:
            rows.append((tag_id, card_id))
    rows.sort()
    card_conn.execute('DELETE FROM system_card_tag_link')
    card_conn.executemany('INSERT INTO system_card_tag_link (tag_id, card_id) VALUES (?, ?)', rows)
    card_conn.commit()
    return len(rows)


def upsert_tag_links(card_conn, members, tag_ids):
    """Replace system_card_tag_link rows for these tags and leave every other tag."""
    for tag_id in tag_ids:
        card_conn.execute('DELETE FROM system_card_tag_link WHERE tag_id = ?', (tag_id,))
    rows = []
    for tag_id in tag_ids:
        for card_id in members.get(tag_id, []):
            rows.append((tag_id, card_id))
    rows.sort()
    card_conn.executemany(
        'INSERT INTO system_card_tag_link (tag_id, card_id) VALUES (?, ?)', rows)
    card_conn.commit()
    return len(rows)
