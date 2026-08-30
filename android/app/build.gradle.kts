plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sponsorbabeinfogawat"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

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
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
            debugSymbolLevel = "FULL"
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
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))
    implementation(fileTree(mapOf("dir" to "libs/aars", "include" to listOf("*.aar"))))
}