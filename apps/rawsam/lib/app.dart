import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'state.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/shell.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class RawsamApp extends StatelessWidget {
  const RawsamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'روسم للتجميل',
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    theme: AppTheme.dark(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
      child: child ?? const SizedBox(),
    ),
    home: const _Gate(),
  );
}

/// شاشة البداية: تسجيل الدخول التلقائي ثم إما الترحيب (أول مرة) أو التطبيق.
class _Gate extends ConsumerStatefulWidget {
  const _Gate();
  @override
  ConsumerState<_Gate> createState() => _GateState();
}

class _GateState extends ConsumerState<_Gate> {
  late Future<bool> _boot = _start();

  Future<bool> _start() async {
    final repo = ref.read(repoProvider);
    await repo.start().timeout(const Duration(seconds: 25));
    final p = await repo.loadProfile();
    ref.read(profileProvider.notifier).setLoaded(p);
    return p.complete;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _boot,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: AppBackground(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [BrandTitle(size: 44), SizedBox(height: 28), CircularProgressIndicator()],
              ),
            ),
          ),
        );
      }
      if (snap.hasError) {
        return Scaffold(
          body: AppBackground(
            child: Center(
              child: EmptyState(
              icon: Icons.wifi_off_rounded,
              text: 'ما كدرنا نتصل بالمركز.\nتأكد من الإنترنت وحاول مرة ثانية.',
              action: FilledButton.icon(
                onPressed: () => setState(() => _boot = _start()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('حاول مرة ثانية'),
              ),
            ),
            ),
          ),
        );
      }
      if (snap.data == true) return const Shell();
      return OnboardingScreen(onDone: () => setState(() => _boot = Future.value(true)));
    },
  );
}
