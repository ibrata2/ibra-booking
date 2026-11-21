#!/usr/bin/env python3
"""روسم للتجميل — تجهيز android/ و ios/ بعد `flutter create`.

الاستخدام (من مجلد apps/rawsam):
  flutter create --org com.ibraprogram --project-name rawsam --platforms android,ios .
  python3 tool/setup_platforms.py
"""
import os
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OVERLAY = os.path.join(ROOT, "platform")
APP_ID = "com.ibraprogram.rawsam"
NAME = "روسم للتجميل"


CRASH_KT = r'''package {pkg}

import android.app.Application
import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.util.Date

/** يسجل سبب أي توقف مفاجئ بملف حتى يطلع للمستخدم بالمرة الجاية ويكدر يدزه للمطوّر. */
class CrashApp : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                File(base.filesDir, "last_crash.txt").writeText(
                    "${Date()}\n${Build.MANUFACTURER} ${Build.MODEL} — Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})\n" +
                        "thread: ${thread.name}\n\n" + Log.getStackTraceString(error)
                )
            } catch (ignored: Throwable) {
            }
            previous?.uncaughtException(thread, error)
        }
    }
}
'''


def fail(msg):
    print("✗ " + msg)
    sys.exit(1)


def copy_tree(src, dst):
    for base, _, files in os.walk(src):
        rel = os.path.relpath(base, src)
        os.makedirs(os.path.join(dst, rel), exist_ok=True)
        for f in files:
            shutil.copyfile(os.path.join(base, f), os.path.join(dst, rel, f))


MANIFEST = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- الإشعارات وتذكير الحجوزات -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <!-- عروض القرب والعروض حسب المنطقة — تُحفظ المنطقة التقريبية فقط -->
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

    <application
        android:label="@string/app_name"
        android:name=".CrashApp"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:networkSecurityConfig="@xml/network_security_config"
        android:allowBackup="false"
        android:supportsRtl="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Firebase: القناة والأيقونة الافتراضية للإشعارات -->
        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="rs_post" />
        <meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_stat_rawsam" />
        <meta-data android:name="com.google.firebase.messaging.default_notification_color" android:resource="@color/rs_accent" />

        <!-- flutter_local_notifications: تذكير الحجوزات -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />

        <!-- native_geofence: دائرة المركز تشتغل حتى والتطبيق مسدود -->
        <receiver android:name="com.chunkytofustudios.native_geofence.receivers.NativeGeofenceBroadcastReceiver" android:exported="true" />
        <receiver android:name="com.chunkytofustudios.native_geofence.receivers.NativeGeofenceRebootBroadcastReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
        <service
            android:name="com.chunkytofustudios.native_geofence.NativeGeofenceForegroundService"
            android:foregroundServiceType="location"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:exported="true" />

        <!-- بعض موبايلات Mali (مثل Honor X6c) تتعطل ويا Vulkan — نستخدم الرسم المتوافق -->
        <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="geo" />
        </intent>
        <intent>
            <action android:name="android.media.action.IMAGE_CAPTURE" />
        </intent>
        <package android:name="com.google.android.apps.maps" />
        <package android:name="com.instagram.android" />
        <package android:name="com.facebook.katana" />
    </queries>
</manifest>
"""


def setup_android():
    android = os.path.join(ROOT, "android")
    if not os.path.isdir(android):
        fail("android/ غير موجود — شغل flutter create أولاً")
    copy_tree(os.path.join(OVERLAY, "android"), android)
    main = os.path.join(android, "app", "src", "main")
    with open(os.path.join(main, "AndroidManifest.xml"), "w") as f:
        f.write(MANIFEST)
    kt = os.path.join(main, "kotlin", *APP_ID.split("."))
    os.makedirs(kt, exist_ok=True)
    with open(os.path.join(kt, "CrashApp.kt"), "w") as f:
        f.write(CRASH_KT.replace("{pkg}", APP_ID))
    res = os.path.join(main, "res")
    for folder in ("values", "values-ar"):
        os.makedirs(os.path.join(res, folder), exist_ok=True)
        with open(os.path.join(res, folder, "strings.xml"), "w") as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">%s</string>\n</resources>\n' % NAME)
    with open(os.path.join(res, "values", "colors.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="rs_background">#070B1C</color>\n    <color name="rs_accent">#2F6BFF</color>\n</resources>\n')
    raw = os.path.join(res, "raw")
    os.makedirs(raw, exist_ok=True)
    for f in os.listdir(os.path.join(ROOT, "assets", "sounds")):
        if f.endswith(".wav"):
            shutil.copyfile(os.path.join(ROOT, "assets", "sounds", f), os.path.join(raw, f))
    # حماية أسماء الأصوات من الحذف عند تصغير الموارد
    with open(os.path.join(raw, "keep.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@raw/*,@drawable/ic_stat_rawsam" />\n')

    gk = os.path.join(android, "app", "build.gradle.kts")
    if not os.path.exists(gk):
        fail("app/build.gradle.kts غير موجود")
    s = open(gk).read()
    s = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "%s"' % APP_ID, s)
    if "isCoreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", s, count=1)
        if n == 0:
            fail("compileOptions غير موجود")
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = maxOf(flutter.minSdkVersion, 24)", s)
    s = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion", "compileSdk = maxOf(flutter.compileSdkVersion, 37)", s)
    # Google Play: أندرويد 16 (API 36) كحد أدنى للتطبيقات الجديدة
    s = re.sub(r"targetSdk\s*=\s*flutter\.targetSdkVersion", "targetSdk = maxOf(flutter.targetSdkVersion, 36)", s)
    if "multiDexEnabled" not in s:
        s = re.sub(r"(defaultConfig\s*\{)", r"\1\n        multiDexEnabled = true", s, count=1)
    # فحص lint بنسخة الإصدار يتعطل على إضافات Firebase — نوقفه (ما يأثر على التطبيق)
    if "checkReleaseBuilds" not in s:
        s = re.sub(r"(\nandroid\s*\{)", r"\1\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }", s, count=1)
    if "keystoreProperties" not in s:
        s = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + s
        s = re.sub(
            r"(\nandroid\s*\{)",
            "\nval keystoreProperties = Properties()\n"
            "val keystorePropertiesFile = rootProject.file(\"key.properties\")\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
            "}\n\\1",
            s,
            count=1,
        )
        signing = (
            "    signingConfigs {\n"
            "        create(\"release\") {\n"
            "            if (keystorePropertiesFile.exists()) {\n"
            "                keyAlias = keystoreProperties[\"keyAlias\"] as String\n"
            "                keyPassword = keystoreProperties[\"keyPassword\"] as String\n"
            "                storeFile = file(keystoreProperties[\"storeFile\"] as String)\n"
            "                storePassword = keystoreProperties[\"storePassword\"] as String\n"
            "            }\n"
            "        }\n"
            "    }\n\n"
            "    buildTypes {"
        )
        s, n = re.subn(r"    buildTypes\s*\{", signing, s, count=1)
        if n == 0:
            fail("buildTypes غير موجود")
        s = s.replace(
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
        )
    if "desugar_jdk_libs" not in s:
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    open(gk, "w").write(s)

    props = os.path.join(android, "gradle.properties")
    text = open(props).read() if os.path.exists(props) else ""
    if "org.gradle.jvmargs" not in text:
        text += "\norg.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:+HeapDumpOnOutOfMemoryError\n"
    if "android.useAndroidX" not in text:
        text += "android.useAndroidX=true\n"
    open(props, "w").write(text)
    print("✓ Android → " + APP_ID)


def write_privacy_manifest(ios, collected):
    """App Store: ملف الخصوصية (Privacy Manifest) — يُضاف للمشروع في CI عبر xcodeproj."""
    def item(t):
        return {"NSPrivacyCollectedDataType": t, "NSPrivacyCollectedDataTypeLinked": True,
                "NSPrivacyCollectedDataTypeTracking": False,
                "NSPrivacyCollectedDataTypePurposes": ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]}
    data = {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [item(t) for t in collected],
        "NSPrivacyAccessedAPITypes": [
            {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults", "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]},
            {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp", "NSPrivacyAccessedAPITypeReasons": ["C617.1"]},
            {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategorySystemBootTime", "NSPrivacyAccessedAPITypeReasons": ["35F9.1"]},
            {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryDiskSpace", "NSPrivacyAccessedAPITypeReasons": ["E174.1"]},
        ],
    }
    with open(os.path.join(ios, "Runner", "PrivacyInfo.xcprivacy"), "wb") as f:
        plistlib.dump(data, f)


def setup_ios():
    ios = os.path.join(ROOT, "ios")
    if not os.path.isdir(ios):
        fail("ios/ غير موجود — شغل flutter create أولاً")
    plist_path = os.path.join(ios, "Runner", "Info.plist")
    with open(plist_path, "rb") as f:
        pl = plistlib.load(f)
    pl["CFBundleDisplayName"] = NAME
    pl["CFBundleName"] = "Rawsam"
    pl["CFBundleDevelopmentRegion"] = "ar"
    pl["CFBundleLocalizations"] = ["ar", "en"]
    pl["NSLocationWhenInUseUsageDescription"] = "حتى توصلك عروض القرب والعروض اللي تخص منطقتك. نحفظ بس منطقتك التقريبية (الكرادة / بغداد) وبعدك عن المركز، مو موقعك بالضبط."
    pl["NSLocationAlwaysAndWhenInUseUsageDescription"] = "حتى يوصلك عرض خاص من تمر قريب من مركز روسم حتى والتطبيق مسدود. نحفظ بس منطقتك التقريبية وبعدك عن المركز، مو موقعك بالضبط."
    pl["NSLocationAlwaysUsageDescription"] = pl["NSLocationAlwaysAndWhenInUseUsageDescription"]
    pl["NSCameraUsageDescription"] = "حتى تصور وترسل صورة للمركز بالمحادثة (مثلاً تصميم التاتو اللي تريده)."
    pl["NSPhotoLibraryUsageDescription"] = "حتى تختار صورة وترسلها للمركز بالمحادثة."
    pl["UIBackgroundModes"] = ["remote-notification"]
    pl["LSApplicationQueriesSchemes"] = ["tel", "https", "comgooglemaps", "maps", "instagram", "fb"]
    pl["ITSAppUsesNonExemptEncryption"] = False
    pl["UIStatusBarStyle"] = "UIStatusBarStyleLightContent"
    pl["FirebaseAppDelegateProxyEnabled"] = True
    with open(plist_path, "wb") as f:
        plistlib.dump(pl, f)

    # native_geofence: تسجيل الإضافات عند إطلاق التطبيق بالخلفية بسبب دخول دائرة المركز
    ad = os.path.join(ios, "Runner", "AppDelegate.swift")
    if os.path.exists(ad):
        s = open(ad).read()
        if "native_geofence" not in s:
            s = s.replace("import Flutter\n", "import Flutter\nimport native_geofence\n", 1)
            s, n = re.subn(
                r"(didFinishLaunchingWithOptions launchOptions:[^\{]*\{\n)",
                "\\1    NativeGeofencePlugin.setPluginRegistrantCallback { registry in\n"
                "      GeneratedPluginRegistrant.register(with: registry)\n"
                "    }\n",
                s,
                count=1,
            )
            if n == 0:
                fail("تعذر تعديل AppDelegate.swift")
        open(ad, "w").write(s)

    # صلاحية الإشعارات البعيدة (Push)
    ent = os.path.join(ios, "Runner", "Runner.entitlements")
    with open(ent, "wb") as f:
        plistlib.dump({"aps-environment": "development"}, f)
    pbx = os.path.join(ios, "Runner.xcodeproj", "project.pbxproj")
    if os.path.exists(pbx):
        t = open(pbx).read()
        if "CODE_SIGN_ENTITLEMENTS" not in t:
            t = re.sub(
                r"(\n(\s*)PRODUCT_BUNDLE_IDENTIFIER = com\.ibraprogram\.rawsam;)",
                r"\n\2CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\1",
                t,
            )
        t = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", t)
        # آيفون فقط (بدون آيباد) — ما يحتاج لقطات آيباد بمراجعة آبل
        t = re.sub(r'TARGETED_DEVICE_FAMILY = "1,2";', "TARGETED_DEVICE_FAMILY = 1;", t)
        open(pbx, "w").write(t)

    sb = os.path.join(ios, "Runner", "Base.lproj", "LaunchScreen.storyboard")
    if os.path.exists(sb):
        s = open(sb).read()
        s = re.sub(
            r'<color key="backgroundColor"[^>]*/>',
            '<color key="backgroundColor" red="0.027" green="0.043" blue="0.11" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
            s,
        )
        open(sb, "w").write(s)

    podfile = os.path.join(ios, "Podfile")
    if os.path.exists(podfile):
        s = open(podfile).read()
        s = re.sub(r"#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.0'", s, count=1)
        open(podfile, "w").write(s)
    write_privacy_manifest(ios, [
        "NSPrivacyCollectedDataTypeName", "NSPrivacyCollectedDataTypePhoneNumber",
        "NSPrivacyCollectedDataTypePhotosorVideos", "NSPrivacyCollectedDataTypeOtherUserContent",
        "NSPrivacyCollectedDataTypeDeviceID", "NSPrivacyCollectedDataTypeCoarseLocation",
    ])
    print("✓ iOS")


if __name__ == "__main__":
    setup_android()
    setup_ios()
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tool", "generate_icons.py"), "--platforms"])
    print("تم تجهيز المنصات ✔")
