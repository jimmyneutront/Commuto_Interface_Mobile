plugins {
    id("com.android.application")
    kotlin("android")
    // Hilt dependency injection
    kotlin("kapt")
    kotlin("plugin.serialization") version "1.6.10"
    id("dagger.hilt.android.plugin")
}

// Trixnity Matrix SDK
val trixnityVersion = "2.1.1"
fun trixnity(module: String, version: String = trixnityVersion) =
    "net.folivo:trixnity-$module:$version"


dependencies {
    //implementation(project(":shared"))
    implementation("com.google.android.material:material:1.6.0")
    implementation("androidx.appcompat:appcompat:1.4.1")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    // Integration with activities
    implementation("androidx.activity:activity-compose:1.4.0")
    // Compose Material Design
    implementation("androidx.compose.material:material:1.1.1")
    // Animations
    implementation("androidx.compose.animation:animation:1.1.1")
    // Tooling support (Previews, etc.)
    implementation("androidx.compose.ui:ui-tooling:1.1.1")
    // Integration with ViewModels
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.4.1")
    // UI Tests
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:1.1.1")
    // Navigation
    val navVersion = "2.4.2"
    implementation("androidx.navigation:navigation-compose:$navVersion")
    // Hilt dependency injection
    implementation("com.google.dagger:hilt-android:2.38.1")
    configurations["kapt"].dependencies.add(
        org.gradle.api.internal.artifacts.dependencies.DefaultExternalModuleDependency(
            "com.google.dagger","hilt-android-compiler", "2.38.1"
        )
    )
    // Web3j
    //TODO: Update these to a version with no vulnerabilities
    implementation("org.web3j:codegen:4.9.2")
    implementation("org.web3j:contracts:4.9.2")
    implementation("org.web3j:core:4.9.2")
    // Kotlin Coroutines for use with CompletableFuture
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-jdk8:1.6.2")
    // Kotlin tests
    testImplementation("junit:junit:4.13.2")
    // Trixnity Matrix SDK
    implementation(trixnity("clientserverapi-client"))
    // Ktor engine for Trixnity
    implementation("io.ktor:ktor-client-okhttp:2.0.1")
    // Serialization Library
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.3.3")
    // Ktor Content negotiation plugin for interactions with TestingServer
    testImplementation("io.ktor:ktor-client-content-negotiation:2.0.1")
    // Ktor JSON serialization plugin for interactions with TestingServer
    testImplementation("io.ktor:ktor-serialization-kotlinx-json:2.0.1")
}

android {
    compileSdk = 32
    defaultConfig {
        applicationId = "com.example.commuto_interface_mobile.android"
        minSdk = 26
        targetSdk = 32
        versionCode = 1
        versionName = "1.0"
    }
    buildFeatures {
        compose = true
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
        freeCompilerArgs = freeCompilerArgs + "-opt-in=kotlin.RequiresOptIn"
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.1.1"
    }
    packagingOptions {
        resources.excludes.add("META-INF/*")
    }
}

// Allow references to generated code
kapt {
    correctErrorTypes = true
}