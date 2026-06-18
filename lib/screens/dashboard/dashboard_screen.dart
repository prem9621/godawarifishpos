import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shell_provider.dart';
import '../../screens/billing/new_bill_screen.dart';
import '../daybook/day_book_screen.dart';
import '../parties/parties_screen.dart';
import '../purchase/purchase_screen.dart';
import '../return/sale_return_screen.dart';

// â”€â”€ Vyapar color palette â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kDark = Color(0xFF1A237E); // navy header (matches nav + home)
const _kMid = Color(0xFF283593);
const _kPrimary = Color(0xFF1565C0); // primary blue actions
const _kRed = Color(0xFFE31E24); // Vyapar accent red
const _kBg = Color(0xFFF2F6FA); // page background
const _kCard = Colors.white;
const _kBorder = Color(0xFFEEF1F6);
const _kText1 = Color(0xFF111827);
const _kText2 = Color(0xFF6B7280);
const _kText3 = Color(0xFF9CA3AF);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  Future<Map<String, dynamic>>? _statsFuture;
  int _lastHomeRefresh = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _statsFuture = _loadStats().then((v) {
      _animController.forward();
      return v;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = context.watch<ShellProvider>().homeRefreshNonce;
    if (n != _lastHomeRefresh) {
      _lastHomeRefresh = n;
      _statsFuture = _loadStats();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final dash = await _db.getDashboardStats();
    final toReceive =
        await _db.getSumBalanceForPartyType(CustomerModel.typeCustomer);
    final toPay =
        await _db.getSumBalanceForPartyType(CustomerModel.typeSupplier);
    final stock = await _db.getTotalStockQuantity();
    final monthPurchase = await _db.getMonthPurchaseTotal();
    final monthExpense = await _db.getMonthExpenseTotal();
    final recent = await _db.getDayBook();
    return {
      ...dash,
      'to_receive': toReceive,
      'to_pay': toPay,
      'stock_total': stock,
      'month_purchase': monthPurchase,
      'month_expense': monthExpense,
      'recent': recent.take(5).toList(),
    };
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    _animController.reset();
    setState(() {
      _statsFuture = _loadStats().then((v) {
        _animController.forward();
        return v;
      });
    });
    await _statsFuture;
  }

  void _go(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _greetEmoji() {
    final h = DateTime.now().hour;
    if (h < 12) return 'â˜€ï¸';
    if (h < 17) return 'ðŸŒ¤ï¸';
    return 'ðŸŒ™';
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;
    final shopName = context.watch<SettingsProvider>().shopName;
    final now = DateTime.now();
    final dateStr = DateFormat('EEE, d MMM yyyy').format(now);

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kRed,
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting &&
                !snap.hasData;
            final d = snap.data ?? {};

            final todaySales = (d['today_total'] as num?)?.toDouble() ?? 0;
            final todayPaid = (d['today_paid'] as num?)?.toDouble() ?? 0;
            final todayCount = (d['today_count'] as num?)?.toInt() ?? 0;
            final monthSales = (d['month_total'] as num?)?.toDouble() ?? 0;
            final toReceive = (d['to_receive'] as num?)?.toDouble() ?? 0;
            final toPay = (d['to_pay'] as num?)?.toDouble() ?? 0;
            final stock = (d['stock_total'] as num?)?.toDouble() ?? 0;
            final custCount = (d['customer_count'] as num?)?.toInt() ?? 0;
            final monthPurchase =
                (d['month_purchase'] as num?)?.toDouble() ?? 0;
            final monthExpense = (d['month_expense'] as num?)?.toDouble() ?? 0;
            final profit = monthSales - monthPurchase - monthExpense;
            final recentTxns = _asMapList(d['recent']);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: _buildHeader(
                    shopName: shopName,
                    dateStr: dateStr,
                    greeting: _greeting(),
                    greetEmoji: _greetEmoji(),
                  ),
                ),

                if (loading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: _kRed, strokeWidth: 2.5),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // â”€â”€ Today Hero â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                              child: _TodayHeroCard(
                                todaySales: todaySales,
                                todayPaid: todayPaid,
                                todayCount: todayCount,
                                sym: sym,
                              ),
                            ),

                            // â”€â”€ Section: Stats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                            _SectionLabel(
                                title: 'Overview', onRefresh: _refresh),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                              child: _buildStatsRow(
                                toReceive: toReceive,
                                toPay: toPay,
                                stock: stock,
                                custCount: custCount,
                                sym: sym,
                              ),
                            ),

                            // â”€â”€ Month Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                            _SectionLabel(
                                title: DateFormat('MMMM yyyy')
                                    .format(DateTime.now())),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                              child: _MonthSummaryCard(
                                monthSales: monthSales,
                                monthPurchase: monthPurchase,
                                monthExpense: monthExpense,
                                profit: profit,
                                sym: sym,
                              ),
                            ),

                            // â”€â”€ Quick Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                            const _SectionLabel(title: 'Quick Actions'),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                              child: _buildQuickActions(),
                            ),

                            // â”€â”€ Recent Transactions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                            if (recentTxns.isNotEmpty) ...[
                              const _SectionLabel(title: 'Recent Activity'),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 0),
                                child: _RecentTransactions(
                                  txns: recentTxns,
                                  sym: sym,
                                  onViewAll: () => _go(const DayBookScreen()),
                                ),
                              ),
                            ],

                            const SizedBox(height: 110),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // â”€â”€ HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader({
    required String shopName,
    required String dateStr,
    required String greeting,
    required String greetEmoji,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kDark, _kMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Shop avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(greeting,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70)),
                      const SizedBox(width: 4),
                      Text(greetEmoji, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    shopName.isNotEmpty ? shopName : 'Godawari Fish POS',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Date chip + refresh
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _refresh,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Refresh',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ STATS ROW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStatsRow({
    required double toReceive,
    required double toPay,
    required double stock,
    required int custCount,
    required String sym,
  }) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'To Receive',
            value: _fmtAmt(toReceive),
            icon: Icons.call_received_rounded,
            color: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            label: 'To Pay',
            value: _fmtAmt(toPay),
            icon: Icons.call_made_rounded,
            color: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            label: 'Stock',
            value: '${stock.toStringAsFixed(1)}kg',
            icon: Icons.scale_rounded,
            color: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            label: 'Parties',
            value: '$custCount',
            icon: Icons.groups_rounded,
            color: _kPrimary,
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
      ],
    );
  }

  // â”€â”€ QUICK ACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildQuickActions() {
    final actions = [
      _QAction(
        icon: Icons.receipt_long_rounded,
        label: 'New Bill',
        gradient: [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
        onTap: () => _go(const NewBillScreen()),
      ),
      _QAction(
        icon: Icons.local_shipping_outlined,
        label: 'Purchase',
        gradient: [const Color(0xFF065F46), const Color(0xFF10B981)],
        onTap: () => _go(const PurchaseScreen()),
      ),
      _QAction(
        icon: Icons.assignment_return_outlined,
        label: 'Return',
        gradient: [const Color(0xFF92400E), const Color(0xFFF59E0B)],
        onTap: () => _go(const SaleReturnScreen()),
      ),
      _QAction(
        icon: Icons.menu_book_outlined,
        label: 'Day Book',
        gradient: [const Color(0xFF5B21B6), const Color(0xFF8B5CF6)],
        onTap: () => _go(const DayBookScreen()),
      ),
      _QAction(
        icon: Icons.people_alt_outlined,
        label: 'Parties',
        gradient: [const Color(0xFF0E7490), const Color(0xFF06B6D4)],
        onTap: () => _go(const PartiesScreen()),
      ),
      _QAction(
        icon: Icons.inventory_2_outlined,
        label: 'Items',
        gradient: [const Color(0xFF1D4ED8), const Color(0xFF60A5FA)],
        onTap: () => context.read<ShellProvider>().setIndex(2),
      ),
      _QAction(
        icon: Icons.bar_chart_rounded,
        label: 'Reports',
        gradient: [const Color(0xFF9F1239), const Color(0xFFF43F5E)],
        onTap: () => context.read<ShellProvider>().setIndex(3),
      ),
    ];

    return Column(
      children: [
        _ActionRow(actions: actions.take(4).toList()),
        const SizedBox(height: 8),
        _ActionRow(actions: actions.skip(4).toList()),
      ],
    );
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// â”€â”€ SECTION LABEL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SectionLabel extends StatelessWidget {
  final String title;
  final VoidCallback? onRefresh;
  const _SectionLabel({required this.title, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Row(
        children: [
          // Left accent bar â€” Vyapar style
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _kRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _kText1,
                  letterSpacing: 0.2)),
          const Spacer(),
          if (onRefresh != null)
            GestureDetector(
              onTap: onRefresh,
              child:
                  const Icon(Icons.refresh_rounded, size: 16, color: _kText3),
            ),
        ],
      ),
    );
  }
}

// â”€â”€ TODAY HERO CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TodayHeroCard extends StatelessWidget {
  final double todaySales, todayPaid;
  final int todayCount;
  final String sym;

  const _TodayHeroCard({
    required this.todaySales,
    required this.todayPaid,
    required this.todayCount,
    required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    final pending = (todaySales - todayPaid).clamp(0.0, double.infinity);
    final collectedPct =
        todaySales > 0 ? (todayPaid / todaySales).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -35,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.today_rounded,
                              color: Colors.white70, size: 11),
                          SizedBox(width: 5),
                          Text("Today's Sales",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$todayCount ${todayCount == 1 ? 'bill' : 'bills'}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  '$sym ${_fmt(todaySales)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),

                const SizedBox(height: 12),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: collectedPct,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                    minHeight: 5,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    _HeroChip(
                      label: 'Collected',
                      value: '$sym ${_fmt(todayPaid)}',
                      dotColor: const Color(0xFF34D399),
                    ),
                    const Spacer(),
                    _HeroChip(
                      label: 'Pending',
                      value: '$sym ${_fmt(pending)}',
                      dotColor: const Color(0xFFFBBF24),
                      alignRight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _HeroChip extends StatelessWidget {
  final String label, value;
  final Color dotColor;
  final bool alignRight;

  const _HeroChip({
    required this.label,
    required this.value,
    required this.dotColor,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!alignRight) ...[
          Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Column(
          crossAxisAlignment:
              alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(value,
                style: TextStyle(
                    color: dotColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        if (alignRight) ...[
          const SizedBox(width: 6),
          Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        ],
      ],
    );
  }
}

// â”€â”€ MINI STAT CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bgColor;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: _kText3, fontWeight: FontWeight.w500),
              maxLines: 1),
        ],
      ),
    );
  }
}

// â”€â”€ MONTH SUMMARY CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MonthSummaryCard extends StatelessWidget {
  final double monthSales, monthPurchase, monthExpense, profit;
  final String sym;

  const _MonthSummaryCard({
    required this.monthSales,
    required this.monthPurchase,
    required this.monthExpense,
    required this.profit,
    required this.sym,
  });

  String _fmtK(double v) => v >= 100000
      ? '${(v / 100000).toStringAsFixed(1)}L'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}K'
          : v.toStringAsFixed(0);

  int _barFlex(double pct) => ((pct * 100).round()).clamp(1, 100);

  @override
  Widget build(BuildContext context) {
    final isProfit = profit >= 0;
    final total = monthSales + monthPurchase + monthExpense;
    final salesPct = total > 0 ? monthSales / total : 0.0;
    final purPct = total > 0 ? monthPurchase / total : 0.0;
    final expPct = total > 0 ? monthExpense / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.insert_chart_outlined_rounded,
                  size: 14, color: _kPrimary),
              const SizedBox(width: 6),
              const Text('Monthly Summary',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _kText1)),
              const Spacer(),
              _ProfitBadge(isProfit: isProfit, profit: profit, sym: sym),
            ],
          ),

          const SizedBox(height: 12),

          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (salesPct > 0)
                  Expanded(
                    flex: _barFlex(salesPct),
                    child: Container(height: 7, color: const Color(0xFF10B981)),
                  ),
                if (purPct > 0)
                  Expanded(
                    flex: _barFlex(purPct),
                    child: Container(height: 7, color: const Color(0xFFF59E0B)),
                  ),
                if (expPct > 0)
                  Expanded(
                    flex: _barFlex(expPct),
                    child: Container(height: 7, color: const Color(0xFFF87171)),
                  ),
                if (total == 0)
                  Expanded(
                    child: Container(height: 7, color: const Color(0xFFE5E7EB)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _SummaryCell(
                dot: const Color(0xFF10B981),
                label: 'Sales',
                value: '$sym ${_fmtK(monthSales)}',
              ),
              _vDivider(),
              _SummaryCell(
                dot: const Color(0xFFF59E0B),
                label: 'Purchase',
                value: '$sym ${_fmtK(monthPurchase)}',
              ),
              _vDivider(),
              _SummaryCell(
                dot: const Color(0xFFF87171),
                label: 'Expense',
                value: '$sym ${_fmtK(monthExpense)}',
              ),
              _vDivider(),
              _SummaryCell(
                dot: isProfit
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                label: 'Net',
                value: '$sym ${_fmtK(profit.abs())}',
                bold: true,
                valueColor: isProfit
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: _kBorder);
}

class _ProfitBadge extends StatelessWidget {
  final bool isProfit;
  final double profit;
  final String sym;

  const _ProfitBadge(
      {required this.isProfit, required this.profit, required this.sym});

  @override
  Widget build(BuildContext context) {
    final color = isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final bg = isProfit ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final icon =
        isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final label = isProfit ? 'Profit' : 'Loss';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final Color dot;
  final String label, value;
  final bool bold;
  final Color? valueColor;

  const _SummaryCell({
    required this.dot,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 9, color: _kText3)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 11 : 10,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: valueColor ?? const Color(0xFF374151),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// â”€â”€ QUICK ACTION ROW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _QAction {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _QAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
}

class _ActionRow extends StatelessWidget {
  final List<_QAction> actions;
  const _ActionRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: actions.map((a) {
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  a.onTap();
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: a.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: a.gradient.last.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(a.icon, color: Colors.white, size: 21),
                    ),
                    const SizedBox(height: 6),
                    Text(a.label,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kText2),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// â”€â”€ RECENT TRANSACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _RecentTransactions extends StatelessWidget {
  final List<Map<String, dynamic>> txns;
  final String sym;
  final VoidCallback onViewAll;

  const _RecentTransactions({
    required this.txns,
    required this.sym,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 14, color: _kText2),
                const SizedBox(width: 6),
                const Text('Recent Activity',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _kText1)),
                const Spacer(),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _kRed,
                  ),
                  child: const Text('View All',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kRed)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _kBorder),

          ...txns.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final type = (t['type'] as String?) ?? (t['kind'] as String?) ?? '';
            final name = (t['party_name'] as String?) ??
                (t['description'] as String?) ??
                (t['title'] as String?) ??
                (t['subtitle'] as String?) ??
                'â€”';
            final amount = (t['amount'] as num?)?.toDouble() ?? 0;
            final dateRaw = (t['date'] as String?) ?? (t['ts'] as String?);
            String timeStr = '';
            if (dateRaw != null) {
              try {
                final dt = DateTime.parse(dateRaw);
                timeStr = DateFormat('h:mm a').format(dt);
              } catch (_) {}
            }

            final cfg = _txnConfig(type);

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cfg.bg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(cfg.icon, color: cfg.color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cfg.bg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(cfg.label,
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: cfg.color)),
                                ),
                                if (timeStr.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(timeStr,
                                      style: const TextStyle(
                                          fontSize: 10, color: _kText3)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${cfg.sign}$sym${_fmtAmt(amount)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: cfg.amtColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < txns.length - 1)
                  const Divider(
                      height: 1, indent: 58, color: Color(0xFFF9FAFB)),
              ],
            );
          }),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  _TxnConfig _txnConfig(String type) {
    switch (type.toLowerCase()) {
      case 'sale':
      case 'invoice':
        return const _TxnConfig(
          icon: Icons.receipt_long_rounded,
          color: Color(0xFF059669),
          bg: Color(0xFFECFDF5),
          label: 'Sale',
          sign: '+',
          amtColor: Color(0xFF059669),
        );
      case 'purchase':
        return const _TxnConfig(
          icon: Icons.local_shipping_outlined,
          color: Color(0xFFF59E0B),
          bg: Color(0xFFFFFBEB),
          label: 'Purchase',
          sign: '-',
          amtColor: Color(0xFFD97706),
        );
      case 'expense':
        return const _TxnConfig(
          icon: Icons.money_off_rounded,
          color: Color(0xFFEF4444),
          bg: Color(0xFFFEF2F2),
          label: 'Expense',
          sign: '-',
          amtColor: Color(0xFFDC2626),
        );
      case 'payment_in':
        return const _TxnConfig(
          icon: Icons.south_west_rounded,
          color: Color(0xFF3B82F6),
          bg: Color(0xFFEFF6FF),
          label: 'Payment In',
          sign: '+',
          amtColor: Color(0xFF2563EB),
        );
      case 'payment_out':
        return const _TxnConfig(
          icon: Icons.north_east_rounded,
          color: Color(0xFF8B5CF6),
          bg: Color(0xFFF5F3FF),
          label: 'Payment Out',
          sign: '-',
          amtColor: Color(0xFF7C3AED),
        );
      case 'sale_return':
        return const _TxnConfig(
          icon: Icons.assignment_return_outlined,
          color: Color(0xFFF97316),
          bg: Color(0xFFFFF7ED),
          label: 'Return',
          sign: '-',
          amtColor: Color(0xFFEA580C),
        );
      default:
        return _TxnConfig(
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFF6B7280),
          bg: const Color(0xFFF9FAFB),
          label: type,
          sign: '',
          amtColor: const Color(0xFF374151),
        );
    }
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _TxnConfig {
  final IconData icon;
  final Color color, bg, amtColor;
  final String label, sign;
  const _TxnConfig({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.sign,
    required this.amtColor,
  });
}


