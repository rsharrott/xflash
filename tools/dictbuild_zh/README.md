# dictbuild_zh: Chinese in a Flash dictionary data

Rebuilds the read-only SQLite databases bundled with cFlash from the pinned
CC-CEDICT release. The tables are the ones the app reads.

| file | plugin key | contents |
|---|---|---|
| `jFlash/sql/cFlash-CARD-2.0.db` | `CF_CARD_DB` 2.0 | `cards`, `cards_html`, `system_card_tag_link`, `version` |
| `jFlash/sql/plugins/cFlash-FTS-2.0.db` | `FTS_DB` 2.0 | `cards_search_content(card_id, headword, reading, content, ptag)` |
| `jFlash/sql/cFlash.db` | `USER_DB` 1.0 | user template; only `tags.count` is refreshed |

Version **2.0** is this dictionary generation, the same kind of step jFlash
took from the 2010 EDICT build to JMdict. The app compares that version when
it decides a bundled plugin is newer. The user template stays 1.0: its tables
did not change, and the revived app has a new bundle id, so there are no old
installs to migrate. The bundle id itself is not changed here.

Search ships in the app bundle (`cFlash-installed.plist`, file location 0).
Remote plugin downloads are off, so a search index that existed only as a
download would never load.

## Usage

```sh
cd tools/dictbuild_zh
python3 fetch_sources.py   # download into sources/ (gitignored); fails unless the file matches sources.lock.json
python3 build.py           # writes the DBs, data/id_map.tsv, and reports/build_report.json
python3 -m unittest -v     # unit tests; the built-database checks run when the DBs are present
```

Python 3.9+ standard library only. Building twice from the same sources and
the committed id map produces byte-identical database files.

### Source and the lock file

`sources.lock.json` records the URL, size, sha256 and CC-CEDICT release date.
Both scripts refuse a file that does not match it. The URL is MDBG's "latest"
file, which is overwritten in place, so a plain fetch fails when a new
release is published. To move to that release:

```sh
python3 fetch_sources.py --update-lock && python3 build.py
```

Commit the lock, `data/id_map.tsv` and the databases together.

| source | URL | licence |
|---|---|---|
| CC-CEDICT (MDBG), traditional/simplified UTF-8 | https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz | CC BY-SA 4.0 |

The generated databases are a derivative of CC-CEDICT and are themselves
CC BY-SA 4.0. See `jFlash/sql/DATA-LICENSE.md`. The MIT licence of the code
does not cover them.

## What the build keeps from the 2011 importer

* **cards.reading** is numbered pinyin with `ü` (`nü3`), neutral tone `5`
  (`r5`), and capitals for proper nouns (`Wei1 xin4`). `u:` and a bare
  lowercase `v` become `ü`. A syllable run glued together (`shi2ke4`) is
  split so each tone digit is its own syllable and tone colouring still works.
* **Meaning HTML** is plain text for one gloss and `<ol><li>…</li></ol>` for
  several. Full-match tags such as `(math.)` are removed. `CL:` measure words
  become `Counter: …` lines.
* **Search text** drops the same English stop words. The FTS `reading` column
  stores numbered pinyin, tone marks, toneless syllables, and the syllables
  run together, so `wei2 xin4`, `wēi xìn`, `wei xin` and `weixin` all match.
* **Erhua forms are their own cards**, including a line that is only
  "erhua variant of …" (一点儿). A see / variant line with no gloss of its
  own is not a card; it becomes an `Also:` note on the target. Variants that
  have a gloss link both ways (`Has Erhua variant` / `Erhua variant of`).
* **ptag** is 1 when the card sits in a set the 2011 importer marked
  `contains_priority_words`: HSK 2.0, TOCFL, the Jun Da character lists, and
  the news/fiction bigram lists. `study_sets.PRIORITY_TAG_IDS` is the list.

## Stable ids

`data/id_map.tsv` is the source of truth, keyed on
`(traditional, simplified, pinyin)`. The first build copied ids out of
`cFlash-CARD-1.0.db`:

1. exact key
2. same characters, pinyin changed, only when that pair is one old card and one new card
3. same simplified + pinyin, traditional changed, same one-to-one rule
4. same traditional + pinyin, simplified changed, same one-to-one rule

Anything else new gets an id at or above 1,000,000, in CEDICT file order.
A key that leaves the dictionary stays in the map, so if it comes back it
gets the same id. A later `build.py` only appends ids; it does not renumber.

## Study sets

`data/system_sets.tsv` is the 2011 link table (`tag_id`, `card_id`) in study
order. Rows whose card is gone from CEDICT are dropped at build time and
counted in `reports/build_report.json`. `tags.count` in `cFlash.db` is
rewritten from the links that remain. Long Weekend Favorites is editable, so
its rows live in `card_tag_link`; a favorite whose card disappeared is removed.

HSK 2.0 stays. Removing it, and adding HSK 3.0, is a later change.

## Later pulls

**HSK 3.0.** Add `data/hsk30_sets.tsv` with the same two columns. `study_sets.py`
appends it. Put any new tag ids that should rank as common words into
`PRIORITY_TAG_IDS`. New cards are whatever ids `id_map.tsv` already assigned.

**Tatoeba.** Not built. The Japanese pipeline writes an EX database
(`sentences`, `card_sentence_link`) and the app attaches it as `EX_DB`.
A Chinese EX build should do the same, joining example words to the card ids
in `id_map.tsv`. `build.py` does not write an EX file and the installed
plugin list does not mention one, so nothing here has to be undone to add it.
