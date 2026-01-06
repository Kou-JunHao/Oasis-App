import java.util.Properties
import java.io.FileInputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 加载签名配置
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "uno.skkk.oasis"
    compileSdk = 36  // Android 16 - API 36 (required by plugins)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    kotlin {
        jvmToolchain(21)
    }

    buildFeatures {
        buildConfig = true
    }

    // 签名配置
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "uno.skkk.oasis"
        minSdk = 24
        targetSdk = 36  // Android 16
        
        // 版本号由 Flutter 管理（pubspec.yaml）
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 生成构建时间戳
        val buildTimestamp = SimpleDateFormat("yyyyMMddHHmmss", Locale.US).format(Date())
        buildConfigField("String", "BUILD_TIMESTAMP", "\"$buildTimestamp\"")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
