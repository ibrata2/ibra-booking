/// إعدادات وقت البناء (تُمرر من GitHub Secrets عبر --dart-define).
///
/// بدون SUPABASE_URL يعمل التطبيق في «وضع العرض» ببيانات تجريبية حتى تشوف شكله.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Firebase (للإشعارات) — من Project settings في Firebase
  static const fbApiKey = String.fromEnvironment('FB_API_KEY');
  static const fbAppIdAndroid = String.fromEnvironment('FB_APP_ID_ANDROID');
  static const fbAppIdIos = String.fromEnvironment('FB_APP_ID_IOS');
  static const fbSenderId = String.fromEnvironment('FB_SENDER_ID');
  static const fbProjectId = String.fromEnvironment('FB_PROJECT_ID');

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
