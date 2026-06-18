import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/shell_provider.dart';
import '../../services/firebase_sync_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../home/vyapar_home_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;
  late final List<bool> _tabLoaded;

  static const _tabs = [
    _TabMeta(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    _TabMeta(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Sales'),
    _TabMeta(Icons.inventory_2_rounded, Icons.inventory_2_outlined, 'Items'),
    _TabMeta(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Reports'),
    _TabMeta(Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();

    // ── Firebase → ShellProvider wiring (logic unchanged) ──────────────────
    FirebaseSyncService.instance.onRemoteDataChanged = () {
      if (!mounted) return;
      context.read<ShellProvider>().bumpHomeRefresh();
      debugPrint('🔄 Remote data changed — UI refreshed');
    };

    // ── Icon bounce controllers ─────────────────────────────────────────────
    _iconControllers = List.generate(
      _tabs.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _iconScales = _iconControllers
        .map((c) => Tween<double>(begin: 1.0, end: 1.25).animate(
              CurvedAnimation(parent: c, curve: Curves.elasticOut),
            ))
        .toList();
    _tabLoaded = List<bool>.filled(_tabs.length, false)..[1] = true;
  }

  @override
  void dispose() {
    FirebaseSyncService.instance.onRemoteDataChanged = null;
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index, ShellProvider shell) {
    if (shell.currentIndex == index) return;
    HapticFeedback.selectionClick();
    _iconControllers[index].forward(from: 0);
    _tabLoaded[index] = true;
    shell.setIndex(index);
  }

  static const _pages = [
    DashboardScreen(),
    VyaparHomeScreen(),
    InventoryScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellProvider>();
    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: shell.currentIndex,
        children: List.generate(
          _pages.length,
          (i) => _tabLoaded[i] ? _pages[i] : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: _ShellNavBar(
        currentIndex: shell.currentIndex,
        tabs: _tabs,
        iconScales: _iconScales,
        onTap: (i) => _onTabTapped(i, shell),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NAV BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ShellNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_TabMeta> tabs;
  final List<Animation<double>> iconScales;
  final ValueChanged<int> onTap;

  const _ShellNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.iconScales,
    required this.onTap,
  });

  // Brand colors matching VyaparHomeScreen
  static const _navyDark = Color(0xFF1A237E);
  static const _navyMid = Color(0xFF283593);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navyDark, _navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = i == currentIndex;
              final tab = tabs[i];
              return Expanded(
                child: _NavItem(
                  meta: tab,
                  selected: selected,
                  scale: iconScales[i],
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NAV ITEM
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final _TabMeta meta;
  final bool selected;
  final Animation<double> scale;
  final VoidCallback onTap;

  static const _accent = Color(0xFFE31E24);
  static const _accentGlow = Color(0x33E31E24);
  static const _white70 = Color(0xB3FFFFFF);

  const _NavItem({
    required this.meta,
    required this.selected,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: selected
            ? BoxDecoration(
                color: _accentGlow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.4),
                  width: 1,
                ),
              )
            : const BoxDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with bounce scale
            ScaleTransition(
              scale: scale,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  selected ? meta.activeIcon : meta.icon,
                  key: ValueKey(selected),
                  size: selected ? 22 : 20,
                  color: selected ? _accent : _white70,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: selected ? 10 : 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? _accent : _white70,
                letterSpacing: selected ? 0.2 : 0,
              ),
              child: Text(meta.label),
            ),
            // Active dot indicator
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: selected ? 18 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────
class _TabMeta {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _TabMeta(this.activeIcon, this.icon, this.label);
}
