#!/usr/bin/env python3
"""Download CC-CEDICT into tools/dictbuild_zh/sources/ (git-ignored) and check
it against sources.lock.json (committed).

  python3 fetch_sources.py                 # fetch if missing, verify the lock
  python3 fetch_sources.py --offline       # only verify the file already there
  python3 fetch_sources.py --update-lock   # take whatever MDBG serves and rewrite the lock

The URL is the "latest" file MDBG overwrites in place. A plain fetch fails
as soon as a new release is published. That is deliberate: moving to a new
release is --update-lock, then build.py, then a commit of the lock and the
databases together. Keep a copy of sources/ to rebuild one release later.
"""

import argparse
import gzip
import hashlib
import json
import os
import shutil
import sys
import urllib.request
from email.utils import parsedate_to_datetime

HERE = os.path.dirname(os.path.abspath(__file__))
LOCK = os.path.join(HERE, 'sources.lock.json')
SOURCE_NAME = 'cedict_1_0_ts_utf-8_mdbg.txt.gz'
SOURCE_URL = 'https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz'


def sha256(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def load_lock():
    with open(LOCK, encoding='utf-8') as handle:
        return json.load(handle)


def header_meta(path):
    """#! date= and #! entries= from the gzip (or plain) CEDICT header."""
    opener = gzip.open if path.endswith('.gz') else open
    meta = {}
    with opener(path, 'rt', encoding='utf-8') as handle:
        for line in handle:
            if line.startswith('#! '):
                key, _, value = line[3:].strip().partition('=')
                meta[key] = value
            elif not line.startswith('#'):
                break
    return meta


def verify(sources_dir, lock=None):
    """Raise SystemExit unless sources_dir holds the locked CEDICT file."""
    lock = lock or load_lock()
    bad = []
    for name, want in lock['files'].items():
        path = os.path.join(sources_dir, name)
        got = sha256(path) if os.path.exists(path) else 'missing'
        if got != want['sha256']:
            bad.append('%s: expected %s, got %s' % (name, want['sha256'], got))
    if bad:
        raise SystemExit(
            'Source files do not match sources.lock.json:\n  ' + '\n  '.join(bad) +
            '\nMDBG publishes new releases under the same URL; run '
            'fetch_sources.py --update-lock to move to the current release.')
    return lock


def fetch(url, dest):
    if not url.startswith('https://'):
        raise SystemExit('refusing non-https URL %s' % url)
    part = dest + '.part'
    req = urllib.request.Request(url, headers={'User-Agent': 'xflash-dictbuild-zh/2.0'})
    with urllib.request.urlopen(req, timeout=120) as response, open(part, 'wb') as handle:
        shutil.copyfileobj(response, handle, 1 << 20)
        modified = response.headers.get('Last-Modified')
    return part, (parsedate_to_datetime(modified).isoformat() if modified else None)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sources', default=os.path.join(HERE, 'sources'))
    parser.add_argument('--update-lock', action='store_true',
                        help='accept the file upstream serves now and rewrite sources.lock.json')
    parser.add_argument('--offline', action='store_true',
                        help="don't download; only verify the file already in --sources")
    args = parser.parse_args()
    os.makedirs(args.sources, exist_ok=True)
    old = load_lock() if os.path.exists(LOCK) else {'files': {}}
    if not args.update_lock and not old.get('files'):
        raise SystemExit('No sources.lock.json yet; run with --update-lock')

    dest = os.path.join(args.sources, SOURCE_NAME)
    prev = old.get('files', {}).get(SOURCE_NAME, {})
    modified = prev.get('last_modified')
    if args.offline:
        if not os.path.exists(dest):
            raise SystemExit('missing %s' % dest)
    elif not args.update_lock and os.path.exists(dest) and sha256(dest) == prev.get('sha256'):
        print('Already have the locked', SOURCE_NAME, file=sys.stderr)
    else:
        print('Fetching', SOURCE_URL, file=sys.stderr)
        part, part_modified = fetch(SOURCE_URL, dest)
        got = sha256(part)
        if args.update_lock or got == prev.get('sha256'):
            os.replace(part, dest)
            modified = part_modified
        else:
            os.remove(part)
            raise SystemExit(
                'Download does not match sources.lock.json (kept the existing file):\n  %s: '
                'upstream now serves sha256 %s (%s), lock has %s\n'
                'Run fetch_sources.py --update-lock to move to the current release.' % (
                    SOURCE_NAME, got, part_modified, prev.get('sha256')))
    meta = header_meta(dest)
    record = {
        'cedict_date': meta.get('date'),
        'cedict_entries': int(meta['entries']) if meta.get('entries', '').isdigit() else None,
        'files': {
            SOURCE_NAME: {
                'url': SOURCE_URL,
                'bytes': os.path.getsize(dest),
                'sha256': sha256(dest),
                'last_modified': modified,
            },
        },
    }
    if args.update_lock:
        with open(LOCK, 'w', encoding='utf-8') as handle:
            json.dump(record, handle, indent=2)
            handle.write('\n')
        print('Wrote', LOCK, file=sys.stderr)
    else:
        verify(args.sources, old)
        print('All sources match sources.lock.json', file=sys.stderr)
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
