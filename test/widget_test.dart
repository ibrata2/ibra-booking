import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibra_booking/domain/entities/entities.dart';
import 'package:ibra_booking/presentation/widgets/common.dart';

Widget _wrap(Widget child, {String lang = 'ar'}) => MaterialApp(
  locale: Locale(lang),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('حالة الحجز بالعربية', (tester) async {
    await tester.pumpWidget(_wrap(const StatusChip(BookingStatus.ongoing)));
    expect(find.text('جارٍ الآن'), findsOneWidget);
  });

  testWidgets('حالة الحجز بالإنكليزية', (tester) async {
    await tester.pumpWidget(_wrap(const StatusChip(BookingStatus.noShow), lang: 'en'));
    expect(find.text('No-show'), findsOneWidget);
  });

  testWidgets('اتجاه RTL للعربية', (tester) async {
    late TextDirection dir;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (c) {
            dir = Directionality.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(dir, TextDirection.rtl);
  });
}
