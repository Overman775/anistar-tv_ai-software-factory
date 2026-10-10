plugins {
    id("com.android.application")
    id("com.android.built-in-kotlin")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
