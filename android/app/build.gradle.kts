plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val milestoneKeystore = System.getenv("PHOMANACHI_KEYSTORE_PATH")
val milestoneStorePassword = System.getenv("PHOMANACHI_STORE_PASSWORD")
val milestoneKeyAlias = System.getenv("PHOMANACHI_KEY_ALIAS")
val milestoneKeyPassword = System.getenv("PHOMANACHI_KEY_PASSWORD")
val milestoneSigningReady = listOf(milestoneKeystore, milestoneStorePassword, milestoneKeyAlias, milestoneKeyPassword).all { !it.isNullOrBlank() }

android {
    namespace = "dev.phomanachi.phomanachi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.phomanachi.phomanachi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (milestoneSigningReady) {
            create("milestone") {
                storeFile = file(milestoneKeystore!!)
                storePassword = milestoneStorePassword
                keyAlias = milestoneKeyAlias
                keyPassword = milestoneKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (milestoneSigningReady) signingConfigs.getByName("milestone") else null
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

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    testImplementation("junit:junit:4.13.2")
}

// Publishing a randomly debug-signed replacement would break installed update chains.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name == "packageRelease" || it.name == "bundleRelease" || it.name == "assembleRelease" }) {
        check(milestoneSigningReady) { "Release signing is required. Configure PHOMANACHI_KEYSTORE_PATH, PHOMANACHI_STORE_PASSWORD, PHOMANACHI_KEY_ALIAS, and PHOMANACHI_KEY_PASSWORD using the same key as installed APKs." }
    }
}
