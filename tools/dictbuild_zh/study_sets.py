"""Built-in cFlash study sets.

Membership lives in data/system_sets.tsv (tag_id, card_id), in the order of
the 2011 link table. build.py drops rows whose card is no longer in CEDICT
and rewrites tags.count in the user-database template.

A later PR can drop data/hsk30_sets.tsv beside it (same two columns). Those
rows are appended. Removing the HSK 2.0 sets is deleting their rows from
system_sets.tsv and the matching tag rows; this module does not do that.

ptag (the search rank) is 1 for a card in any set the 2011 importer flagged
contains_priority_words: HSK, TOCFL, the Jun Da character lists, and the
news/fiction bigram lists. Add a new HSK 3.0 tag id to PRIORITY_TAG_IDS when
that set should rank the same way.
"""

import os

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
    """Drop links to cards that are not in this dictionary. Order is kept."""
    return [(tag_id, card_id) for tag_id, card_id in rows if card_id in card_ids]


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
