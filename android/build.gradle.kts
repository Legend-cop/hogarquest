plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
}

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

// Fuerza compileSdk 36 en los módulos de plugins (file_picker, nearby_connections,
// etc.) que de otro modo usan un valor bajo y fallan porque sus dependencias
// (androidx.lifecycle 2.7.0, core-ktx 1.13.1, ...) exigen >= 34.
// Se hace en plugins.withId (durante la aplicación del plugin Android, ANTES de
// que el plugin lea compileSdk para configurar sus tareas). No usar afterEvaluate:
// en ese punto el plugin ya leyó compileSdk y Gradle da "too late to set compileSdk".
subprojects {
    plugins.withId("com.android.library") {
        extensions
            .getByType(com.android.build.api.dsl.LibraryExtension::class.java)
            .compileSdk = 36
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
