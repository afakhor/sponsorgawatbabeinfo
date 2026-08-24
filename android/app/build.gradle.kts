plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// HAPUS repositories {} dari sini - sudah di settings.gradle.kts!

android {
    namespace = "com.example.sponsorbabeinfogawat"
    compileSdk = 35
    ndkVersion = "25.1.8937393" // GANTI DARI 28.0.12433566 KE 25.1.8937393 - SUDAH ADA DI RUNNER!
    
  

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { 
        jvmTarget = "17" 
    }

    defaultConfig {
        applicationId = "com.example.sponsorbabeinfogawat"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/*",
                "META-INF/licenses/*",
                "**/LICENSE*"
            )
        }
        jniLibs {
            pickFirsts += setOf(
                "**/libc++_shared.so",
                "**/libjShared.so",
                "**/libangle.so",
                "**/libEGL.so",
                "**/libGLESv2.so"
            )
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
            ndk {
                debugSymbolLevel = "FULL"
            }
        }
    }
}

flutter { 
    source = "../.." 
}

dependencies {
    implementation("com.google.android.material:material:1.9.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Tambah untuk flutter_angle local libs
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))
    implementation(fileTree(mapOf("dir" to "libs/aars", "include" to listOf("*.aar"))))
}