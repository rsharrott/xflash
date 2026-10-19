"""Streaming JMdict (JMdict_e) parser.

JMdict encodes part-of-speech and misc codes as XML entities whose
replacement text is a long English description.  We rewrite the DTD so each
entity expands to its own name (e.g. &v1; -> "v1"), which keeps the short
codes the jFlash formatter needs, and keep the descriptions for fallbacks."""

import gzip
import io
import re
import xml.etree.ElementTree as ET

_ENTITY_RE = re.compile(r'<!ENTITY\s+(\S+)\s+"([^"]*)">')
COMMON_PRI = {'news1', 'ichi1', 'spec1', 'spec2', 'gai1'}  # = EDICT "(P)"
METADATA_SEQ = 9999999   # JMdict's pseudo-entry carrying the release date, not a word


def _safe_dtd(dtd):
    """Rewrite every entity to expand to its own name, and refuse anything else.

    The only declarations JMdict has are plain internal general entities
    (<!ENTITY v1 "Ichidan verb">).  External (SYSTEM/PUBLIC) or parameter (%)
    entities, or any declaration the simple pattern doesn't cover, abort the
    build instead of being handed to the XML parser.  After the rewrite each
    entity expands to its own short name, so nothing can expand recursively
    (no billion-laughs)."""
    declared = len(re.findall(r'<!ENTITY', dtd))
    if declared != len(_ENTITY_RE.findall(dtd)) or re.search(r'<!ENTITY\s+%|SYSTEM|PUBLIC', dtd):
        raise ValueError('JMdict DTD has entity declarations other than simple internal ones; refusing to parse')
    # Every value (including any '&other;' references) is replaced by the bare name.
    return _ENTITY_RE.sub(lambda m: '<!ENTITY %s "%s">' % (m.group(1), m.group(1)), dtd)


def read_header(path):
    """Return (created_date, entity_descriptions) from the DTD header."""
    with gzip.open(path, 'rt', encoding='utf-8') as f:
        head = []
        for line in f:
            head.append(line)
            if line.startswith(']>'):
                break
        rest = f.read(2000)
    text = ''.join(head)
    ents = dict(_ENTITY_RE.findall(text))
    m = re.search(r'JMdict created: (\d{4}-\d{2}-\d{2})', text + rest)
    return (m.group(1) if m else None), ents


def iter_entries(path):
    with gzip.open(path, 'rb') as f:
        raw = f.read()
    split = raw.index(b']>') + 2
    dtd = _safe_dtd(raw[:split].decode('utf-8')).encode('utf-8')
    data = io.BytesIO(dtd + raw[split:])
    del raw
    for event, el in ET.iterparse(data, events=('end',)):
        if el.tag != 'entry':
            continue
        e = {'seq': int(el.findtext('ent_seq')), 'k': [], 'r': [], 's': []}
        if e['seq'] == METADATA_SEQ:
            el.clear()
            continue
        for k in el.findall('k_ele'):
            e['k'].append({
                'text': k.findtext('keb'),
                'inf': [x.text for x in k.findall('ke_inf')],
                'pri': [x.text for x in k.findall('ke_pri')],
            })
        for r in el.findall('r_ele'):
            e['r'].append({
                'text': r.findtext('reb'),
                'nokanji': r.find('re_nokanji') is not None,
                'restr': [x.text for x in r.findall('re_restr')],
                'inf': [x.text for x in r.findall('re_inf')],
                'pri': [x.text for x in r.findall('re_pri')],
            })
        for s in el.findall('sense'):
            e['s'].append({
                'pos': [x.text for x in s.findall('pos')],
                'misc': [x.text for x in s.findall('misc')],
                'field': [x.text for x in s.findall('field')],
                'stagk': [x.text for x in s.findall('stagk')],
                'stagr': [x.text for x in s.findall('stagr')],
                'inf': [x.text for x in s.findall('s_inf')],
                'gloss': [x.text for x in s.findall('gloss') if x.text],
            })
        el.clear()
        yield e
