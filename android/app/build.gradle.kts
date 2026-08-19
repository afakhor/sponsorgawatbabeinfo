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

    // Fix Duplicate libc++_shared.so (Penting untuk FlutterGL, Angle & FFmpeg)
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

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions { 
        jvmTarget = "1.8" 
    }

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
    
    // Menyediakan AAR secara langsung dari file tree jika resolution dari pub-cache tidak terdeteksi
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
}
