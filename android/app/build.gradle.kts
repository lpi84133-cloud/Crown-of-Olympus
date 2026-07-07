import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Wire Firebase google-services processing only when the config file has been
// provisioned — this keeps the app buildable in the interim before Firebase
// credentials are handed over. Firebase.initializeApp() then no-ops at runtime.
if (project.file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// -------- Signing config --------
val signingProps = Properties()
val signingPropsFile = rootProject.file("key.properties")
if (signingPropsFile.exists()) {
    signingProps.load(FileInputStream(signingPropsFile))
}
val hasSigning = signingProps.isNotEmpty()

android {
    namespace = "com.olympcrown.crownofolympus"
    // 36 matches the transitive requirement from newer plugin releases;
    // must stay in sync with the subprojects override in ../build.gradle.kts.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 18.x reaches for java.time.* on API 24-25
        // so core-library desugaring is mandatory.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.olympcrown.crownofolympus"
        minSdk = 30
        targetSdk = 35
        versionCode = 5
        versionName = "1.0.1"
    }

    if (hasSigning) {
        signingConfigs {
            create("release") {
                keyAlias = signingProps["keyAlias"] as String
                keyPassword = signingProps["keyPassword"] as String
                storeFile = file(signingProps["storeFile"] as String)
                storePassword = signingProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (hasSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
