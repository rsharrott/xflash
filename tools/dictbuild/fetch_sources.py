#!/usr/bin/env python3
"""Download the dictionary sources into tools/dictbuild/sources/ (git-ignored)
and record their dates and checksums in sources/manifest.json.

  JMdict_e.gz           EDRDG, CC BY-SA 4.0   https://www.edrdg.org/pub/Nihongo/
  edicthdr.txt          EDRDG release header (date / entry count)
  jpn_indices.tar.bz2   Tatoeba, CC BY 2.0 FR https://downloads.tatoeba.org/exports/
  sentences.tar.bz2     Tatoeba (all languages; only jpn/eng rows are used)

ftp.edrdg.org is often unreachable; www.edrdg.org serves the same /pub/Nihongo tree.
KANJIDIC2 is not fetched: the app ships no kanji (card_type 2) cards.
"""

import hashlib
import json
import os
import re
import shutil
import sys
import urllib.request
from email.utils import parsedate_to_datetime

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = [
    ('JMdict_e.gz', ['https://www.edrdg.org/pub/Nihongo/JMdict_e.gz',
                     'http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz']),
    ('edicthdr.txt', ['https://www.edrdg.org/pub/Nihongo/edicthdr.txt',
                      'http://ftp.edrdg.org/pub/Nihongo/edicthdr.txt']),
    ('jpn_indices.tar.bz2', ['https://downloads.tatoeba.org/exports/jpn_indices.tar.bz2']),
    ('sentences.tar.bz2', ['https://downloads.tatoeba.org/exports/sentences.tar.bz2']),
]


def fetch(name, urls, dest):
    last = None
    for url in urls:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'xflash-dictbuild/2.0'})
            with urllib.request.urlopen(req, timeout=60) as r, open(dest + '.part', 'wb') as f:
                shutil.copyfileobj(r, f, 1 << 20)
                lm = r.headers.get('Last-Modified')
            os.replace(dest + '.part', dest)
            return url, lm
        except Exception as e:  # try the next mirror
            last = e
            print('  %s failed: %s' % (url, e), file=sys.stderr)
    raise SystemExit('Could not download %s: %s' % (name, last))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'sources')
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, urls in SOURCES:
        dest = os.path.join(out, name)
        print('Fetching', name, file=sys.stderr)
        url, lm = fetch(name, urls, dest)
        h = hashlib.sha256()
        with open(dest, 'rb') as f:
            for chunk in iter(lambda: f.read(1 << 20), b''):
                h.update(chunk)
        manifest[name] = {
            'url': url, 'bytes': os.path.getsize(dest), 'sha256': h.hexdigest(),
            'last_modified': parsedate_to_datetime(lm).isoformat() if lm else None,
        }
    with open(os.path.join(out, 'edicthdr.txt'), 'rb') as f:
        hdr = f.read().decode('euc-jp', 'replace')
    m = re.search(r'Created: (\d{4}-\d{2}-\d{2})', hdr)
    manifest['edicthdr.txt']['created'] = m.group(1) if m else None
    with open(os.path.join(out, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=2)
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
