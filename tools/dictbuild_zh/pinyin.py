"""Numbered pinyin (nü3) and tone-mark pinyin, following the 2011 cFlash importer.

cards.reading stays numbered, with u: / v written as ü, so ChineseCard can
colour tones from the digit. The search index also stores the tone-mark
form and a toneless form (see fts_reading).
"""

import re

# Precomposed tone letters. Tone 3 is the caron (ǎ U+01CE), the form the
# 2011 importer wrote, not the breve (ă).
_MARKS = {
    'a': 'āáǎàa',
    'e': 'ēéěèe',
    'i': 'īíǐìi',
    'o': 'ōóǒòo',
    'u': 'ūúǔùu',
    'ü': 'ǖǘǚǜü',
}
_TONE_INDEX = {'1': 0, '2': 1, '3': 2, '4': 3, '5': 4}
_VOWELS = 'aeiouü'
# A tone digit glued to the next syllable (兙 shi2ke4) is split so each
# syllable keeps one tone. The 2011 converter left the digit in the middle.
_FUSED = re.compile(r'[A-Za-züÜ]+[1-5]')
_SEPARATORS = {':', '·', ',', '，'}


def normalize_reading(raw):
    """CEDICT bracket text -> cards.reading.

    u: and U: and a bare lowercase v become ü (CEDICT's ü spelling; a
    capital V is the letter V). Syllables stuck together as shi2ke4 are
    split. Everything else, including capitals, is kept.
    """
    if not raw:
        return ''
    text = raw.strip().replace('u:', 'ü').replace('U:', 'ü').replace('v', 'ü')
    parts = []
    for syl in text.split(' '):
        if not syl:
            continue
        parts.extend(_split_fused(syl))
    return ' '.join(parts)


def _split_fused(syl):
    if syl in _SEPARATORS or not re.search(r'[1-5][A-Za-züÜ]', syl):
        return [syl]
    pieces = _FUSED.findall(syl)
    if pieces and ''.join(pieces) == syl:
        return pieces
    return [syl]


def diacritic(reading, spaces=True):
    """Tone-mark form. spaces=True keeps a space between syllables (the FTS
    form); spaces=False is the 2011 no-space form used by its unit tests."""
    if not reading or not reading.strip():
        return ''
    out = []
    for syl in reading.split(' '):
        piece = syllable_diacritic(syl)
        if piece == '':
            continue
        out.append(piece)
    return (' '.join(out) if spaces else ''.join(out)).strip()


def syllable_diacritic(syl):
    """One syllable to its tone-mark form. Unknown shapes are returned as-is
    so one odd CEDICT token cannot drop the card."""
    if syl == 'r5':
        return 'r'
    if syl == 'xx5':
        return ''
    # The 2011 converter kept these two with the digit and no mark.
    if syl in ('m2', 'm4'):
        return syl
    if syl in _SEPARATORS:
        return syl
    matched = re.fullmatch(r'(.+)([1-5])', syl)
    if not matched or not re.search(r'[A-Za-züÜ]', matched.group(1)):
        return syl
    body, tone = matched.group(1), matched.group(2)
    marked = _apply_mark(body, tone)
    if marked is None:
        return body if tone == '5' else syl
    return marked


def _apply_mark(body, tone):
    lower = body.lower()
    pos = None
    for i, ch in enumerate(lower):
        if ch in 'ae':
            pos = i
            break
    if pos is None:
        ou = lower.find('ou')
        if ou >= 0:
            pos = ou
    if pos is None:
        idxs = [i for i, ch in enumerate(lower) if ch in _VOWELS]
        if not idxs:
            return None
        pos = idxs[1] if len(idxs) > 1 else idxs[0]
    base = lower[pos]
    marked = _MARKS[base][_TONE_INDEX[tone]]
    if body[pos].isupper():
        marked = marked.upper()
    return body[:pos] + marked + body[pos + 1:]


def strip_tone_digit(syl):
    """Syllable without its tone digit, for toneless search. r5 -> r.
    A token that is not a toned syllable (OK, 11, ·) is unchanged."""
    if syl == 'r5':
        return 'r'
    if syl == 'xx5':
        return ''
    matched = re.fullmatch(r'(.+)([1-5])', syl)
    if matched and re.search(r'[A-Za-züÜ]', matched.group(1)):
        return matched.group(1)
    return syl


def fts_reading(reading):
    """Reading column of cards_search_content.

    Numbered pinyin, then tone marks, then toneless syllables, then the
    syllables run together. Search for wei2 xin4, wēi xìn, wei xin and
    weixin all hit the same card. Single-syllable words skip the run-together
    copy because it is the same token as the toneless syllable.
    """
    if not reading:
        return ''
    marked = diacritic(reading, spaces=True)
    toneless = [strip_tone_digit(s) for s in reading.split(' ')]
    toneless = [s for s in toneless if s]
    spaced = ' '.join(toneless)
    squashed = ''.join(toneless).lower()
    parts = [reading]
    for extra in (marked, spaced):
        if extra and extra not in parts:
            parts.append(extra)
    if ' ' in reading and squashed and squashed not in parts:
        parts.append(squashed)
    return ' '.join(parts)
