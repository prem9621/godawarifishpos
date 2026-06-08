import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_utils.dart';
import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PURCHASE SCREEN  (improved: edit qty inline, search chip grid, better UI)
// ─────────────────────────────────────────────────────────────────────────────
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({
    super.key,
    this.editingPurchaseId,
    this.initialSupplier,
  });

  final int? editingPurchaseId;
  final CustomerModel? initialSupplier;

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _search    = TextEditingController();
  final _discount  = TextEditingController(text: '0');
  final _paid      = TextEditingController();
  final _notesCtrl = TextEditingController();
  String        _paymentMethod  = 'Cash';
  CustomerModel? _supplier;
  DateTime      _purchaseDate   = DateTime.now();
  bool          _paidUserEdited = false;
  bool          _saving         = false;
  bool          _loadingEdit    = false;
  PurchaseProvider? _purchaseRef;

  static const _payMethods = ['Cash', 'UPI', 'Card', 'Credit'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CustomerProvider>().loadCustomers();
      if (widget.initialSupplier != null) {
        setState(() => _supplier = widget.initialSupplier);
      }
      if (widget.editingPurchaseId != null) {
        _loadPurchaseForEdit(widget.editingPurchaseId!);
      }
    });
  }

  @override
  void dispose() {
    _purchaseRef?.removeListener(_onPurchaseChanged);
    _search.dispose();
    _discount.dispose();
    _paid.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<PurchaseProvider>();
    if (!identical(_purchaseRef, p)) {
      _purchaseRef?.removeListener(_onPurchaseChanged);
      _purchaseRef = p;
      _purchaseRef!.addListener(_onPurchaseChanged);
    }
    _syncPaid();
  }

  void _onPurchaseChanged() => _syncPaid();

  Future<void> _loadPurchaseForEdit(int id) async {
    setState(() => _loadingEdit = true);
    final row = await DatabaseHelper.instance.getPurchaseById(id);
    if (row == null) {
      if (!mounted) return;
      setState(() => _loadingEdit = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Purchase not found')));
      return;
    }

    CustomerModel? supplier;
    final supplierId = row['supplier_id'] as int?;
    if (supplierId != null) {
      final supplierRow =
          await DatabaseHelper.instance.getCustomerById(supplierId);
      if (supplierRow != null) supplier = CustomerModel.fromMap(supplierRow);
    }

    if (!mounted) return;
    context.read<PurchaseProvider>().loadForEdit(row);
    setState(() {
      _supplier = supplier;
      _discount.text =
          ((row['discount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
      _paid.text =
          ((row['paid'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
      _notesCtrl.text = row['notes']?.toString() ?? '';
      _paymentMethod = row['payment_method']?.toString() ?? 'Cash';
      _purchaseDate =
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now();
      _paidUserEdited = true;
      _loadingEdit = false;
    });
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _purchaseDate = picked);
    }
  }

  double _discountVal(SettingsProvider s) {
    if (!s.discountEnabled) return 0;
    return double.tryParse(_discount.text) ?? 0;
  }

  void _syncPaid() {
    if (!mounted || _paidUserEdited) return;
    final pr   = context.read<PurchaseProvider>();
    final st   = context.read<SettingsProvider>();
    final t    = pr.totalAfter(st, _discountVal(st));
    final next = t.toStringAsFixed(2);
    if (_paid.text != next) {
      _paid.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length));
    }
  }

  Future<void> _pickSupplier() async {
    final list = context
        .read<CustomerProvider>()
        .customers
        .where((c) => c.isSupplier)
        .toList();
    final sym = context.read<SettingsProvider>().currencySymbol;

    final chosen = await showModalBottomSheet<CustomerModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select Supplier',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(ctx).size.height * 0.5),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.storefront_outlined)),
                      title: const Text('Walk-in supplier'),
                      onTap: () => Navigator.pop(ctx, null),
                    ),
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No suppliers found',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ...list.map((c) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Text(c.name[0].toUpperCase(),
                                style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Payable: ${AppUtils.formatCurrency(c.balance, symbol: sym)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: c.balance > 0
                                      ? Colors.red
                                      : Colors.green)),
                          onTap: () => Navigator.pop(ctx, c),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _supplier = chosen);
  }

  // ── Add item from inventory chip ─────────────────────────────────────────
  Future<void> _addItem(
      Map<String, dynamic> row, PurchaseProvider pr) async {
    HapticFeedback.lightImpact();
    final existIdx = pr.lines.indexWhere(
        (l) => l.itemId == (row['id'] as int?) && row['id'] != null);
    if (existIdx >= 0) {
      await _editLine(existIdx, pr);
      return;
    }

    final price  = (row['price'] as num).toDouble();
    final unit   = row['unit']?.toString() ?? 'Kg';
    final name   = row['name'] as String;
    final qtyCtrl   = TextEditingController(text: '1');
    final priceCtrl =
        TextEditingController(text: price.toStringAsFixed(2));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _PurchaseItemSheet(
          itemName: name,
          unit: unit,
          qtyCtrl: qtyCtrl,
          priceCtrl: priceCtrl,
          onSave: () {
            final q = double.tryParse(qtyCtrl.text) ?? 1;
            final p = double.tryParse(priceCtrl.text) ?? price;
            if (q > 0) {
              pr.addManualItem(
                  itemId: row['id'] as int?,
                  itemName: name,
                  qty: q,
                  unit: unit,
                  price: p);
              setState(() => _paidUserEdited = false);
            }
            Navigator.pop(ctx);
          },
        ),
      ),
    );
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _editLine(int index, PurchaseProvider pr) async {
    final line      = pr.lines[index];
    final qtyCtrl   =
        TextEditingController(text: line.qty.toStringAsFixed(2));
    final priceCtrl =
        TextEditingController(text: line.price.toStringAsFixed(2));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _PurchaseItemSheet(
          itemName: line.itemName,
          unit: line.unit,
          qtyCtrl: qtyCtrl,
          priceCtrl: priceCtrl,
          isEdit: true,
          onSave: () {
            final q = double.tryParse(qtyCtrl.text) ?? line.qty;
            final p = double.tryParse(priceCtrl.text) ?? line.price;
            pr.setQtyAndPrice(index, qty: q, price: p);
            setState(() => _paidUserEdited = false);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final pr       = context.read<PurchaseProvider>();
    final inv      = context.read<InventoryProvider>();
    if (pr.lines.isEmpty) return;

    setState(() => _saving = true);
    final paid  = double.tryParse(_paid.text) ?? 0;
    final err   = await pr.savePurchase(
      settings      : settings,
      inventory     : inv,
      supplier      : _supplier,
      discount      : _discountVal(settings),
      paid          : paid,
      paymentMethod : _paymentMethod,
      notes         : _notesCtrl.text.trim(),
      purchaseDate  : _purchaseDate,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await context.read<CustomerProvider>().loadCustomers();
    if (!mounted) return;
    if (widget.editingPurchaseId != null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _supplier      = null;
      _paidUserEdited = false;
      _discount.text = '0';
      _purchaseDate = DateTime.now();
    });
    _paid.clear();
    _syncPaid();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Purchase saved · stock updated'),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final pr       = context.watch<PurchaseProvider>();
    final inv      = context.watch<InventoryProvider>();
    final sym      = settings.currencySymbol;

    final filtered = _search.text.isEmpty
        ? inv.items
        : inv.items
            .where((e) => (e['name'] as String)
                .toLowerCase()
                .contains(_search.text.toLowerCase()))
            .toList();

    final sub   = pr.subtotal;
    final disc  = _discountVal(settings);
    final tax   = pr.taxAmount(
        settings, (sub - disc).clamp(0.0, double.infinity));
    final total = pr.totalAfter(settings, disc);

    if (_loadingEdit) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(widget.editingPurchaseId == null
              ? 'New Purchase'
              : 'Edit Purchase',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Supplier tile
                    _SupplierTile(
                        supplier: _supplier,
                        sym: sym,
                        onTap: _pickSupplier),
                    const SizedBox(height: 12),
                    _PurchaseDateTile(
                      date: _purchaseDate,
                      onTap: _pickPurchaseDate,
                    ),
                    const SizedBox(height: 12),

                    // ── Search
                    TextField(
                      controller: _search,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 18, color: Colors.grey),
                        hintText: 'Search items…',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.orange, width: 1.5)),
                        suffixIcon: _search.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 16),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                })
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),

                    // ── Item grid (horizontal scroll)
                    if (inv.loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      _buildItemGrid(filtered, pr, sym),

                    const SizedBox(height: 14),

                    // ── Cart header
                    Row(children: [
                      const Text('Cart',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      if (pr.lines.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${pr.lines.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      const Spacer(),
                      if (pr.lines.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            pr.clear();
                            setState(() => _paidUserEdited = false);
                          },
                          icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 16),
                          label: const Text('Clear',
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 6),

                    pr.lines.isEmpty
                        ? _EmptyPurchaseCart()
                        : _buildCartList(pr, sym),

                    const SizedBox(height: 14),

                    // ── Payment method
                    _buildPaymentMethod(),
                    const SizedBox(height: 10),

                    // ── Discount
                    if (settings.discountEnabled) ...[
                      _FieldRow(
                        label: 'Discount',
                        ctrl: _discount,
                        onChanged: (_) =>
                            setState(() => _paidUserEdited = false),
                        sym: sym,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Paid
                    _FieldRow(
                      label: 'Amount Paid',
                      ctrl: _paid,
                      onChanged: (_) =>
                          setState(() => _paidUserEdited = true),
                      sym: sym,
                    ),
                    const SizedBox(height: 10),

                    // ── Notes
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Notes (optional)…',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: Colors.grey.shade200)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Summary bar
            _PurchaseSummaryBar(
              sub: sub,
              disc: disc,
              tax: tax,
              total: total,
              sym: sym,
              isEmpty: pr.lines.isEmpty,
              saving: _saving,
              onSave: _save,
              saveLabel: widget.editingPurchaseId == null
                  ? 'SAVE PURCHASE'
                  : 'UPDATE PURCHASE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid(
      List<Map<String, dynamic>> items, PurchaseProvider pr, String sym) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: Text('No items found',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 13))),
      );
    }
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final row     = items[i];
          final name    = row['name'] as String;
          final price   = (row['price'] as num).toDouble();
          final inCart  = pr.lines.any((l) =>
              l.itemId == (row['id'] as int?) && row['id'] != null);

          return GestureDetector(
            onTap: () => _addItem(row, pr),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 106,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: inCart
                    ? Colors.orange.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: inCart
                      ? Colors.orange.shade400
                      : Colors.orange.shade100,
                  width: inCart ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.set_meal_rounded,
                        size: 14,
                        color: Colors.orange.shade700),
                    const Spacer(),
                    if (inCart)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            size: 9, color: Colors.white),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.add,
                            size: 9, color: Colors.orange),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('$sym${price.toStringAsFixed(0)}/Kg',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartList(PurchaseProvider pr, String sym) {
    return Column(
      children: List.generate(pr.lines.length, (index) {
        final line = pr.lines[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _editLine(index, pr),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.itemName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(
                            '$sym${line.price.toStringAsFixed(0)}/${line.unit}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius:
                                  BorderRadius.circular(4)),
                          child: const Text('Tap to edit',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              // Quick qty buttons
              Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(
                  icon: Icons.remove_rounded,
                  color: Colors.red.shade50,
                  iconColor: Colors.red,
                  onTap: () {
                    final step = line.unit.toLowerCase() == 'kg'
                        ? 0.5
                        : 1.0;
                    if (line.qty > step) {
                      pr.setQty(index, line.qty - step);
                    } else {
                      pr.removeAt(index);
                    }
                    setState(() => _paidUserEdited = false);
                  },
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _editLine(index, pr),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '${line.qty % 1 == 0 ? line.qty.toInt() : line.qty.toStringAsFixed(1)} ${line.unit}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _QtyBtn(
                  icon: Icons.add_rounded,
                  color: Colors.orange.shade50,
                  iconColor: Colors.orange,
                  onTap: () {
                    final step = line.unit.toLowerCase() == 'kg'
                        ? 0.5
                        : 1.0;
                    pr.setQty(index, line.qty + step);
                    setState(() => _paidUserEdited = false);
                  },
                ),
              ]),
              const SizedBox(width: 8),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$sym${line.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        pr.removeAt(index);
                        setState(() => _paidUserEdited = false);
                      },
                      child: Icon(Icons.close_rounded,
                          size: 18, color: Colors.red.shade300),
                    ),
                  ]),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildPaymentMethod() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Method',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _payMethods.map((m) {
                final sel = m == _paymentMethod;
                return GestureDetector(
                  onTap: () => setState(() => _paymentMethod = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.orange.shade700
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel
                              ? Colors.orange.shade700
                              : Colors.grey.shade300),
                    ),
                    child: Text(m,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? Colors.white
                                : Colors.grey.shade700)),
                  ),
                );
              }).toList(),
            ),
          ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PURCHASE ITEM SHEET (add / edit)
// ─────────────────────────────────────────────────────────────────────────────
class _PurchaseDateTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _PurchaseDateTile({
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.calendar_month_outlined,
                color: Colors.orange.shade700, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Purchase Bill Date',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87)),
              ],
            ),
          ),
          Icon(Icons.edit_calendar_outlined,
              color: Colors.orange.shade700, size: 18),
        ]),
      ),
    );
  }
}

class _PurchaseItemSheet extends StatefulWidget {
  final String itemName, unit;
  final TextEditingController qtyCtrl, priceCtrl;
  final VoidCallback onSave;
  final bool isEdit;

  const _PurchaseItemSheet({
    required this.itemName,
    required this.unit,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.onSave,
    this.isEdit = false,
  });

  @override
  State<_PurchaseItemSheet> createState() => _PurchaseItemSheetState();
}

class _PurchaseItemSheetState extends State<_PurchaseItemSheet> {
  late final FocusNode _qtyFocus;

  @override
  void initState() {
    super.initState();
    _qtyFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _qtyFocus.requestFocus();
      widget.qtyCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.qtyCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _qtyFocus.dispose();
    super.dispose();
  }

  void _quick(String v) {
    widget.qtyCtrl.text = v;
    widget.qtyCtrl.selection =
        TextSelection.collapsed(offset: v.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = (double.tryParse(widget.qtyCtrl.text) ?? 0) *
        (double.tryParse(widget.priceCtrl.text) ?? 0);

    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_shipping_outlined,
                color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.itemName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  Text('Per ${widget.unit}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.orange.shade200)),
            child: Text('Rs.${total.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade800)),
          ),
        ]),
        const SizedBox(height: 16),

        // Quick qty
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['0.5', '1', '2', '5', '10', '20', '50']
              .map((v) => GestureDetector(
                    onTap: () => _quick(v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.qtyCtrl.text == v
                            ? Colors.orange.shade700
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: widget.qtyCtrl.text == v
                                ? Colors.orange.shade700
                                : Colors.grey.shade200),
                      ),
                      child: Text(v,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.qtyCtrl.text == v
                                  ? Colors.white
                                  : Colors.black87)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(
            child: _PurchaseInputField(
                label: 'Quantity (${widget.unit})',
                ctrl: widget.qtyCtrl,
                focusNode: _qtyFocus,
                onChanged: () => setState(() {})),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PurchaseInputField(
                label: 'Price (Rs./${widget.unit})',
                ctrl: widget.priceCtrl,
                onChanged: () => setState(() {})),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.onSave,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(
                widget.isEdit
                    ? Icons.edit_rounded
                    : Icons.add_shopping_cart_rounded,
                size: 18),
            label: Text(
              widget.isEdit
                  ? 'Update  ·  Rs.${total.toStringAsFixed(0)}'
                  : 'Add to Cart  ·  Rs.${total.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PurchaseInputField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final FocusNode? focusNode;
  final VoidCallback? onChanged;

  const _PurchaseInputField({
    required this.label,
    required this.ctrl,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        focusNode: focusNode,
        autofocus: focusNode != null,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Colors.orange, width: 2)),
        ),
        onChanged: (_) => onChanged?.call(),
      ),
    ]);
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _SupplierTile extends StatelessWidget {
  final CustomerModel? supplier;
  final String sym;
  final VoidCallback onTap;
  const _SupplierTile(
      {required this.supplier,
      required this.sym,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: supplier != null
                  ? Colors.orange.shade300
                  : Colors.grey.shade200),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: supplier != null
                ? Colors.orange.shade100
                : Colors.grey.shade100,
            child: Icon(
              supplier != null
                  ? Icons.local_shipping_outlined
                  : Icons.add_business_outlined,
              size: 18,
              color: supplier != null
                  ? Colors.orange.shade700
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier?.name ?? 'Walk-in Supplier',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: supplier != null
                              ? Colors.black87
                              : Colors.grey.shade600)),
                  if (supplier != null)
                    Text(
                        'Payable: $sym${supplier!.balance.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: supplier!.balance > 0
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w600))
                  else
                    Text('Tap to select supplier',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                ]),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

class _EmptyPurchaseCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(children: [
        Icon(Icons.shopping_cart_outlined,
            size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('Tap an item above to add to cart',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color, iconColor;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon,
      required this.onTap,
      this.color = const Color(0xFFF5F5F5),
      this.iconColor = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200)),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final ValueChanged<String>? onChanged;
  final String sym;

  const _FieldRow({
    required this.label,
    required this.ctrl,
    this.onChanged,
    this.sym = 'Rs.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        SizedBox(
          width: 120,
          child: TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixText: '$sym ',
              prefixStyle:
                  const TextStyle(fontSize: 12, color: Colors.grey),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300)),
            ),
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}

class _PurchaseSummaryBar extends StatelessWidget {
  final double sub, disc, tax, total;
  final String sym;
  final bool isEmpty, saving;
  final VoidCallback onSave;
  final String saveLabel;

  const _PurchaseSummaryBar({
    required this.sub,
    required this.disc,
    required this.tax,
    required this.total,
    required this.sym,
    required this.isEmpty,
    required this.saving,
    required this.onSave,
    required this.saveLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _row('Subtotal', '$sym${sub.toStringAsFixed(2)}'),
            if (disc > 0) ...[
              const SizedBox(height: 4),
              _row('Discount', '- $sym${disc.toStringAsFixed(2)}',
                  valueColor: Colors.orange),
            ],
            if (tax > 0) ...[
              const SizedBox(height: 4),
              _row('Tax', '$sym${tax.toStringAsFixed(2)}'),
            ],
            const Divider(height: 16),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  Text('$sym${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange)),
                ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (isEmpty || saving) ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  disabledBackgroundColor: Colors.grey.shade200,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18),
                label: Text(
                  saving ? 'Saving…' : 'SAVE PURCHASE',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(String l, String v, {Color? valueColor}) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600)),
          Text(v,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87)),
        ]);
  }
}
