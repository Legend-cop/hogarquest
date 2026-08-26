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
// Se hace en plugins.withId + finalizeDsl: el callback de withId corre al aplicar
// el plugin, y finalizeDsl es el último punto donde AGP permite modificar compileSdk
// SIN el error "too late to set compileSdk" (el build.gradle del plugin ya fijó su
// propio valor durante la evaluación, así que nuestro set debe ir después, en
// finalizeDsl). No usar afterEvaluate: en ese punto ya es demasiado tarde.
subprojects {
    plugins.withId("com.android.library") {
        extensions
            .getByType(com.android.build.api.dsl.LibraryExtension::class.java)
            .androidComponents
            .finalizeDsl {
                compileSdk = 36
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
