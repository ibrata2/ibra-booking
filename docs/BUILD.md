# البناء والتثبيت والنشر — IBRA BOOKING

## 1) البناء التلقائي عبر GitHub (موصى به)

1. أنشئ مستودعاً **فارغاً** باسم `ibra-booking`.
2. ارفع كل محتويات المشروع (تأكد أن مجلد `.github/workflows/build.yml` مرفوع — المجلدات التي تبدأ بنقطة قد تكون مخفية).
3. افتح تبويب **Actions** — يبدأ البناء تلقائياً (حوالي 15–25 دقيقة).
4. عند الانتهاء تجد الملفات في **Releases → v1.0.0**.

كل رفع جديد إلى `main` يعيد البناء ويحدّث ملفات الإصدار. لرفع الإصدار غيّر `version:` في `pubspec.yaml` (مثلاً `1.0.1+2`).

### ما يفعله سير العمل
1. `flutter create` يولد مجلدي `android/` و `ios/` بأحدث قوالب Flutter.
2. `python3 tool/setup_platforms.py` يضيف الصلاحيات، مستقبلات الإشعارات، الأصوات المدمجة، الشاشة الافتتاحية، Desugaring، التوقيع، إعدادات Info.plist، ويولد الأيقونات.
3. `flutter analyze` و `flutter test`.
4. بناء APK (عام + لكل معمارية) و AAB، ثم iOS بدون توقيع.

## 2) توقيع أندرويد للنشر على Google Play

بدون إعداد يُوقَّع الـ APK بمفتاح تجريبي (يعمل للتثبيت المباشر). للنشر في Google Play:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ibra
base64 -w0 upload-keystore.jks > keystore.txt
```

في GitHub: **Settings → Secrets and variables → Actions** أضف:

| الاسم | القيمة |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | محتوى `keystore.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | كلمة مرور الملف |
| `ANDROID_KEY_ALIAS` | `ibra` |
| `ANDROID_KEY_PASSWORD` | كلمة مرور المفتاح |

> احتفظ بملف `upload-keystore.jks` في مكان آمن — بدونه لا يمكن تحديث التطبيق في المتجر.

## 3) التثبيت

**أندرويد:** نزّل `android-universal.apk` وثبته (اسمح بالتثبيت من مصادر غير معروفة). عند أول فتح اسمح بالإشعارات و«المنبهات والتذكيرات»، ويفضل استثناء التطبيق من تحسين البطارية من صفحة **المزيد ← التنبيهات**.

**آيفون:** ملف `ios-unsigned.ipa` غير موقّع. وقّعه وثبّته بإحدى الطرق:
- **Sideloadly** أو **AltStore** بحساب Apple ID مجاني (يتجدد كل 7 أيام).
- حساب **Apple Developer** (99$ سنوياً) للتوقيع الدائم و TestFlight / App Store.

## 4) البناء من Xcode (iOS)

نزّل `ios-xcode-project.zip` على جهاز Mac فيه Flutter و Xcode:

```bash
unzip IBRA-BOOKING-1.0.0-ios-xcode-project.zip -d ibra_booking && cd ibra_booking
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

في Xcode: **Runner → Signing & Capabilities** اختر فريقك، ثم **Product → Archive** لإنشاء IPA موقّع أو الرفع إلى App Store Connect.

## 5) البناء محلياً (اختياري)

```bash
flutter create --org com.ibraprogram --project-name ibra_booking --platforms android,ios .
pip install pillow
python3 tool/setup_platforms.py
flutter pub get
flutter test
flutter build apk --release
flutter build appbundle --release
flutter build ios --release --no-codesign   # على Mac
```

## 6) النشر

- **Google Play:** ارفع `android.aab` في Play Console (يتطلب التوقيع أعلاه). صلاحية `SCHEDULE_EXACT_ALARM` و `USE_FULL_SCREEN_INTENT` تحتاج تبريراً في نموذج المتجر: «تطبيق تذكير بمواعيد الحجوزات ومنبه».
- **App Store:** من Xcode Archive بحساب مطور.
- **موقعك:** ارفع الـ APK على https://ibraprogram.netlify.app/

## المتطلبات
- Flutter stable حديث (3.44 أو أحدث)، Dart 3.8+
- Android 7.0 (API 24) فما فوق
- iOS 15 فما فوق
