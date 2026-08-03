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
    if (name == "file_picker") {
        pluginManager.apply("org.jetbrains.kotlin.android")
    }
    if (name == "wasm_run_flutter") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                namespace = "com.example.wasm_run_flutter"
            }
        }
        afterEvaluate {
            extensions.findByType<com.android.build.api.dsl.LibraryExtension>()?.apply {
                compileSdk = 34
                // The published plugin pins NDK 21.4.7075529, which its old
                // Android Gradle Plugin can no longer install reliably. Use
                // the same complete NDK version required by this Flutter SDK.
                ndkVersion = "28.2.13676358"
                defaultConfig {
                    minSdk = 21
                }
            }
        }
    }
    if (name == "quickjs_engine") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                defaultConfig {
                    externalNativeBuild {
                        cmake {
                            arguments += "-DCMAKE_SHARED_LINKER_FLAGS=-llog"
                        }
                    }
                }
            }
        }
        // The plugin's own build script re-pins compileOptions to 1.8 after
        // any extension-level override, and AGP finalizes compileOptions
        // during evaluation. Align Java with the Kotlin target at task level.
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
    if (name == "app" || name == "file_picker" || name == "quickjs_engine") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
