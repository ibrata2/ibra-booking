import 'package:flutter/widgets.dart';

import '../edition.dart';
import 'strings.dart';
import 'strings_center.dart';
import 'strings_general.dart';

/// الترجمة: العربية افتراضية والإنكليزية كاملة.
class Tr {
  Tr._();

  static String t(String key, {required bool ar, Map<String, Object?> args = const {}}) {
    final pair = (Edition.isCenter ? kCenterStrings[key] : null) ?? (Edition.isBusiness ? kGeneralStrings[key] : null) ?? kStrings[key];
    var s = pair == null ? key : (ar ? pair[0] : pair[1]);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }
}

extension TrContext on BuildContext {
  bool get ar => Localizations.localeOf(this).languageCode == 'ar';
  String t(String key, [Map<String, Object?> args = const {}]) => Tr.t(key, ar: ar, args: args);
}
