import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';

// ── Vyapar palette ────────────────────────────────────────────────────────────
const _kNavDark = Color(0xFF1A237E);
const _kNavMid  = Color(0xFF283593);
const _kRed     = Color(0xFFE31E24);
const _kBlue    = Color(0xFF1565C0);
const _kBg      = Color(0xFFF2F6FA);
const _kCard    = Colors.white;
const _kBorder  = Color(0xFFEEF1F6);
const _kText1   = Color(0xFF111827);
const _kText2   = Color(0xFF6B7280);
const _kText3   = Color(0xFF9CA3AF);

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmt(double v, String sym) =>
    '$sym${NumberFormat('#,##,##0.00').format(v)}';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return DateFormat('dd MMM yy').format(d.toLocal());
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        // ── Vyapar-style gradient header with tabs ──────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kNavDark, _kNavMid],
              begin : Alignment.topLeft,
              end   : Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(children: [
                  Container(
                    width : 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color        : Colors.white.withOpacity(0.15),
                      borderRadius : BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Reports',
                      style: TextStyle(
                          fontSize  : 16,
                          fontWeight: FontWeight.w800,
                          color     : Colors.white)),
                ]),
              ),
              const SizedBox(height: 6),
              // Tab bar
              TabBar(
                controller          : _tab,
                labelColor          : Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor      : _kRed,
                indicatorWeight     : 3,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Summary'),
                  Tab(text: 'Bills'),
                  Tab(text: 'Expenses'),
                  Tab(text: 'Profit'),
                ],
              ),
            ]),
          ),
        ),

        // ── Tab content ────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children  : const [
              _SummaryTab(),
              _BillsTab(),
              _ExpensesTab(),
              _ProfitTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  TAB 1 — SUMMARY
// ╚═══════════════════════════════════════════════════════════════════════════╝
class _SummaryTab extends StatefulWidget {
  const _SummaryTab();
  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  bool _loading = true;
  Map<String, double> _dash = {};
  double _purchaseMonth = 0, _expenseMonth = 0, _stockQty = 0,
         _toReceive = 0, _toPay = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db      = DatabaseHelper.instance;
    final results = await Future.wait([
      db.getDashboardStats(),
      db.getMonthPurchaseTotal(),
      db.getMonthExpenseTotal(),
      db.getTotalStockQuantity(),
      db.getSumBalanceForPartyType('customer'),
      db.getSumBalanceForPartyType('supplier'),
    ]);
    if (!mounted) return;
    setState(() {
      _dash          = results[0] as Map<String, double>;
      _purchaseMonth = results[1] as double;
      _expenseMonth  = results[2] as double;
      _stockQty      = results[3] as double;
      _toReceive     = results[4] as double;
      _toPay         = results[5] as double;
      _loading       = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kRed, strokeWidth: 2.5));
    }

    final todaySales = _dash['today_total']    ?? 0;
    final todayPaid  = _dash['today_paid']     ?? 0;
    final monthSales = _dash['month_total']    ?? 0;
    final pending    = _dash['pending_balance']?? 0;
    final todayCount = (_dash['today_count']   ?? 0).toInt();
    final profit     = monthSales - _purchaseMonth - _expenseMonth;

    return RefreshIndicator(
      color    : _kRed,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [

          // ── Today hero card ───────────────────────────────────────────
          _SectionLabel(
              label: "TODAY — ${DateFormat('dd MMM yyyy').format(DateTime.now())}"),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
                begin : Alignment.topLeft,
                end   : Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color     : _kNavDark.withOpacity(0.25),
                    blurRadius: 10,
                    offset    : const Offset(0, 4))
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(child: _BlueStat(
                    label: 'Sales',
                    value: _fmt(todaySales, sym),
                    icon : Icons.point_of_sale_outlined)),
                Container(width: 1, height: 48, color: Colors.white24),
                Expanded(child: _BlueStat(
                    label: 'Collected',
                    value: _fmt(todayPaid, sym),
                    icon : Icons.payments_outlined)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _BlueStat(
                    label: 'Bills',
                    value: '$todayCount',
                    icon : Icons.receipt_long_outlined)),
                Container(width: 1, height: 48, color: Colors.white24),
                Expanded(child: _BlueStat(
                    label : 'Pending',
                    value : _fmt(todaySales - todayPaid, sym),
                    icon  : Icons.pending_outlined,
                    accent: Colors.orangeAccent.shade200)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // ── This month ────────────────────────────────────────────────
          const _SectionLabel(label: 'THIS MONTH'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard(
                label: 'Sales',
                value: _fmt(monthSales, sym),
                icon : Icons.trending_up_rounded,
                color: _kBlue)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
                label: 'Purchase',
                value: _fmt(_purchaseMonth, sym),
                icon : Icons.shopping_bag_outlined,
                color: Colors.purple.shade600)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard(
                label: 'Expenses',
                value: _fmt(_expenseMonth, sym),
                icon : Icons.money_off_outlined,
                color: Colors.orange.shade700)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
                label: 'Net Profit',
                value: _fmt(profit, sym),
                icon : profit >= 0
                    ? Icons.thumb_up_alt_outlined
                    : Icons.thumb_down_alt_outlined,
                color: profit >= 0 ? Colors.green.shade700 : _kRed)),
          ]),
          const SizedBox(height: 16),

          // ── Party balances ────────────────────────────────────────────
          const _SectionLabel(label: 'PARTY BALANCES'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color        : _kCard,
              borderRadius : BorderRadius.circular(12),
              border       : Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                    color     : Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset    : const Offset(0, 2))
              ],
            ),
            child: Column(children: [
              _BalanceRow(
                  label   : 'To Receive (Customers)',
                  value   : _toReceive,
                  sym     : sym,
                  positive: true,
                  icon    : Icons.arrow_downward_rounded),
              const Divider(height: 1, color: _kBorder),
              _BalanceRow(
                  label   : 'To Pay (Suppliers)',
                  value   : _toPay,
                  sym     : sym,
                  positive: false,
                  icon    : Icons.arrow_upward_rounded),
              const Divider(height: 1, color: _kBorder),
              _BalanceRow(
                  label   : 'Unpaid Bills (Pending)',
                  value   : pending,
                  sym     : sym,
                  positive: false,
                  icon    : Icons.receipt_long_outlined),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Inventory ─────────────────────────────────────────────────
          const _SectionLabel(label: 'INVENTORY'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color        : _kCard,
              borderRadius : BorderRadius.circular(12),
              border       : Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                    color     : Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset    : const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Container(
                width : 44,
                height: 44,
                decoration: BoxDecoration(
                    color        : Colors.teal.shade50,
                    borderRadius : BorderRadius.circular(10)),
                child: Icon(Icons.inventory_2_outlined,
                    color: Colors.teal.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Stock on Hand',
                    style: TextStyle(fontSize: 12, color: _kText2)),
                Text('${_stockQty.toStringAsFixed(1)} Kg',
                    style: const TextStyle(
                        fontSize  : 20,
                        fontWeight: FontWeight.w800,
                        color     : _kText1)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  TAB 2 — BILLS
// ╚═══════════════════════════════════════════════════════════════════════════╝
class _BillsTab extends StatefulWidget {
  const _BillsTab();
  @override
  State<_BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends State<_BillsTab> {
  bool _loading    = true;
  List<Map<String, dynamic>> _invoices = [];
  String _statusFilter = 'All';
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();
  final _search  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DatabaseHelper.instance.getInvoices(
      from  : _from,
      to    : _to,
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      status: _statusFilter == 'All' ? null : _statusFilter.toLowerCase(),
    );
    if (!mounted) return;
    setState(() { _invoices = rows; _loading = false; });
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context    : context,
      initialDate: isFrom ? _from : _to,
      firstDate  : DateTime(2020),
      lastDate   : DateTime.now(),
      builder: (ctx, child) => Theme(
        data : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _kNavDark)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (isFrom) { _from = picked; } else { _to = picked; } });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final sym          = context.watch<SettingsProvider>().currencySymbol;
    final totalSales   = _invoices.fold(0.0, (s, r) => s + ((r['total']   as num?)?.toDouble() ?? 0));
    final totalPaid    = _invoices.fold(0.0, (s, r) => s + ((r['paid']    as num?)?.toDouble() ?? 0));
    final totalBalance = _invoices.fold(0.0, (s, r) => s + ((r['balance'] as num?)?.toDouble() ?? 0));

    return Column(children: [
      // ── Filters ─────────────────────────────────────────────────────
      Container(
        color  : _kCard,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child  : Column(children: [
          Row(children: [
            Expanded(child: _DateChip(
                label: DateFormat('dd MMM yy').format(_from),
                icon : Icons.calendar_today_outlined,
                onTap: () => _pickDate(true))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child  : Text('to',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
            Expanded(child: _DateChip(
                label: DateFormat('dd MMM yy').format(_to),
                icon : Icons.calendar_today_outlined,
                onTap: () => _pickDate(false))),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Paid', 'Unpaid', 'Partial'].map((s) {
                final sel = s == _statusFilter;
                return GestureDetector(
                  onTap: () { setState(() => _statusFilter = s); _load(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin : const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color       : sel ? _kRed : _kBg,
                      borderRadius: BorderRadius.circular(20),
                      border      : Border.all(
                          color: sel ? _kRed : _kBorder),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            fontSize  : 12,
                            fontWeight: FontWeight.w700,
                            color     : sel ? Colors.white : _kText2)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            style     : const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18, color: _kText3),
              hintText  : 'Search bills…',
              hintStyle : const TextStyle(fontSize: 13, color: _kText3),
              filled    : true,
              fillColor : _kBg,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide  : const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide  : const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide  : const BorderSide(color: _kBlue, width: 1.5)),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(
                      icon    : const Icon(Icons.clear, size: 16),
                      onPressed: () { _search.clear(); _load(); })
                  : null,
            ),
            onChanged: (_) => _load(),
          ),
        ]),
      ),

      // ── Summary strip ───────────────────────────────────────────────
      if (!_loading)
        Container(
          color  : _kBg,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child  : Row(children: [
            _MiniStat(label: 'Total',    value: _fmt(totalSales,   sym), color: _kNavDark),
            const SizedBox(width: 8),
            _MiniStat(label: 'Received', value: _fmt(totalPaid,    sym), color: Colors.green.shade700),
            const SizedBox(width: 8),
            _MiniStat(label: 'Balance',  value: _fmt(totalBalance, sym), color: _kRed),
            const Spacer(),
            Text('${_invoices.length} bills',
                style: const TextStyle(fontSize: 11, color: _kText3)),
          ]),
        ),

      // ── List ────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kRed, strokeWidth: 2.5))
            : _invoices.isEmpty
                ? const _EmptyState(
                    message: 'No bills found',
                    icon   : Icons.receipt_long_outlined)
                : RefreshIndicator(
                    color    : _kRed,
                    onRefresh: _load,
                    child    : ListView.builder(
                      padding   : const EdgeInsets.fromLTRB(12, 6, 12, 24),
                      itemCount : _invoices.length,
                      itemBuilder: (_, i) =>
                          _BillCard(row: _invoices[i], sym: sym),
                    ),
                  ),
      ),
    ]);
  }
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final String sym;
  const _BillCard({required this.row, required this.sym});

  @override
  Widget build(BuildContext context) {
    final status  = (row['status'] as String? ?? 'unpaid').toLowerCase();
    final total   = (row['total']   as num?)?.toDouble() ?? 0;
    final paid    = (row['paid']    as num?)?.toDouble() ?? 0;
    final balance = (row['balance'] as num?)?.toDouble() ?? 0;
    final method  = row['payment_method'] as String? ?? '';
    final summary = row['items_summary']  as String? ?? '';

    Color  statusColor;
    String statusLabel;
    if (status == 'paid') {
      statusColor = Colors.green.shade700; statusLabel = 'PAID';
    } else if (status == 'partial') {
      statusColor = Colors.orange.shade700; statusLabel = 'PARTIAL';
    } else {
      statusColor = _kRed; statusLabel = 'UNPAID';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color        : _kCard,
        borderRadius : BorderRadius.circular(10),
        border       : Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color     : Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset    : const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          Row(children: [
            // Avatar
            Container(
              width : 36,
              height: 36,
              decoration: BoxDecoration(
                color       : statusColor.withOpacity(0.1),
                shape       : BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  ((row['customer_name'] as String?) ?? 'W')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                      fontSize  : 15,
                      fontWeight: FontWeight.w800,
                      color     : statusColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(row['invoice_no'] as String? ?? '',
                    style: const TextStyle(
                        fontSize  : 12,
                        fontWeight: FontWeight.w800,
                        color     : _kText1)),
                const SizedBox(height: 1),
                Text(row['customer_name'] as String? ?? 'Walk-in',
                    style: const TextStyle(
                        fontSize: 11, color: _kText2)),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(summary,
                      maxLines : 1,
                      overflow : TextOverflow.ellipsis,
                      style    : const TextStyle(
                          fontSize: 10, color: _kText3)),
                ],
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(total, sym),
                  style: const TextStyle(
                      fontSize  : 14,
                      fontWeight: FontWeight.w800,
                      color     : _kText1)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color       : statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border      : Border.all(
                      color: statusColor.withOpacity(0.3)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize  : 9,
                        fontWeight: FontWeight.w800,
                        color     : statusColor)),
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 11, color: _kText3),
            const SizedBox(width: 3),
            Text(_fmtDate(row['created_at'] as String?),
                style: const TextStyle(fontSize: 10, color: _kText3)),
            const SizedBox(width: 8),
            if (method.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color        : _kBg,
                    borderRadius : BorderRadius.circular(4),
                    border       : Border.all(color: _kBorder)),
                child: Text(method,
                    style: const TextStyle(
                        fontSize  : 10,
                        color     : _kText2,
                        fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            if (status != 'paid') ...[
              Text('Paid: ${_fmt(paid, sym)}',
                  style: TextStyle(
                      fontSize: 10, color: Colors.green.shade600)),
              const SizedBox(width: 6),
              Text('Due: ${_fmt(balance, sym)}',
                  style: const TextStyle(
                      fontSize  : 10,
                      color     : _kRed,
                      fontWeight: FontWeight.w700)),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  TAB 3 — EXPENSES
// ╚═══════════════════════════════════════════════════════════════════════════╝
class _ExpensesTab extends StatefulWidget {
  const _ExpensesTab();
  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _expenses = [];
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();
  bool _saving   = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DatabaseHelper.instance
        .getExpenses(from: _from, to: _to);
    if (!mounted) return;
    setState(() { _expenses = rows; _loading = false; });
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context    : context,
      initialDate: isFrom ? _from : _to,
      firstDate  : DateTime(2020),
      lastDate   : DateTime.now(),
      builder: (ctx, child) => Theme(
        data : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _kNavDark)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (isFrom) { _from = picked; } else { _to = picked; } });
    _load();
  }

  Future<void> _addExpense() async {
    final titleCtrl  = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl  = TextEditingController();
    String cat = 'General';

    final ok = await showModalBottomSheet<bool>(
      context           : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setLocal) {
          return Container(
            decoration: const BoxDecoration(
              color        : Colors.white,
              borderRadius : BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: Container(
                      width : 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color        : Colors.grey.shade300,
                          borderRadius : BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width : 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color        : Colors.orange.shade50,
                        borderRadius : BorderRadius.circular(10)),
                    child: Icon(Icons.money_off_outlined,
                        color: Colors.orange.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Add Expense',
                      style: TextStyle(
                          fontSize  : 15,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 18),
                TextField(
                  controller        : titleCtrl,
                  autofocus         : true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText : 'Title *',
                    prefixIcon: const Icon(Icons.label_outline),
                    border    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller  : amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    labelText : 'Amount *',
                    prefixIcon: const Icon(Icons.currency_rupee_outlined),
                    border    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration  : InputDecoration(
                    labelText : 'Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    'General', 'Transport', 'Rent', 'Salary',
                    'Utilities', 'Maintenance', 'Other'
                  ]
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setLocal(() => cat = v ?? cat),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText : 'Notes',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape  : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon : const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Save Expense',
                        style: TextStyle(
                            fontSize  : 14,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
    );

    if (ok != true || !mounted) return;
    final title  = titleCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠ Enter title and valid amount')));
      titleCtrl.dispose(); amountCtrl.dispose(); notesCtrl.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      await DatabaseHelper.instance.insertExpense({
        'title'     : title,
        'amount'    : amount,
        'category'  : cat,
        'notes'     : notesCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content        : Text('✅ "$title" added'),
          backgroundColor: Colors.green.shade700,
          behavior       : SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $e'), backgroundColor: _kRed));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    titleCtrl.dispose(); amountCtrl.dispose(); notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sym   = context.watch<SettingsProvider>().currencySymbol;
    final total = _expenses.fold(0.0,
        (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));

    final byCategory = <String, double>{};
    for (final e in _expenses) {
      final cat = e['category'] as String? ?? 'General';
      byCategory[cat] =
          (byCategory[cat] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
    }

    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed      : _saving ? null : _addExpense,
        backgroundColor: Colors.orange.shade700,
        icon: _saving
            ? const SizedBox(
                width : 18,
                height: 18,
                child : CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense',
            style: TextStyle(
                color     : Colors.white,
                fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Date filter
        Container(
          color  : _kCard,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child  : Row(children: [
            Expanded(child: _DateChip(
                label: DateFormat('dd MMM yy').format(_from),
                icon : Icons.calendar_today_outlined,
                onTap: () => _pickDate(true))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child  : Text('to',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
            Expanded(child: _DateChip(
                label: DateFormat('dd MMM yy').format(_to),
                icon : Icons.calendar_today_outlined,
                onTap: () => _pickDate(false))),
          ]),
        ),

        // Total banner
        if (!_loading)
          Container(
            color  : Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.money_off_outlined,
                  size: 17, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text('Total Expenses',
                  style: TextStyle(
                      fontSize  : 12,
                      color     : Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_fmt(total, sym),
                  style: TextStyle(
                      fontSize  : 15,
                      fontWeight: FontWeight.w800,
                      color     : Colors.orange.shade800)),
            ]),
          ),

        // Category chips
        if (!_loading && byCategory.isNotEmpty)
          Container(
            color  : _kCard,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child  : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: byCategory.entries.map((e) => Container(
                  margin : const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color        : Colors.orange.shade50,
                    borderRadius : BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(children: [
                    Text(e.key,
                        style: TextStyle(
                            fontSize  : 10,
                            color     : Colors.orange.shade700,
                            fontWeight: FontWeight.w600)),
                    Text(_fmt(e.value, sym),
                        style: TextStyle(
                            fontSize  : 12,
                            fontWeight: FontWeight.w800,
                            color     : Colors.orange.shade800)),
                  ]),
                )).toList(),
              ),
            ),
          ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: _kRed, strokeWidth: 2.5))
              : _expenses.isEmpty
                  ? const _EmptyState(
                      message: 'No expenses found',
                      icon   : Icons.money_off_outlined)
                  : RefreshIndicator(
                      color    : _kRed,
                      onRefresh: _load,
                      child    : ListView.builder(
                        padding   : const EdgeInsets.fromLTRB(12, 8, 12, 100),
                        itemCount : _expenses.length,
                        itemBuilder: (_, i) {
                          final e      = _expenses[i];
                          final amount = (e['amount'] as num?)?.toDouble() ?? 0;
                          final cat    = e['category'] as String? ?? '';
                          final notes  = e['notes']   as String? ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color        : _kCard,
                              borderRadius : BorderRadius.circular(10),
                              border       : Border.all(color: _kBorder),
                              boxShadow: [
                                BoxShadow(
                                    color     : Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset    : const Offset(0, 2))
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(children: [
                                Container(
                                  width : 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color        : Colors.orange.shade50,
                                      borderRadius : BorderRadius.circular(8)),
                                  child: Icon(Icons.money_off_outlined,
                                      size: 17,
                                      color: Colors.orange.shade700),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(e['title'] as String? ?? '',
                                        style: const TextStyle(
                                            fontSize  : 13,
                                            fontWeight: FontWeight.w700,
                                            color     : _kText1)),
                                    if (cat.isNotEmpty || notes.isNotEmpty)
                                      Text(
                                          cat.isNotEmpty ? cat : notes,
                                          style: const TextStyle(
                                              fontSize: 11, color: _kText2)),
                                    Text(
                                        _fmtDate(e['created_at'] as String?),
                                        style: const TextStyle(
                                            fontSize: 10, color: _kText3)),
                                  ]),
                                ),
                                Text(_fmt(amount, sym),
                                    style: TextStyle(
                                        fontSize  : 14,
                                        fontWeight: FontWeight.w800,
                                        color     : Colors.orange.shade800)),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  TAB 4 — PROFIT
// ╚═══════════════════════════════════════════════════════════════════════════╝
class _ProfitTab extends StatefulWidget {
  const _ProfitTab();
  @override
  State<_ProfitTab> createState() => _ProfitTabState();
}

class _ProfitTabState extends State<_ProfitTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _salesReport = [];
  List<Map<String, dynamic>> _topItems    = [];
  double _purchaseMonth = 0, _expenseMonth = 0;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db      = DatabaseHelper.instance;
    final results = await Future.wait([
      db.getSalesReport(_from, _to),
      db.getTopItems(_from, _to),
      db.getMonthPurchaseTotal(),
      db.getMonthExpenseTotal(),
    ]);
    if (!mounted) return;
    setState(() {
      _salesReport   = results[0] as List<Map<String, dynamic>>;
      _topItems      = results[1] as List<Map<String, dynamic>>;
      _purchaseMonth = results[2] as double;
      _expenseMonth  = results[3] as double;
      _loading       = false;
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context    : context,
      initialDate: isFrom ? _from : _to,
      firstDate  : DateTime(2020),
      lastDate   : DateTime.now(),
      builder: (ctx, child) => Theme(
        data : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _kNavDark)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (isFrom) { _from = picked; } else { _to = picked; } });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final sym        = context.watch<SettingsProvider>().currencySymbol;
    final totalSales = _salesReport.fold(0.0,
        (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
    final profit = totalSales - _purchaseMonth - _expenseMonth;
    final margin = totalSales > 0 ? (profit / totalSales * 100) : 0.0;

    return Column(children: [
      // Date filter row
      Container(
        color  : _kCard,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child  : Row(children: [
          Expanded(child: _DateChip(
              label: DateFormat('dd MMM yy').format(_from),
              icon : Icons.calendar_today_outlined,
              onTap: () => _pickDate(true))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child  : Text('to',
                style: TextStyle(color: Colors.grey.shade500)),
          ),
          Expanded(child: _DateChip(
              label: DateFormat('dd MMM yy').format(_to),
              icon : Icons.calendar_today_outlined,
              onTap: () => _pickDate(false))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _load,
            child: Container(
              width : 34,
              height: 34,
              decoration: BoxDecoration(
                color        : _kBg,
                borderRadius : BorderRadius.circular(8),
                border       : Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: _kNavDark),
            ),
          ),
        ]),
      ),

      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                color: _kRed, strokeWidth: 2.5))
            : RefreshIndicator(
                color    : _kRed,
                onRefresh: _load,
                child    : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [

                    // ── P&L card ───────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color        : _kCard,
                        borderRadius : BorderRadius.circular(14),
                        border       : Border.all(color: _kBorder),
                        boxShadow: [
                          BoxShadow(
                              color     : Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset    : const Offset(0, 3))
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Container(
                            width : 3,
                            height: 14,
                            decoration: BoxDecoration(
                                color        : _kRed,
                                borderRadius : BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 8),
                          const Text('Profit & Loss',
                              style: TextStyle(
                                  fontSize  : 13,
                                  fontWeight: FontWeight.w800,
                                  color     : _kText1)),
                        ]),
                        const SizedBox(height: 14),
                        _PLRow(label: 'Sales Revenue',
                            value: totalSales, sym: sym, positive: true),
                        _PLRow(label: 'Purchase Cost',
                            value: _purchaseMonth, sym: sym, positive: false),
                        _PLRow(label: 'Expenses',
                            value: _expenseMonth, sym: sym, positive: false),
                        const Divider(color: _kBorder, height: 20),
                        Row(children: [
                          const Expanded(
                            child: Text('Net Profit',
                                style: TextStyle(
                                    fontSize  : 14,
                                    fontWeight: FontWeight.w800,
                                    color     : _kText1)),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            Text(_fmt(profit, sym),
                                style: TextStyle(
                                    fontSize  : 18,
                                    fontWeight: FontWeight.w900,
                                    color     : profit >= 0
                                        ? Colors.green.shade700
                                        : _kRed)),
                            Text('${margin.toStringAsFixed(1)}% margin',
                                style: TextStyle(
                                    fontSize: 11,
                                    color   : profit >= 0
                                        ? Colors.green.shade600
                                        : _kRed)),
                          ]),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // ── Daily sales ────────────────────────────────────
                    if (_salesReport.isNotEmpty) ...[
                      const _SectionLabel(label: 'DAILY SALES'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color        : _kCard,
                          borderRadius : BorderRadius.circular(12),
                          border       : Border.all(color: _kBorder),
                        ),
                        child: Column(
                          children: _salesReport.take(14).map((row) {
                            final date     = row['date'] as String? ?? '';
                            final cnt      = (row['count'] as num?)?.toInt() ?? 0;
                            final dayTotal = (row['total'] as num?)?.toDouble() ?? 0;
                            final dayPaid  = (row['paid']  as num?)?.toDouble() ?? 0;
                            return Column(children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 10, 12, 10),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(_fmtDate(date),
                                          style: const TextStyle(
                                              fontSize  : 12,
                                              fontWeight: FontWeight.w700,
                                              color     : _kText1)),
                                      Text(
                                          '$cnt bill${cnt == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                              fontSize: 10, color: _kText3)),
                                    ]),
                                  ),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                    Text(_fmt(dayTotal, sym),
                                        style: const TextStyle(
                                            fontSize  : 13,
                                            fontWeight: FontWeight.w800,
                                            color     : _kText1)),
                                    Text('Paid: ${_fmt(dayPaid, sym)}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color   : Colors.green.shade600)),
                                  ]),
                                ]),
                              ),
                              const Divider(height: 1, color: _kBorder),
                            ]);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Top items ──────────────────────────────────────
                    if (_topItems.isNotEmpty) ...[
                      const _SectionLabel(label: 'TOP SELLING ITEMS'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color        : _kCard,
                          borderRadius : BorderRadius.circular(12),
                          border       : Border.all(color: _kBorder),
                        ),
                        child: Column(
                          children: _topItems.asMap().entries.map((entry) {
                            final i    = entry.key;
                            final item = entry.value;
                            final name = item['item_name']     as String? ?? '';
                            final qty  = (item['total_qty']    as num?)?.toDouble() ?? 0;
                            final amt  = (item['total_amount'] as num?)?.toDouble() ?? 0;
                            final pct  = totalSales > 0 ? amt / totalSales : 0.0;
                            return Column(children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 10, 12, 10),
                                child: Row(children: [
                                  // Rank badge
                                  Container(
                                    width : 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: i < 3
                                          ? Colors.amber.shade100
                                          : _kBg,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text('${i + 1}',
                                          style: TextStyle(
                                              fontSize  : 11,
                                              fontWeight: FontWeight.w800,
                                              color     : i < 3
                                                  ? Colors.amber.shade800
                                                  : _kText2)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontSize  : 12,
                                              fontWeight: FontWeight.w700,
                                              color     : _kText1)),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: pct.clamp(0.0, 1.0).toDouble(),
                                          backgroundColor: _kBorder,
                                          valueColor: AlwaysStoppedAnimation(
                                            i == 0
                                                ? Colors.amber.shade600
                                                : i == 1
                                                    ? Colors.blue.shade400
                                                    : Colors.teal.shade400,
                                          ),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                    Text(_fmt(amt, sym),
                                        style: const TextStyle(
                                            fontSize  : 13,
                                            fontWeight: FontWeight.w800,
                                            color     : _kText1)),
                                    Text('${qty.toStringAsFixed(1)} Kg',
                                        style: const TextStyle(
                                            fontSize: 10, color: _kText3)),
                                  ]),
                                ]),
                              ),
                              if (i < _topItems.length - 1)
                                const Divider(height: 1, color: _kBorder),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    ]);
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width : 3,
          height: 13,
          decoration: BoxDecoration(
              color: _kRed, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                fontSize  : 10,
                fontWeight: FontWeight.w800,
                color     : _kText2,
                letterSpacing: 0.4)),
      ]);
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color        : _kCard,
          borderRadius : BorderRadius.circular(10),
          border       : Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color     : Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset    : const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width : 36,
            height: 36,
            decoration: BoxDecoration(
                color        : color.withOpacity(0.1),
                borderRadius : BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: _kText3, fontWeight: FontWeight.w600)),
              Text(value,
                  style: TextStyle(
                      fontSize  : 13,
                      fontWeight: FontWeight.w800,
                      color     : color)),
            ]),
          ),
        ]),
      );
}

class _BlueStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? accent;
  const _BlueStat({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 17, color: accent ?? Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Colors.white60)),
              Text(value,
                  style: TextStyle(
                      fontSize  : 13,
                      fontWeight: FontWeight.w800,
                      color     : accent ?? Colors.white)),
            ]),
          ),
        ]),
      );
}

class _BalanceRow extends StatelessWidget {
  final String label, sym;
  final double value;
  final bool positive;
  final IconData icon;
  const _BalanceRow({
    required this.label,
    required this.value,
    required this.sym,
    required this.positive,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green.shade700 : _kRed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 12, color: _kText1))),
        Text(_fmt(value, sym),
            style: TextStyle(
                fontSize  : 13,
                fontWeight: FontWeight.w800,
                color     : color)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 11, color: _kText2)),
          Text(value,
              style: TextStyle(
                  fontSize  : 11,
                  fontWeight: FontWeight.w800,
                  color     : color)),
        ],
      );
}

class _DateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DateChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color        : _kBg,
            borderRadius : BorderRadius.circular(8),
            border       : Border.all(color: _kBorder),
          ),
          child: Row(children: [
            Icon(icon, size: 13, color: _kText2),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize  : 12,
                    fontWeight: FontWeight.w600,
                    color     : _kText1)),
          ]),
        ),
      );
}

class _PLRow extends StatelessWidget {
  final String label, sym;
  final double value;
  final bool positive;
  const _PLRow({
    required this.label,
    required this.value,
    required this.sym,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(positive ? '+' : '−',
              style: TextStyle(
                  fontSize  : 13,
                  fontWeight: FontWeight.w700,
                  color     : positive
                      ? Colors.green.shade600
                      : _kRed)),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 12, color: _kText1))),
          Text(_fmt(value, sym),
              style: TextStyle(
                  fontSize  : 13,
                  fontWeight: FontWeight.w700,
                  color     : positive
                      ? Colors.green.shade700
                      : _kText1)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width : 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E8), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: _kRed),
            ),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    fontSize  : 14,
                    fontWeight: FontWeight.w600,
                    color     : _kText1)),
            const SizedBox(height: 5),
            const Text('Change filters or date range',
                style: TextStyle(fontSize: 12, color: _kText3)),
          ],
        ),
      );
}