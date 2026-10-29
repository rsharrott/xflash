"""In-place upgrade of a 2.0 jFlash user database to the bundled catalog.

The app copies jFlash.db into Documents once.  An install that is already at
data version 2.0 keeps that file when a newer build ships a new template, so
tags, groups and links would stay on the old study-set list while the card
database moved on.  This updates the user file from the new template:

* system tags, groups and group_tag_link match the template
* users, user_history, My Starred Words (tag 0), user-created sets and
  last_state are kept
* a user-created tag whose id is a system id in the template (644 and up)
  is renumbered, and card_tag_link, group_tag_link, last_state and
  tag_user_card_levels follow it
* The built-in Nouns list (tag 133) and Nouns 02–13 (tags 620–631) are
  removed.  An active set on one of them moves to Common Nouns Full Set.
  Card progress stays on user_history, so a card that is also in Common
  Nouns keeps its level.  An editable row at one of those ids is a user
  set and is left alone
* group links whose tag row does not exist are deleted (the 2.0 template
  has 68 of these)

JFlashUpdateManager's 2.1 step runs the same statements.  Keep the two in step.
"""

import sqlite3

import study_sets


def migrate(user_path, template_path):
    """Update user_path using template_path.  Returns {old_tag_id: new_tag_id}."""
    conn = sqlite3.connect(user_path)
    try:
        conn.execute('ATTACH DATABASE ? AS tpl', (template_path,))
        _ensure_locale_columns(conn)
        mapping = _renumber_collisions(conn)
        _copy_system_tags(conn)
        _copy_groups(conn)
        _replace_system_links(conn)
        mapping.update(_fold_retired_noun_tags(conn))
        _drop_dangling_links(conn)
        _copy_kept_japanese(conn)
        _recount_groups(conn)
        _refresh_starred_count(conn)
        _bump_sequence(conn)
        # DETACH is refused while a transaction still has the attached file open.
        conn.commit()
        conn.execute('DETACH DATABASE tpl')
        return mapping
    except Exception:
        conn.rollback()
        try:
            conn.execute('DETACH DATABASE tpl')
        except sqlite3.OperationalError:
            pass
        raise
    finally:
        conn.close()


def _column_names(conn, table):
    return {row[1] for row in conn.execute('PRAGMA table_info(%s)' % table)}


def _ensure_locale_columns(conn):
    """A 2.0 user file has no Japanese columns.  Adding them is idempotent."""
    if 'tag_name_ja' not in _column_names(conn, 'tags'):
        conn.execute('ALTER TABLE tags ADD COLUMN tag_name_ja TEXT')
    if 'description_ja' not in _column_names(conn, 'tags'):
        conn.execute('ALTER TABLE tags ADD COLUMN description_ja TEXT')
    if 'group_name_ja' not in _column_names(conn, 'groups'):
        conn.execute('ALTER TABLE groups ADD COLUMN group_name_ja TEXT')


def _system_tag_ids_sql():
    return 'SELECT tag_id FROM tpl.tags WHERE editable = 0 AND tag_id != 0'


def _renumber_collisions(conn):
    collisions = [row[0] for row in conn.execute(
        'SELECT tag_id FROM tags WHERE editable = 1 AND tag_id IN (%s) ORDER BY tag_id'
        % _system_tag_ids_sql())]
    if not collisions:
        return {}
    max_user = conn.execute('SELECT COALESCE(MAX(tag_id), 0) FROM tags').fetchone()[0]
    max_tpl = conn.execute('SELECT COALESCE(MAX(tag_id), 0) FROM tpl.tags').fetchone()[0]
    nxt = max(max_user, max_tpl) + 1
    mapping = {}
    for old in collisions:
        new = nxt
        nxt += 1
        mapping[old] = new
        for sql in (
            'UPDATE card_tag_link SET tag_id = ? WHERE tag_id = ?',
            'UPDATE group_tag_link SET tag_id = ? WHERE tag_id = ?',
            'UPDATE last_state SET tag_id = ? WHERE tag_id = ?',
            'UPDATE tag_user_card_levels SET tag_id = ? WHERE tag_id = ?',
            'UPDATE tags SET tag_id = ? WHERE tag_id = ?',
        ):
            conn.execute(sql, (new, old))
    return mapping


def _retired_noun_where():
    """Tag 133 and Nouns 02–13.  cFlash tag 133 is a different set; this step is jFlash."""
    return '(tag_id = %d OR tag_id BETWEEN %d AND %d)' % (
        study_sets.NOUN_ANCHOR,
        study_sets.RETIRED_NOUN_TAGS[0],
        study_sets.RETIRED_NOUN_TAGS[-1])


def _common_nouns_full_set_id(conn):
    row = conn.execute(
        "SELECT tag_id FROM tpl.tags WHERE tag_name = 'Common Nouns Full Set' AND editable = 0"
    ).fetchone()
    if row is None:
        raise RuntimeError('template is missing Common Nouns Full Set')
    return row[0]


def _fold_retired_noun_tags(conn):
    """Remove the built-in Nouns list and Nouns 02–13.

    A 2.0 file still has those system tags.  The template does not, so the
    system-tag copy leaves them in place.  last_state moves to Common Nouns
    Full Set.  user_history is per card and is not touched, so a card that
    is also in Common Nouns keeps its level.  Per-tag level counts counted
    a different list and are not copied.  Returns {old_tag_id: full_set_id}
    for each system tag removed, and for a last_state that still names one
    of these ids.  An editable row is a user set and is left alone.
    """
    full_set = _common_nouns_full_set_id(conn)
    where = _retired_noun_where()
    not_user = 'AND tag_id NOT IN (SELECT tag_id FROM tags WHERE editable = 1)'
    rows = conn.execute(
        'SELECT tag_id FROM tags WHERE editable = 0 AND %s '
        'UNION SELECT tag_id FROM last_state WHERE %s %s' % (where, where, not_user)
    ).fetchall()
    mapping = {row[0]: full_set for row in rows}
    # Move the active set before the tag row disappears.
    conn.execute(
        'UPDATE last_state SET tag_id = ? WHERE %s %s' % (where, not_user),
        (full_set,))
    for sql in (
        'DELETE FROM tag_user_card_levels WHERE %s %s' % (where, not_user),
        'DELETE FROM card_tag_link WHERE %s %s' % (where, not_user),
        'DELETE FROM group_tag_link WHERE %s %s' % (where, not_user),
        'DELETE FROM tags WHERE editable = 0 AND %s' % where,
    ):
        conn.execute(sql)
    return mapping


def _copy_system_tags(conn):
    # Tag 0 (My Starred Words) is editable = 0 but its cards live in this file.
    # Its Japanese columns are copied in _copy_kept_japanese, without touching count.
    conn.execute(
        'INSERT OR REPLACE INTO tags '
        '(tag_id, tag_name, description, tag_name_ja, description_ja, editable, count) '
        'SELECT tag_id, tag_name, description, tag_name_ja, description_ja, editable, count '
        'FROM tpl.tags WHERE editable = 0 AND tag_id != 0')


def _copy_groups(conn):
    conn.execute(
        'INSERT OR REPLACE INTO groups '
        '(group_id, group_name, group_name_ja, owner_id, tag_count, recommended) '
        'SELECT group_id, group_name, group_name_ja, owner_id, tag_count, recommended '
        'FROM tpl.groups')


def _copy_kept_japanese(conn):
    """Japanese names for rows the system-tag copy deliberately skips.

    Tag 0 keeps its card count.  An editable built-in (Long Weekend Favorites)
    keeps a Japanese name only while its English name still matches the
    template.  A renamed set, and every user-created set, is left as named.
    """
    conn.execute(
        'UPDATE tags SET tag_name_ja = (SELECT tag_name_ja FROM tpl.tags WHERE tag_id = 0), '
        'description_ja = (SELECT description_ja FROM tpl.tags WHERE tag_id = 0) '
        'WHERE tag_id = 0')
    conn.execute(
        'UPDATE tags SET tag_name_ja = (SELECT tag_name_ja FROM tpl.tags t WHERE t.tag_id = tags.tag_id), '
        'description_ja = (SELECT description_ja FROM tpl.tags t WHERE t.tag_id = tags.tag_id) '
        'WHERE editable = 1 AND tag_id IN (SELECT tag_id FROM tpl.tags WHERE editable = 1) '
        'AND tag_name = (SELECT tag_name FROM tpl.tags t WHERE t.tag_id = tags.tag_id)')
    conn.execute(
        'UPDATE tags SET tag_name_ja = NULL, description_ja = NULL '
        'WHERE editable = 1 AND tag_id IN (SELECT tag_id FROM tpl.tags WHERE editable = 1) '
        'AND tag_name != (SELECT tag_name FROM tpl.tags t WHERE t.tag_id = tags.tag_id)')


def _replace_system_links(conn):
    conn.execute(
        'DELETE FROM group_tag_link WHERE tag_id IN (%s)' % _system_tag_ids_sql())
    conn.execute(
        'INSERT INTO group_tag_link (group_id, tag_id) '
        'SELECT group_id, tag_id FROM tpl.group_tag_link WHERE tag_id IN (%s)'
        % _system_tag_ids_sql())


def _drop_dangling_links(conn):
    conn.execute(
        'DELETE FROM group_tag_link WHERE tag_id NOT IN (SELECT tag_id FROM tags)')


def _recount_groups(conn):
    conn.execute('''
        UPDATE groups SET tag_count = (
            SELECT count(*) FROM group_tag_link g
            JOIN tags t ON t.tag_id = g.tag_id
            WHERE g.group_id = groups.group_id AND g.tag_id != 0
        )
    ''')


def _refresh_starred_count(conn):
    row = conn.execute('SELECT 1 FROM tags WHERE tag_id = 0').fetchone()
    if row is None:
        return
    n = conn.execute('SELECT count(*) FROM card_tag_link WHERE tag_id = 0').fetchone()[0]
    conn.execute('UPDATE tags SET count = ? WHERE tag_id = 0', (n,))


def _bump_sequence(conn):
    max_id = conn.execute('SELECT COALESCE(MAX(tag_id), 0) FROM tags').fetchone()[0]
    row = conn.execute("SELECT seq FROM sqlite_sequence WHERE name = 'tags'").fetchone()
    if row is None:
        conn.execute("INSERT INTO sqlite_sequence (name, seq) VALUES ('tags', ?)", (max_id,))
    elif row[0] < max_id:
        conn.execute("UPDATE sqlite_sequence SET seq = ? WHERE name = 'tags'", (max_id,))
