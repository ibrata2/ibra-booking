import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rawsam/core/theme.dart';

void main() {
  testWidgets('شعار روسم للتجميل', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Center(child: BrandTitle()))),
      ),
    );
    expect(find.text('روسم'), findsOneWidget);
    expect(find.text('للتجميل'), findsOneWidget);
  });
}
