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
    }
    configurations.all {
        resolutionStrategy {
            force("org.bouncycastle:bcpkix-jdk15on:1.70")
            force("org.bouncycastle:bcprov-jdk15on:1.70")
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
