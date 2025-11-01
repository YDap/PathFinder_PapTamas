// Project-level Gradle (Kotlin DSL)

plugins {
    // Firebase Google Services plugin a projekt-szinten (apply false)
    id("com.google.gms.google-services") version "4.4.4" apply false
}

// A régi Flutter-sémának megfelelő repók
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// (Opció) a Flutter által használt "build" mappa átirányítás – hagyd, ha nálad eddig így volt
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Biztosítsuk, hogy az :app modul értékelődik le
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
