plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 🔁 Use your real package id here (must match MainActivity package & folder)
    namespace = "com.yourstudio.brainybubbles"

    // 🔧 Pin SDK + NDK as required by Play & your plugins
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    // Keep Java 11 to match your current toolchain
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.yourstudio.brainybubbles"
        // Use at least 21; if Flutter’s min is higher, keep it.
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = 35

        // Use Flutter’s version fields so `flutter build` controls them
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: replace with your real release signing before uploading to Play
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Tell the Flutter plugin where the module root is
flutter {
    source = "../.."
}
