import 'package:flutter_test/flutter_test.dart';
import 'package:rawsam/core/format.dart';
import 'package:rawsam/data/models.dart';

void main() {
  test('تضمين منشور انستغرام', () {
    final p = Post(id: 1, url: 'https://www.instagram.com/p/AbC123_x/?igsh=xyz', createdAt: DateTime(2026));
    expect(p.embedUrl, 'https://www.instagram.com/p/AbC123_x/embed/captioned/');
    final r = Post(id: 2, url: 'https://www.instagram.com/reels/Zz9/', createdAt: DateTime(2026));
    expect(r.embedUrl, 'https://www.instagram.com/reel/Zz9/embed/captioned/');
  });

  test('تضمين منشور فيسبوك', () {
    final p = Post(id: 1, url: 'https://www.facebook.com/Ibrahemtattoo/posts/123', createdAt: DateTime(2026));
    expect(p.embedUrl, startsWith('https://www.facebook.com/plugins/post.php?href='));
    final v = Post(id: 2, url: 'https://www.facebook.com/reel/555', createdAt: DateTime(2026));
    expect(v.embedUrl, startsWith('https://www.facebook.com/plugins/video.php'));
  });

  test('وقت 12 ساعة', () {
    expect(Fmt.time(DateTime(2026, 1, 1, 0, 5)), '12:05 منتصف الليل');
    expect(Fmt.time(DateTime(2026, 1, 1, 9, 0)), '9:00 صباحاً');
    expect(Fmt.time(DateTime(2026, 1, 1, 12, 30)), '12:30 ظهراً');
    expect(Fmt.time(DateTime(2026, 1, 1, 21, 15)), '9:15 مساءً');
  });

  test('الكوبون المنتهي', () {
    final c = Coupon(id: 1, code: 'RSM-1', title: 't', expiresAt: DateTime.now().subtract(const Duration(days: 1)), createdAt: DateTime(2026));
    expect(c.effectiveStatus, 'expired');
    expect(c.usable, false);
  });

  test('المبالغ', () => expect(Fmt.money(25000), '25,000 د.ع'));
}
