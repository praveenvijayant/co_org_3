plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ Add Google Services plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.railway_caution_viewer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // ✅ OK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.railway_caution_viewer"
        minSdk = 21 // ✅ Firebase requires minimum SDK 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use debug signingConfig just for testing — replace for production!
            signingConfig = signingConfigs.debug
        }
    }
}
