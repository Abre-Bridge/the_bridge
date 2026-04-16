pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val propertiesFile = file("local.properties")
            if (propertiesFile.exists()) {
                propertiesFile.inputStream().use { properties.load(it) }
            }
            val sdkPath = properties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")
            require(sdkPath != null) { "Flutter SDK not found. Define flutter.sdk in local.properties or FLUTTER_ROOT env variable" }
            sdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
