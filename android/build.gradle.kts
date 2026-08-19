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

    // Memaksa versi Kotlin 1.9.22 ke seluruh plugin/library
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("1.9.22")
            }
        }
    }

    // Auto-inject Namespace untuk plugin lama (flutter_gl, flutter_angle, dll)
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
