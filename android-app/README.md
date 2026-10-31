# Japanese in a Flash! for Android

A new Jetpack Compose app. It searches the jFlash 2.0 dictionary (headword, reading, meaning, example sentences) and has an about screen for the data licences.

The 2012 Eclipse app in `android/` is legacy. It stays in the repo as a reference for the old SQL and practice logic. It is not built by this project. See `android/README.md`.

`applicationId` is `com.japaneseinaflash.app`. That is a placeholder for Ross to confirm before the first Play upload. The 2012 app used `com.longweekendmobile.android.xflash`. The id cannot be changed after the listing is published.

## Build

JDK 17 or newer (CI uses 21) and an Android SDK with platform `android-36` and build-tools `36.0.0`.

```sh
export ANDROID_HOME="$HOME/android-sdk"   # or wherever the SDK lives
cd android-app
./gradlew assembleDebug lint test
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. It is signed with the debug keystore only. There is no release key in this repo.

Android Studio (current stable, AGP 9.5 / Gradle 9.6, the Gradle version that AGP release asks for) can open this directory as the project root. Kotlin is 2.4.21. The Compose BOM is 2026.06.01 (Compose 1.11), not 2026.09.00: Compose 1.12 requires compileSdk 37, and this app is set to compileSdk 36. Lifecycle is 2.10.0 for the same reason.

### Where the databases come from

The app does not commit a second copy of the dictionary. `dictionary-sources.properties` points at the files `tools/dictbuild` already writes:

| asset in the APK | source |
|---|---|
| `jFlash.db` | `jFlash/sql/jFlash.db` |
| `jFlash-CARD-2.0.db` | `jFlash/sql/jFlash-CARD-2.0.db` |
| `jFlash-FTS-2.0.db` | `jFlash/sql/plugins/jFlash-FTS-2.0.db` |
| `jFlash-EX-2.0.db` | `jFlash/sql/plugins/jFlash-EX-2.0.db` |

`copyDictionaryDatabasesDebug` / `copyDictionaryDatabasesRelease` copy those into the build's generated assets. `./gradlew assembleDebug` runs the debug copy. The files are left compressed inside the APK (aapt's default). On disk they are 121,278,464 bytes (card 44,945,408, search 44,986,368, examples 30,461,952, user template 884,736). The debug APK that contains them is 66,624,491 bytes, about 64 MiB. The app cannot open a database inside the APK, so the first launch copies them out. Play Asset Delivery, below, is how to stop shipping them in the base module.

Table names match the legacy queries: `cards`, `cards_html`, `cards_search_content`, `sentences`, `card_sentence_link`. Search follows the iOS FTS query: the keyword is a bound `MATCH` argument, `?` in the box is the `*` wildcard, and rows are ordered by shortest `content`, then common-word `ptag`, then `card_id`.

On first launch the four files are copied into the app's database directory. `jFlash.db` is the writable user database and is not overwritten once it exists. CARD, FTS, and EX are attached read-only (`immutable=1`) under the names `CARD_DB`, `FTS_DB`, and `EX_DB`. They are copied again only when the plugin version in the app changes. Auto Backup is off so that copy is not uploaded. The copy needs about 180 MiB free.

## Tests

`./gradlew test` is JVM tests, not instrumented tests.

* Search-query tests check the FTS expression and the SQL text (bound `MATCH`, ranking, `should_show = 1`, the 10-sentence cap).
* Installer tests check "copy once", "do not clobber the user database", and "refresh the read-only files when the version stamp changes".
* A sqlite3 test runs the same SQL against the real 2.0 files and checks the user template does not define `cards` or `sentences` (those names have to resolve to the attached databases).
* A Robolectric test opens a small fixture through `android.database.sqlite`, attaches the three plugins, and checks ranking, example sentences, and that the card database rejects writes.

The real dictionary is not packed into the unit-test assets. `test` would otherwise decompress the whole dictionary on every run.

## What's next

This build is search and the licence screen.

* **Practice mode.** The legacy screen and the iOS card level / right-wrong counts in `user_history` are the reference. The user template already has those tables; this app opens it and does not write study progress yet.
* **Study sets.** Built-in membership is `system_card_tag_link` in the card database. User sets, groups, and tags are in `jFlash.db`.
* **Reminders.** The 2012 app scheduled a local notification. A new implementation would use WorkManager, not the old `AlarmManager` receiver.
* **Play Billing and subscriptions tied to web accounts.** Not started. There is no account system and no `INTERNET` permission in this build, which is what the Data safety answers below assume. Adding billing or accounts means a new permission, a new Data safety form, and a decision about how a web account maps to Play Billing.
* **Play Asset Delivery.** The dictionary makes the base module heavy. Move the three read-only databases (and, for a fresh install, the user template) into an install-time asset pack so they are on the device before first launch, and keep `jFlash.db` in app storage after the first copy. The Gradle copy task would then write the pack instead of base-module assets. Sideloading a debug APK would need a different story, because asset packs are delivered by Play.

## Play Console (for Ross)

1. Confirm `com.japaneseinaflash.app`, or switch it before the first upload. Create the app in Play Console with that id.
2. Enroll in Play App Signing. Generate an upload key locally. Do not commit the keystore or passwords.
3. Closed testing. For a personal Play Console account created under Google's closed-testing policy, production access requires a closed test with at least 12 testers who stay opted in for 14 consecutive days. Organization accounts have been exempt from that gate. Confirm which kind of account this listing uses before relying on the 12 / 14 rule.
4. Data safety. This build collects nothing and shares nothing. Search queries and the copied dictionary stay on the device. There are no accounts, ads, or analytics, and the manifest has no `INTERNET` permission. Say that in the form. Revisit the form when billing, accounts, or crash reporting is added.
5. Privacy policy URL: `https://japaneseinaflash.com/privacy`. The in-app About screen links to the same URL.
6. Content rating questionnaire, store listing, and the target API requirement. This project targets API 36. Confirm that still meets the current Play deadline.
7. Ship an Android App Bundle for Play. `assembleDebug` is the CI artifact; it is not the Play upload.

## Licences

The app source is MIT (`LICENSE` at the repo root). The dictionary is not.

* JMdict / EDICT (cards, meanings, and the search index) is CC BY-SA 4.0, Electronic Dictionary Research and Development Group. The files are a modified work; the modified data is shared under the same licence. EDRDG licence: https://www.edrdg.org/edrdg/licence.html . JMdict: https://www.edrdg.org/jmdict/j_jmdict.html .
* Core 1000 is the JMdict nf01 and nf02 bands (Mainichi Shimbun), not a separate word list, under the same CC BY-SA 4.0 licence.
* Example sentences are from the Tatoeba Project (originally the Tanaka Corpus), CC BY 2.0 FR: https://creativecommons.org/licenses/by/2.0/fr/ . Tatoeba: https://tatoeba.org .
* Details and the exact source dates are in `jFlash/sql/DATA-LICENSE.md`.

The About screen in the app carries the same attribution. Japanese UI copy can go in `app/src/main/res/values-ja/strings.xml` later; every user-visible string is already in `values/strings.xml`.
