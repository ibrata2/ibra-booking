import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../../core/time/time_format.dart';
import '../../data/repositories/sqlite_repositories.dart';
import '../../domain/entities/entities.dart';
import '../../services/launcher_service.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'appointment_details_screen.dart';
import 'appointment_form_screen.dart';

/// حساب إحصائيات الزبون من حجوزاته.
CustomerStats statsFor(Customer c, List<Appointment> appts, Map<int, double> paid, DateTime now) {
  final mine = appts.where((a) => a.customerId == c.id && a.status != BookingStatus.cancelled).toList();
  final fees = mine.fold(0.0, (s, a) => s + a.fee);
  final rem = mine.fold(0.0, (s, a) => s + (a.fee - receivedFor(a, paid)).clamp(0, double.infinity));
  mine.sort((a, b) => b.start.compareTo(a.start));
  return CustomerStats(
    total: mine.length,
    upcoming: mine.where((a) => a.start.isAfter(now)).length,
    totalFees: fees,
    remaining: rem,
    lastDate: mine.isEmpty ? null : mine.first.start,
  );
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final paid = ref.watch(paidTotalsProvider).value ?? const <int, double>{};
    final sym = ref.watch(settingsProvider).currencySymbol;
    final showFin = ref.watch(settingsProvider).showFinance;
    final now = DateTime.now();
    final list = customers.where((c) => _q.isEmpty || c.name.contains(_q) || c.phone.contains(_q)).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(context.t('customers'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: context.t('import_contacts'),
                  onPressed: () => _importContacts(context),
                  icon: const Icon(Icons.contacts_rounded),
                ),
                IconButton.filledTonal(
                  tooltip: context.t('add_customer'),
                  onPressed: () => editCustomer(context, ref, null),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(hintText: context.t('search_customers'), prefixIcon: const Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(icon: Icons.people_outline_rounded, text: context.t('no_customers'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final cu = list[i];
                      final st = statsFor(cu, appts, paid, now);
                      return Glass(
                        blur: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailsScreen(customerId: cu.id!))),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              child: Text(
                                cu.name.isEmpty ? '?' : cu.name.characters.first,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cu.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                                  if (cu.phone.isNotEmpty)
                                    Text(
                                      cu.phone,
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(color: Theme.of(context).hintColor),
                                    ),
                                  Text(
                                    '${context.t('bookings_count')}: ${st.total}'
                                    '${showFin && st.remaining > 0 ? ' • ${context.t('remaining')}: ${MoneyFmt.format(st.remaining, sym)}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: st.remaining > 0 && showFin ? Colors.orange : Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (cu.phone.isNotEmpty) ...[
                              IconButton(
                                onPressed: () => Launcher.call(cu.phone),
                                icon: const Icon(Icons.call_rounded, color: Color(0xFF00C853)),
                              ),
                              IconButton(
                                onPressed: () => Launcher.whatsapp(cu.phone),
                                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _importContacts(BuildContext context) async {
    final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
    if (status != fc.PermissionStatus.granted && status != fc.PermissionStatus.limited) {
      if (context.mounted) toast(context, context.t('contacts_denied'));
      return;
    }
    final all = await fc.FlutterContacts.getAll(properties: {fc.ContactProperty.name, fc.ContactProperty.phone});
    final items = all.where((c) => c.phones.isNotEmpty).toList()..sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<List<fc.Contact>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactsPicker(items: items),
    );
    if (chosen == null || chosen.isEmpty) return;
    final repo = ref.read(customerRepoProvider);
    for (final c in chosen) {
      await repo.findOrCreate(
        name: c.displayName ?? c.phones.first.number,
        phone: c.phones.first.number,
        phone2: c.phones.length > 1 ? c.phones[1].number : '',
      );
    }
    ref.read(dataVersionProvider.notifier).bump();
    if (context.mounted) toast(context, context.t('imported_n', {'n': chosen.length}));
  }
}

class _ContactsPicker extends StatefulWidget {
  const _ContactsPicker({required this.items});
  final List<fc.Contact> items;
  @override
  State<_ContactsPicker> createState() => _ContactsPickerState();
}

class _ContactsPickerState extends State<_ContactsPicker> {
  final _sel = <int>{};
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final idx = [
      for (var i = 0; i < widget.items.length; i++)
        if (_q.isEmpty || (widget.items[i].displayName ?? '').contains(_q) || widget.items[i].phones.first.number.contains(_q)) i,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (c, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(context.t('import_contacts'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, [for (final i in _sel) widget.items[i]]),
                  child: Text('${context.t('import')} (${_sel.length})'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.t('search')),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: idx.length,
              itemBuilder: (c, k) {
                final i = idx[k];
                final ct = widget.items[i];
                return CheckboxListTile(
                  value: _sel.contains(i),
                  onChanged: (v) => setState(() => v == true ? _sel.add(i) : _sel.remove(i)),
                  title: Text(ct.displayName ?? ''),
                  subtitle: Text(ct.phones.first.number, textDirection: TextDirection.ltr),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// إضافة أو تعديل زبون.
Future<void> editCustomer(BuildContext context, WidgetRef ref, Customer? c) async {
  final name = TextEditingController(text: c?.name);
  final phone = TextEditingController(text: c?.phone);
  final phone2 = TextEditingController(text: c?.phone2);
  final address = TextEditingController(text: c?.address);
  final notes = TextEditingController(text: c?.notes);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.t(c == null ? 'add_customer' : 'edit_customer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: ctx.t('customer_name'), prefixIcon: const Icon(Icons.person_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: ctx.t('phone'), prefixIcon: const Icon(Icons.phone_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone2,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: ctx.t('phone2'), prefixIcon: const Icon(Icons.phone_forwarded_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: address,
              decoration: InputDecoration(labelText: ctx.t('address'), prefixIcon: const Icon(Icons.home_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: InputDecoration(labelText: ctx.t('notes'), prefixIcon: const Icon(Icons.notes_rounded)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('save'))),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  final repo = ref.read(customerRepoProvider);
  final data = Customer(
    id: c?.id,
    name: name.text.trim(),
    phone: SqliteCustomerRepository.normalizePhone(phone.text),
    phone2: SqliteCustomerRepository.normalizePhone(phone2.text),
    address: address.text.trim(),
    notes: notes.text.trim(),
    createdAt: c?.createdAt ?? DateTime.now(),
  );
  await repo.save(data);
  ref.read(dataVersionProvider.notifier).bump();
}

class CustomerDetailsScreen extends ConsumerWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.ar;
    final customer = (ref.watch(customersProvider).value ?? const <Customer>[]).where((c) => c.id == customerId).firstOrNull;
    if (customer == null)
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.person_off_rounded, text: context.t('not_found')),
      );
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final paid = ref.watch(paidTotalsProvider).value ?? const <int, double>{};
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final st = statsFor(customer, appts, paid, now);
    final mine = appts.where((a) => a.customerId == customer.id).toList()..sort((a, b) => b.start.compareTo(a.start));
    final upcoming = mine.where((a) => a.start.isAfter(now) && !a.status.isClosed).toList()..sort((a, b) => a.start.compareTo(b.start));
    final past = mine.where((a) => !upcoming.contains(a)).toList();
    EventCategory? cat(Appointment a) => cats.where((c) => c.id == a.categoryId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(onPressed: () => editCustomer(context, ref, customer), icon: const Icon(Icons.edit_rounded)),
          IconButton(
            onPressed: () async {
              if (await confirmDialog(
                context,
                title: context.t('delete_customer'),
                message: context.t('delete_customer_msg'),
                danger: true,
                ok: context.t('delete'),
              )) {
                await ref.read(customerRepoProvider).delete(customer.id!);
                ref.read(dataVersionProvider.notifier).bump();
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(customer: customer))),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('new_booking')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Glass(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    customer.name.isEmpty ? '?' : customer.name.characters.first,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(customer.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                if (customer.phone.isNotEmpty) Text(customer.phone, textDirection: TextDirection.ltr),
                if (customer.phone2.isNotEmpty)
                  Text(
                    customer.phone2,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                if (customer.address.isNotEmpty)
                  Text(
                    customer.address,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (customer.phone.isNotEmpty)
                      RoundAction(
                        icon: Icons.call_rounded,
                        label: context.t('call'),
                        color: const Color(0xFF00C853),
                        onTap: () => Launcher.call(customer.phone),
                      ),
                    if (customer.phone.isNotEmpty)
                      RoundAction(
                        icon: Icons.chat_rounded,
                        label: context.t('whatsapp'),
                        color: const Color(0xFF25D366),
                        onTap: () => Launcher.whatsapp(customer.phone),
                      ),
                    if (customer.phone.isNotEmpty)
                      RoundAction(icon: Icons.sms_rounded, label: context.t('sms'), onTap: () => Launcher.sms(customer.phone)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Mini(label: context.t('bookings_count'), value: '${st.total}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Mini(label: context.t('upcoming'), value: '${st.upcoming}'),
              ),
              if (settings.showFinance) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _Mini(label: context.t('total_fees'), value: MoneyFmt.number(st.totalFees)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Mini(label: context.t('remaining'), value: MoneyFmt.number(st.remaining), color: st.remaining > 0 ? Colors.orange : null),
                ),
              ],
            ],
          ),
          if (customer.notes.isNotEmpty) ...[
            SectionTitle(context.t('notes')),
            Glass(
              child: SizedBox(width: double.infinity, child: Text(customer.notes)),
            ),
          ],
          SectionTitle(context.t('upcoming_bookings'), trailing: Text('${upcoming.length}')),
          if (upcoming.isEmpty) Text(context.t('none'), style: TextStyle(color: Theme.of(context).hintColor)),
          for (final a in upcoming)
            AppointmentTile(
              appt: a,
              category: cat(a),
              now: now,
              showDate: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: a.id!))),
            ),
          SectionTitle(context.t('past_events'), trailing: Text('${past.length}')),
          if (past.isEmpty) Text(context.t('none'), style: TextStyle(color: Theme.of(context).hintColor)),
          for (final a in past)
            AppointmentTile(
              appt: a,
              category: cat(a),
              now: now,
              showDate: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: a.id!))),
            ),
          if (st.lastDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${context.t('last_booking')}: ${TimeFmt.date(st.lastDate!, ar: ar)}',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Glass(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    child: Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color),
          ),
        ),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
      ],
    ),
  );
}
