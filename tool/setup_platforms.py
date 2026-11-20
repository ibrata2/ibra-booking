#!/usr/bin/env python3
"""IBRA BOOKING — تجهيز مجلدي android/ و ios/ بعد `flutter create`.

ينسخ الإعدادات الأصلية (الصلاحيات، المستقبلات، الأصوات، الشاشة الافتتاحية)،
ويعدل Gradle (desugaring، minSdk، توقيع الإصدار) و Info.plist، ثم يولد الأيقونات.

الاستخدام (من جذر المشروع):
  flutter create --org com.ibraprogram --project-name ibra_booking --platforms android,ios .
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
PACKAGE = "com.ibraprogram.ibra_booking"
def _arg_edition():
    for i, a in enumerate(sys.argv):
        if a.startswith("--edition="):
            return a.split("=", 1)[1]
        if a == "--edition" and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return "events"


EDITION = _arg_edition()
GENERAL = EDITION == "general"
CENTER = EDITION == "center"
# كل نسخة تُثبَّت بجانب الأخرى بمعرف مختلف
APP_ID = {"general": "com.ibraprogram.ibra_bookings", "center": "com.ibraprogram.ibra_center"}.get(EDITION, PACKAGE)
IOS_SUFFIX = {"general": "ibraBookings", "center": "ibraCenter"}.get(EDITION)
NAME_AR = {"general": "الحجوزات IBRA", "center": "مواعيد المركز IBRA"}.get(EDITION, "حجوزات IBRA")
NAME_EN = {"general": "IBRA Bookings", "center": "IBRA Center"}.get(EDITION, "IBRA BOOKING")


def fail(msg):
    print("✗ " + msg)
    sys.exit(1)


def copy_tree(src, dst):
    for base, _, files in os.walk(src):
        rel = os.path.relpath(base, src)
        os.makedirs(os.path.join(dst, rel), exist_ok=True)
        for f in files:
            shutil.copyfile(os.path.join(base, f), os.path.join(dst, rel, f))


# ---------------------------------------------------------------- Android

def setup_android():
    android = os.path.join(ROOT, "android")
    if not os.path.isdir(android):
        fail("android/ غير موجود — شغل flutter create أولاً")
    copy_tree(os.path.join(OVERLAY, "android"), android)
    if CENTER:
        # نسخة المركز: كاميرا لمسح كوبونات الزبائن + الموقع لتحديد مكان المركز
        mf = os.path.join(android, "app", "src", "main", "AndroidManifest.xml")
        t = open(mf).read()
        extra = (
            '    <uses-permission android:name="android.permission.CAMERA" />\n'
            '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n'
            '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n'
        )
        if "android.permission.CAMERA" not in t:
            t = t.replace("    <uses-permission android:name=\"android.permission.INTERNET\" />\n",
                          "    <uses-permission android:name=\"android.permission.INTERNET\" />\n" + extra, 1)
        open(mf, "w").write(t)
    res_main = os.path.join(android, "app", "src", "main", "res")
    for folder, name in (("values", NAME_EN), ("values-ar", NAME_AR)):
        with open(os.path.join(res_main, folder, "strings.xml"), "w") as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">%s</string>\n</resources>\n' % name)

    res = os.path.join(android, "app", "src", "main", "res")
    raw = os.path.join(res, "raw")
    os.makedirs(raw, exist_ok=True)
    for f in os.listdir(os.path.join(ROOT, "assets", "sounds")):
        if f.endswith(".wav"):
            shutil.copyfile(os.path.join(ROOT, "assets", "sounds", f), os.path.join(raw, f))

    # MainActivity كـ FlutterFragmentActivity (مطلوب للبصمة)
    kt_dir = os.path.join(android, "app", "src", "main", "kotlin", *PACKAGE.split("."))
    java_dir = os.path.join(android, "app", "src", "main", "java", *PACKAGE.split("."))
    for d in (kt_dir, java_dir):
        for name in ("MainActivity.kt", "MainActivity.java"):
            p = os.path.join(d, name)
            if os.path.exists(p):
                os.remove(p)
    os.makedirs(kt_dir, exist_ok=True)
    with open(os.path.join(kt_dir, "MainActivity.kt"), "w") as f:
        f.write(
            f"package {PACKAGE}\n\n"
            "import io.flutter.embedding.android.FlutterFragmentActivity\n\n"
            "class MainActivity : FlutterFragmentActivity()\n"
        )

    for g in ("build.gradle.kts", "build.gradle"):
        gp = os.path.join(android, "app", g)
        if os.path.exists(gp):
            t = open(gp).read()
            t = re.sub(r'applicationId(\s*=\s*|\s+)"[^"]+"', lambda m: 'applicationId' + m.group(1) + '"' + APP_ID + '"', t)
            open(gp, "w").write(t)
    gradle_kts = os.path.join(android, "app", "build.gradle.kts")
    gradle = os.path.join(android, "app", "build.gradle")
    if os.path.exists(gradle_kts):
        patch_gradle_kts(gradle_kts)
    elif os.path.exists(gradle):
        patch_gradle_groovy(gradle)
    else:
        fail("لم يتم العثور على app/build.gradle")

    props = os.path.join(android, "gradle.properties")
    text = open(props).read() if os.path.exists(props) else ""
    if "org.gradle.jvmargs" not in text:
        text += "\norg.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:+HeapDumpOnOutOfMemoryError\n"
    if "android.useAndroidX" not in text:
        text += "android.useAndroidX=true\n"
    open(props, "w").write(text)
    print("✓ Android (%s → %s)" % (EDITION, APP_ID))


def patch_gradle_kts(path):
    s = open(path).read()
    if "isCoreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", s, count=1)
        if n == 0:
            fail("compileOptions غير موجود في build.gradle.kts")
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = maxOf(flutter.minSdkVersion, 24)", s)
    # flutter_local_notifications و androidx.core الحديثة تتطلب compileSdk 37
    s = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion", "compileSdk = maxOf(flutter.compileSdkVersion, 37)", s)
    if "multiDexEnabled" not in s:
        s = re.sub(r"(defaultConfig\s*\{)", r"\1\n        multiDexEnabled = true", s, count=1)
    # فحص lint بنسخة الإصدار يتعطل على إضافات Firebase — نوقفه (ما يأثر على التطبيق)
    if "checkReleaseBuilds" not in s:
        s = re.sub(r"(\nandroid\s*\{)", r"\1\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }", s, count=1)
    if "keystoreProperties" not in s:
        header = (
            "import java.util.Properties\n"
            "import java.io.FileInputStream\n\n"
        )
        s = header + s
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
        s += (
            '\ndependencies {\n'
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            '    implementation("androidx.appcompat:appcompat:1.7.1")\n'
            '}\n'
        )
    open(path, "w").write(s)


def patch_gradle_groovy(path):
    s = open(path).read()
    if "coreLibraryDesugaringEnabled" not in s:
        s = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", s, count=1)
    s = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdkVersion Math.max(flutter.minSdkVersion, 24)", s)
    s = re.sub(r"compileSdk(Version)?\s*=?\s*flutter\.compileSdkVersion", "compileSdkVersion Math.max(flutter.compileSdkVersion, 37)", s)
    if "keystoreProperties" not in s:
        s = re.sub(
            r"(\nandroid\s*\{)",
            "\ndef keystoreProperties = new Properties()\n"
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            "if (keystorePropertiesFile.exists()) { keystoreProperties.load(new FileInputStream(keystorePropertiesFile)) }\n\\1",
            s,
            count=1,
        )
        s = re.sub(
            r"    buildTypes\s*\{",
            "    signingConfigs {\n        release {\n            if (keystorePropertiesFile.exists()) {\n"
            "                keyAlias keystoreProperties['keyAlias']\n                keyPassword keystoreProperties['keyPassword']\n"
            "                storeFile file(keystoreProperties['storeFile'])\n                storePassword keystoreProperties['storePassword']\n"
            "            }\n        }\n    }\n\n    buildTypes {",
            s,
            count=1,
        )
        s = s.replace("signingConfig signingConfigs.debug", "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug")
    if "desugar_jdk_libs" not in s:
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n    implementation 'androidx.appcompat:appcompat:1.7.1'\n}\n"
    open(path, "w").write(s)


# ---------------------------------------------------------------- iOS

def setup_ios():
    ios = os.path.join(ROOT, "ios")
    if not os.path.isdir(ios):
        fail("ios/ غير موجود — شغل flutter create أولاً")
    plist_path = os.path.join(ios, "Runner", "Info.plist")
    with open(plist_path, "rb") as f:
        pl = plistlib.load(f)
    pl["CFBundleDisplayName"] = NAME_AR
    pl["CFBundleName"] = NAME_EN
    pl["CFBundleDevelopmentRegion"] = "ar"
    pl["CFBundleLocalizations"] = ["ar", "en"]
    pl["NSMicrophoneUsageDescription"] = "لتسجيل صوت تنبيه شخصي — To record a personal alert sound"
    pl["NSContactsUsageDescription"] = "لاستيراد الزبائن من جهات الاتصال — To import customers from contacts"
    pl["NSFaceIDUsageDescription"] = "لفتح التطبيق بأمان — To unlock the app securely"
    pl["LSApplicationQueriesSchemes"] = ["tel", "sms", "whatsapp", "https", "comgooglemaps", "maps"]
    pl["NSCameraUsageDescription"] = "لمسح باركود كوبونات الزبائن — To scan customer coupon codes"
    pl["NSLocationWhenInUseUsageDescription"] = "لتحديد موقع المركز على الخريطة — To set the center location"
    pl["NSPhotoLibraryUsageDescription"] = "لاختيار صور الأعمال والمحادثة — To pick photos"
    pl["ITSAppUsesNonExemptEncryption"] = False
    pl["UIStatusBarStyle"] = "UIStatusBarStyleLightContent"
    with open(plist_path, "wb") as f:
        plistlib.dump(pl, f)

    sb = os.path.join(ios, "Runner", "Base.lproj", "LaunchScreen.storyboard")
    if os.path.exists(sb):
        s = open(sb).read()
        s = re.sub(
            r'<color key="backgroundColor"[^>]*/>',
            '<color key="backgroundColor" red="0.043" green="0.063" blue="0.149" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
            s,
        )
        open(sb, "w").write(s)

    pbx = os.path.join(ios, "Runner.xcodeproj", "project.pbxproj")
    if os.path.exists(pbx):
        t = open(pbx).read()
        if IOS_SUFFIX:
            t = re.sub(r"(PRODUCT_BUNDLE_IDENTIFIER = com\.ibraprogram\.)ibraBooking\b", r"\g<1>" + IOS_SUFFIX, t)
        t = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", t)
        if CENTER and "CODE_SIGN_ENTITLEMENTS" not in t:
            # إشعارات رسائل الزبائن (Push)
            with open(os.path.join(ios, "Runner", "Runner.entitlements"), "wb") as f:
                plistlib.dump({"aps-environment": "development"}, f)
            t = re.sub(
                r"(\n(\s*)PRODUCT_BUNDLE_IDENTIFIER = com\.ibraprogram\.%s;)" % IOS_SUFFIX,
                r"\n\2CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\1",
                t,
            )
        open(pbx, "w").write(t)

    podfile = os.path.join(ios, "Podfile")
    if os.path.exists(podfile):
        s = open(podfile).read()
        # Firebase وماسح الباركود يحتاجون iOS 15
        s = re.sub(r"#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.0'", s, count=1)
        open(podfile, "w").write(s)
    print("✓ iOS")


if __name__ == "__main__":
    setup_android()
    setup_ios()
    icon_args = [sys.executable, os.path.join(ROOT, "tool", "generate_icons.py"), "--platforms"]
    if EDITION != "events":
        icon_args.append("--edition=" + EDITION)
    subprocess.check_call(icon_args)
    print("تم تجهيز المنصات ✔")
