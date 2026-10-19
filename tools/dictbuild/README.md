# dictbuild: Japanese in a Flash! dictionary data

Rebuilds the three read-only SQLite databases bundled with jFlash from current
open data, with the tables and columns the app reads:

| file | plugin key | contents |
|---|---|---|
| `jFlash/sql/jFlash-CARD-2.0.db` | `CARD_DB` 2.0 | `cards`, `cards_html`, `system_card_tag_link` (built-in sets), `version` |
| `jFlash/sql/plugins/jFlash-FTS-2.0.db` | `FTS_DB` 2.0 | full-text table `cards_search_content(card_id, content, ptag)` |
| `jFlash/sql/plugins/jFlash-EX-2.0.db` | `EX_DB` 2.0 | `sentences`, `card_sentence_link` (with `should_show`) |

It also refreshes the cached `tags.count` column in the user DB templates:
`jFlash/sql/jFlash.db`, and `jFlash/sql/jFlashJr.db` only if that file exists
(it goes away with the jFlashJr target). A template is rewritten only when a
count actually changes, so re-running the build leaves it byte-identical.

## Usage

```sh
cd tools/dictbuild
python3 fetch_sources.py   # download into sources/ (gitignored); fails unless the files match sources.lock.json
python3 build.py           # ~1 min; checks the lock again, writes the DBs and reports/build_report.json
```

Python 3.9+ standard library only (sqlite3 with FTS4, gzip, tarfile/bz2).
Building twice from the same sources produces byte-identical files.

### Sources and the lock file

`sources.lock.json` (committed) records the URL, size, sha256, Last-Modified
date and JMdict release date of every input. Both scripts refuse to run on files
that don't match it.

**The URLs are "latest" URLs that upstream overwrites in place** (JMdict is
regenerated daily, the Tatoeba exports weekly), so `fetch_sources.py` starts
failing as soon as a new release is published. That is intentional. To move to
the current release:

```sh
python3 fetch_sources.py --update-lock && python3 build.py
git add sources.lock.json reports/ ../../jFlash/sql/   # commit lock + DBs together
```

Neither project keeps old releases at these URLs. To be able to rebuild a given
release byte for byte later, keep a copy of `sources/`.
`python3 fetch_sources.py --offline` re-checks files you already have.

| source | URL | licence |
|---|---|---|
| JMdict_e (English-only JMdict) | https://www.edrdg.org/pub/Nihongo/JMdict_e.gz | CC BY-SA 4.0, EDRDG, https://www.edrdg.org/edrdg/licence.html |
| EDICT header (release date) | https://www.edrdg.org/pub/Nihongo/edicthdr.txt | |
| Tatoeba `jpn_indices` (B-lines, ex-Tanaka Corpus) | https://downloads.tatoeba.org/exports/jpn_indices.tar.bz2 | CC BY 2.0 FR |
| Tatoeba `sentences` (jpn + eng text) | https://downloads.tatoeba.org/exports/sentences.tar.bz2 | CC BY 2.0 FR |

Every URL is https; there are no plain-HTTP or ftp fallbacks. KANJIDIC2 is not
used, because the app has no kanji (card_type 2) cards.

The generated DBs are a derivative of JMdict and are therefore themselves
CC BY-SA 4.0. See `jFlash/sql/DATA-LICENSE.md`. The MIT licence of the code
does not cover them. The in-app Acknowledgements text
(`JapaneseSettingsDataSource.m`, `Localizable.strings`) carries the attribution
and licence links.

## Design notes

* **card_id = JMdict `ent_seq`** for dictionary cards (card_type 3), so ids stay
  stable across future JMdict releases. Hand-made cards keep their 1.x ids
  (< 1,000,000), which never collide with ent_seq values. JMdict's metadata
  pseudo-entry 9999999 is skipped.
* **XML safety**: the JMdict DTD may only contain simple internal entities
  (POS/misc codes). Each is rewritten to expand to its own name. Anything else
  (SYSTEM/PUBLIC/parameter entities) aborts the build.
* **Headword** = first kanji form that isn't a search-only (`sK`) form, else the
  first kana form. Readings are the kana forms that apply to that headword.
  `kana_only` = sense 1 is marked `uk`. `ptag` (common word) = any
  news1/ichi1/spec1/spec2/gai1 priority.
* **Meaning HTML** follows the 1.x format: `<ol><li>gloss / gloss<dfn>POS</dfn></li>…</ol>`
  for several senses, plain text for one, with the old POS labels (`cards.POS_LABELS`).
* **Search (FTS)**:
  * Content is `headword[; alt forms] [ readings / romaji ] glosses` (stop words
    removed). The space-less romaji is added only when it differs (multi-word readings).
  * The table is FTS4 with the same three columns as 1.x. `card_id` and `ptag` are
    `notindexed`, because the app only MATCHes text and reads them back, and
    `matchinfo=fts3` drops the unused docsize table. The app's queries
    (`… MATCH ? ORDER BY LENGTH(…), ptag DESC`) are unchanged. This took the file
    from 51.7 MB to under 45 MB, below GitHub's 50 MB warning.
  * Hand-made cards that duplicate a JMdict entry (same headword and readings)
    stay out of the search index, so search doesn't list such words twice.
    Studying their sets still shows them.
* **Example sentences**:
  * Each `jpn_indices` B-line word is resolved to a card by kanji or kana form,
    filtered by the given reading (or the `#ent_seq` disambiguator), preferring the
    exact headword, then common words. Words with more than 3 candidate cards are skipped.
  * Per card, the 10 best links (checked words first, then shorter sentences) get
    `should_show = 1`, and at most 20 links are kept.
  * `sentence_id` = Tatoeba Japanese sentence id.
* **Curated inputs** in `data/` hold what JMdict doesn't provide, and they are
  the source of truth for it. Edit them to change built-in sets.
  * `curated_cards.jsonl`: 343 word + 214 kana cards, plus every hand-made
    1.x card (id ≥ 145383) used by a set, copied verbatim from CARD 1.1.
  * `system_sets.tsv`: built-in study set membership.

## One-off 1.x → 2.0 migration

`migrate_legacy.py` produced `data/` from the 2010 EDICT-based 1.1 DBs. It
matched each legacy card to JMdict in this order:

1. exact
2. headword+reading, including katakana/hiragana
3. another legacy reading
4. unique headword, only if the English meanings overlap
5. reading-only, when the legacy kanji form was dropped, only with the same
   first gloss

Anything that fails these checks is **dropped rather than mis-mapped**.
Readings are split on `;`/`,` only, never on `、`, which is punctuation inside
phrase readings. Hand-made cards (id ≥ 145383) are never re-mapped.

The script also re-maps `card_tag_link`/`last_state` in the user DB templates
you pass with `--user-db`. A missing path is skipped, so you can leave out
`jFlashJr.db` once that target is removed. The results are in
`reports/legacy_match.md` (per-set counts) and `reports/legacy_unmatched.tsv`
(dropped memberships, plus the kept headword-/reading-only matches to review).
It doesn't need to run again. The usage line is in the script's docstring.

## Bumping versions

1. Change `VERSION` in `build.py` and rename the output files.
2. Update `jFlash/Plugins/jFlash-installed.plist` and the file references in
   `xFlash.xcodeproj` (and `jFlash/Tests/SetupDatabaseHelper.m`).

At launch the app re-registers the bundled plugins whenever the registered ones
point at missing files or older versions. See
`-[PluginManager bundledPluginsNeedRegistering:]`.
