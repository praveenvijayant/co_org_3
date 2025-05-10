plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Firebase plugin
}

android {
    namespace = "com.example.railway_caution_viewer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

signingConfigs {
    create("release") {
        storeFile = file(System.getenv("CM_KEYSTORE_PATH"))
        storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
        keyAlias = System.getenv("CM_KEY_ALIAS")
        keyPassword = System.getenv("CM_KEY_PASSWORD")
    }
}
buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = false
        isShrinkResources = false
    }
}

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.railway_caution_viewer"
        minSdk = 21 // ✅ Minimum required for Firebase
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // ✅ Safe Kotlin DSL signing config
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // 🔧 Optional: add release signing later
            // signingConfig = signingConfigs.getByName("release")
            // minifyEnabled = false
            // shrinkResources = false
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
