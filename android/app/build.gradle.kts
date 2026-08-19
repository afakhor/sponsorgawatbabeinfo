plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

repositories {
    google()
    mavenCentral()
    flatDir {
        dirs("libs", "libs/aars")
    }
}

android {
    namespace = "com.babe.info"
    compileSdk = 35
    ndkVersion = "25.1.8937393"

    packaging {
        resources {
            excludes += "META-INF/*"
        }
        jniLibs {
            pickFirsts += listOf(
                "**/libc++_shared.so",
                "**/libjShared.so"
            )
        }
    }

    // --- PERUBAHAN DI SINI (Ubah 1.8 ke 17) ---
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { 
        jvmTarget = "17" 
    }
    // ------------------------------------------

    defaultConfig {
        applicationId = "com.babe.info"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
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
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
}
