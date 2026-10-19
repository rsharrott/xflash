"""Tatoeba exports -> Japanese/English sentence pairs with Tanaka-style B-line indices."""

import re
import tarfile

_REF = re.compile(r'^(?P<w>[^(\[{~]+)(?:\((?P<r>[^)]*)\))?(?:\[(?P<s>\d+)\])?(?:\{(?P<f>[^}]*)\})?(?P<c>~)?$')

# Same stop list as the 2010 importer (_tanc_parser.rb): particles and very
# common function words are not linked to cards.
STOP_WORDS = set(["は", "か", "が", "に", "乃", "と", "だ", "へ", "です", "を", "私", "よ", "で", "も",
                  "には", "にも", "から", "しか", "でも", "より", "し", "ので", "たい", "ね", "な", "や",
                  "さ", "わ", "でしょう", "でした", "である", "為る", "為れる", "有る", "在る", "しまう",
                  "此の", "其の", "あの", "どの", "此処", "其処", "彼処", "此れ", "其れ", "何処", "何れ"])


def _lines(path):
    with tarfile.open(path, 'r:bz2') as t:
        for m in t:
            if not m.isfile():
                continue
            f = t.extractfile(m)
            for raw in f:
                yield raw.decode('utf-8').rstrip('\n')


def read_indices(path):
    """Yield (jpn_id, eng_id, refs, checked) from jpn_indices.tar.bz2.
    refs = [(word, reading, sense_number, checked)]"""
    for line in _lines(path):
        parts = line.split('\t')
        if len(parts) < 3:
            continue
        jid, eid, bline = int(parts[0]), int(parts[1]), parts[2]
        refs = []
        for tok in bline.split(' '):
            tok = tok.strip()
            if not tok:
                continue
            m = _REF.match(tok)
            if not m:
                continue
            w = m.group('w').strip()
            if not w or w in STOP_WORDS:
                continue
            refs.append((w, m.group('r') or '', int(m.group('s') or 0), bool(m.group('c'))))
        yield jid, eid, refs, '~' in bline


def read_sentences(path, wanted_ids):
    """Return {id: text} for the wanted sentence ids (jpn and eng only)."""
    out = {}
    for line in _lines(path):
        a = line.split('\t', 2)
        if len(a) < 3 or a[1] not in ('jpn', 'eng'):
            continue
        i = int(a[0])
        if i in wanted_ids:
            out[i] = a[2]
    return out
