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
    namespace = "com.example.sponsorbabeinfogawat"
    compileSdk = 35
    ndkVersion = "25.1.8937393"

    packaging {
        resources {
            excludes += listOf(
                "META-INF/*",
                "META-INF/licenses/*",
                "**/LICENSE*"
            )
        }
        jniLibs {
            pickFirsts += listOf(
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
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            // Matikan shrink/minify jika tidak memerlukan obfuscation berat
            isMinifyEnabled = false
            isShrinkResources = false

            // Hubungkan ProGuard Rules
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
}
