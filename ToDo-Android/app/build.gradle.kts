import java.util.Properties

val supabaseProperties = Properties().apply {
    val configurationFile = project.file("supabase.properties")
    if (configurationFile.exists()) {
        configurationFile.inputStream().use(::load)
    }
}

fun configuredValue(name: String): String =
    supabaseProperties.getProperty(name)?.trim().orEmpty()

fun buildConfigString(value: String): String =
    "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("androidx.room3")
    id("com.google.devtools.ksp")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

room3 {
    schemaDirectory("$projectDir/schemas")
}

android {
    namespace = "dev.iamshift.todo.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.iamshift.todo.android"
        minSdk = 36
        targetSdk = 36
        versionCode = 1
        versionName = "3.1.0"

        buildConfigField("String", "SUPABASE_URL", buildConfigString(configuredValue("supabase.url")))
        buildConfigField(
            "String",
            "SUPABASE_PUBLISHABLE_KEY",
            buildConfigString(configuredValue("supabase.publishableKey"))
        )

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
        compose = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.10.0")
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    implementation("androidx.room3:room3-runtime:3.0.1")
    implementation("androidx.sqlite:sqlite-bundled:2.7.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    // 3.6.0 includes the Realtime consecutive-connect fix needed after a
    // transient Android network/socket interruption.
    implementation(platform("io.github.jan-tennert.supabase:bom:3.6.0"))
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    // The Android Ktor engine does not support WebSockets. OkHttp is used so
    // Supabase Realtime and the regular PostgREST client share one engine.
    implementation("io.ktor:ktor-client-okhttp:3.3.1")
    implementation("io.ktor:ktor-client-websockets:3.3.1")
    ksp("androidx.room3:room3-compiler:3.0.1")

    implementation(platform("com.google.firebase:firebase-bom:34.17.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-crashlytics")

    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.material3:material3")

    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.06.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
