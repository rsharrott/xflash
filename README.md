xflash
======

This is the source codebase for Japanese Flash and Chinese Flash (jFlash/cFlash), two language learning applications created by Long Weekend LLC (LWE) and its respective members. As LWE is no longer trading, the original authors have decided to open-source the codebase. The application supported iOS and Android.

## Android

`android/` is the original 2012 Eclipse/Ant app. It targets API 8 and is kept only as a reference for the old SQL and practice logic. It does not build with current Android tools.

`android-app/` is the new Jetpack Compose app (search, with the 2.0 dictionary databases). See `android-app/README.md`.

Licence
=======
The source code is MIT licensed (see `LICENSE`). The bundled dictionary and
example-sentence data is not: JMdict/EDICT is CC BY-SA 4.0 (EDRDG) and the
Tatoeba sentences are CC BY 2.0 FR. See `jFlash/sql/DATA-LICENSE.md`, and
`tools/dictbuild/` for how the jFlash data is built.
Most iOS UI icons are Apple SF Symbols (system symbols, used under Apple's SF Symbols
licence; not bundled). The Android tab icons and the Fix Card menu icon are Google
Material Symbols (https://fonts.google.com/icons, Apache License 2.0).

Known Issues
============
An avid jFlash user contacted us in 2017 and told us that as of iOS11, only 64-bit applications would work. The last good binary of jFlash for iOS was compiled against iOS6 (we think), so will cease to operate with iOS11.

Any jFlash user that may be interested in bringing this project back to life, feel free to open a pull request to do so.

Help from the original authors
==============================
The original authors still work together and still even have jFlash on their phones (this particular individual still uses it to look up words).
While we are busy with other endeavours and cannot invest time in this project, as time permits, we can try to provide support if you have any questions about the codebase.

No doubt that there are cobwebs in there that need to be cleaned out.  ASIHTTPRequest is one I can think of. 
