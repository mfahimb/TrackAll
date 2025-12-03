plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.trackall_app"
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
        applicationId = "com.example.trackall_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing config (you can replace with your own key later)
            signingConfig = signingConfigs.getByName("debug")

            // Disable code shrinking & resource shrinking to fix your previous error
            isMinifyEnabled = false
            isShrinkResources = false

            // ProGuard file (optional, safe to keep)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Debug settings remain default
        }
    }

    // Optional: Enable view binding if needed
    buildFeatures {
        viewBinding = true
    }
}

flutter {
    source = "../.."
}
