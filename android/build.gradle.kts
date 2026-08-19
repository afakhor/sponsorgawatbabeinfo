import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // FIX 1: Memaksa versi Kotlin & Stdlib ke 1.9.22 untuk SEMUA subproject (termasuk flutter_gl)
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("1.9.22")
            }
        }
    }

    afterEvaluate {
        // FIX 2: Inject Namespace untuk plugin lama (seperti flutter_gl) jika belum set namespace
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            val androidExt = project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            if (androidExt != null && androidExt.namespace == null) {
                val cleanName = project.name.replace("-", "_").replace(".", "_")
                androidExt.namespace = "com.example.$cleanName"
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
