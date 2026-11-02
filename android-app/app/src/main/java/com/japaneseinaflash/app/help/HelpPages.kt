package com.japaneseinaflash.app.help

/**
 * Help pages copied from the iOS bundle. Browse, corrections, sharing,
 * multiple users, and integration are left out because those parts of the
 * app are not in this version.
 */
object HelpPages {
    const val ASSET_HOST = "appassets.androidplatform.net"

    val shown = listOf(
        "welcome@2x.html",
        "studysets@2x.html",
        "practice@2x.html",
        "search@2x.html",
        "algorithm@2x.html",
        "tags@2x.html",
    )

    val omitted = listOf(
        "browse@2x.html",
        "corrections@2x.html",
        "share@2x.html",
        "integration@2x.html",
    )

    fun assetPath(file: String, japanese: Boolean): String {
        val relative = if (japanese) "help/ja/$file" else "help/$file"
        return "https://$ASSET_HOST/assets/$relative"
    }
}

/** Appended to help.css when Paper is in dark mode. Values are the app's dark tokens. */
internal const val HELP_DARK_CSS =
    ":root { color-scheme: dark; --ink:#FBF8F3; --ink-2:#CFC6B8; --paper:#1D1A16; " +
        "--paper-2:#29241F; --line:#4A433B; --fire:#F2826E; }"
