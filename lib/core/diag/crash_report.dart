import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// إذا توقف التطبيق فجأة بالمرة السابقة، نعرض السبب حتى ينرسل للمطوّر، وبعدها نكمل عادي.
Future<void> showLastCrashIfAny() async {
  if (!Platform.isAndroid) return;
  File f;
  String text;
  try {
    f = File('${(await getApplicationSupportDirectory()).path}/last_crash.txt');
    if (!f.existsSync()) return;
    text = f.readAsStringSync();
  } catch (_) {
    return;
  }
  final done = Completer<void>();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('التطبيق توقف بالمرة السابقة')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('انسخ هذا التقرير ودزه للمطوّر حتى يصلح المشكلة:', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                      child: SingleChildScrollView(
                        child: SelectableText(text, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتسخ التقرير')));
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('نسخ التقرير'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () { if (!done.isCompleted) done.complete(); }, child: const Text('متابعة')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await done.future;
  try {
    f.deleteSync();
  } catch (_) {}
}
