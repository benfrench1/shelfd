buildscript {
    configurations.all {
        resolutionStrategy {
            force("org.bouncycastle:bcpkix-jdk15on:1.70")
            force("org.bouncycastle:bcprov-jdk15on:1.70")
        }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://plugins.gradle.org/m2/") }
    }
    configurations.all {
        resolutionStrategy {
            force("org.bouncycastle:bcpkix-jdk15on:1.70")
            force("org.bouncycastle:bcprov-jdk15on:1.70")
            // Pin coroutines to avoid fetching 1.8.1 from Maven Central
            force("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
            force("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
