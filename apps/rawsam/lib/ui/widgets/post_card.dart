import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/media.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final hasLink = p.url != null && p.url!.isNotEmpty;
    final platformIcon = switch (p.platform ?? (hasLink ? Post.detectPlatform(p.url!) : null)) {
      'instagram' => Icons.camera_alt_rounded,
      'facebook' => Icons.facebook_rounded,
      _ => Icons.auto_awesome_rounded,
    };
    return Glass(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      tint: p.isOffer ? Brand.rose.withValues(alpha: 0.10) : null,
      onTap: hasLink ? () => _open(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (p.isOffer)
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Brand.rose, borderRadius: BorderRadius.circular(8)),
                        child: const Text('عرض', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                    if (p.pinned) const Padding(padding: EdgeInsetsDirectional.only(end: 6), child: Icon(Icons.push_pin_rounded, size: 16, color: Brand.gold)),
                    Expanded(
                      child: Text(p.title.isEmpty ? 'منشور جديد' : p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Icon(platformIcon, size: 18, color: Colors.white.withValues(alpha: 0.6)),
                  ],
                ),
                if (p.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(p.body, style: TextStyle(height: 1.55, color: Colors.white.withValues(alpha: 0.82))),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(Fmt.relative(p.createdAt), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                    const Spacer(),
                    if (hasLink)
                      TextButton.icon(onPressed: () => _open(context), icon: const Icon(Icons.play_circle_rounded), label: const Text('شوف المنشور')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    final embed = post.embedUrl;
    if (embed == null) {
      Launch.url(post.url!);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostViewer(post: post, embedUrl: embed)));
  }
}

/// يعرض منشور الانستغرام/الفيسبوك داخل التطبيق (التضمين الرسمي للمنشورات العامة).
class PostViewer extends StatefulWidget {
  const PostViewer({super.key, required this.post, required this.embedUrl});
  final Post post;
  final String embedUrl;
  @override
  State<PostViewer> createState() => _PostViewerState();
}

class _PostViewerState extends State<PostViewer> {
  late final WebViewController _web;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final host = Uri.parse(widget.embedUrl).host;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Brand.navy)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (req) {
            final h = Uri.tryParse(req.url)?.host ?? '';
            // أي رابط يطلع برا المنشور (بروفايل، تعليقات…) يفتح بتطبيق الانستا/الفيس نفسه
            if (req.isMainFrame && h.isNotEmpty && h != host && !req.url.startsWith(widget.embedUrl)) {
              Launch.url(req.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    final isFb = (widget.post.platform ?? Post.detectPlatform(widget.post.url ?? '')) == 'facebook';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post.title.isEmpty ? 'المنشور' : widget.post.title),
        actions: [
          IconButton(
            tooltip: isFb ? 'افتح بالفيسبوك' : 'افتح بالانستغرام',
            onPressed: () => Launch.url(widget.post.url!),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _web),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: () => Launch.url(widget.post.url!),
          icon: Icon(isFb ? Icons.facebook_rounded : Icons.camera_alt_rounded),
          label: Text(isFb ? 'افتح بالفيسبوك للتعليق واللايك' : 'افتح بالانستغرام للتعليق واللايك'),
        ),
      ),
    );
  }
}
