import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/models.dart';
import 'data/repository.dart';

/// يُستبدل عند الإقلاع (main.dart) بالنسخة السحابية أو التجريبية.
final repoProvider = Provider<CenterRepository>((ref) => throw UnimplementedError('repository not initialized'));

final centerInfoProvider = StreamProvider<CenterInfo>((ref) => ref.watch(repoProvider).centerInfo());
final postsProvider = StreamProvider<List<Post>>((ref) => ref.watch(repoProvider).posts());
final worksProvider = FutureProvider<List<WorkItem>>((ref) => ref.watch(repoProvider).works());
final mallStepsProvider = FutureProvider<List<MallStep>>((ref) => ref.watch(repoProvider).mallSteps());
final servicesProvider = FutureProvider<List<ServiceInfo>>((ref) => ref.watch(repoProvider).services());
final messagesProvider = StreamProvider<List<ChatMessage>>((ref) => ref.watch(repoProvider).messages());
final unreadProvider = StreamProvider<int>((ref) => ref.watch(repoProvider).unreadCount());
final couponsProvider = StreamProvider<List<Coupon>>((ref) => ref.watch(repoProvider).coupons());
final bookingsProvider = StreamProvider<List<Booking>>((ref) => ref.watch(repoProvider).bookings());

CenterInfo centerOf(WidgetRef ref) => ref.watch(centerInfoProvider).value ?? const CenterInfo();

class ProfileNotifier extends Notifier<CustomerProfile> {
  @override
  CustomerProfile build() => const CustomerProfile();

  void setLoaded(CustomerProfile p) => state = p;

  Future<void> save(CustomerProfile p) async {
    state = p;
    await ref.read(repoProvider).saveProfile(p);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, CustomerProfile>(ProfileNotifier.new);

/// القسم المفتوح في الشريط السفلي.
class TabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

final tabProvider = NotifierProvider<TabNotifier, int>(TabNotifier.new);

class Tabs {
  Tabs._();
  static const home = 0;
  static const works = 1;
  static const chat = 2;
  static const gifts = 3;
  static const more = 4;
}
