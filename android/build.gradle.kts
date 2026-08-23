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

// Fuerza compileSdk 36 en los módulos de plugins (file_picker, etc.) que de
// otro modo usan el valor por defecto de Flutter (34) y fallan al compilar
// porque flutter_plugin_android_lifecycle exige 36. Los plugins son subprojects
// del proyecto android raíz, no de :app.
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            android {
                compileSdk = 36
                compileSdkVersion = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
