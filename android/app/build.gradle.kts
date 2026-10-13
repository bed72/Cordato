import java.util.Properties

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")

if (signingPropertiesFile.isFile) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? =
    System.getenv(environmentName) ?: signingProperties.getProperty(propertyName)

val releaseStoreFile = releaseSigningValue("storeFile", "ANDROID_RELEASE_STORE_FILE")
val releaseKeyAlias = releaseSigningValue("keyAlias", "ANDROID_RELEASE_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "ANDROID_RELEASE_KEY_PASSWORD")
val releaseStorePassword = releaseSigningValue("storePassword", "ANDROID_RELEASE_STORE_PASSWORD")

val missingReleaseSigningValues = listOfNotNull(
    "ANDROID_RELEASE_STORE_FILE or android/key.properties storeFile".takeIf {
        releaseStoreFile.isNullOrBlank()
    },
    "ANDROID_RELEASE_STORE_PASSWORD or android/key.properties storePassword".takeIf {
        releaseStorePassword.isNullOrBlank()
    },
    "ANDROID_RELEASE_KEY_ALIAS or android/key.properties keyAlias".takeIf {
        releaseKeyAlias.isNullOrBlank()
    },
    "ANDROID_RELEASE_KEY_PASSWORD or android/key.properties keyPassword".takeIf {
        releaseKeyPassword.isNullOrBlank()
    },
)

dependencies {
    implementation("androidx.core:core-splashscreen:1.2.0")
}

android {
    compileSdk = 37
    namespace = "com.bed.cordato"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "com.bed.cordato"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!releaseStoreFile.isNullOrBlank()) {
                storeFile = rootProject.file(releaseStoreFile)
            }
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

val validateReleaseSigning by tasks.registering {
    doLast {
        check(missingReleaseSigningValues.isEmpty()) {
            "Missing Android release signing configuration: " +
                missingReleaseSigningValues.joinToString()
        }
        check(rootProject.file(requireNotNull(releaseStoreFile)).isFile) {
            "Android release keystore does not exist: $releaseStoreFile"
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_21
    }
}

flutter {
    source = "../.."
}
