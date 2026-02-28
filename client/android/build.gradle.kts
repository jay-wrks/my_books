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
subprojects {
    project.plugins.withId("com.android.library") {
        project.extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (namespace.isNullOrEmpty()) {
                val manifest = project.file("src/main/AndroidManifest.xml")
                namespace = if (manifest.exists()) {
                    val pkg = Regex("""package="([^"]+)"""").find(manifest.readText())?.groupValues?.get(1)
                    pkg ?: "com.example.${project.name.replace("-", "_")}"
                } else {
                    "com.example.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
