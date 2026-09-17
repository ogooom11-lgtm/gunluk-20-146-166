plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gunluk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // مطلوب لمكتبة الإشعارات (java.time على الإصدارات الأقدم)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.injazi.daily"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("ar", "en")
    }

    signingConfigs {
        // مفتاح توقيع تجريبي ثابت مرفوع مع المستودع، والغرض منه أن تكون كل
        // نسخ CI موقّعة بنفس المفتاح فتُثبَّت النسخة الجديدة فوق القديمة مباشرة.
        // (مفتاح التصحيح التلقائي كان يُعاد توليده في كل تشغيل، فيرفض النظام
        // التحديث برسالة «التطبيق غير مثبَّت»).
        // للنشر على المتجر: استبدله بمفتاحك الخاص ولا ترفعه للمستودع أبدًا.
        create("injazi") {
            storeFile = file("injazi-test-signing.p12")
            storeType = "PKCS12"
            storePassword = "injazi2026"
            keyAlias = "injazi"
            keyPassword = "injazi2026"
        }
    }

    buildTypes {
        release {
            // نستخدم المفتاح الثابت إن وُجد، وإلا نعود لمفتاح التصحيح.
            signingConfig = if (file("injazi-test-signing.p12").exists()) {
                signingConfigs.getByName("injazi")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // نافذة التعرّف على الوجه/البصمة لعرض تفاصيل المنبّه بعد التحقّق.
    implementation("androidx.biometric:biometric:1.1.0")
}
