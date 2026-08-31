pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").takeIf { it.exists() }?.inputStream()?.use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        maven { url = java.net.URI("https://storage.googleapis.com/download.flutter.io") }
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // DUA REPOSITORI WAJIB UNTUK FLUTTER ENGINE & JITPACK/FFMPEG
        maven { url = java.net.URI("https://storage.googleapis.com/download.flutter.io") }
        maven { url = java.net.URI("https://jitpack.io") }
        
        flatDir {
            dirs(
                file("${rootDir}/app/libs"),
                file("${rootDir}/app/libs/aars")
            )
        }
    }
}

rootProject.name = "android"
include(":app")
