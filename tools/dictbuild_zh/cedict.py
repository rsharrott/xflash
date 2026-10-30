"""CC-CEDICT reader.

The line format is the one MDBG publishes:

    Traditional Simplified [pin1 yin1] /gloss/gloss/

What becomes a card, and how the meaning HTML and the search text look,
follows the 2011 Ruby importer (importer/lib/ctedilib) with one deliberate
difference: an erhua form is always its own card, even when the line is
only "erhua variant of …". 一点儿 is the example. A see/variant line with
no gloss of its own is not a card; it is an "Also:" note on the target.

HSK 3.0 lists and Tatoeba sentences are not read here. They join later by
card_id (see ids.py and study_sets.py).
"""

import gzip
import os
import re

import pinyin

# Parentheticals the 2011 importer removed from the displayed gloss. The
# tag was kept in its own column then; the app never read that column, so
# only the stripping still matters. Partial tags (Japanese, math., …) stay
# in the text, matching Meaning.rb (only a full-match tag is removed).
_FULL_TAGS = {
    'classical', 'golf', 'mechanics', 'honorific', 'Chinese medicine', 'psychology',
    'telecommunications', 'technology', 'slang', 'physiology', 'agriculture',
    'astronomy', 'military', 'sexual', 'suffix', 'prefix', 'navigation', 'animal',
    'electric', 'phonetic', 'automotive', 'zoology', 'mythology', 'electronics',
    'meteorology', 'accountancy', 'derogatory', 'political', 'Communist',
    'martial arts', 'color', 'archaic', 'topolect', 'pharmacology', 'buddhism',
    'sports', 'statistics', 'fashion', 'colloquial', 'idiom', 'onomatopoeia',
    'philosophy', 'expression', 'vulgar', 'interjection', 'Taiwan', 'Cantonese',
    'computing', 'software', 'law', 'constellation', 'economics', 'finance',
    'dialect', 'loanword', 'geometry', 'formal', 'language', 'abbr', 'literary',
    'mathematics', 'grammar', 'geology', 'medicine', 'anatomy', 'name', 'music',
    'linguistics', 'biology', 'botany', 'chemistry', 'physics', 'history',
    'business', 'euphemism', 'humble', 'particles', 'punctuation', 'email',
    'logic', 'korean', 'tibetan', 'mongolian', 'uighur', 'russian', 'aramaic',
    'japanese', 'greek', 'zhuang', 'amoy', 'sanskrit', 'kangxi', 'archaeology',
    'surname', 'common saying', 'athletics', 'polite', 'gymnastics', 'person name',
    'hon.', 'geological', 'historical', 'common expression', 'elec.', 'politics',
    'derog.', 'computing software', 'pharm.', 'arch.', 'old', 'old term',
    'old usage', 'onomatopeia', 'zoo.', 'euph.', 'computer', 'banking', 'coll.',
    'expr.', 'math', 'math.', 'med.', 'abbr.', 'interj.', 'informal', 'medical',
    'ling.', 'comp.', 'punct.', 'biol.', 'onomat.', 'Cant.',
}
_PAREN_TAG = re.compile(r' \(([^)]+)\)')
_TRAILING_PAREN = re.compile(r'\([^)]*\)$')
_STOP_WORDS = {
    'Variant', 'variant', 'Erhua', 'Counter', 'Has', 'I', 'me', 'a', 'an', 'am',
    'are', 'as', 'at', 'be', 'by', 'how', 'in', 'is', 'it', 'of', 'on', 'or',
    'that', 'than', 'the', 'this', 'to', 'was', 'what', 'when', 'where', 'who',
    'will', 'with',
}
_LINE = re.compile(r'^(\S+) (\S+) \[([^\]]+)\] /(.*)/\s*$')
_SEE = re.compile(r'^see (also |)([^a-zA-Z0-9\s]+)(\[[^\]]+\])?$')
_VARIANT = re.compile(
    r'^(erhua |archaic |old |)variant of (\w+(?:\|\w+)*)(?:\[([^\]]+)\])?(.*)$')
_INLINE = re.compile(r'^([^\[|]+)(?:\|([^\[\]]*))?(?:\[([^\]]+)\])?$')
_KIND = {'': 'variant', 'erhua': 'erhua', 'archaic': 'archaic', 'old': 'archaic'}
_MODIFIER_ON_BASE = {
    'erhua': 'Has Erhua variant',
    'archaic': 'Has archaic variant',
    'variant': 'Has variant',
}
_MODIFIER_ON_SELF = {
    'erhua': 'Erhua variant of',
    'archaic': 'Archaic variant of',
    'variant': 'Variant of',
}


class Entry:
    def __init__(self, trad, simp, pinyin, glosses, classifiers, variant_kind,
                 variant_target, refs):
        self.trad = trad
        self.simp = simp
        self.pinyin = pinyin
        self.glosses = glosses
        self.classifiers = classifiers
        self.variant_kind = variant_kind
        self.variant_target = variant_target
        self.refs = refs
        self.extra = []
        self.card_id = None
        self.ptag = 0
        self.include = False

    @property
    def redirect_only(self):
        return not self.glosses and (self.variant_kind is not None or bool(self.refs))


def parse_line(line):
    """One CEDICT entry, or None for a comment / blank / metadata line."""
    line = line.strip()
    if not line or line.startswith('#'):
        return None
    matched = _LINE.match(line)
    if not matched:
        raise ValueError('not a CEDICT line: %s' % line[:120])
    trad, simp, raw_pinyin, defs = matched.groups()
    glosses, classifiers, variant_kind, variant_target, refs = _senses(defs)
    entry = Entry(
        trad, simp, pinyin.normalize_reading(raw_pinyin),
        glosses, classifiers, variant_kind, variant_target, refs)
    entry.include = (not entry.redirect_only) or variant_kind == 'erhua'
    if not glosses and not classifiers and variant_kind is None and not refs:
        entry.include = False
    return entry


def iter_file(path):
    """Yield (meta, entries) from a CEDICT file, gzip or plain text."""
    opener = gzip.open if path.endswith('.gz') else open
    meta = {}
    entries = []
    with opener(path, 'rt', encoding='utf-8') as handle:
        for line in handle:
            if line.startswith('#! '):
                key, _, value = line[3:].strip().partition('=')
                meta[key] = value
                continue
            entry = parse_line(line)
            if entry is not None:
                entries.append(entry)
    return meta, entries


def cross_link(entries):
    """Attach Also / Has variant / Erhua variant of notes. Returns the cards."""
    cards = [entry for entry in entries if entry.include]
    by_trad = {}
    for entry in cards:
        by_trad.setdefault(entry.trad, []).append(entry)

    for entry in entries:
        if entry.include or entry.variant_kind == 'erhua':
            continue
        target = _resolve(entry.variant_target or (entry.refs[0] if entry.refs else None), by_trad)
        if target is not None:
            target.extra.append(_note('Also', entry))

    for entry in cards:
        if not entry.variant_kind:
            continue
        base = _resolve(entry.variant_target, by_trad)
        if base is not None and base is not entry:
            base.extra.append(_note(_MODIFIER_ON_BASE[entry.variant_kind], entry))
            entry.extra.append(_note(_MODIFIER_ON_SELF[entry.variant_kind], base))
        elif entry.variant_kind == 'erhua':
            entry.extra.append('Erhua variant of: %s' % _raw_target(entry.variant_target))
    return cards


def meanings(entry):
    """Glosses, then measure-word counters, then cross-references."""
    out = list(entry.glosses)
    out.extend('Counter: %s' % item for item in entry.classifiers)
    out.extend(entry.extra)
    return out


def meaning_html(entry):
    items = [_escape(item) for item in meanings(entry)]
    if not items:
        return ''
    if len(items) == 1:
        return items[0]
    return '<ol>' + ''.join('<li>%s</li>' % item for item in items) + '</ol>'


def meaning_fts(entry):
    """English search text: stop words and a trailing parenthetical removed,
    duplicate senses dropped. Same rules as Entry#meaning_fts / xfrm_remove_stop_words.
    """
    seen = []
    for item in meanings(entry):
        text = _remove_stop_words(item)
        if text and text not in seen:
            seen.append(text)
    return ' '.join(seen)


def headword_en(entry):
    """Short English headword: the first gloss, not a counter or an Also note.
    An erhua card with no gloss of its own uses its cross-reference. Cut at
    255 characters, the width of the old MySQL column."""
    source = entry.glosses or meanings(entry)
    if not source:
        return ''
    text = re.sub(r' {2,}', ' ', source[0]).strip()
    if len(text) <= 255:
        return text
    cut = text[:255]
    for sep in ('; ', ', ', ' '):
        at = cut.rfind(sep)
        if at >= 40:
            return cut[:at].rstrip(' ;,')
    return cut.rstrip()


def fts_headword(entry):
    return '%s %s' % (entry.trad, entry.simp)


def _senses(defs):
    glosses, classifiers, refs = [], [], []
    variant_kind = variant_target = None
    for part in defs.split('/'):
        part = part.strip()
        if not part:
            continue
        if part.startswith('CL:'):
            classifiers.extend(piece.strip() for piece in part[3:].split(',') if piece.strip())
            continue
        if 'see you' in part:
            glosses.append(_strip_tags(part))
            continue
        see = _SEE.match(part)
        if see:
            refs.append(see.group(2) + (see.group(3) or ''))
            continue
        variant = _VARIANT.match(part)
        if variant:
            prefix = variant.group(1).strip()
            variant_kind = _KIND[prefix]
            target = variant.group(2)
            if variant.group(3):
                target += '[' + variant.group(3) + ']'
            variant_target = target
            rest = variant.group(4).strip().lstrip(',').strip()
            if rest:
                glosses.append(_strip_tags(rest))
            continue
        glosses.append(_strip_tags(part))
    return glosses, classifiers, variant_kind, variant_target, refs


def _strip_tags(text):
    def replace(match):
        return '' if match.group(1) in _FULL_TAGS else match.group(0)
    return re.sub(r' {2,}', ' ', _PAREN_TAG.sub(replace, text)).strip()


def _remove_stop_words(text):
    text = _TRAILING_PAREN.sub('', text).strip()
    kept = []
    for word in text.split(' '):
        if not word:
            continue
        key = re.sub(r'[^a-zA-Z|\s]', '', word).strip()
        if key in _STOP_WORDS:
            continue
        kept.append(word)
    return ' '.join(kept)


def _escape(text):
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def _parse_inline(target):
    if not target:
        return None
    matched = _INLINE.match(target.strip())
    if not matched:
        return None
    trad, simp, raw = matched.group(1), matched.group(2) or None, matched.group(3)
    py = pinyin.normalize_reading(raw) if raw else None
    return trad, simp, py


def _resolve(target, by_trad):
    parsed = _parse_inline(target)
    if parsed is None:
        return None
    trad, _simp, py = parsed
    cands = by_trad.get(trad, [])
    if py:
        cands = [entry for entry in cands if entry.pinyin == py]
    return cands[0] if cands else None


def _note(modifier, entry):
    return '%s: %s|%s [%s]' % (modifier, entry.trad, entry.simp, entry.pinyin)


def _raw_target(target):
    parsed = _parse_inline(target)
    if parsed is None:
        return target or ''
    trad, simp, py = parsed
    simp = simp or trad
    if py:
        return '%s|%s [%s]' % (trad, simp, py)
    return '%s|%s' % (trad, simp)


def source_path(sources_dir):
    name = 'cedict_1_0_ts_utf-8_mdbg.txt.gz'
    return os.path.join(sources_dir, name)
