plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties from key.properties file
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = mutableMapOf<String, String>()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.readLines().forEach { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty() && !trimmed.startsWith("#") && trimmed.contains("=")) {
            val (key, value) = trimmed.split("=", limit = 2)
            keystoreProperties[key.trim()] = value.trim()
        }
    }
}

android {
    namespace = "com.liftlab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID for Play Store (must not use com.example)
        applicationId = "com.liftlab"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21  // Android 5.0 Lollipop - supports ~99% of active devices
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Note: Flutter includes all ABIs by default (armeabi-v7a, arm64-v8a, x86, x86_64)
        // Explicitly setting abiFilters can cause upgrade issues if previous releases didn't have them
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists() && keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] ?: ""
                keyPassword = keystoreProperties["keyPassword"] ?: ""
                var storeFilePath = keystoreProperties["storeFile"] ?: ""
                // Convert Git Bash path format (/c/...) to Windows path (C:/...)
                if (storeFilePath.startsWith("/c/") || storeFilePath.startsWith("/C/")) {
                    storeFilePath = "C:" + storeFilePath.substring(2)
                } else if (storeFilePath.startsWith("/") && storeFilePath.length > 2 && storeFilePath[1].isLetter()) {
                    // Handle other drive letters like /d/, /e/, etc.
                    val driveLetter = storeFilePath[1].uppercaseChar()
                    storeFilePath = "$driveLetter:" + storeFilePath.substring(2)
                }
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] ?: ""
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
