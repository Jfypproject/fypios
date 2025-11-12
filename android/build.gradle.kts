buildscript {
    // 1. Add repositories for the buildscript dependencies
    repositories {
        google()
        mavenCentral()
    }
    // 2. Add the classpath dependency
    dependencies {
        // Replace 4.4.1 with the latest version
        classpath("com.google.gms:google-services:4.4.4")
    }
}

// Your existing content starts here
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ... rest of your file ...


allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
