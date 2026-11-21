/// إعدادات وقت البناء (تُمرر من GitHub Secrets عبر --dart-define).
///
/// بدون SUPABASE_URL يعمل التطبيق في «وضع العرض» ببيانات تجريبية حتى تشوف شكله.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Firebase (للإشعارات) — من Project settings في Firebase
  static const _fbApiKeyEnv = String.fromEnvironment('FB_API_KEY');
  static const fbApiKey = _fbApiKeyEnv == '' ? 'AIzaSyArRq8gXYYVeiIpI_NrV7lhYtQXmbMpOfU' : _fbApiKeyEnv;
  static const _fbAppIdAndroidEnv = String.fromEnvironment('FB_APP_ID_ANDROID');
  static const fbAppIdAndroid = _fbAppIdAndroidEnv == '' ? '1:81201229438:android:9e6b32e7f8a4ced4b3322f' : _fbAppIdAndroidEnv;
  static const _fbAppIdIosEnv = String.fromEnvironment('FB_APP_ID_IOS');
  static const fbAppIdIos = _fbAppIdIosEnv == '' ? '1:81201229438:ios:bff82d13c6dece18b3322f' : _fbAppIdIosEnv;
  static const _fbSenderIdEnv = String.fromEnvironment('FB_SENDER_ID');
  static const fbSenderId = _fbSenderIdEnv == '' ? '81201229438' : _fbSenderIdEnv;
  static const _fbProjectIdEnv = String.fromEnvironment('FB_PROJECT_ID');
  static const fbProjectId = _fbProjectIdEnv == '' ? 'rawsam-app' : _fbProjectIdEnv;

  /// store = نسخة المتاجر (Google Play / App Store) — site = نسخة موقعك مع التحديث الذاتي.
  static const dist = String.fromEnvironment('DIST', defaultValue: 'site');
  static bool get isStore => dist == 'store';

  static bool get hasCloud => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasFirebase => fbApiKey.isNotEmpty && fbSenderId.isNotEmpty && fbProjectId.isNotEmpty;

  static const centerName = 'روسم للتجميل';
  static const privacyUrl = 'https://ibraprogram.netlify.app/rawsam/privacy.html';
  static const deleteUrl = 'https://ibraprogram.netlify.app/rawsam/delete.html';
  static const customersTopic = 'rs_customers';
}
