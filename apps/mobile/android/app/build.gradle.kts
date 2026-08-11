import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing material is infrastructure, never a committed file. key.properties is
// git-ignored and written by CI from repository secrets; the keystore it points
// at stays outside the working tree entirely.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

// A COMMITTED KEYSTORE, AND IT IS NOT A CREDENTIAL. Read this before deleting it.
//
// Android refuses to install an update whose signature differs from the installed app — the rule
// that stops anyone pushing a fake update over your banking app. The demo APK used to fall back to
// the local debug key, and a GitHub runner generates a fresh one on every run, so every demo build
// was a different app as far as the phone was concerned: "App not installed", and the only way
// through was to uninstall, losing the session and every answer the app remembered. Reported by the
// founder on 2026-08-10, after the second demo build.
//
// This keystore fixes that by being the same every time. Its password is `android`, it is in the
// repository on purpose, and publishing it costs nothing: it signs nothing that can reach a store,
// anybody can generate an equivalent one in ten seconds, and the Play Store rejects it. The upload
// key — the one that IS a credential — is still never in the tree and still arrives through
// key.properties from a secret.
//
// It expires in 2056. If a demo build ever refuses to install after that, this is why.
val demoKeystoreFile = rootProject.file("demo/demo.keystore")

android {
    namespace = "com.kafoo.kafoo_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kafoo.kafoo_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }


    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
        if (demoKeystoreFile.exists()) {
            create("demo") {
                storeFile = demoKeystoreFile
                storePassword = "android"
                keyAlias = "kafoodemo"
                keyPassword = "android"
            }
        }
    }

    buildTypes {
        release {
            // Upload key when key.properties is present, demo key otherwise, and the
            // local debug key only if somebody deleted the demo keystore. None of the
            // fallbacks is publishable — the deploy workflow reads the certificate out
            // of the finished artifact and says which one it found, rather than trusting
            // that secrets were configured.
            signingConfig = when {
                hasUploadKey -> signingConfigs.getByName("release")
                demoKeystoreFile.exists() -> signingConfigs.getByName("demo")
                else -> signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
