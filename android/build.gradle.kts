import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
        flatDir {
            dirs(
                "${rootProject.projectDir}/app/libs",
                "${rootProject.projectDir}/app/libs/aars"
            )
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    repositories {
        google()
        mavenCentral()
        flatDir {
            dirs(
                "${rootProject.projectDir}/app/libs",
                "${rootProject.projectDir}/app/libs/aars"
            )
        }
    }

    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.0.0")
            }
        }
    }

    // PAKSA SEMUA JADI 17 SETELAH PACKAGE DI-EVALUATE (INI KUNCI BUAT audio_waveforms)
    afterEvaluate {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }

        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }

        // PAKSA JUGA ANDROID LIBRARY COMPILE OPTIONS
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            androidExt.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            androidExt.compileOptions.targetCompatibility = JavaVersion.VERSION_17
            if (androidExt.namespace == null) {
                val cleanName = project.name.replace("-", "_").replace(".", "_")
                androidExt.namespace = "com.plugin.$cleanName"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}