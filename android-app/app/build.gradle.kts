import com.android.build.api.variant.ApplicationAndroidComponentsExtension
import org.gradle.api.GradleException
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import java.io.File
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
        files.forEach { src ->
            if (!src.isFile) {
                throw GradleException("Missing dictionary database: ${src.absolutePath}")
            }
            src.copyTo(dest.resolve(src.name), overwrite = true)
            logger.lifecycle("Dictionary asset ${src.name}: ${src.length()} bytes")
        }
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
    }
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
            isMinifyEnabled = false
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
        unitTests.isIncludeAndroidResources = false
        unitTests.all { test ->
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
    implementation(libs.kotlinx.coroutines.android)
    debugImplementation(libs.androidx.compose.ui.tooling)

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
}
