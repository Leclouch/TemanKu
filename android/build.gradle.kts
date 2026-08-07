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

// tflite_flutter's own android/build.gradle (a third-party plugin we don't
// control) hardcodes Java 1.8 compileOptions and sets no Kotlin jvmTarget at
// all, so its compileDebugKotlin task falls back to whatever JDK is running
// Gradle (21 here) — a mismatch against its own compileDebugJavaWithJavac
// (1.8) that AGP now hard-errors on. Forcing every subproject's Java/Kotlin
// compile tasks to the same JVM target the app module already uses (17)
// fixes this uniformly, without editing pub-cache files that `flutter pub
// get` would just reset anyway.
// Deliberately not a plain `subprojects { afterEvaluate { ... } }`: AGP
// registers its own afterEvaluate hook (during each plugin subproject's own
// build.gradle evaluation) that re-asserts compileOptions.sourceCompatibility
// onto the JavaCompile task, and that hook is registered *after* one of ours
// would be, so it wins the ordering race and silently reverts a same-phase
// override — that's why only the Kotlin half of an earlier version of this
// fix stuck. `gradle.projectsEvaluated` runs once every project (and all of
// their afterEvaluate callbacks, AGP's included) has finished configuring,
// so this unambiguously has the last word, for both compile task types.
gradle.projectsEvaluated {
    subprojects {
        // :app doesn't need this — app/build.gradle.kts already declares
        // matching Java 17 / Kotlin 17 itself. Only third-party plugin
        // subprojects (tflite_flutter today) need the override.
        if (name == "app") return@subprojects
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
