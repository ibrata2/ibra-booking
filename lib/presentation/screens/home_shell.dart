import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common.dart';
import 'appointment_form_screen.dart';
import 'calendar_screen.dart';
import 'customers_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';

/// الهيكل الرئيسي: خمسة أقسام في الشريط السفلي، وزر إضافة الحجز بارز وزجاجي في المنتصف.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _pages = const [HomeScreen(), CalendarScreen(), CustomersScreen(), MoreScreen()];

  void _add() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppointmentFormScreen()));

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, context.t('nav_home')),
      (Icons.calendar_month_rounded, context.t('nav_calendar')),
      (Icons.people_alt_rounded, context.t('nav_customers')),
      (Icons.more_horiz_rounded, context.t('nav_more')),
    ];
    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: _GlassNavBar(items: items, index: _index, onTap: (i) => setState(() => _index = i), onAdd: _add, addLabel: context.t('nav_add')),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.items, required this.index, required this.onTap, required this.onAdd, required this.addLabel});
  final List<(IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    Widget item(int i) {
      final selected = i == index;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.15 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(items[i].$1, color: selected ? primary : Theme.of(context).hintColor),
                ),
                const SizedBox(height: 3),
                Text(
                  items[i].$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? primary : Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.7),
                  border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.white),
                ),
                child: Row(children: [item(0), item(1), const SizedBox(width: 74), item(2), item(3)]),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Semantics(
              button: true,
              label: addLabel,
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Brand.red, Brand.blue]),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    boxShadow: [
                      BoxShadow(color: Brand.red.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(-4, 6)),
                      BoxShadow(color: Brand.blue.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(4, 8)),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
