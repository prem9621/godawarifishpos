import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/shell_provider.dart';
import '../billing/new_bill_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../daybook/day_book_screen.dart';
import '../items/items_screen.dart';
import '../parties/parties_screen.dart';
import '../purchase/purchase_screen.dart';
import '../reports/reports_screen.dart';
import '../return/sale_return_screen.dart';
import '../settings/settings_screen.dart';
import 'vyapar_home_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  static const _titles = ['Home', 'Dashboard', 'Items', 'Reports'];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InventoryProvider>().loadItems();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _openNewSale() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const NewBillScreen()));
    if (!mounted) return;
    context.read<ShellProvider>().bumpHomeRefresh();
  }

  int _barSelectedIndex(int shellIndex) => shellIndex;

  void _onBarSelected(BuildContext context, ShellProvider shell, int barIndex) {
    shell.setIndex(barIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShellProvider>(
      builder: (context, shell, _) {
        final idx = shell.currentIndex;
        final isHome = idx == 0;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
              return;
            }
            final now = DateTime.now();
            if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
              _lastBackPress = now;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Press back again to exit app')),
              );
              return;
            }
            SystemNavigator.pop();
          },
          child: Scaffold(
            key: _scaffoldKey,
            drawer: _buildDrawer(shell),
            appBar: isHome
                ? null
                : AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    title: Text(_titles[idx]),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => _open(const SettingsScreen()),
                      ),
                    ],
                  ),
            body: IndexedStack(
              index: idx,
              children: const [
                VyaparHomeScreen(),
                DashboardScreen(),
                ItemsScreen(),
                ReportsScreen(),
              ],
            ),
            floatingActionButton: isHome ? _buildFab() : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            bottomNavigationBar: NavigationBar(
              height: 66,
              selectedIndex: _barSelectedIndex(idx),
              onDestinationSelected: (i) => _onBarSelected(context, shell, i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded),
                  label: 'Items',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assessment_outlined),
                  selectedIcon: Icon(Icons.assessment_rounded),
                  label: 'Reports',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        elevation: 6,
        shadowColor: AppTheme.vyaparRed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        color: AppTheme.vyaparRed,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _openNewSale,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'New Sale',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Clean drawer, styled to match the reference design ─────────────────
  Widget _buildDrawer(ShellProvider shell) {
    return Drawer(
      backgroundColor: Colors.white,
      width: 290,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.set_meal_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Godawari Fish',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('Business menu',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                children: [
                  _DrawerItem(
                    icon: Icons.add_shopping_cart_outlined,
                    label: 'New sale',
                    onTap: () { Navigator.pop(context); _openNewSale(); },
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Purchase bill',
                    onTap: () { Navigator.pop(context); _open(const PurchaseScreen()); },
                  ),
                  _DrawerItem(
                    icon: Icons.undo_outlined,
                    label: 'Sale return',
                    onTap: () { Navigator.pop(context); _open(const SaleReturnScreen()); },
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Day book',
                    onTap: () { Navigator.pop(context); _open(const DayBookScreen()); },
                  ),
                  _DrawerItem(
                    icon: Icons.groups_outlined,
                    label: 'Parties',
                    onTap: () { Navigator.pop(context); _open(const PartiesScreen()); },
                  ),
                  _DrawerItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'Items',
                    onTap: () { Navigator.pop(context); shell.setIndex(2); },
                  ),
                  _DrawerItem(
                    icon: Icons.assessment_outlined,
                    label: 'Reports',
                    onTap: () { Navigator.pop(context); shell.setIndex(3); },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () { Navigator.pop(context); _open(const SettingsScreen()); },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryBlue, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Godawari Fish POS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('v1.0', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  DRAWER ITEM — rounded pill highlight on tap, like the reference design
// ──────────────────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _DrawerItem({
    required this.icon, required this.label, required this.onTap,
  }) : selected = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppTheme.primaryBlue.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Icon(icon, size: 21, color: selected ? AppTheme.primaryBlue : const Color(0xFF475569)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.primaryBlue : const Color(0xFF1E293B),
                    )),
              ),
              if (selected)
                Container(
                  width: 4, height: 18,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}