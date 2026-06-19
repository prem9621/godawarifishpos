import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/printing/thermal_invoice_printer.dart';
import '../../core/receipt/invoice_receipt_pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shell_provider.dart';
import '../../widgets/invoice_detail_sheet.dart';
import '../billing/new_bill_screen.dart';
import '../daybook/day_book_screen.dart';
import '../parties/parties_screen.dart';
import '../parties/party_detail_screen.dart';
import '../settings/settings_screen.dart';

class VyaparHomeScreen extends StatefulWidget {
  const VyaparHomeScreen({super.key});

  @override
  State<VyaparHomeScreen> createState() => _VyaparHomeScreenState();
}

class _VyaparHomeScreenState extends State<VyaparHomeScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  int _segment = 0;
  List<Map<String, dynamic>> _invoices = [];
  bool _loadingInvoices = true;
  bool _loadError = false;
  int _lastHomeRefresh = 0;
  Map<String, double> _stats = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _segment = _tabController.index);
    });
    _loadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = context.watch<ShellProvider>().homeRefreshNonce;
    if (n != _lastHomeRefresh) {
      _lastHomeRefresh = n;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _loadingInvoices = true; _loadError = false; });
    try {
      final rows  = await _db.getInvoices(limit: 40);
      final stats = await _db.getDashboardStats();
      if (mounted) {
        setState(() {
          _invoices        = rows;
          _stats           = stats;
          _loadingInvoices = false;
        });
      }
    } catch (e) {
      debugPrint('Home load error: $e');
      if (mounted) setState(() { _loadingInvoices = false; _loadError = true; });
    }
  }

  Future<void> _editCompanyName() async {
    final s    = context.read<SettingsProvider>();
    final ctrl = TextEditingController(text: s.shopName);
    final ok   = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Shop Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter shop name',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final name = ctrl.text.trim();
      if (name.isNotEmpty) {
        await context.read<SettingsProvider>().updateShopInfo(name: name);
      }
    }
    ctrl.dispose();
  }

  Future<void> _sharePdf(int invoiceId) async {
    final settings = context.read<SettingsProvider>();
    try {
      final inv = await _db.getInvoiceById(invoiceId);
      if (!mounted || inv == null) return;
      final rawItems = inv['items'];
      final items = rawItems is List
          ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final bytes = await InvoiceReceiptPdf.build(invoice: inv, items: items, settings: settings);
      if (!mounted) return;
      final name = inv['invoice_no'] as String? ?? 'bill';
      await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not share PDF: $e'),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _printThermal(int invoiceId) async {
    final settings = context.read<SettingsProvider>();
    try {
      final inv = await _db.getInvoiceById(invoiceId);
      if (!mounted || inv == null) return;
      final rawItems = inv['items'];
      final items = rawItems is List
          ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final err = await ThermalInvoicePrinter.printInvoice(settings: settings, invoice: inv, items: items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Sent to printer ✓'),
        backgroundColor: err == null ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Print failed: $e'),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings     = context.watch<SettingsProvider>();
    final sym          = settings.currencySymbol;
    final needsPrinter = settings.bluetoothPrinter.trim().isEmpty;
    final today        = _stats['today_total'] ?? 0;
    final toReceive    = _stats['to_receive']  ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(settings, needsPrinter, sym, today, toReceive),
            _buildTabBar(),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryBlue,
                onRefresh: () async {
                  await _loadAll();
                  if (mounted) await context.read<CustomerProvider>().loadCustomers();
                },
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactions(sym),
                    _buildParties(sym),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── COMPACT HEADER ─────────────────────────────────────────────────────
  Widget _buildHeader(SettingsProvider settings, bool needsPrinter, String sym, double today, double toReceive) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF1976D2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.set_meal_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                onTap: _editCompanyName,
                child: Row(children: [
                  Flexible(
                    child: Text(
                      settings.shopName.isEmpty ? 'Godawari Fish' : settings.shopName,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined, color: Colors.white54, size: 12),
                ]),
              ),
            ),
            Text(DateFormat('d MMM').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(width: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context)
                      .push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                  icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                ),
                if (needsPrinter)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: Color(0xFFFFB74D), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _StatPill(
                label: "Today's Sales", value: 'Rs.${today.toStringAsFixed(0)}',
                icon: Icons.trending_up_rounded, color: const Color(0xFF69F0AE),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatPill(
                label: 'To Receive', value: 'Rs.${toReceive.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_outlined, color: const Color(0xFFFFCC80),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── TAB BAR ────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryBlue,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: AppTheme.primaryBlue,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [Tab(text: 'Transactions'), Tab(text: 'Parties')],
      ),
    );
  }

  // ─── TRANSACTIONS ───────────────────────────────────────────────────────
  Widget _buildTransactions(String sym) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _quickLinksCard()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              const Text('Recent Sales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push<void>(MaterialPageRoute<void>(builder: (_) => const DayBookScreen())),
                child: const Text('See all',
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
        if (_loadingInvoices)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          )
        else if (_loadError)
          SliverToBoxAdapter(child: _buildErrorState())
        else if (_invoices.isEmpty)
          SliverToBoxAdapter(child: _emptyTransactions())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _txnCard(_invoices[i], sym)),
                childCount: _invoices.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(children: [
        Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Could not load sales data', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        TextButton.icon(onPressed: _loadAll, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry')),
      ]),
    );
  }

  Widget _emptyTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppTheme.primaryBlue),
        ),
        const SizedBox(height: 16),
        const Text('No sales yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Tap "New Sale" to create your first bill.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const NewBillScreen()));
            if (mounted) context.read<ShellProvider>().bumpHomeRefresh();
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('New Sale', style: TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }

  // ─── QUICK LINKS ────────────────────────────────────────────────────────
  Widget _quickLinksCard() {
    final links = [
      _QuickLink(
        icon: Icons.add_shopping_cart_rounded, label: 'New Sale', color: const Color(0xFF1565C0),
        onTap: () async {
          await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const NewBillScreen()));
          if (mounted) context.read<ShellProvider>().bumpHomeRefresh();
        },
      ),
      _QuickLink(
        icon: Icons.assessment_outlined, label: 'Reports', color: const Color(0xFF2E7D32),
        onTap: () => context.read<ShellProvider>().setIndex(3),
      ),
      _QuickLink(
        icon: Icons.groups_outlined, label: 'Parties', color: const Color(0xFFE65100),
        onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const PartiesScreen())),
      ),
      _QuickLink(
        icon: Icons.menu_book_outlined, label: 'Day Book', color: const Color(0xFF6A1B9A),
        onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const DayBookScreen())),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF2F7)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: links.map((l) => _QuickLinkTile(link: l)).toList(),
        ),
      ),
    );
  }

  // ─── TXN CARD ───────────────────────────────────────────────────────────
  Widget _txnCard(Map<String, dynamic> row, String sym) {
    final id      = row['id'] as int?;
    final name    = (row['customer_name'] as String? ?? 'Walk-in').trim().isEmpty
        ? 'Walk-in'
        : row['customer_name'] as String;
    final invNo   = row['invoice_no'] as String? ?? '';
    final total   = (row['total']   as num?)?.toDouble() ?? 0;
    final balance = (row['balance'] as num?)?.toDouble() ?? 0;
    final paid    = (row['paid']    as num?)?.toDouble() ?? 0;
    final status  = row['status']   as String? ?? 'unpaid';
    final created = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
    final dateLabel = DateFormat('d MMM, yy · h:mm a').format(created);
    final isPaid = status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: id == null ? null : () => showInvoiceDetailSheet(context, id),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: (isPaid ? const Color(0xFF2E7D32) : AppTheme.primaryBlue).withValues(alpha: 0.1),
                    child: Text(
                      name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: isPaid ? const Color(0xFF2E7D32) : AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(dateLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isPaid ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0B2)),
                    ),
                    child: Text(
                      isPaid ? 'PAID' : 'UNPAID',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                          color: isPaid ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
                    ),
                  ),
                ]),
                if ((row['items_summary'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8FE),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      row['items_summary'] as String,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AmountCell(label: 'Total', value: 'Rs.${total.toStringAsFixed(0)}'),
                    _AmountCell(label: 'Paid', value: 'Rs.${paid.toStringAsFixed(0)}', valueColor: const Color(0xFF2E7D32)),
                    _AmountCell(
                      label: 'Balance', value: 'Rs.${balance.toStringAsFixed(0)}',
                      valueColor: balance > 0 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
                Row(children: [
                  Text('#$invNo',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 0.4)),
                  const Spacer(),
                  _ActionBtn(icon: Icons.print_outlined, tooltip: 'Print', onTap: id == null ? null : () => _printThermal(id)),
                  const SizedBox(width: 6),
                  _ActionBtn(icon: Icons.share_outlined, tooltip: 'Share PDF', onTap: id == null ? null : () => _sharePdf(id)),
                  const SizedBox(width: 6),
                  _ActionBtn(icon: Icons.visibility_outlined, tooltip: 'View', onTap: id == null ? null : () => showInvoiceDetailSheet(context, id)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── PARTIES ────────────────────────────────────────────────────────────
  Widget _buildParties(String sym) {
    return Consumer<CustomerProvider>(
      builder: (context, cp, _) {
        if (cp.loading && cp.customers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = cp.customers;

        if (list.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 60),
              Center(
                child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(color: Color(0xFFFFF3E0), shape: BoxShape.circle),
                    child: const Icon(Icons.groups_2_outlined, size: 36, color: Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 16),
                  const Text('No parties yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Add customers or suppliers', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const PartiesScreen())),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Party', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),
              ),
            ],
          );
        }

        final customers = list.where((c) => c.partyType == CustomerModel.typeCustomer);
        final suppliers = list.where((c) => c.partyType == CustomerModel.typeSupplier);
        final totalReceive = customers.fold<double>(0, (s, c) => s + (c.balance > 0 ? c.balance : 0));
        final totalPay = suppliers.fold<double>(0, (s, c) => s + (c.balance > 0 ? c.balance : 0));

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Row(children: [
              Expanded(
                child: _PartySummaryPill(
                  label: 'To Receive', value: 'Rs.${totalReceive.toStringAsFixed(0)}',
                  color: const Color(0xFFE65100), icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PartySummaryPill(
                  label: 'To Pay', value: 'Rs.${totalPay.toStringAsFixed(0)}',
                  color: const Color(0xFF5E35B1), icon: Icons.north_east_rounded,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            ...list.map((c) {
              final bal        = c.balance;
              final isSupplier = c.partyType == CustomerModel.typeSupplier;
              final color      = isSupplier ? const Color(0xFF5E35B1) : const Color(0xFFE65100);
              final initial    = c.name.isNotEmpty ? c.name.substring(0, 1).toUpperCase() : '?';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEF2F7)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: c.id == null
                        ? null
                        : () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(builder: (_) => PartyDetailScreen(customerId: c.id!)),
                            ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Text(initial,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                                  child: Text(isSupplier ? 'Supplier' : 'Customer',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                                ),
                                if (c.phone != null && c.phone!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(c.phone!, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Rs.${bal.abs().toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: bal > 0.009 ? color : const Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Text(
                              bal > 0.009 ? (isSupplier ? 'To Pay' : 'To Receive') : 'Settled',
                              style: TextStyle(fontSize: 10, color: bal > 0.009 ? color : const Color(0xFFCBD5E1)),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCBD5E1)),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  HELPER WIDGETS
// ──────────────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatPill({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

class _QuickLink {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickLink({required this.icon, required this.label, required this.color, required this.onTap});
}

class _QuickLinkTile extends StatelessWidget {
  final _QuickLink link;
  const _QuickLinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: link.onTap,
      child: Column(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: link.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: link.color.withValues(alpha: 0.18)),
          ),
          child: Icon(link.icon, color: link.color, size: 22),
        ),
        const SizedBox(height: 7),
        Text(link.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _AmountCell extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _AmountCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? const Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 31, height: 31,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 15, color: onTap == null ? const Color(0xFFCBD5E1) : AppTheme.primaryBlue),
        ),
      ),
    );
  }
}

class _PartySummaryPill extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _PartySummaryPill({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ]),
    );
  }
}