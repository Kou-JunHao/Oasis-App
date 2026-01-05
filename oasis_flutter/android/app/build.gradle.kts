import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
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
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "uno.skkk.oasis"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24  // Android 7.0 (Nougat) - API 24
        targetSdk = 34  // Android 15 (Vanilla Ice Cream) - API 34
        
        // 动态版本配置
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        setProperty("archivesBaseName", "oasis_v${flutter.versionName}")
    }

    buildTypes {
        release {
            // 使用自定义签名配置
            signingConfig = signingConfigs.getByName("release")
        }
    }
    
    // 自定义APK输出文件名
    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val abiFilter = output.filters.find { it.filterType == com.android.build.OutputFile.ABI }
            val abiName = abiFilter?.identifier ?: "universal"
            output.outputFileName = "oasis_${versionName}_${abiName}.apk"
        }
    }
}

flutter {
    source = "../.."
}
