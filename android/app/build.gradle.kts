import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google services plugin for Firebase
    id("com.google.gms.google-services")
    // Firebase Crashlytics for crash reporting
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.hur.delivery"
    compileSdk = 35  // Android 15 (required for latest plugins)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Load keystore properties
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    defaultConfig {
        applicationId = "com.hur.delivery"
        // Updated for Firebase messaging compatibility
        minSdk = 23  // Android 6.0 (required for Firebase messaging)
        targetSdk = 35  // Android 15 (latest)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        
        // Enable split-per-ABI for smaller APKs
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    // Configure signing
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file("../" + keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Split APK by ABI for smaller downloads
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true  // Also generate a universal APK
        }
    }

    buildTypes {
        release {
            // Use release signing configuration
            signingConfig = signingConfigs.getByName("release")
            
            // Enable R8 code shrinking and obfuscation for smaller app size
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Force compatible androidx.core versions to avoid API level conflicts
configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
