plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sub_zero"
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
    applicationId = "com.example.sub_zero" // Try changing this to be safe
    minSdk = 24       // Android 7.0+
    targetSdk = 33    // Android 13
    versionCode = flutter.versionCode
    versionName = flutter.versionName

    multiDexEnabled = true // ADD THIS LINE
}

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 🟢 FIX 3: ADD DEPENDENCIES
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
