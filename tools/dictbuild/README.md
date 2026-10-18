# dictbuild: Japanese in a Flash! dictionary data

Rebuilds the three read-only SQLite databases bundled with jFlash from current
open data, with the exact schemas the app reads:

| file | plugin key | contents |
|---|---|---|
| `jFlash/sql/jFlash-CARD-2.0.db` | `CARD_DB` 2.0 | `cards`, `cards_html`, `system_card_tag_link` (built-in sets), `version` |
| `jFlash/sql/plugins/jFlash-FTS-2.0.db` | `FTS_DB` 2.0 | FTS3 `cards_search_content(card_id, content, ptag)` |
| `jFlash/sql/plugins/jFlash-EX-2.0.db` | `EX_DB` 2.0 | `sentences`, `card_sentence_link` (with `should_show`) |

It also refreshes the cached `tags.count` column in the user DB templates
`jFlash/sql/jFlash.db` and `jFlashJr.db`.

## Usage

```sh
cd tools/dictbuild
python3 fetch_sources.py   # downloads into sources/ (gitignored) + sources/manifest.json
python3 build.py           # ~1 min; writes the DBs and reports/build_report.json
```

Python 3.9+ standard library only (sqlite3 with FTS3, gzip, tarfile/bz2).

## Sources and licences

| source | URL | licence |
|---|---|---|
| JMdict_e (English-only JMdict) | https://www.edrdg.org/pub/Nihongo/JMdict_e.gz | CC BY-SA 4.0, EDRDG, https://www.edrdg.org/edrdg/licence.html |
| Tatoeba `jpn_indices` (B-lines, ex-Tanaka Corpus) | https://downloads.tatoeba.org/exports/jpn_indices.tar.bz2 | CC BY 2.0 FR |
| Tatoeba `sentences` (jpn + eng text) | https://downloads.tatoeba.org/exports/sentences.tar.bz2 | CC BY 2.0 FR |

KANJIDIC2 is not used: the app has no kanji (card_type 2) cards. ftp.edrdg.org
is often unreachable; `fetch_sources.py` uses the https mirror first.

The generated DBs are a derivative of JMdict and are therefore themselves
CC BY-SA 4.0. The in-app Acknowledgements text (`JapaneseSettingsDataSource.m`,
`Localizable.strings`) carries the required attribution and licence links.

## Design notes

* **card_id = JMdict `ent_seq`** for dictionary cards (card_type 3), so ids stay
  stable across future JMdict releases. Hand-made cards keep their 1.x ids
  (< 1,000,000), which never collide with ent_seq values.
* **Headword** = first kanji form that isn't a search-only (`sK`) form, else the
  first kana form. Readings are the kana forms that apply to that headword.
  `kana_only` = sense 1 is marked `uk`. `ptag` (common word) = any
  news1/ichi1/spec1/spec2/gai1 priority.
* **Meaning HTML** follows the 1.x format: `<ol><li>gloss / gloss<dfn>POS</dfn></li>…</ol>`
  for several senses, plain text for one, with the old POS labels (`cards.POS_LABELS`).
* **FTS content** = `headword[; alt forms] [ readings / romaji / romaji-no-spaces ] glosses`
  (stop words removed), the format the app's `MATCH … ORDER BY LENGTH(content)` expects.
* **Example sentences**: each `jpn_indices` B-line word is resolved to a card by
  kanji or kana form, filtered by the given reading (or the `#ent_seq`
  disambiguator), preferring the exact headword then common words; words with
  more than 3 candidate cards are skipped. Per card the 10 best links (checked
  words first, then shorter sentences) get `should_show = 1`; at most 20 links are kept.
  `sentence_id` = Tatoeba Japanese sentence id.
* **Curated inputs** in `data/` are the source of truth for things JMdict doesn't
  provide: `curated_cards.jsonl` (343 word + 214 kana cards and 293 LWE
  hand-made phrase cards, copied verbatim from CARD 1.1) and `system_sets.tsv`
  (built-in study set membership). Edit these to change built-in sets.

## One-off 1.x → 2.0 migration

`migrate_legacy.py` produced `data/` from the 2010 EDICT-based 1.1 DBs by
matching each legacy card to JMdict by headword+reading (exact →
headword+reading incl. katakana/hiragana → other reading → unique headword →
reading-only when the legacy kanji form was dropped). It also re-mapped
`card_tag_link`/`last_state` in the user DB templates. Results:
`reports/legacy_match.md` (per-set counts) and `reports/legacy_unmatched.tsv`
(dropped and low-confidence memberships). It does not need to be run again;
the usage line is in the script's docstring.

## Bumping versions

Change `VERSION` in `build.py`, rename the output files, and update
`jFlash/Plugins/jFlash-installed.plist`, `LWE_CURRENT_CARD_DATABASE` in
`Constants.m` and the file references in `xFlash.xcodeproj`. Plugins from the
installed plist are registered only on first launch, so test with a fresh install.
