#!/usr/bin/env python3
"""Download the dictionary sources into tools/dictbuild/sources/ (git-ignored)
and check them against sources.lock.json (committed).

  JMdict_e.gz           EDRDG, CC BY-SA 4.0   https://www.edrdg.org/pub/Nihongo/
  edicthdr.txt          EDRDG release header (date / entry count)
  jpn_indices.tar.bz2   Tatoeba, CC BY 2.0 FR https://downloads.tatoeba.org/exports/
  sentences.tar.bz2     Tatoeba (all languages; only jpn/eng rows are used)

  python3 fetch_sources.py                 # fetch what's missing, verify against the lock
  python3 fetch_sources.py --offline       # only verify the files already in sources/
  python3 fetch_sources.py --update-lock   # take whatever upstream serves now and rewrite the lock

All URLs are https.  They are "latest" URLs: EDRDG and Tatoeba overwrite the
files in place (JMdict daily, Tatoeba weekly), so a plain fetch fails as soon as
upstream publishes a new release.  A download is checked as sources/<name>.part
and only replaces the file in sources/ if it has the locked sha256 (or with
--update-lock); otherwise it is deleted and the locked copy is left alone.  That is deliberate: a refresh is an explicit
--update-lock + build + commit of the lock and the DBs together.  Keep a copy of
sources/ if you need to rebuild a given release byte for byte later.
KANJIDIC2 is not fetched: the app ships no kanji (card_type 2) cards.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import urllib.request
from email.utils import parsedate_to_datetime

HERE = os.path.dirname(os.path.abspath(__file__))
LOCK = os.path.join(HERE, 'sources.lock.json')
SOURCES = [
    ('JMdict_e.gz', 'https://www.edrdg.org/pub/Nihongo/JMdict_e.gz'),
    ('edicthdr.txt', 'https://www.edrdg.org/pub/Nihongo/edicthdr.txt'),
    ('jpn_indices.tar.bz2', 'https://downloads.tatoeba.org/exports/jpn_indices.tar.bz2'),
    ('sentences.tar.bz2', 'https://downloads.tatoeba.org/exports/sentences.tar.bz2'),
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def load_lock():
    with open(LOCK) as f:
        return json.load(f)


def verify(sources_dir, lock=None):
    """Raise SystemExit unless every locked file in sources_dir has the locked sha256."""
    lock = lock or load_lock()
    bad = []
    for name, want in lock['files'].items():
        path = os.path.join(sources_dir, name)
        got = sha256(path) if os.path.exists(path) else 'missing'
        if got != want['sha256']:
            bad.append('%s: expected %s, got %s' % (name, want['sha256'], got))
    if bad:
        raise SystemExit('Source files do not match sources.lock.json:\n  ' + '\n  '.join(bad) +
                         '\nUpstream publishes new releases under the same URLs; run '
                         'fetch_sources.py --update-lock to move to the current release.')
    return lock


def fetch(url, dest):
    """Download url to dest + '.part'; return (part path, Last-Modified).  Nothing in
    sources/ is touched: the caller decides whether the download may replace dest."""
    if not url.startswith('https://'):
        raise SystemExit('refusing non-https URL %s' % url)
    part = dest + '.part'
    req = urllib.request.Request(url, headers={'User-Agent': 'xflash-dictbuild/2.0'})
    with urllib.request.urlopen(req, timeout=120) as r, open(part, 'wb') as f:
        shutil.copyfileobj(r, f, 1 << 20)
        lm = r.headers.get('Last-Modified')
    return part, (parsedate_to_datetime(lm).isoformat() if lm else None)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--sources', default=os.path.join(HERE, 'sources'))
    ap.add_argument('--update-lock', action='store_true',
                    help='accept the files upstream serves now and rewrite sources.lock.json')
    ap.add_argument('--offline', action='store_true',
                    help="don't download; only verify the files already in --sources")
    a = ap.parse_args()
    os.makedirs(a.sources, exist_ok=True)
    old = load_lock() if os.path.exists(LOCK) else {'files': {}}
    if not a.update_lock and not old['files']:
        raise SystemExit('No sources.lock.json yet; run with --update-lock')

    files, rejected = {}, []
    for name, url in SOURCES:
        dest = os.path.join(a.sources, name)
        prev = old['files'].get(name, {})
        lm = prev.get('last_modified')
        if a.offline:
            pass
        elif not a.update_lock and os.path.exists(dest) and sha256(dest) == prev.get('sha256'):
            print('Already have the locked', name, file=sys.stderr)
        else:
            print('Fetching', url, file=sys.stderr)
            part, part_lm = fetch(url, dest)
            got = sha256(part)
            if a.update_lock or got == prev.get('sha256'):
                os.replace(part, dest)
                lm = part_lm
            else:
                # Upstream has moved on.  Never let the new release overwrite the locked
                # copy (it may be the only one left); throw the download away.
                os.remove(part)
                rejected.append('%s: upstream now serves sha256 %s (%s), lock has %s' % (
                    name, got, part_lm, prev.get('sha256')))
                if not os.path.exists(dest):
                    continue
        files[name] = {'url': url, 'bytes': os.path.getsize(dest), 'sha256': sha256(dest),
                       'last_modified': lm}
    if rejected:
        raise SystemExit('Downloads do not match sources.lock.json (kept the existing files):\n  ' +
                         '\n  '.join(rejected) + '\nRun fetch_sources.py --update-lock to move to '
                         'the current release.')
    with open(os.path.join(a.sources, 'edicthdr.txt'), 'rb') as f:
        hdr = f.read().decode('euc-jp', 'replace')
    m = re.search(r'Created: (\d{4}-\d{2}-\d{2})', hdr)
    new = {'jmdict_created': m.group(1) if m else None, 'files': files}

    if a.update_lock:
        with open(LOCK, 'w') as f:
            json.dump(new, f, indent=2)
            f.write('\n')
        print('Wrote', LOCK, file=sys.stderr)
    else:
        verify(a.sources, old)
        print('All sources match sources.lock.json', file=sys.stderr)
    print(json.dumps(new, indent=2))


if __name__ == '__main__':
    main()
