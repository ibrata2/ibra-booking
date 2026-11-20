import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/media.dart';
import '../../state.dart';

/// «وصّلني»: يفتح الطريق بكوكل ماب، ويشغّل صوت الترحيب، وخطوات الوصول داخل المول بصوت عراقي.
class DirectionsScreen extends ConsumerStatefulWidget {
  const DirectionsScreen({super.key});
  @override
  ConsumerState<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends ConsumerState<DirectionsScreen> {
  int? _playing;

  @override
  void dispose() {
    VoiceGuide.stop();
    super.dispose();
  }

  Future<void> _play(int key, String? url) async {
    setState(() => _playing = key);
    final ok = await VoiceGuide.play(url);
    if (!ok && mounted) toast(context, 'الصوت مو جاهز بعد');
    if (mounted) setState(() => _playing = null);
  }

  Future<void> _go() async {
    final c = centerOf(ref);
    VoiceGuide.play(c.welcomeVoiceUrl);
    await Launch.directions(c);
  }

  @override
  Widget build(BuildContext context) {
    final c = centerOf(ref);
    final steps = ref.watch(mallStepsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('وصّلني للمركز')),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 46, color: Brand.rose),
                    const SizedBox(height: 8),
                    Text(c.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(c.address, textAlign: TextAlign.center, style: TextStyle(height: 1.5, color: Colors.white.withValues(alpha: 0.8))),
                    if (c.workingHours.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('🕘 ${c.workingHours}', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: _go, icon: const Icon(Icons.navigation_rounded), label: const Text('ابدأ الطريق')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _play(-1, c.welcomeVoiceUrl),
                            icon: Icon(_playing == -1 ? Icons.graphic_eq_rounded : Icons.volume_up_rounded),
                            label: const Text('صوت الترحيب'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(onPressed: () => Launch.call(c.phone), icon: const Icon(Icons.call_rounded), label: const Text('اتصل بينا')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'الطريق ينفتح بكوكل ماب. من توصل المول، اتبع الخطوات هنا وصوتها يدلك لحد باب المركز.',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.white.withValues(alpha: 0.6)),
              ),
              if (steps.isNotEmpty) ...[
                const SectionTitle('داخل المول لحد الباب'),
                for (var i = 0; i < steps.length; i++)
                  Glass(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: () => _play(i, steps[i].voiceUrl),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 15, backgroundColor: Brand.blue, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(steps[i].text, style: const TextStyle(height: 1.5))),
                        if (steps[i].voiceUrl != null && steps[i].voiceUrl!.isNotEmpty)
                          Icon(_playing == i ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, color: Brand.sky),
                      ],
                    ),
                  ),
              ],
              if (c.arrivalVoiceUrl != null && c.arrivalVoiceUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _play(-2, c.arrivalVoiceUrl),
                  icon: const Icon(Icons.celebration_rounded),
                  label: const Text('وصلت! 🌸'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
