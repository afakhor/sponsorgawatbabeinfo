import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
        
        // PENTING: Mendaftarkan folder AAR bawaan dari flutter_gl agar tiga file AAR (threeegl, dll.) dapat ditemukan
        flatDir {
            dirs(
                "libs",
                "libs/aars",
                "${rootProject.projectDir}/../.pub-cache/hosted/pub.dev/flutter_gl-0.7.1/android/libs",
                "${rootProject.projectDir}/../.pub-cache/hosted/pub.dev/flutter_gl-0.7.1/android/libs/aars"
            )
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Memaksa pencarian AAR di level subproject/plugin
    repositories {
        google()
        mavenCentral()
        flatDir {
            dirs("libs", "libs/aars")
        }
    }

    // Paksa versi Kotlin ke 1.9.22
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("1.9.22")
            }
        }
    }

    // Auto-inject Namespace untuk plugin lama
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.BaseExtension) {
                if (androidExt.namespace == null) {
                    val cleanName = project.name.replace("-", "_").replace(".", "_")
                    androidExt.namespace = "com.plugin.$cleanName"
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
