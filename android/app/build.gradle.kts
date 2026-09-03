import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials are never stored in the repository. We look for
// android/key.properties first (per-checkout override), then fall back to the
// shared out-of-repo location used by this project.
val keystoreProperties = Properties()
val keystorePropertiesFile: File? = listOf(
    rootProject.file("key.properties"),
    File(System.getProperty("user.home"), ".config/tajweed/key.properties"),
).firstOrNull { it.exists() }

keystorePropertiesFile?.let { file ->
    FileInputStream(file).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.ebaidllc.tajweed_practice"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ebaidllc.tajweed_practice"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile != null) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile != null) {
                signingConfigs.getByName("release")
            } else {
                // Keeps `flutter run --release` working on machines without the
                // upload key. Google Play rejects debug-signed bundles, so this
                // must never be used for a Play upload.
                logger.warn(
                    "WARNING: no key.properties found - signing release with the DEBUG key. " +
                        "This build CANNOT be uploaded to Google Play.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Play Integrity API: the Android counterpart to iOS App Attest.
    implementation("com.google.android.play:integrity:1.4.0")
}
