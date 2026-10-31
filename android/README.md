# Legacy Android app

This directory is the 2012 Eclipse/Ant Java app (`target=android-8` in
`project.properties`, package `com.longweekendmobile.android.xflash`). It
cannot be built with current Android tools. It is kept as a reference for
the original SQL queries and practice logic. Do not add features here, and
do not delete it.

The current Android app is [`android-app/`](../android-app/README.md). It reads
the jFlash 2.0 databases (`jFlash-CARD-2.0.db`, `jFlash-FTS-2.0.db`,
`jFlash-EX-2.0.db`, and the `jFlash.db` user template). Those files use the
same table names this code queries.
