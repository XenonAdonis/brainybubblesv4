// android/app/build.gradle.kts  (Kotlin DSL)

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yourstudio.brainybubbles"

    // These values are provided by the Flutter plugin; keep them.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        // <-- Your package / application id here
        applicationId = "com.yourstudio.brainybubbles"

        // If you need to override Flutter’s defaults, set them explicitly:
        minSdk = maxOf(21, flutter.minSdkVersion)   // ensure at least 21
        targetSdk = 34                              // or: flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            // Use your real signing config for Play uploads later.
            // For now, keep debug keys so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
        }
        debug {
            // optional debug tweaks here
        }
    }
}

flutter {
    // Path to the Flutter module (two levels up from android/)
    source = "../.."
}
