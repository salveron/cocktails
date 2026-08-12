import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing is a fact about the machine, not the repo: key.properties and the
// keystore it names stay outside version control (android/.gitignore).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
} else if (gradle.startParameter.taskNames.any { it.contains("Release") }) {
    throw GradleException(
        "A release build needs android/key.properties naming storeFile, " +
            "storePassword, keyAlias and keyPassword — see the release keystore " +
            "section of docs/architecture.md. Falling back to the debug key is " +
            "refused on purpose: Android tells two builds apart by their " +
            "signature, so an APK signed with a debug key cannot update one " +
            "signed anywhere else, and the only way past that is an uninstall " +
            "that takes every bar on the device with it."
    )
}

android {
    namespace = "dev.salveron.cocktails"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.salveron.cocktails"
        // Flutter's own defaults, taken as they move (architecture.md).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Both read pubspec.yaml's `version:`, its one home.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
