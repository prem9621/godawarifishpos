import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shell_provider.dart';
import '../../widgets/invoice_detail_sheet.dart';
import '../../screens/billing/new_bill_screen.dart';
import '../../core/receipt/thermal_invoice_printer.dart';
import '../../core/receipt/invoice_pdf_generator.dart';
import '../../core/receipt/invoice_image_generator.dart';
import '../daybook/day_book_screen.dart';
import '../parties/parties_screen.dart';
import '../parties/party_detail_screen.dart';
import '../purchase/purchase_screen.dart';
import '../settings/settings_screen.dart';

const _kNavDark = Color(0xFF1A237E);
const _kNavMid = Color(0xFF283593);
const _kRed = Color(0xFFE31E24);
const _kBlue = Color(0xFF1565C0);
const _kBg = Color(0xFFF2F6FA);
const _kCard = Colors.white;
const _kBorder = Color(0xFFEEF1F6);

class VyaparHomeScreen extends StatefulWidget {
  const VyaparHomeScreen({super.key});
  @override
  State<VyaparHomeScreen> createState() => _VyaparHomeScreenState();
}

class _VyaparHomeScreenState extends State<VyaparHomeScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _payments = [];
  bool _loadingInvoices = true;
  int _lastHomeRefresh = 0;
  Map<String, double> _stats = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    setState(() => _loadingInvoices = true);
    try {
      final rows = await _db.getInvoices(limit: 40);
      final purchases = await _db.getPurchases();
      final payments = await _db.getRecentPartyPayments(limit: 20);
      final stats = await _db.getDashboardStats();
      if (mounted) {
        setState(() {
          _invoices = rows;
          _purchases = purchases;
          _payments = payments;
          _stats = stats;
          _loadingInvoices = false;
        });
      }
    } catch (e) {
      debugPrint('Home load failed: $e');
      if (mounted) setState(() => _loadingInvoices = false);
    }
  }

  // â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _editCompanyName() async {
    final s = context.read<SettingsProvider>();
    final ctrl = TextEditingController(text: s.shopName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Shop Name',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
              hintText: 'Enter shop name',
              filled: true,
              fillColor: Colors.grey.shade50,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _kBlue),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == true && mounted) {
      await context
          .read<SettingsProvider>()
          .updateShopInfo(name: ctrl.text.trim());
    }
  }

  Future<void> _printThermal(int invoiceId) async {
    final settings = context.read<SettingsProvider>();
    final inv = await _db.getInvoiceById(invoiceId);
    if (!mounted || inv == null) return;
    
    // Get full items
    final db = DatabaseHelper.instance;
    final rows = await (await db.database).query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    final items = rows.map((e) => Map<String, dynamic>.from(e)).toList();

    final err = await ThermalInvoicePrinter.printInvoice(
      settings: settings,
      invoice: inv,
      items: items,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? '✅ Sent to printer'),
      backgroundColor: err == null ? Colors.green : Colors.red,
    ));
  }

  Future<void> _shareInvoice(int invoiceId) async {
    final settings = context.read<SettingsProvider>();
    final inv = await _db.getInvoiceById(invoiceId);
    if (!mounted || inv == null) return;

    final db = DatabaseHelper.instance;
    final rows = await (await db.database).query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    final items = rows.map((e) => Map<String, dynamic>.from(e)).toList();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.teal),
              title: const Text('Share as Image'),
              subtitle: const Text('Generate PNG receipt and share'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await InvoiceImageGenerator.shareInvoiceImage(
                    context: context,
                    invoice: inv,
                    items: items,
                    settings: settings,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
              title: const Text('Share as PDF'),
              subtitle: const Text('Generate PDF invoice and share'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await InvoicePdfGenerator.shareInvoicePdf(
                    invoice: inv,
                    items: items,
                    settings: settings,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _addPartyDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    String partyType = CustomerModel.typeCustomer;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setLocal) {
          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add_alt_1,
                        color: _kBlue, size: 18)),
                const SizedBox(width: 12),
                const Text('Add New Party',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(
                      child: _TypeToggle(
                          label: 'Customer',
                          selected: partyType == CustomerModel.typeCustomer,
                          color: _kBlue,
                          onTap: () => setLocal(
                              () => partyType = CustomerModel.typeCustomer))),
                  Expanded(
                      child: _TypeToggle(
                          label: 'Supplier',
                          selected: partyType == CustomerModel.typeSupplier,
                          color: Colors.indigo,
                          onTap: () => setLocal(
                              () => partyType = CustomerModel.typeSupplier))),
                ]),
              ),
              const SizedBox(height: 14),
              _Field(
                  ctrl: nameCtrl,
                  label: 'Name *',
                  icon: Icons.person_outline,
                  autofocus: true,
                  caps: TextCapitalization.words),
              const SizedBox(height: 10),
              _Field(
                  ctrl: phoneCtrl,
                  label: 'Phone (optional)',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _Field(
                  ctrl: addrCtrl,
                  label: 'Address (optional)',
                  icon: Icons.location_on_outlined),
              const SizedBox(height: 18),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                          backgroundColor:
                              partyType == CustomerModel.typeCustomer
                                  ? _kBlue
                                  : Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save Party',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)))),
            ]),
          );
        }),
      ),
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('âš  Enter party name')));
      return;
    }
    try {
      final now = DateTime.now().toIso8601String();
      await DatabaseHelper.instance.insertCustomer({
        'name': name,
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'address': addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
        'party_type': partyType,
        'balance': 0.0,
        'created_at': now,
        'updated_at': now,
      });
      if (mounted) {
        context.read<CustomerProvider>().loadCustomers();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('âœ… $partyType "$name" added'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('âŒ Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteParty(CustomerModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Party?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text('Delete "${c.name}"? This cannot be undone.',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DatabaseHelper.instance.deleteCustomer(c.id!);
      if (mounted) {
        context.read<CustomerProvider>().loadCustomers();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${c.name}" deleted'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('âŒ Delete failed: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // â”€â”€ BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final sym = settings.currencySymbol;
    final today = _stats['today_total'] ?? 0;
    final toReceive = _stats['to_receive'] ?? 0;
    final toPay = ((_stats['pending_balance'] ?? 0) - toReceive)
        .clamp(0, double.infinity)
        .toDouble();

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _VyaparHeader(
          shopName:
              settings.shopName.isEmpty ? 'Godawari Fish' : settings.shopName,
          today: today,
          toReceive: toReceive,
          toPay: toPay,
          sym: sym,
          onEditName: _editCompanyName,
          onSettings: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          onNewSale: () async {
            await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const NewBillScreen()));
            if (mounted) context.read<ShellProvider>().bumpHomeRefresh();
          },
          onAddParty: _addPartyDialog,
          onParties: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const PartiesScreen())),
          onDayBook: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const DayBookScreen())),
          onPurchase: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const PurchaseScreen())),
        ),

        // â”€â”€ TAB BAR â”€â”€
        Container(
          color: _kCard,
          child: TabBar(
            controller: _tabController,
            labelColor: _kRed,
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: _kRed,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [Tab(text: 'Transactions'), Tab(text: 'Parties')],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: _kRed,
            onRefresh: () async {
              await _loadAll();
              if (mounted) {
                await context.read<CustomerProvider>().loadCustomers();
              }
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
      ]),
    );
  }

  // â”€â”€ TRANSACTIONS TAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTransactions(String sym) {
    // Merge sales + purchases + payments, sort by date desc
    final List<Map<String, dynamic>> merged = [];

    for (final r in _invoices) {
      merged.add({...r, '_kind': 'sale'});
    }
    for (final r in _purchases) {
      merged.add({...r, '_kind': 'purchase'});
    }
    for (final r in _payments) {
      merged.add({...r, '_kind': 'payment'});
    }

    merged.sort((a, b) {
      final ta =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
      final tb =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
      return tb.compareTo(ta);
    });

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              const Text('All Transactions',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
              const Spacer(),
              GestureDetector(
                  onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                          builder: (_) => const DayBookScreen())),
                  child: const Text('See all',
                      style: TextStyle(
                          fontSize: 12,
                          color: _kRed,
                          fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
        if (_loadingInvoices)
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child:
                      Center(child: CircularProgressIndicator(color: _kRed))))
        else if (merged.isEmpty)
          SliverToBoxAdapter(child: _emptyTransactions())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: _VyaparTxnRow(
                    row: merged[i],
                    sym: sym,
                    onTap: () {
                      final kind = merged[i]['_kind'];
                      final id = merged[i]['id'] as int?;
                      if (kind == 'sale' && id != null) {
                        showInvoiceDetailSheet(context, id);
                      }
                    },
                    onPrint: merged[i]['_kind'] == 'sale' && merged[i]['id'] != null
                        ? () => _printThermal(merged[i]['id'] as int)
                        : null,
                    onShare: merged[i]['_kind'] == 'sale' && merged[i]['id'] != null
                        ? () => _shareInvoice(merged[i]['id'] as int)
                        : null,
                  ),
                ),
                childCount: merged.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(children: [
        Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
                color: Color(0xFFFDE8E8), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined,
                size: 32, color: _kRed)),
        const SizedBox(height: 14),
        const Text('No transactions yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text('Tap "New Sale" to create your first bill.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 18),
        FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => const NewBillScreen()));
              if (mounted) context.read<ShellProvider>().bumpHomeRefresh();
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New Sale', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
                backgroundColor: _kRed,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)))),
      ]),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 30, color: Colors.grey.shade200);

  // â”€â”€ PARTIES TAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildParties(String sym) {
    return Consumer<CustomerProvider>(
      builder: (context, cp, _) {
        if (cp.loading && cp.customers.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: _kRed));
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
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFDE8E8), shape: BoxShape.circle),
                    child: const Icon(Icons.groups_2_outlined,
                        size: 32, color: _kRed)),
                const SizedBox(height: 14),
                const Text('No parties yet',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text('Add customers or suppliers',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 18),
                FilledButton.icon(
                    onPressed: _addPartyDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label:
                        const Text('Add Party', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                        backgroundColor: _kRed,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)))),
              ])),
            ],
          );
        }

        final toGet = list
            .where((c) => c.balance > 0.009)
            .fold<double>(0, (s, c) => s + c.balance);
        final toGive = list
            .where((c) => c.balance < -0.009)
            .fold<double>(0, (s, c) => s + c.balance.abs());

        return Stack(children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            children: [
              // Summary
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                      child: _SummaryPill(
                          label: "You'll Get",
                          value: '$sym${toGet.toStringAsFixed(0)}',
                          color: const Color(0xFF2E7D32),
                          icon: Icons.south_west_rounded)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _SummaryPill(
                          label: "You'll Give",
                          value: '$sym${toGive.toStringAsFixed(0)}',
                          color: _kRed,
                          icon: Icons.north_east_rounded)),
                ]),
              ),
              Divider(height: 1, color: Colors.grey.shade200),

              ...list.map((c) {
                final bal = c.balance;
                final isPositive = bal > 0.009;
                final hasBal = bal.abs() > 0.009;
                final Color balColor = !hasBal
                    ? Colors.grey.shade400
                    : isPositive
                        ? const Color(0xFF2E7D32)
                        : _kRed;

                return Column(children: [
                  Dismissible(
                    key: ValueKey(c.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.shade600,
                        child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.white, size: 20),
                              SizedBox(height: 2),
                              Text('Delete',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ])),
                    confirmDismiss: (_) async {
                      if (c.id == null) return false;
                      await _deleteParty(c);
                      return false;
                    },
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: c.id == null
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        PartyDetailScreen(customerId: c.id!))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      c.name.trim().isEmpty
                                          ? 'Party'
                                          : c.name.trim(),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Text(
                                      DateFormat('d MMM yyyy')
                                          .format(c.updatedAt),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500)),
                                ])),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$sym${bal.abs().toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: balColor)),
                                  const SizedBox(height: 2),
                                  Text(
                                      !hasBal
                                          ? 'Settled'
                                          : isPositive
                                              ? "You'll Get"
                                              : "You'll Give",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: balColor,
                                          fontWeight: FontWeight.w600)),
                                ]),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                ]);
              }),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 14,
            right: 14,
            child: FilledButton.icon(
                onPressed: _addPartyDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add Party',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                    backgroundColor: _kRed,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)))),
          ),
        ]);
      },
    );
  }
}

// â”€â”€ Vyapar-style transaction row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _VyaparTxnRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final String sym;
  final VoidCallback? onTap;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  const _VyaparTxnRow({
    required this.row,
    required this.sym,
    this.onTap,
    this.onPrint,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final kind = row['_kind'] as String? ?? 'sale';

    // â”€â”€ per-kind config â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    String tagLabel;
    Color tagBg, tagFg;
    String partyName;
    String refNo;
    double total;
    double balance;
    DateTime date;
    bool showActions = false;

    switch (kind) {
      case 'purchase':
        tagLabel = 'PURCHASE';
        tagBg = const Color(0xFFFFF3E0);
        tagFg = const Color(0xFFE65100);
        partyName = row['supplier_name']?.toString().trim().isNotEmpty == true
            ? row['supplier_name'] as String
            : 'Supplier';
        refNo = row['purchase_no']?.toString() ?? '';
        total = (row['total'] as num?)?.toDouble() ?? 0;
        balance = (row['balance'] as num?)?.toDouble() ?? 0;
        date = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now();
        break;

      case 'payment':
        tagLabel = 'PAYMENT-OUT';
        tagBg = const Color(0xFFFFEBEE);
        tagFg = _kRed;
        partyName = row['party_name']?.toString().trim().isNotEmpty == true
            ? row['party_name'] as String
            : 'Party';
        refNo = '#${row['id'] ?? ''}';
        total = (row['amount'] as num?)?.toDouble() ?? 0;
        balance = total; // unused amount for display
        date = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now();
        break;

      default: // sale
        tagLabel = 'SALE';
        tagBg = const Color(0xFFE8F5E9);
        tagFg = const Color(0xFF2E7D32);
        partyName = row['customer_name']?.toString().trim().isNotEmpty == true
            ? row['customer_name'] as String
            : 'Walk-in';
        refNo = row['invoice_no']?.toString() ?? '';
        total = (row['total'] as num?)?.toDouble() ?? 0;
        balance = (row['balance'] as num?)?.toDouble() ?? 0;
        date = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now();
        showActions = true;
    }

    final dateStr = DateFormat('d MMM').format(date);
    final isPayment = kind == 'payment';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // â”€â”€ Row 1: name + date/ref â”€â”€
              Row(children: [
                Expanded(
                    child: Text(partyName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                Text(dateStr,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                if (refNo.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('#${refNo.replaceAll(RegExp(r'^#'), '')}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500)),
                ],
              ]),

              const SizedBox(height: 6),

              // â”€â”€ Row 2: tag badge â”€â”€
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: tagBg, borderRadius: BorderRadius.circular(4)),
                  child: Text(tagLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: tagFg,
                          letterSpacing: 0.3))),

              const SizedBox(height: 10),

              // â”€â”€ Row 3: Total + Balance/Unused â”€â”€
              Row(children: [
                _TxnAmtCol(
                    label: 'Total', value: '$sym${total.toStringAsFixed(2)}'),
                const SizedBox(width: 32),
                _TxnAmtCol(
                    label: isPayment ? 'Unused' : 'Balance',
                    value: '$sym${balance.toStringAsFixed(2)}',
                    valueColor: balance > 0.009 ? _kRed : Colors.grey.shade500),
                const Spacer(),
                if (row['_kind'] == 'sale') ...[
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 18, color: Colors.teal),
                    onPressed: onShare,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.print_outlined, size: 18, color: Colors.blue),
                    onPressed: onPrint,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ]),
            ]),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
        ]),
      ),
    );
  }
}

class _TxnAmtCol extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _TxnAmtCol({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.black87)),
    ]);
  }
}

// â”€â”€ VYAPAR HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _VyaparHeader extends StatelessWidget {
  final String shopName, sym;
  final double today, toReceive, toPay;
  final VoidCallback onEditName,
      onSettings,
      onNewSale,
      onAddParty,
      onParties,
      onDayBook,
      onPurchase;

  const _VyaparHeader({
    required this.shopName,
    required this.sym,
    required this.today,
    required this.toReceive,
    required this.toPay,
    required this.onEditName,
    required this.onSettings,
    required this.onNewSale,
    required this.onAddParty,
    required this.onParties,
    required this.onDayBook,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [_kNavDark, _kNavMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
      child: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 0),
              child: Row(children: [
                Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2), width: 1)),
                    child: const Icon(Icons.set_meal_rounded,
                        color: Colors.white, size: 18)),
                const SizedBox(width: 8),
                Expanded(
                    child: GestureDetector(
                        onTap: onEditName,
                        child: Row(children: [
                          Flexible(
                              child: Text(shopName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined,
                              color: Colors.white54, size: 11),
                        ]))),
                Text(DateFormat('d MMM').format(DateTime.now()),
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(width: 2),
                IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white, size: 20)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                _StatBox(
                    label: "Today's Sale",
                    value: '$sym${today.toStringAsFixed(0)}',
                    icon: Icons.trending_up_rounded,
                    color: Colors.greenAccent.shade400),
                const SizedBox(width: 8),
                _StatBox(
                    label: 'To Receive',
                    value: '$sym${toReceive.toStringAsFixed(0)}',
                    icon: Icons.south_west_rounded,
                    color: Colors.orangeAccent.shade200),
                const SizedBox(width: 8),
                _StatBox(
                    label: 'To Pay',
                    value: '$sym${toPay.toStringAsFixed(0)}',
                    icon: Icons.north_east_rounded,
                    color: Colors.redAccent.shade200),
              ]),
            ),
            Container(
              color: _kCard,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _QuickLink(
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'Sale',
                        color: _kRed,
                        onTap: onNewSale),
                    _QuickLink(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Purchase',
                        color: _kBlue,
                        onTap: onPurchase),
                    _QuickLink(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Add Party',
                        color: const Color(0xFF2E7D32),
                        onTap: onAddParty),
                    _QuickLink(
                        icon: Icons.groups_outlined,
                        label: 'Parties',
                        color: const Color(0xFFE65100),
                        onTap: onParties),
                    _QuickLink(
                        icon: Icons.menu_book_outlined,
                        label: 'Day Book',
                        color: const Color(0xFF6A1B9A),
                        onTap: onDayBook),
                  ]),
            ),
          ])),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1)),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 8,
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickLink(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      ]),
    );
  }
}
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
  }) : onTap = null;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: onTap == null
                ? Colors.grey.shade50
                : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: onTap == null
                  ? Colors.grey.shade200
                  : const Color(0xFFBFDBFE),
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: onTap == null ? Colors.grey.shade300 : _kBlue,
          ),
        ),
      ),
    );
  }
}
class _TypeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeToggle(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool autofocus;
  final TextCapitalization caps;
  final TextInputType? keyboard;

  const _Field(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.autofocus = false,
      this.caps = TextCapitalization.none,
      this.keyboard});

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: ctrl,
        autofocus: autofocus,
        textCapitalization: caps,
        keyboardType: keyboard,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));
  }
}
