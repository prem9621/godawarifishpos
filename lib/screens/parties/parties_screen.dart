import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/export/party_account_export.dart';
import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/settings_provider.dart';
import 'party_detail_screen.dart';

const _kRed = Color(0xFFE31E24);
const _kNavy = Color(0xFF1A237E);
const _kBlue = Color(0xFF1565C0);
const _kBg = Color(0xFFF2F6FA);

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});
  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late TabController _tabController;
  String? _partyKind;
  bool _saving = false;
  int? _loadedStoreId;
  final Map<int, DateTime?> _lastTxnDate = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        switch (_tabController.index) {
          case 1:
            _partyKind = CustomerModel.typeCustomer;
            break;
          case 2:
            _partyKind = CustomerModel.typeSupplier;
            break;
          default:
            _partyKind = null;
        }
      });
      _reload();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeId = context.watch<SettingsProvider>().currentStoreId;
    if (_loadedStoreId == storeId) return;
    _loadedStoreId = storeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  void _reload() {
    context.read<CustomerProvider>().loadCustomers(partyType: _partyKind);
    _loadLastTxnDates();
  }

  Future<void> _loadLastTxnDates() async {
    final storeId = context.read<SettingsProvider>().currentStoreId;
    // ✅ FIX: was one DB query per party (N+1). Now a single grouped query.
    final lastDates = await DatabaseHelper.instance
        .getLastTransactionDatesForCustomers(storeId: storeId);
    if (!mounted) return;
    setState(() {
      _lastTxnDate
        ..clear()
        ..addEntries(lastDates.entries.map(
          (e) => MapEntry(e.key, e.value != null ? DateTime.tryParse(e.value!) : null),
        ));
    });
  }

  Future<void> _deleteParty(CustomerModel party) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Party?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          party.balance.abs() > 0.01
              ? '"${party.name}" has a balance of ₹${party.balance.abs().toStringAsFixed(0)}. Deleting will remove all records.'
              : 'Delete "${party.name}"? This cannot be undone.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || party.id == null) return;
    try {
      await DatabaseHelper.instance.deleteCustomer(party.id!);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${party.name}" deleted'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _addParty() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    String partyType = _partyKind ?? CustomerModel.typeCustomer;
    Map<String, dynamic>? result;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (ctx, setLocal) {
            final canSave = nameCtrl.text.trim().isNotEmpty;
            return Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.person_add_alt_1,
                            color: _kBlue, size: 20)),
                    const SizedBox(width: 12),
                    const Text('Add New Party',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(
                          child: GestureDetector(
                        onTap: () => setLocal(
                            () => partyType = CustomerModel.typeCustomer),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                                color: partyType == CustomerModel.typeCustomer
                                    ? _kBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('Customer',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color:
                                        partyType == CustomerModel.typeCustomer
                                            ? Colors.white
                                            : Colors.grey.shade600))),
                      )),
                      Expanded(
                          child: GestureDetector(
                        onTap: () => setLocal(
                            () => partyType = CustomerModel.typeSupplier),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                                color: partyType == CustomerModel.typeSupplier
                                    ? Colors.indigo
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('Supplier',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color:
                                        partyType == CustomerModel.typeSupplier
                                            ? Colors.white
                                            : Colors.grey.shade600))),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setLocal(() {}),
                      decoration: InputDecoration(
                          labelText: 'Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                          labelText: 'Phone (optional)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: addrCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                          labelText: 'Address (optional)',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: gstCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                          labelText: 'GST Number (optional)',
                          prefixIcon: const Icon(Icons.receipt_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: !canSave
                            ? null
                            : () {
                                result = {
                                  'name': nameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'address': addrCtrl.text.trim(),
                                  'gst': gstCtrl.text.trim().toUpperCase(),
                                  'type': partyType,
                                };
                                Navigator.pop(ctx);
                              },
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                partyType == CustomerModel.typeCustomer
                                    ? _kBlue
                                    : Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save Party',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800))),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    addrCtrl.dispose();
    gstCtrl.dispose();
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final name = result!['name'] as String;
      await DatabaseHelper.instance.insertCustomer({
        'name': name,
        'phone': (result!['phone'] as String).isEmpty ? null : result!['phone'],
        'address':
            (result!['address'] as String).isEmpty ? null : result!['address'],
        'gst_number':
            (result!['gst'] as String).isEmpty ? null : result!['gst'],
        'party_type': result!['type'],
        'balance': 0.0,
        'created_at': now,
        'updated_at': now,
      });
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ${result!['type']} "$name" added'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final rows = await DatabaseHelper.instance.getCustomers();
      final csv = PartyAccountExport.buildAllPartiesCsv(rows);
      await PartyAccountExport.shareCsv('all_parties_export.csv', csv);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Parties CSV ready')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      final settings = context.read<SettingsProvider>();
      final rows = await DatabaseHelper.instance.getCustomers();
      await PartyAccountExport.shareAllPartiesPdf(
        shopName: settings.shopName,
        shopPhone: settings.shopPhone,
        currencySymbol: settings.currencySymbol,
        customers: rows,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PDF ready to share')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PDF failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;
    final cust = context.watch<CustomerProvider>();

    final query = _search.text.toLowerCase();
    final list = query.isEmpty
        ? cust.customers
        : cust.customers
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                (c.phone ?? '').contains(query))
            .toList();

    final toGet = list
        .where((c) => c.balance > 0.009)
        .fold<double>(0, (s, c) => s + c.balance);
    final toGive = list
        .where((c) => c.balance < -0.009)
        .fold<double>(0, (s, c) => s + c.balance.abs());

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Parties',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: cust.loading ? null : _exportCsv),
          IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: cust.loading ? null : _exportPdf),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _kRed,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Customers'),
            Tab(text: 'Suppliers'),
          ],
        ),
      ),
      body: Column(children: [
        // ── You'll Get / You'll Give summary ──
        _TopSummaryBar(
            toGet: toGet, toGive: toGive, sym: sym, count: list.length),

        // ── Search + New Party ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: Colors.grey),
                      hintText: 'Search party…',
                      hintStyle:
                          const TextStyle(fontSize: 13, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _kBlue, width: 1.5)),
                      suffixIcon: _search.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              })
                          : null),
                  onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _saving ? null : _addParty,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: _kBlue, borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('New Party',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),

        // ── List ──
        Expanded(
          child: cust.loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? _EmptyParties(onAdd: _addParty)
                  : RefreshIndicator(
                      color: _kRed,
                      onRefresh: () async => _reload(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (_, i) {
                          final party = list[i];
                          final lastDate =
                              party.id != null ? _lastTxnDate[party.id] : null;
                          return _VyaparPartyTile(
                            party: party,
                            sym: sym,
                            lastDate: lastDate,
                            onTap: party.id == null
                                ? null
                                : () => Navigator.of(context)
                                        .push(MaterialPageRoute<void>(
                                            builder: (_) => PartyDetailScreen(
                                                customerId: party.id!)))
                                        .then((_) {
                                      if (mounted) _reload();
                                    }),
                            onDelete: () => _deleteParty(party),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ── Top summary bar ──────────────────────────────────────────────────────────
class _TopSummaryBar extends StatelessWidget {
  final double toGet, toGive;
  final String sym;
  final int count;
  const _TopSummaryBar(
      {required this.toGet,
      required this.toGive,
      required this.sym,
      required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
            child: _SummaryChip(
                label: "You'll Get",
                value: '$sym${toGet.toStringAsFixed(2)}',
                valueColor: const Color(0xFF2E7D32),
                icon: Icons.south_west_rounded,
                iconColor: const Color(0xFF2E7D32))),
        const SizedBox(width: 12),
        Expanded(
            child: _SummaryChip(
                label: "You'll Give",
                value: '$sym${toGive.toStringAsFixed(2)}',
                valueColor: _kRed,
                icon: Icons.north_east_rounded,
                iconColor: _kRed)),
      ]),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color valueColor, iconColor;
  final IconData icon;
  const _SummaryChip(
      {required this.label,
      required this.value,
      required this.valueColor,
      required this.iconColor,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
          color: valueColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: valueColor.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: valueColor)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Vyapar-style party tile ──────────────────────────────────────────────────
class _VyaparPartyTile extends StatelessWidget {
  final CustomerModel party;
  final String sym;
  final DateTime? lastDate;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _VyaparPartyTile(
      {required this.party,
      required this.sym,
      this.lastDate,
      this.onTap,
      this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bal = party.balance;
    final hasBal = bal.abs() > 0.009;
    final isPositive = bal > 0.009;

    final Color balColor = !hasBal
        ? Colors.grey.shade400
        : isPositive
            ? const Color(0xFF2E7D32)
            : _kRed;

    final String balLabel =
        !hasBal ? '₹0' : '$sym${bal.abs().toStringAsFixed(2)}';

    final String statusLabel = !hasBal
        ? 'Settled'
        : isPositive
            ? "You'll Get"
            : "You'll Give";

    final String dateStr = lastDate != null
        ? DateFormat('d MMM yyyy').format(lastDate!)
        : DateFormat('d MMM yyyy').format(party.createdAt);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(party.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    balLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: balColor),
                  ),
                ),
                const SizedBox(height: 2),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: balColor,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────
class _EmptyParties extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyParties({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
              color: Color(0xFFFDE8E8), shape: BoxShape.circle),
          child: const Icon(Icons.groups_2_outlined, size: 36, color: _kRed)),
      const SizedBox(height: 16),
      const Text('No parties yet',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Tap below to add your first party',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 20),
      FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
          label: const Text('Add Party', style: TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
              backgroundColor: _kRed,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)))),
    ]));
  }
}