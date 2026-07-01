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

// -----------------------------------------------------------------------------
// Redirect subproject build outputs AND enforce a minimum compileSdk of 36 on
// every Android library plugin. Some plugins ship with compileSdk = 34 while
// their transitive deps (e.g. flutter_plugin_android_lifecycle) demand >= 36 —
// Gradle's CheckAarMetadata then aborts the build.
//
// The `afterEvaluate` override MUST be registered inside this first subprojects
// block, BEFORE the `evaluationDependsOn(":app")` block below. Once
// evaluationDependsOn has run, all subprojects are already evaluated and any
// later afterEvaluate registration throws:
//   "Cannot run Project.afterEvaluate(Action) when the project is already
//    evaluated"
// -----------------------------------------------------------------------------
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
