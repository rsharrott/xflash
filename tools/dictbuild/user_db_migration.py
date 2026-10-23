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
* group links whose tag row does not exist are deleted (the 2.0 template
  has 68 of these)

JFlashUpdateManager's 2.1 step runs the same statements.  Keep the two in step.
"""

import sqlite3


def migrate(user_path, template_path):
    """Update user_path using template_path.  Returns {old_tag_id: new_tag_id}."""
    conn = sqlite3.connect(user_path)
    try:
        conn.execute('ATTACH DATABASE ? AS tpl', (template_path,))
        mapping = _renumber_collisions(conn)
        _copy_system_tags(conn)
        _copy_groups(conn)
        _replace_system_links(conn)
        _drop_dangling_links(conn)
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


def _copy_system_tags(conn):
    # Tag 0 (My Starred Words) is editable = 0 but its cards live in this file.
    conn.execute(
        'INSERT OR REPLACE INTO tags (tag_id, tag_name, description, editable, count) '
        'SELECT tag_id, tag_name, description, editable, count FROM tpl.tags '
        'WHERE editable = 0 AND tag_id != 0')


def _copy_groups(conn):
    conn.execute(
        'INSERT OR REPLACE INTO groups (group_id, group_name, owner_id, tag_count, recommended) '
        'SELECT group_id, group_name, owner_id, tag_count, recommended FROM tpl.groups')


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
