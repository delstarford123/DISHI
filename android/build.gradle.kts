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
    
    configurations.all {
        resolutionStrategy {
            force("androidx.camera:camera-core:1.4.2")
            force("androidx.camera:camera-camera2:1.4.2")
            force("androidx.camera:camera-lifecycle:1.4.2")
            force("com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1")
        }
    }

    afterEvaluate {
        if (project.plugins.hasPlugin("kotlin-android") || project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            project.extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinProjectExtension>("kotlin") {
                jvmToolchain(17)
            }
        }
        
        project.tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
