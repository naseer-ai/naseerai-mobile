plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.naseerai"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.naseerai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // NDK configuration for native C++ library
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a", "x86_64"))
        }

        // Packaging options to handle duplicate SO files
        packaging {
            resources {
                pickFirsts += listOf(
                    "**/libc++_shared.so",
                    "**/libggml.so",
                    "**/libllama.so"
                )
            }
        }

        // External native build configuration - DISABLED (using pre-built jniLibs)
        // externalNativeBuild {
        //     cmake {
        //         arguments(
        //             "-DCMAKE_BUILD_TYPE=Release",
        //             "-DANDROID_STL=c++_shared",
        //             "-DANDROID_CPP_FEATURES=rtti exceptions"
        //         )
        //         cppFlags("-std=c++17", "-fPIC")
        //     }
        // }
    }

    // External native build configuration - DISABLED (using pre-built jniLibs)
    // externalNativeBuild {
    //     cmake {
    //         path = file("src/main/cpp/CMakeLists.txt")
    //         version = "3.22.1"
    //     }
    // }

    buildTypes {
        debug {
            // Debug build configuration
            isDebuggable = true
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Optimize for release
            isDebuggable = false
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
