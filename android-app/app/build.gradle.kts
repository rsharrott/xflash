import com.android.build.api.variant.ApplicationAndroidComponentsExtension
import org.gradle.api.GradleException
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import java.io.File
import java.security.MessageDigest
import java.util.Locale

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.compiler)
}

// The jFlash 2.0 databases stay where dictbuild writes them. This task copies
// those files into a generated assets directory for the APK only. They are
// left compressed (aapt's default): gzip takes the ~116 MiB of SQLite down to
// about half, and the app copies them out of assets on first launch anyway.
// Play Asset Delivery is the follow-up that pulls them back out of the base
// module. See android-app/README.md.

data class DictionarySource(val role: String, val assetName: String, val file: File)

fun loadDictionarySources(): List<DictionarySource> {
    val manifest = rootProject.file("dictionary-sources.properties")
    if (!manifest.isFile) {
        throw GradleException("Missing $manifest")
    }
    return manifest.readLines().mapNotNull { raw ->
        val line = raw.substringBefore("#").trim()
        if (line.isEmpty()) {
            return@mapNotNull null
        }
        val parts = line.split("=", limit = 3)
        if (parts.size != 3) {
            throw GradleException("Bad dictionary source line: $raw")
        }
        val role = parts[0].trim()
        val assetName = parts[1].trim()
        val relative = parts[2].trim()
        if (role != "user" && role != "plugin") {
            throw GradleException("Unknown dictionary role '$role' in $raw")
        }
        val file = rootProject.file(relative)
        if (file.name != assetName) {
            throw GradleException("Asset name $assetName does not match ${file.name}")
        }
        DictionarySource(role, assetName, file)
    }
}

val dictionarySources = loadDictionarySources()
if (dictionarySources.count { it.role == "user" } != 1) {
    throw GradleException("dictionary-sources.properties needs exactly one user database")
}

abstract class CopyDictionaryDatabasesTask : DefaultTask() {
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val sourceFiles: ConfigurableFileCollection

    @get:OutputDirectory
    abstract val outputDirectory: DirectoryProperty

    @TaskAction
    fun copy() {
        val dest = outputDirectory.get().asFile
        dest.deleteRecursively()
        dest.mkdirs()
        val files = sourceFiles.files.sortedBy { it.name }
        if (files.isEmpty()) {
            throw GradleException("No dictionary databases were configured")
        }
        val digest = MessageDigest.getInstance("SHA-256")
        val sizes = sortedMapOf<String, Long>()
        files.forEach { src ->
            if (!src.isFile) {
                throw GradleException("Missing dictionary database: ${src.absolutePath}")
            }
            digest.update(src.name.toByteArray(Charsets.UTF_8))
            digest.update(0)
            var total = 0L
            src.inputStream().use { input ->
                dest.resolve(src.name).outputStream().use { output ->
                    val buffer = ByteArray(1024 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        total += read
                    }
                }
            }
            sizes[src.name] = total
            logger.lifecycle("Dictionary asset ${src.name}: $total bytes")
        }
        val stamp = digest.digest().joinToString("") { "%02x".format(it) }
        // Same text format as parseAssetManifest / DictionaryFiles.MANIFEST.
        val manifest = buildString {
            append("stamp ").append(stamp).append('\n')
            sizes.forEach { (name, size) ->
                append("size ").append(name).append(' ').append(size).append('\n')
            }
        }
        dest.resolve("dictionary-manifest.txt").writeText(manifest)
        logger.lifecycle("Dictionary manifest stamp $stamp")
    }
}

abstract class CopyHelpAssetsTask : DefaultTask() {
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sourceDirectory: DirectoryProperty

    @get:OutputDirectory
    abstract val outputDirectory: DirectoryProperty

    @TaskAction
    fun copy() {
        val source = sourceDirectory.get().asFile
        val dest = outputDirectory.get().asFile.resolve("help")
        dest.deleteRecursively()
        val pages = listOf(
            "welcome@2x.html",
            "studysets@2x.html",
            "practice@2x.html",
            "search@2x.html",
            "algorithm@2x.html",
            "tags@2x.html",
        )
        val images = listOf(
            "practice-progress-bar-en.png",
            "practice-progress-bar-ja.png",
            "practice-progress-popup-en.png",
            "practice-progress-popup-ja.png",
            "studysets-list-en.png",
            "studysets-list-ja.png",
            "algorithm-difficulty-en.png",
            "algorithm-difficulty-ja.png",
            "search-results-en.png",
            "search-results-ja.png",
        )
        pages.forEach { name ->
            writeAdapted(source.resolve(name), dest.resolve(name), name)
            writeAdapted(source.resolve("ja").resolve(name), dest.resolve("ja").resolve(name), "ja/$name")
        }
        writeAdapted(source.resolve("help.css"), dest.resolve("help.css"), "help.css")
        val img = dest.resolve("img")
        img.mkdirs()
        images.forEach { name ->
            source.resolve("img").resolve(name).copyTo(img.resolve(name))
        }
    }

    private fun writeAdapted(from: File, to: File, relative: String) {
        check(from.isFile) { "Missing help source $from" }
        to.parentFile.mkdirs()
        to.writeText(adaptHelp(relative, from.readText()))
    }

    /** Android copies only. The iOS originals stay as they are. */
    private fun adaptHelp(relative: String, text: String): String {
        var out = text
        when (relative) {
            "practice@2x.html" -> {
                out = dropParagraph(
                    out,
                    "<p>Already know a card? Tap <strong>Learned</strong> to mark it learned " +
                        "(the same as the Learned progress column). With <strong>Hide Learned Cards</strong> " +
                        "on in Difficulty settings, those cards stop coming up in practice.</p>",
                )
                out = dropParagraph(
                    out,
                    "<p>Tap <strong>Actions</strong> to add the card to a study set, share it, " +
                        "or report a mistake with <strong>Fix Card</strong>.</p>",
                )
            }
            "ja/practice@2x.html" -> {
                out = dropParagraph(
                    out,
                    "<p>もう知っているカードは「<strong class=\"nw\">もう覚えた</strong>」をタップすると" +
                        "「<strong class=\"nw\">覚えた</strong>」レベルに移ります。難易度設定の" +
                        "「<strong class=\"nw\">覚えたカードを隠す</strong>」をオンにすると、練習に出なくなります。</p>",
                )
                out = dropParagraph(
                    out,
                    "<p><strong class=\"nw\">アクション</strong>をタップすると、カードを学習セットに追加したり、" +
                        "シェアしたり、「<strong class=\"nw\">誤りを報告</strong>」で知らせたりできます。</p>",
                )
            }
            "studysets@2x.html" -> {
                val from = "To add new words to your new set, you can use <strong>Search</strong>, " +
                    "or you can also add cards to a set from another set using the <strong>Actions</strong> button."
                val to = "To add new words to your new set, you can use <strong>Search</strong>."
                check(out.contains(from)) { "studysets Actions clause missing" }
                out = out.replace(from, to)
            }
            "ja/studysets@2x.html" -> {
                val from = "新しいセットに単語を追加するには、<strong class=\"nw\">検索</strong>を使うか、" +
                    "ほかのセットのカードから<strong class=\"nw\">アクション</strong>ボタンで追加します。"
                val to = "新しいセットに単語を追加するには、<strong class=\"nw\">検索</strong>を使います。"
                check(out.contains(from)) { "studysets Actions clause missing" }
                out = out.replace(from, to)
            }
            "help.css" -> {
                check(out.contains("font: -apple-system-body;")) { "help.css font shorthand missing" }
                out = out.replace("  font: -apple-system-body;\n", "")
            }
        }
        return out
    }

    private fun dropParagraph(text: String, paragraph: String): String {
        val indented = "  $paragraph\n"
        check(text.contains(indented)) { "Help paragraph not found: $paragraph" }
        return text.replace(indented, "")
    }
}

extensions.configure<ApplicationAndroidComponentsExtension>("androidComponents") {
    onVariants { variant ->
        val taskName = "copyDictionaryDatabases" +
            variant.name.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() }
        val copyTask = tasks.register<CopyDictionaryDatabasesTask>(taskName) {
            sourceFiles.from(dictionarySources.map { it.file })
        }
        variant.sources.assets!!.addGeneratedSourceDirectory(
            copyTask,
            CopyDictionaryDatabasesTask::outputDirectory,
        )
        val helpTaskName = "copyHelpAssets" +
            variant.name.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() }
        val helpTask = tasks.register<CopyHelpAssetsTask>(helpTaskName) {
            sourceDirectory.set(rootProject.file("../jFlash/Assets/JFlash/help"))
        }
        variant.sources.assets!!.addGeneratedSourceDirectory(
            helpTask,
            CopyHelpAssetsTask::outputDirectory,
        )
    }
}

tasks.matching { it.name == "testDebugUnitTest" || it.name == "testReleaseUnitTest" }.configureEach {
    dependsOn("copyHelpAssetsDebug")
}

android {
    namespace = "com.japaneseinaflash.app"
    compileSdk = 36

    defaultConfig {
        // Placeholder. Ross needs to confirm this before the first Play upload.
        // The 2012 app used com.longweekendmobile.android.xflash.
        applicationId = "com.japaneseinaflash.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    lint {
        abortOnError = true
    }

    testOptions {
        // Unit tests build their own tiny databases. Packaging the real
        // dictionary into the unit-test assets would decompress ~116 MiB on
        // every test run and is not what `test` is for.
        // Compose UI tests resolve string resources through Robolectric, which
        // needs the merged debug resources. The dictionary copy task is the
        // same one assembleDebug runs; it stays incremental and the tests do
        // not open those databases.
        unitTests.isIncludeAndroidResources = true
        unitTests.all { test ->
            // Compose tests resolve @Config(manifest) from the working directory.
            test.workingDir = project.projectDir
            test.testLogging {
                events("passed", "skipped", "failed")
            }
            test.jvmArgs(
                "--add-opens=java.base/java.lang=ALL-UNNAMED",
                "--add-opens=java.base/java.util=ALL-UNNAMED",
                "--add-opens=java.base/java.io=ALL-UNNAMED",
                "--add-opens=java.base/java.net=ALL-UNNAMED",
                "--add-opens=java.base/java.security=ALL-UNNAMED",
                "--add-opens=java.base/java.text=ALL-UNNAMED",
                "--add-opens=java.base/jdk.internal.access=ALL-UNNAMED",
                "--add-opens=java.desktop/java.awt.font=ALL-UNNAMED",
                "--add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED",
            )
            test.maxHeapSize = "1g"
        }
    }
}

dependencies {
    val composeBom = platform(libs.androidx.compose.bom)
    implementation(composeBom)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore)
    implementation(libs.androidx.adaptive.nav)
    implementation(libs.androidx.webkit)
    implementation(libs.kotlinx.coroutines.android)
    debugImplementation(libs.androidx.compose.ui.tooling)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.compose.ui.test.junit4)
}
