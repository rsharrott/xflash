package com.japaneseinaflash.app.help

/**
 * Help pages copied from the iOS bundle. Browse, multiple users, and
 * integration are left out because those parts of the app are not in this
 * version.
 */
object HelpPages {
    val shown = listOf(
        "welcome@2x.html",
        "studysets@2x.html",
        "practice@2x.html",
        "search@2x.html",
        "corrections@2x.html",
        "algorithm@2x.html",
        "tags@2x.html",
    )

    val omitted = listOf(
        "browse@2x.html",
        "share@2x.html",
        "integration@2x.html",
    )

    fun assetPath(file: String, japanese: Boolean): String =
        if (japanese) "file:///android_asset/help/ja/$file" else "file:///android_asset/help/$file"
}
