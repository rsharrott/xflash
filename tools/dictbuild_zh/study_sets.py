"""Built-in cFlash study sets.

Membership lives in data/system_sets.tsv (tag_id, card_id), in the order of
the 2011 link table. A link whose card is gone is remapped before it is
dropped:

1. the one card with the same simplified characters and pinyin (case and ü
   ignored), so a capitalised place card such as 兴隆 Xing1 long2 keeps the
   common word xing1 long2 instead of growing into 兴隆县
2. the same traditional + simplified when that card's pinyin matches
3. a variant / see target: a longer place name only when the short form is
   no longer a card (广东 → 广东省), and among several see targets the one
   whose English gloss overlaps the old definition; a same-pinyin character
   variant (粘 nian2 → 黏) when no card keeps that syllable
4. the same traditional + simplified, preferring the gloss that shares words
   with the old English and using pinyin distance only to break a tie
5. the same traditional + pinyin, then the one card for that simplified word

A link is dropped when nothing is close (no shared meaning and a different
syllable), or the replacement is already in the set. tags.count in the user
template is rewritten from the links that remain.

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


# English tokens that carry no meaning for a gloss comparison.
_STOP = frozenset(
    'a an the of to in on for and or with by from as at into via its it be'.split())
# Demonstratives and the words CEDICT uses for grammatical particles.
# "this" shares no letters with "modal final particle", but it is the same
# kind of word, and "mile" is not.
_FUNCTION = frozenset(
    'this that these those particle modal interjection pronoun'.split())
_NOT_CLOSE = 'no close meaning or pinyin match'


def index_replacements(legacy_of, cards, redirects, rejected=None):
    """legacy_of: {old card_id: (trad, simp, pinyin)} or a 4-tuple with the
    2011 English headword as the last item.

    Returns {old card_id: (new card_id, how)} for ids that have a live card
    to stand in for them. how is 'simp+pinyin', 'trad+simp', 'redirect',
    'trad+pinyin', or 'simp'.

    rejected, when a dict is passed, receives {old card_id: reason} for ids
    that had candidates but none close enough to keep.
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
    for old_id, spec in legacy_of.items():
        trad, simp, py = spec[0], spec[1], spec[2]
        english = spec[3] if len(spec) > 3 else ''
        hit, how, reason = _replacement(
            trad, simp, py, english, by_key, by_chars, simp_py, trad_simp,
            trad_py, simp_cards, cards)
        if hit is not None:
            out[old_id] = (hit, how)
        elif reason and rejected is not None:
            rejected[old_id] = reason
    return out


def _unique(cards):
    found = {}
    for card in cards:
        found[card.card_id] = card
    return list(found.values())


def _replacement(trad, simp, py, english, by_key, by_chars, simp_py, trad_simp,
                 trad_py, simp_cards, cards):
    # Exact simplified + pinyin before any see/variant. 兴隆 Xing1 long2 is
    # one card, xing1 long2 "prosperous", and must not become 兴隆县.
    same = _unique(simp_py.get((simp, loose_pinyin(py)), []))
    if len(same) == 1:
        return same[0].card_id, 'simp+pinyin', None
    chars = _unique(trad_simp.get((trad, simp), []))
    same_py = [card for card in chars if loose_pinyin(card.pinyin) == loose_pinyin(py)]
    if len(same_py) == 1:
        return same_py[0].card_id, 'trad+simp', None

    redirect = _matching_redirect(trad, simp, py, by_key, by_chars)
    if redirect is not None:
        hit, reason = _choose_redirect(simp, py, english, redirect, simp_cards, cards)
        if hit is not None:
            return hit.card_id, 'redirect', None
        if reason:
            # A place name with several see targets and no acceptable one
            # still falls through; only keep the reason if nothing later hits.
            redirect_reason = reason
        else:
            redirect_reason = None
    else:
        redirect_reason = None

    if len(chars) == 1:
        # The only card for these characters (角色 jiao3 se4 → jue2 se4).
        # A different syllable is still this word when no better variant won
        # above. 粘 nian2 does not get here: its redirect is 黏.
        return chars[0].card_id, 'trad+simp', None
    if len(chars) > 1:
        best = _best_candidate(py, english, chars)
        if best is not None:
            return best.card_id, 'trad+simp', None
        redirect_reason = _NOT_CLOSE
    trad_same = _unique(trad_py.get((trad, loose_pinyin(py)), []))
    if len(trad_same) == 1:
        return trad_same[0].card_id, 'trad+pinyin', None
    # Same simplified headword, pinyin and traditional both edited (週到
    # zhou1 dao5 → 周到 zhou1 dao4). Only when that headword is one card.
    only = _unique(simp_cards.get(simp, []))
    if len(only) == 1:
        return only[0].card_id, 'simp', None
    return None, None, redirect_reason


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


def _choose_redirect(old_simp, old_py, english, redirect, simp_cards, cards):
    """The see/variant card to use, or (None, reason).

    A longer place name is used only when the short form is not itself a
    card (the exact simplified+pinyin match above already returned). Several
    see targets (兴安 → 盟 / 区 / 县) are ranked by the old English gloss.
    A jump to a different simplified word is kept when the old headword has
    no card of its own (桔子 → 橘子), or when it is the same-pinyin variant
    and every surviving card of the old headword is a different syllable
    (粘 nian2 → 黏, while 粘 zhan1 stays a different word). 与 yu2 does not
    jump to 欤: 与 yu3 is the same syllable.
    """
    targets = []
    seen = set()
    notes = []
    if redirect.variant_target:
        notes.append(redirect.variant_target)
    notes.extend(redirect.refs)
    for note in notes:
        hit = cedict.card_for_reference(note, cards)
        if hit is None or hit.card_id in seen:
            continue
        seen.add(hit.card_id)
        targets.append(hit)
    if not targets:
        return None, None
    own = simp_cards.get(old_simp, [])
    usable = []
    for target in targets:
        if target.simp == old_simp or (target.simp or '').startswith(old_simp):
            usable.append(target)
        elif not own:
            usable.append(target)
        elif _same_pinyin(target.pinyin, old_py) and _other_syllable(own, old_py):
            usable.append(target)
    if not usable:
        return None, None
    if len(usable) == 1:
        return usable[0], None
    best = _best_candidate(old_py, english, usable)
    if best is None:
        return None, _NOT_CLOSE
    return best, None


def _other_syllable(cards, pinyin):
    """True when no card shares the old syllable bodies."""
    old = _bodies(pinyin)
    return bool(old) and all(_bodies(card.pinyin) != old for card in cards)


def _same_pinyin(left, right):
    return loose_pinyin(left) == loose_pinyin(right)


def _best_candidate(old_py, english, cards):
    """Highest gloss overlap, then the closer pinyin. None when the winner
    is tied, or when nothing shares a gloss and the pinyin is a different
    syllable.
    """
    ranked = sorted(
        cards,
        key=lambda card: (_meaning_score(english, card), -_pinyin_distance(old_py, card.pinyin)),
        reverse=True)
    best = ranked[0]
    best_key = (_meaning_score(english, best), _pinyin_distance(old_py, best.pinyin))
    tied = [
        card for card in ranked[1:]
        if (_meaning_score(english, card), _pinyin_distance(old_py, card.pinyin)) == best_key
    ]
    if tied:
        return None
    if best_key[0] == 0 and best_key[1] >= 10:
        return None
    return best


def _meaning_score(old_en, card):
    old = _tokens(old_en)
    new = _tokens(_english(card))
    score = len(old & new)
    if (old & _FUNCTION) and (new & _FUNCTION):
        score += 1
    return score


def _english(card):
    glosses = getattr(card, 'glosses', None)
    if glosses:
        return ' ; '.join(glosses)
    return getattr(card, 'english', None) or ''


def _tokens(text):
    words = re.findall(r"[A-Za-z']+", text or '')
    return {word.lower() for word in words if len(word) > 1 and word.lower() not in _STOP}


def _bodies(reading):
    out = []
    for syllable in (reading or '').split(' '):
        matched = re.match(r'(.+?)([1-5])$', syllable)
        piece = matched.group(1) if matched else syllable
        out.append(loose_pinyin(piece))
    return tuple(out)


def _pinyin_distance(old, new):
    """0 is the same reading. 10 per syllable that is a different body, so a
    different word sorts after any same-syllable tone change. Case is a
    tenth, which breaks Cong2 vs cong2 without beating a real tone."""
    left, right = (old or '').split(' '), (new or '').split(' ')
    if len(left) != len(right) or not left[0]:
        return 100
    score = 0
    for alpha, beta in zip(left, right):
        ma = re.match(r'(.+?)([1-5])$', alpha)
        mb = re.match(r'(.+?)([1-5])$', beta)
        if not ma or not mb:
            score += 0 if loose_pinyin(alpha) == loose_pinyin(beta) else 10
        elif loose_pinyin(ma.group(1)) != loose_pinyin(mb.group(1)):
            score += 10
        else:
            score += abs(int(ma.group(2)) - int(mb.group(2)))
        if alpha[:1].isupper() != beta[:1].isupper():
            score += 0.1
    return score


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
