plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.advertising_screen"
    compileSdkVersion(rootProject.extra["compileSdkVersion"] as Int)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.advertising_screen"
        minSdk = 23  // Change this line - set it directly to 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    buildToolsVersion = "35.0.1"
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")

    // Firebase BOM - ensures all Firebase libraries use compatible versions
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))

    // Firebase libraries - no need to specify versions when using BOM
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")

    // Core Android dependencies
    implementation("androidx.core:core-ktx:1.12.0")
}
flutter {
    source = "../.."
}