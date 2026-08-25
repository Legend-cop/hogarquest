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

// Fuerza compileSdk 36 en los módulos de plugins (location, file_saver, etc.)
// que de otro modo usan compileSdk 33 y fallan porque sus dependencias
// (androidx.lifecycle 2.7.0, core-ktx 1.13.1, ...) exigen >= 34.
// Debe hacerse en afterEvaluate: el plugin fija su propio compileSdk durante la
// evaluación del build.gradle del plugin, así que un callback en plugins.withId
// (que corre antes) es sobrescrito. En afterEvaluate ya ganamos nosotros.
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val lib =
                project.extensions.getByType(com.android.build.api.dsl.LibraryExtension::class.java)
            lib.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
