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
// El plugin fija su propio compileSdk 33 durante la evaluación de su build.gradle,
// así que no basta ponerlo en plugins.withId (se ejecuta antes y es sobrescrito).
// Registramos el afterEvaluate DENTRO del callback plugins.withId: se registra
// temprano (al aplicar el plugin) y se ejecuta después del android {} del plugin,
// por lo que nuestro 36 gana. No ponemos afterEvaluate suelto en subprojects{}
// porque el subproyecto ya está evaluado y Gradle lo rechaza.
subprojects {
    plugins.withId("com.android.library") {
        afterEvaluate {
            extensions
                .getByType(com.android.build.api.dsl.LibraryExtension::class.java)
                .compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
