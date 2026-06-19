import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shell_provider.dart';
import '../billing/new_bill_screen.dart';
import '../daybook/day_book_screen.dart';
import '../parties/parties_screen.dart';
import '../purchase/purchase_screen.dart';
import '../return/sale_return_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    try {
      final dash = await _db.getDashboardStats();
      final toReceive = await _db.getSumBalanceForPartyType(CustomerModel.typeCustomer);
      final toPay = await _db.getSumBalanceForPartyType(CustomerModel.typeSupplier);
      final stock = await _db.getTotalStockQuantity();
      final monthPurchase = await _db.getMonthPurchaseTotal();
      final monthExpense = await _db.getMonthExpenseTotal();
      return {
        ...dash,
        'to_receive': toReceive,
        'to_pay': toPay,
        'stock_total': stock,
        'month_purchase': monthPurchase,
        'month_expense': monthExpense,
      };
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      return {};
    }
  }

  Future<void> _refresh() async {
    final future = _loadStats();
    setState(() => _statsFuture = future);
    await future;
  }

  void _go(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      body: RefreshIndicator(
        color: AppTheme.primaryBlue,
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
            final hasError = snap.hasError;
            final d = snap.data ?? {};

            final todaySales = (d['today_total'] as num?)?.toDouble() ?? 0;
            final todayPaid = (d['today_paid'] as num?)?.toDouble() ?? 0;
            final todayCount = (d['today_count'] as num?)?.toInt() ?? 0;
            final monthSales = (d['month_total'] as num?)?.toDouble() ?? 0;
            final toReceive = (d['to_receive'] as num?)?.toDouble() ?? 0;
            final toPay = (d['to_pay'] as num?)?.toDouble() ?? 0;
            final stock = (d['stock_total'] as num?)?.toDouble() ?? 0;
            final custCount = (d['customer_count'] as num?)?.toInt() ?? 0;
            final monthPurchase = (d['month_purchase'] as num?)?.toDouble() ?? 0;
            final monthExpense = (d['month_expense'] as num?)?.toDouble() ?? 0;
            final profit = monthSales - monthPurchase - monthExpense;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildTopBar(dateStr)),

                if (loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (hasError)
                  SliverToBoxAdapter(child: _buildErrorState())
                else ...[
                  SliverToBoxAdapter(
                    child: _TodayHeroCard(
                      todaySales: todaySales, todayPaid: todayPaid,
                      todayCount: todayCount, sym: sym,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildStatsGrid(
                        toReceive: toReceive, toPay: toPay,
                        stock: stock, monthSales: monthSales, sym: sym,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MonthProfitCard(
                        monthSales: monthSales, monthPurchase: monthPurchase,
                        monthExpense: monthExpense, profit: profit, sym: sym,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _InfoBanner(
                        icon: Icons.groups_outlined,
                        text: '$custCount registered parties · ${stock.toStringAsFixed(1)} Kg total stock',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: _buildQuickActions()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Could not load dashboard data',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      ]),
    );
  }

  // ─── TOP BAR ────────────────────────────────────────────────────────────
  Widget _buildTopBar(String dateStr) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE3F2FD),
              foregroundColor: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS GRID ─────────────────────────────────────────────────────────
  Widget _buildStatsGrid({
    required double toReceive, required double toPay,
    required double stock, required double monthSales, required String sym,
  }) {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _StatCard(
              label: 'To Receive', value: 'Rs.${_fmt(toReceive)}',
              icon: Icons.south_west_rounded,
              iconBg: const Color(0xFFFFF3E0), iconColor: const Color(0xFFE65100),
              valueColor: const Color(0xFFE65100),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'To Pay', value: 'Rs.${_fmt(toPay)}',
              icon: Icons.north_east_rounded,
              iconBg: const Color(0xFFEDE7F6), iconColor: const Color(0xFF5E35B1),
              valueColor: const Color(0xFF5E35B1),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _StatCard(
              label: 'Month Sales', value: 'Rs.${_fmt(monthSales)}',
              icon: Icons.bar_chart_rounded,
              iconBg: const Color(0xFFE8F5E9), iconColor: const Color(0xFF2E7D32),
              valueColor: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Total Stock', value: '${stock.toStringAsFixed(1)} Kg',
              icon: Icons.scale_rounded,
              iconBg: const Color(0xFFE3F2FD), iconColor: AppTheme.primaryBlue,
              valueColor: AppTheme.primaryBlue,
            ),
          ),
        ]),
      ],
    );
  }

  // ─── QUICK ACTIONS ──────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      _Action(icon: Icons.add_shopping_cart_rounded, label: 'New Bill',
          color: AppTheme.primaryBlue, onTap: () => _go(const NewBillScreen())),
      _Action(icon: Icons.shopping_bag_outlined, label: 'Purchase',
          color: const Color(0xFF2E7D32), onTap: () => _go(const PurchaseScreen())),
      _Action(icon: Icons.undo_outlined, label: 'Return',
          color: const Color(0xFFE65100), onTap: () => _go(const SaleReturnScreen())),
      _Action(icon: Icons.menu_book_outlined, label: 'Day Book',
          color: const Color(0xFF6A1B9A), onTap: () => _go(const DayBookScreen())),
      _Action(icon: Icons.groups_outlined, label: 'Parties',
          color: const Color(0xFF00695C), onTap: () => _go(const PartiesScreen())),
      _Action(icon: Icons.inventory_2_outlined, label: 'Items',
          color: const Color(0xFF1565C0), onTap: () => context.read<ShellProvider>().setIndex(2)),
      _Action(icon: Icons.assessment_outlined, label: 'Reports',
          color: const Color(0xFFC62828), onTap: () => context.read<ShellProvider>().setIndex(3)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _ActionGroupCard(children: actions.take(4).toList()),
        const SizedBox(height: 10),
        _ActionGroupCard(children: actions.skip(4).toList()),
      ],
    );
  }

  String _fmt(double v) => v >= 100000
      ? '${(v / 100000).toStringAsFixed(1)}L'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}K'
          : v.toStringAsFixed(0);
}

class _ActionGroupCard extends StatelessWidget {
  final List<_Action> children;
  const _ActionGroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children.map((a) => _ActionTile(action: a)).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  TODAY HERO CARD
// ──────────────────────────────────────────────────────────────────────────
class _TodayHeroCard extends StatelessWidget {
  final double todaySales, todayPaid;
  final int todayCount;
  final String sym;

  const _TodayHeroCard({
    required this.todaySales, required this.todayPaid,
    required this.todayCount, required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    final pending = (todaySales - todayPaid).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF1976D2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text("Today's Overview",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Text('$todayCount bills', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          const SizedBox(height: 16),
          const Text('Total Sales', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Rs.${todaySales.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: _HeroStat(
                  label: 'Collected', value: 'Rs.${todayPaid.toStringAsFixed(0)}',
                  color: const Color(0xFF69F0AE)),
            ),
            Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
            Expanded(
              child: _HeroStat(
                  label: 'Pending', value: 'Rs.${pending.toStringAsFixed(0)}',
                  color: const Color(0xFFFFCC80), rightAlign: true),
            ),
          ]),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool rightAlign;

  const _HeroStat({
    required this.label, required this.value, required this.color, this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: rightAlign ? 16 : 0, right: rightAlign ? 0 : 16),
      child: Column(
        crossAxisAlignment: rightAlign ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  STAT CARD
// ──────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconBg, iconColor, valueColor;

  const _StatCard({
    required this.label, required this.value, required this.icon,
    required this.iconBg, required this.iconColor, required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  MONTH PROFIT CARD
// ──────────────────────────────────────────────────────────────────────────
class _MonthProfitCard extends StatelessWidget {
  final double monthSales, monthPurchase, monthExpense, profit;
  final String sym;

  const _MonthProfitCard({
    required this.monthSales, required this.monthPurchase,
    required this.monthExpense, required this.profit, required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMMM').format(DateTime.now());
    final isPositive = profit >= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.insights_rounded, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            Text('$month Summary', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 12,
                  color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                ),
                const SizedBox(width: 4),
                Text(
                  isPositive ? 'Profit' : 'Loss',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _ProfitCell(label: 'Sales', value: 'Rs.${_fmtK(monthSales)}', color: const Color(0xFF2E7D32)),
            _divider(),
            _ProfitCell(label: 'Purchase', value: 'Rs.${_fmtK(monthPurchase)}', color: const Color(0xFFE65100)),
            _divider(),
            _ProfitCell(label: 'Expense', value: 'Rs.${_fmtK(monthExpense)}', color: const Color(0xFFEF5350)),
            _divider(),
            _ProfitCell(
                label: 'Net', value: 'Rs.${_fmtK(profit.abs())}',
                color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F), bold: true),
          ]),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 34, color: const Color(0xFFF1F5F9), margin: const EdgeInsets.symmetric(horizontal: 4));

  String _fmtK(double v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
}

class _ProfitCell extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;

  const _ProfitCell({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: color,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  INFO BANNER
// ──────────────────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF0D47A1), fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  ACTION TILE
// ──────────────────────────────────────────────────────────────────────────
class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});
}

class _ActionTile extends StatelessWidget {
  final _Action action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: action.color.withOpacity(0.18)),
            ),
            child: Icon(action.icon, color: action.color, size: 23),
          ),
          const SizedBox(height: 7),
          Text(action.label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}