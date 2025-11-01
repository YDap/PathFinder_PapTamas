plugins {
    id("com.android.application")
    // újabb elnevezés (a régi "kotlin-android" helyett):
    id("org.jetbrains.kotlin.android")
    // A Flutter Gradle Plugin-t az Android és Kotlin plugin után kell alkalmazni
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Google Services plugin (modul-szinten ténylegesen alkalmazzuk)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.pathfinder_app"   // <-- ha nálad más, írd át
    // A pluginjeid (pl. geolocator, path_provider) miatt érdemes a 36-ot használni
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        // A projekted eddig Java 11-re volt állítva – maradhat
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.pathfinder_app"  // <-- tartsd összhangban a namespace-szel
        // Flutter által kezelt minSdk – maradhat
        minSdk = flutter.minSdkVersion
        // A kompatibilitás miatt célszerű a 36-ot beállítani
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Debugban nincs shrinkelés
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // Ha majd optimalizált release kell: mindkettőt állítsd true-ra és tegyél alá proguard szabályokat
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Flutter modul hivatkozása – hagyd így
flutter {
    source = "../.."
}

/*
 * Ha NATIVE (Kotlin/Java) Firebase SDK-kat is használsz, a BoM-ot itt importálhatod.
 * FlutterFire esetén ez NEM kötelező, de nem árt.
 */
dependencies {
    // Firebase BoM – nem verziózunk külön komponenseket, a BoM kezeli az összeillőséget
    implementation(platform("com.google.firebase:firebase-bom:34.5.0"))

    // Példa: ha natívan is használnád az Analytics/Crashlytics/Auth KTX-t, ide veheted fel:
    // implementation("com.google.firebase:firebase-analytics-ktx")
    // implementation("com.google.firebase:firebase-auth-ktx")
}
