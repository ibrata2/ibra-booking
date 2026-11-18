import 'package:flutter/widgets.dart';

import 'strings.dart';

/// الترجمة: العربية افتراضية والإنكليزية كاملة.
class Tr {
  Tr._();

  static String t(String key, {required bool ar, Map<String, Object?> args = const {}}) {
    final pair = kStrings[key];
    var s = pair == null ? key : (ar ? pair[0] : pair[1]);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }
}

extension TrContext on BuildContext {
  bool get ar => Localizations.localeOf(this).languageCode == 'ar';
  String t(String key, [Map<String, Object?> args = const {}]) => Tr.t(key, ar: ar, args: args);
}
