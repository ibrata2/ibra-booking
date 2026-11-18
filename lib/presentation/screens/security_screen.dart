import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/l10n/tr.dart';
import '../../core/security/sha256.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'lock_screen.dart';

/// الخصوصية والأمان: رمز PIN، البصمة، Face ID.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _auth = LocalAuthentication();
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final ok = await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
        if (mounted) setState(() => _bioAvailable = ok);
      } catch (_) {}
    }();
  }

  Future<String?> _askPin(String title) => Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (c) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: PinPad(
            title: title,
            onComplete: (pin) async {
              Navigator.pop(c, pin);
              return true;
            },
          ),
        ),
      ),
    ),
  );

  Future<void> _setPin() async {
    final a = await _askPin(context.t('new_pin'));
    if (a == null || !mounted) return;
    final b = await _askPin(context.t('confirm_pin'));
    if (b == null || !mounted) return;
    if (a != b) {
      toast(context, context.t('pin_mismatch'));
      return;
    }
    final s = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).set(s.copyWith(pinHash: Sha256.pin(a)));
    if (mounted) toast(context, context.t('pin_set'));
  }

  Future<bool> _verify() async {
    final s = ref.read(settingsProvider);
    final p = await _askPin(context.t('enter_pin'));
    return p != null && Sha256.pin(p) == s.pinHash;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('security'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Glass(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.pin_rounded),
                  value: s.hasPin,
                  title: Text(context.t('pin_lock')),
                  subtitle: Text(context.t('pin_lock_hint')),
                  onChanged: (v) async {
                    if (v) {
                      await _setPin();
                    } else if (await _verify()) {
                      await ref.read(settingsProvider.notifier).set(s.copyWith(pinHash: '', biometric: false));
                    } else if (context.mounted) {
                      toast(context, context.t('wrong_pin'));
                    }
                  },
                ),
                if (s.hasPin)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.password_rounded),
                    title: Text(context.t('change_pin')),
                    onTap: () async {
                      if (await _verify()) {
                        await _setPin();
                      } else if (context.mounted) {
                        toast(context, context.t('wrong_pin'));
                      }
                    },
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.fingerprint_rounded),
                  value: s.biometric && s.hasPin,
                  title: Text(context.t('biometric')),
                  subtitle: Text(_bioAvailable ? context.t('biometric_hint') : context.t('biometric_unavailable')),
                  onChanged: !_bioAvailable || !s.hasPin
                      ? null
                      : (v) async {
                          if (v) {
                            final ok = await _auth.authenticate(localizedReason: context.t('unlock_reason'), biometricOnly: true);
                            if (!ok) return;
                          }
                          await ref.read(settingsProvider.notifier).set(s.copyWith(biometric: v));
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Glass(
            child: Row(
              children: [
                const Icon(Icons.privacy_tip_rounded, color: Color(0xFF00C853)),
                const SizedBox(width: 10),
                Expanded(child: Text(context.t('privacy_note'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
