"""Turn JMdict entries into jFlash card rows (same column formats as the
2010 importer in importer/lib/tasks/tedilib3)."""

import html
import re

from jmdict import COMMON_PRI
from romaji import kana_to_romaji

CARD_TYPE_WORD, CARD_TYPE_KANA, CARD_TYPE_DICTIONARY = 0, 1, 3

# JMdict part-of-speech code -> the short labels the 1.x data used in <dfn>.
POS_LABELS = {
    'n': 'noun', 'n-adv': 'adv noun', 'n-t': 'temporal noun', 'n-suf': 'noun suffix',
    'n-pref': 'prefix noun', 'n-pr': 'proper noun', 'pn': 'pronoun',
    'adj-i': 'い adj', 'adj-ix': 'い adj (いい/よい)', 'adj-na': 'な adj', 'adj-no': 'の adj',
    'adj-t': 'たる adj', 'adj-pn': 'prenoun adj', 'adj-f': 'prenom v/adv',
    'adj-ku': '~く adj (arch)', 'adj-shiku': '~しく adj (arch)', 'adj-nari': '~なり adj (arch)',
    'adj-kari': '~かり adj (arch)',
    'adv': 'adverb', 'adv-to': '~と adverb',
    'aux': 'aux', 'aux-v': 'aux verb', 'aux-adj': 'aux adj', 'cop': 'copula',
    'conj': 'conjunction', 'ctr': 'counter', 'exp': 'expression', 'int': 'interjection',
    'num': 'numeric', 'pref': 'prefix', 'suf': 'suffix', 'prt': 'particle',
    'v1': 'verb L1', 'v1-s': 'verb L1 sp', 'vz': '~ずる verb L1',
    'v5aru': '~ある verb L5', 'v5b': '~ぶ verb L5', 'v5g': '~ぐ verb L5', 'v5k': '~く verb L5',
    'v5k-s': '~(い/ゆ)く verb L5', 'v5m': '~む verb L5', 'v5n': '~ぬ verb L5',
    'v5r': '~る verb L5', 'v5r-i': '~る verb irr L5', 'v5s': '~す verb L5',
    'v5t': '~つ verb L5', 'v5u': '~う verb L5', 'v5u-s': '~う verb L5 sp',
    'v5uru': '~うる verb L5',
    'vk': '~くる verb sp', 'vn': '~ぬ verb irr', 'vr': '~り verb irr',
    'vs': '~する verb reg', 'vs-s': '~する verb sp', 'vs-i': '~する verb irr',
    'vs-c': '~す verb (arch)', 'vt': 'verb trans', 'vi': 'verb intrans',
    'v-unspec': 'verb',
}
# Archaic yodan/nidan verbs: "~る verb L4", "~ぶ verb L2" ...
_END = {'b': 'ぶ', 'g': 'ぐ', 'h': 'ふ', 'k': 'く', 'm': 'む', 'n': 'ぬ', 'r': 'る',
        's': 'す', 't': 'つ', 'u': 'う', 'a': 'う', 'w': 'う', 'y': 'ゆ', 'z': 'ず', 'd': 'づ'}
SKIP_POS = {'unc'}

STOP_WORDS = {'I', 'me', 'a', 'an', 'am', 'are', 'as', 'at', 'be', 'by', 'how', 'in', 'is',
              'it', 'of', 'on', 'or', 'that', 'than', 'the', 'this', 'to', 'was', 'what',
              'when', 'where', 'who', 'will', 'with'}


def pos_label(code):
    if code in POS_LABELS:
        return POS_LABELS[code]
    m = re.match(r'v([24])([a-z])(?:-[ks])?$', code)
    if m:
        return '~%s verb L%s' % (_END.get(m.group(2), m.group(2)), m.group(1))
    return code


def is_kana(text):
    return all(0x3040 <= ord(c) <= 0x30FF or c in 'ー・〜' for c in text)


def _is_common(pri):
    return bool(COMMON_PRI.intersection(pri))


def remove_stop_words(text):
    out = []
    for w in text.split(' '):
        if re.sub(r'[^a-zA-Z|\s]', '', w).strip() in STOP_WORDS:
            continue
        out.append(w)
    return ' '.join(x for x in out if x)


def entry_forms(e):
    """All written forms of an entry (incl. search-only), for matching."""
    return [k['text'] for k in e['k']], [r['text'] for r in e['r']]


def build_card(e):
    """Return a dict with the CARD/FTS columns for one JMdict entry."""
    kebs = [k for k in e['k'] if 'sK' not in k['inf']] or e['k']
    rebs = [r for r in e['r'] if 'sk' not in r['inf']] or e['r']
    if kebs:
        hw = kebs[0]
        readings = [r for r in rebs if not r['nokanji'] and
                    (not r['restr'] or hw['text'] in r['restr'])] or rebs
        alt = [k['text'] for k in kebs[1:]]
    else:
        hw = rebs[0]
        readings = rebs
        alt = []
    reading_texts = [r['text'] for r in readings]
    extra_readings = [r['text'] for r in rebs if r['text'] not in reading_texts]
    romaji = [kana_to_romaji(r) for r in reading_texts]
    common = _is_common(hw['pri']) or _is_common(readings[0]['pri'])
    kana_only = 1 if (kebs and e['s'] and 'uk' in e['s'][0]['misc']) else 0

    html_items, fts_items = [], []
    for s in e['s']:
        glosses = ' / '.join(g.strip() for g in s['gloss'])
        if not glosses:
            continue
        text = html.escape(glosses, quote=False)
        if s['inf']:
            text += ' (' + html.escape('; '.join(s['inf']), quote=False) + ')'
        labels = [pos_label(p) for p in s['pos'] if p not in SKIP_POS]
        text += ''.join('<dfn>%s</dfn>' % html.escape(l, quote=False) for l in labels)
        html_items.append(text)
        fts_items.append(glosses)
    if len(html_items) > 1:
        meaning = '<ol>' + ''.join('<li>%s</li>' % t for t in html_items) + '</ol>'
    else:
        meaning = html_items[0] if html_items else ''
    headword_en = e['s'][0]['gloss'][0] if e['s'] and e['s'][0]['gloss'] else ''

    reading_str = '; '.join(reading_texts)
    romaji_str = '; '.join(romaji)
    headword_part = '; '.join([hw['text']] + alt)
    content = '%s [ %s / %s / %s ] %s' % (headword_part, reading_str, romaji_str,
                                          romaji_str.replace(' ', ''),
                                          remove_stop_words('; '.join(fts_items)))
    if extra_readings:
        content += ' ; ' + ' '.join(extra_readings)
    return {
        'card_id': e['seq'], 'card_type': str(CARD_TYPE_DICTIONARY),
        'headword': hw['text'], 'headword_en': headword_en, 'reading': reading_str,
        'romaji': romaji_str, 'kana_only': kana_only, 'meaning': meaning,
        'content': content, 'ptag': 1 if common else 0,
    }
