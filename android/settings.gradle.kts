pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Pinned to the narrow window that satisfies two conflicting floors:
    //   - below 9.0: AGP 9.x hard-errors on the tensorflow-lite /
    //     tensorflow-lite-api AAR duplicate-namespace conflict (both declare
    //     "org.tensorflow.lite" — an upstream tflite_flutter packaging
    //     issue, not fixable from this app's Gradle config; AGP 8.x only
    //     warns on it).
    //   - at least 8.9.1: androidx.activity/androidx.core's AAR metadata
    //     requires it (8.7.3, tried first, failed checkDebugAarMetadata).
    // 8.11.1 is what Flutter's own tooling already asked for in this
    // project's build warnings, so it's the version Flutter itself expects
    // going forward, not just the minimum that happens to satisfy the two
    // floors above. Matched with the Gradle 8.14.0 wrapper below (Flutter's
    // other stated minimum).
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
