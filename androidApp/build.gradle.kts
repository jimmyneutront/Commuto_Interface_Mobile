plugins {
    id("com.android.application")
    kotlin("android")
}

dependencies {
    //implementation(project(":shared"))
    implementation("com.google.android.material:material:1.6.0")
    implementation("androidx.appcompat:appcompat:1.4.1")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
}

android {
    compileSdk = 32
    defaultConfig {
        applicationId = "com.example.commuto_interface_mobile.android"
        minSdk = 21
        targetSdk = 32
        versionCode = 1
        versionName = "1.0"
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }
}