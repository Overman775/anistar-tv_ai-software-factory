import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.android.built-in-kotlin")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Direct Gradle invocations stay unsigned. Only the local release wrapper opts in.
val signingMode = providers.environmentVariable("ANISTAR_ANDROID_SIGNING_MODE").orElse("unsigned").get()
require(signingMode in setOf("local", "unsigned")) { "Invalid Android signing mode" }
val localSigning = if (signingMode == "local") {
    val properties = Properties()
    try {
        val checkout = rootDir.parentFile.canonicalFile.toPath()
        val privateDirectory = checkout.resolve(".private")
        val config = File(providers.environmentVariable("ANISTAR_ANDROID_SIGNING_PROPERTIES").orNull
            ?: privateDirectory.resolve("signing/key.properties").toString())
        require(config.isAbsolute && config.isFile)
        val canonicalConfig = config.canonicalFile
        require(!canonicalConfig.toPath().startsWith(checkout) ||
            canonicalConfig.toPath().startsWith(privateDirectory))
        canonicalConfig.inputStream().use { properties.load(it) }
        require(listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
            !properties.getProperty(it).isNullOrBlank()
        })
        val configuredKey = File(properties.getProperty("storeFile"))
        val key = (if (configuredKey.isAbsolute) configuredKey else
            File(config.parentFile, configuredKey.path)).canonicalFile
        require(key.isFile)
        require(!key.toPath().startsWith(checkout) || key.toPath().startsWith(privateDirectory))
        properties.setProperty("storeFile", key.absolutePath)
    } catch (_: Exception) {
        throw GradleException("Local Android signing configuration is missing or invalid")
    }
    properties
} else null

android {
    namespace = "com.anistar.anistar_tv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.anistar.anistar_tv"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["usesCleartextTraffic"] = "false"
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        create("prod") {
            dimension = "environment"
        }
    }

    signingConfigs {
        if (localSigning != null) {
            create("production") {
                storeFile = file(localSigning.getProperty("storeFile"))
                storePassword = localSigning.getProperty("storePassword")
                keyAlias = localSigning.getProperty("keyAlias")
                keyPassword = localSigning.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (localSigning != null) signingConfigs.getByName("production") else null
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Flutter 3.44 / AGP 9 can reuse the previous JNI merge after compiling new
// Dart AOT libraries. Re-run this small copy stage so the APK contains the
// current libapp.so. Keep until an SDK upgrade passes verify_android_apk.py.
tasks.configureEach {
    if (name.startsWith("merge") && name.endsWith("JniLibFolders")) {
        outputs.upToDateWhen { false }
    }
}
