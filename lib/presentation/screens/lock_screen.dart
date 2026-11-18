import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/l10n/tr.dart';
import '../../core/security/sha256.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// لوحة أرقام PIN (تستخدم للقفل ولإعداد الرمز).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.title, required this.onComplete, this.length = 4, this.error, this.extra});
  final String title;
  final int length;
  final String? error;
  final Widget? extra;
  final Future<bool> Function(String pin) onComplete;
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _shake = false;

  Future<void> _tap(String d) async {
    if (_pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == widget.length) {
      final ok = await widget.onComplete(_pin);
      if (!mounted) return;
      if (!ok) {
        HapticFeedback.heavyImpact();
        setState(() => _shake = true);
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (mounted) {
        setState(() {
          _pin = '';
          _shake = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget key(String d) => Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _tap(d),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.12),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
          ),
          child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        AnimatedSlide(
          offset: _shake ? const Offset(0.05, 0) : Offset.zero,
          duration: const Duration(milliseconds: 80),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.length; i++)
                Container(
                  margin: const EdgeInsets.all(8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < _pin.length ? primary : primary.withValues(alpha: 0.2)),
                ),
            ],
          ),
        ),
        if (widget.error != null) Text(widget.error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) key(d)]),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 88, height: 88, child: widget.extra),
                  key('0'),
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: IconButton(
                      onPressed: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// شاشة القفل (PIN + بصمة/Face ID).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _auth = LocalAuthentication();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ref.read(settingsProvider).biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  Future<void> _bio() async {
    try {
      final ok = await _auth.authenticate(localizedReason: Tr.t('unlock_reason', ar: ref.read(settingsProvider).isArabic), biometricOnly: true);
      if (ok) widget.onUnlocked();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return Material(
      color: Colors.transparent,
      child: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset('assets/images/logo.png', width: 84, height: 84)),
                  const SizedBox(height: 10),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [Brand.red, Brand.blue]).createShader(r),
                    child: Text(
                      context.t('app_name'),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PinPad(
                    title: context.t('enter_pin'),
                    error: _error,
                    extra: s.biometric ? IconButton(onPressed: _bio, icon: const Icon(Icons.fingerprint_rounded, size: 36)) : null,
                    onComplete: (pin) async {
                      if (Sha256.pin(pin) == s.pinHash) {
                        widget.onUnlocked();
                        return true;
                      }
                      setState(() => _error = context.t('wrong_pin'));
                      return false;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
