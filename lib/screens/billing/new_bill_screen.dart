import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/firebase_sync_service.dart';
import '../../widgets/invoice_detail_sheet.dart';

const _kPrimary = Color(0xFF1A73E8);
const _kDark = Color(0xFF1C2B4A);
const _kAccent = Color(0xFF34A853);
const _kRed = Color(0xFFEA4335);
const _kOrange = Color(0xFFF9AB00);
const _kBg = Color(0xFFF1F3F6);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE0E4EC);
const _kTextDark = Color(0xFF1C2B4A);
const _kTextGrey = Color(0xFF6B7280);

class NewBillScreen extends StatefulWidget {
  final CustomerModel? preselectedCustomer;
  const NewBillScreen({super.key, this.preselectedCustomer});
  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController(text: '0');
  final _packagingCtrl = TextEditingController(text: '0');

  // CHANGED: replaced _deliveryCtrl TextEditingController with state variable
  String _deliveryPerson = '';

  String _paymentMethod = 'Credit';
  CustomerModel? _customer;
  bool _paidUserEdited = false;
  bool _customerPreset = false;
  bool _showQr = false;
  bool _saving = false;
  bool _showDiscount = false;
  bool _showShipping = false;
  bool _showPackaging = false;
  BillingProvider? _billRef;
  String _categoryFilter = 'All';
  DateTime _billDate = DateTime.now();

  static const _payMethods = ['Cash', 'UPI', 'Card', 'Credit'];
  static const _categories = [
    'All',
    'Fresh Water Fish',
    'Sea Water Fish',
    'Prawn & Shrimp',
    'Crab & Lobster',
    'Squid & Octopus',
    'Chicken',
    'Mutton',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadItems();
      final bill = context.read<BillingProvider>();
      if (bill.editingInvoiceId != null) {
        _shippingCtrl.text = bill.shipping.toStringAsFixed(2);
        _packagingCtrl.text = bill.packaging.toStringAsFixed(2);
        _showShipping = bill.shipping > 0;
        _showPackaging = bill.packaging > 0;
        _deliveryPerson = bill.deliveryBoyName ?? '';
        _findAndSetCustomer(bill.editingInvoiceId!);
      }
    });
  }

  Future<void> _findAndSetCustomer(int invoiceId) async {
    final inv = await DatabaseHelper.instance.getInvoiceById(invoiceId);
    if (inv != null && inv['customer_id'] != null) {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(AppConstants.tableCustomers,
          where: 'id = ?', whereArgs: [inv['customer_id']]);
      if (rows.isNotEmpty && mounted) {
        setState(() => _customer = CustomerModel.fromMap(rows.first));
      }
    }
  }

  @override
  void dispose() {
    _billRef?.removeListener(_onBillChanged);
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _shippingCtrl.dispose();
    _packagingCtrl.dispose();
    // CHANGED: _deliveryCtrl.dispose() removed — no controller anymore
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_customerPreset && widget.preselectedCustomer != null) {
      _customer = widget.preselectedCustomer;
      _customerPreset = true;
    }
    final bill = context.read<BillingProvider>();
    if (!identical(_billRef, bill)) {
      _billRef?.removeListener(_onBillChanged);
      _billRef = bill;
      _billRef!.addListener(_onBillChanged);
    }
    if (!_paidUserEdited) _syncPaid();
  }

  void _onBillChanged() {
    if (!mounted) return;
    if (!_paidUserEdited) _syncPaid();
  }

  double _disc() =>
      _showDiscount ? (double.tryParse(_discountCtrl.text) ?? 0) : 0;
  double _shipping() =>
      _showShipping ? (double.tryParse(_shippingCtrl.text) ?? 0) : 0;
  double _packaging() =>
      _showPackaging ? (double.tryParse(_packagingCtrl.text) ?? 0) : 0;

  void _syncPaid() {
    if (!mounted || _paidUserEdited) return;
    if (_paidCtrl.text != '0') {
      _paidCtrl.value = const TextEditingValue(
          text: '0', selection: TextSelection.collapsed(offset: 1));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _kPrimary)),
          child: child!),
    );
    if (picked != null && mounted) {
      setState(() => _billDate = DateTime(picked.year, picked.month, picked.day,
          _billDate.hour, _billDate.minute, _billDate.second));
    }
  }

  String _buildUpiQr(double amount) =>
      'upi://pay?pa=godawarifish@upi&pn=Godawari+Fish'
      '&am=${amount.toStringAsFixed(2)}&cu=INR';

  Future<void> _pickCustomer() async {
    final result = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (result != null && mounted) setState(() => _customer = result);
  }

  Future<void> _addNewItemDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final unitNotifier = ValueNotifier<String>('Kg');
    final catNotifier = ValueNotifier<String>('Fresh Water Fish');
    bool saving = false;
    final units = ['Kg', 'Piece', 'Dozen', 'Gram', 'Litre'];
    final cats = [
      'Fresh Water Fish',
      'Sea Water Fish',
      'Prawn & Shrimp',
      'Crab & Lobster',
      'Squid & Octopus',
      'Chicken',
      'Mutton'
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setLocal) {
          return Container(
            decoration: const BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add_box_outlined,
                        color: _kAccent, size: 22)),
                const SizedBox(width: 12),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add New Item',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _kTextDark)),
                      Text('Saves to inventory automatically',
                          style: TextStyle(fontSize: 11, color: _kTextGrey)),
                    ]),
              ]),
              const SizedBox(height: 20),
              _VyTextField(
                  ctrl: nameCtrl,
                  label: 'Item Name *',
                  hint: 'e.g. Rohu Fish, Prawn',
                  icon: Icons.set_meal_outlined,
                  autofocus: true,
                  caps: TextCapitalization.words),
              const SizedBox(height: 12),
              _VyTextField(
                  ctrl: priceCtrl,
                  label: 'Selling Price *',
                  hint: 'Price per unit',
                  icon: Icons.currency_rupee_outlined,
                  numeric: true),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                  valueListenable: unitNotifier,
                  builder: (_, unit, __) => _ChipGroup(
                      title: 'Unit',
                      items: units,
                      selected: unit,
                      color: _kPrimary,
                      onTap: (u) => unitNotifier.value = u)),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                  valueListenable: catNotifier,
                  builder: (_, cat, __) => _ChipGroup(
                      title: 'Category',
                      items: cats,
                      selected: cat,
                      color: _kAccent,
                      onTap: (c) => catNotifier.value = c)),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final price =
                                  double.tryParse(priceCtrl.text) ?? 0;
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Enter item name')));
                                return;
                              }
                              if (price <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Enter valid price')));
                                return;
                              }
                              setLocal(() => saving = true);
                              try {
                                final now = DateTime.now().toIso8601String();
                                await DatabaseHelper.instance.insertItem({
                                  'name': name,
                                  'category': catNotifier.value,
                                  'unit': unitNotifier.value,
                                  'price': price,
                                  'purchase_price': 0.0,
                                  'stock': 100.0,
                                  'min_stock': 0.0,
                                  'is_active': 1,
                                  'created_at': now,
                                  'updated_at': now,
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  await context
                                      .read<InventoryProvider>()
                                      .loadItems();
                                  final items =
                                      context.read<InventoryProvider>().items;
                                  final newItem = items.firstWhere(
                                      (i) =>
                                          (i['name'] as String).toLowerCase() ==
                                          name.toLowerCase(),
                                      orElse: () => {});
                                  if (newItem.isNotEmpty && mounted) {
                                    context
                                        .read<BillingProvider>()
                                        .addManualItem(
                                            itemId: newItem['id'] as int?,
                                            itemName: name,
                                            qty: 1,
                                            unit: unitNotifier.value,
                                            price: price);
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                '"$name" added to inventory & cart'),
                                            backgroundColor: _kAccent,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10))));
                                  }
                                }
                              } catch (e) {
                                setLocal(() => saving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text('Failed: $e'),
                                          backgroundColor: Colors.red));
                                }
                              }
                            },
                      style: FilledButton.styleFrom(
                          backgroundColor: _kAccent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                          saving ? 'Saving...' : 'Save Item & Add to Cart',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)))),
            ])),
          );
        }),
      ),
    );
    nameCtrl.dispose();
    priceCtrl.dispose();
    unitNotifier.dispose();
    catNotifier.dispose();
  }

  Future<void> _onItemTap(
      Map<String, dynamic> row, BillingProvider bill) async {
    HapticFeedback.lightImpact();
    final name = row['name'] as String;
    final price = (row['price'] as num).toDouble();
    final unit = row['unit']?.toString() ?? 'Kg';
    final existIdx = bill.lines.indexWhere(
        (l) => l.itemId == (row['id'] as int?) && row['id'] != null);
    if (existIdx >= 0) {
      await _editLine(existIdx, bill);
      return;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, double>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: _AddItemSheet(
                itemName: name,
                unit: unit,
                initialQty: 1.0,
                initialPrice: price)));
    if (result != null && mounted) {
      final q = result['qty'] ?? 1.0;
      final p = result['price'] ?? price;
      if (q > 0) {
        bill.addManualItem(
            itemId: row['id'] as int?,
            itemName: name,
            qty: q,
            unit: unit,
            price: p);
        setState(() {});
      }
    }
  }

  Future<void> _editLine(int index, BillingProvider bill) async {
    if (index >= bill.lines.length) return;
    final line = bill.lines[index];
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, double>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: _AddItemSheet(
                itemName: line.itemName,
                unit: line.unit,
                initialQty: line.qty,
                initialPrice: line.price,
                isEdit: true)));
    if (result != null && mounted) {
      final q = result['qty'] ?? line.qty;
      final p = result['price'] ?? line.price;
      bill.updateLine(index, qty: q, price: p);
      setState(() {});
    }
  }

  Future<void> _saveBill() async {
    final bill = context.read<BillingProvider>();
    final s = context.read<SettingsProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (bill.lines.isEmpty) return;
    setState(() => _saving = true);
    try {
      int? customerId = _customer?.id;
      if (customerId == null &&
          _customer != null &&
          _customer!.name != 'Walk-in Customer') {
        customerId = await DatabaseHelper.instance.insertCustomer({
          'name': _customer!.name,
          'phone': _customer!.phone ?? '',
          'balance': 0.0,
          'party_type': 'customer',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        if (!mounted) return;
        _customer = _customer!.copyWith(id: customerId);
      }

      final disc = _disc();
      final sub = bill.subtotal();
      final shipping = _shipping();
      final packaging = _packaging();
      final total = bill.totalAfterDiscountAndTax(s, disc,
          shipping: shipping, packaging: packaging);
      final paid = double.tryParse(_paidCtrl.text) ?? 0;
      final balance = (total - paid).clamp(0.0, double.infinity);
      final tax = bill.taxAmount(s, (sub - disc).clamp(0.0, double.infinity));
      final now = _billDate;

      String invoiceNo;
      final existingId = bill.editingInvoiceId;
      double prevBal;
      if (existingId != null) {
        invoiceNo = bill.editingInvoiceNo!;
        final oldInvoice =
            await DatabaseHelper.instance.getInvoiceById(existingId);
        final oldBalance = (oldInvoice?['balance'] as num?)?.toDouble() ?? 0.0;
        prevBal = (_customer?.balance ?? 0.0) - oldBalance;
      } else {
        final nextNo = await s.getNextInvoiceNo();
        final code = s.invoicePrefix.trim().isEmpty
            ? AppConstants.defaultPrefix
            : s.invoicePrefix.trim().toUpperCase();
        invoiceNo = '$code$nextNo';
        prevBal = _customer?.balance ?? 0.0;
      }
      final curBal = prevBal + balance;

      // CHANGED: reads _deliveryPerson state instead of _deliveryCtrl.text
      final deliveryPerson = _deliveryPerson.trim();
      final notes = [
        _notesCtrl.text.trim(),
        if (deliveryPerson.isNotEmpty) 'Delivery: $deliveryPerson',
      ].where((e) => e.isNotEmpty).join(' | ');

      final invoiceMap = {
        'invoice_no': invoiceNo,
        'customer_id': customerId,
        'customer_name': _customer?.name ?? 'Walk-in Customer',
        'customer_phone': _customer?.phone ?? '',
        'subtotal': sub,
        'discount': disc,
        'tax': tax,
        'shipping': shipping,
        'packaging': packaging,
        'total': total,
        'paid': paid,
        'balance': balance,
        'previous_balance': prevBal,
        'current_balance': curBal,
        'payment_method': _paymentMethod,
        'delivery_boy_id': bill.deliveryBoyId,
        'delivery_boy_name': bill.deliveryBoyName ?? '',
        'status': balance <= 0
            ? 'paid'
            : paid > 0
                ? 'partial'
                : 'unpaid',
        'notes': notes,
        'store_id': s.currentStoreId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final itemMaps = bill.lines
          .map((e) => {
                'item_id': e.itemId,
                'item_name': e.itemName,
                'quantity': e.qty,
                'unit': e.unit,
                'price': e.price,
                'amount': e.amount,
              })
          .toList();

      int finalId;
      if (existingId != null) {
        await DatabaseHelper.instance.updateInvoice(
            invoiceId: existingId, invoice: invoiceMap, items: itemMaps);
        finalId = existingId;
      } else {
        finalId =
            await DatabaseHelper.instance.insertInvoice(invoiceMap, itemMaps);
      }
      
      // Don't await Firebase sync — let it happen in background to avoid UI delays
      unawaited(FirebaseSyncService.instance.pushInvoice(finalId).catchError((e) {
        debugPrint('Firebase sync failed: $e');
      }));

      if (!mounted) return;
      bill.clear();
      _notesCtrl.clear();
      // CHANGED: reset _deliveryPerson state instead of _deliveryCtrl.clear()
      _shippingCtrl.text = '0';
      _packagingCtrl.text = '0';
      _discountCtrl.text = '0';
      _paidCtrl.text = '0';
      setState(() {
        _deliveryPerson = '';
        _customer = null;
        _paidUserEdited = false;
        _saving = false;
        _showDiscount = false;
        _showShipping = false;
        _showPackaging = false;
        _paymentMethod = 'Credit';
        _billDate = DateTime.now();
      });
      navigator.pop();
      if (mounted) {
        // Use a local context copy for showReceiptPopup
        final localContext = context;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (localContext.mounted) {
            showReceiptPopup(localContext, finalId);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ _saveBill error: $e');
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text('Error saving bill: $e'),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final bill = context.watch<BillingProvider>();
    final inv = context.watch<InventoryProvider>();
    const sym = 'Rs.';
    final isEditing = bill.editingInvoiceId != null;

    final search = _searchCtrl.text.toLowerCase();
    final filtered = inv.items.where((e) {
      final name = (e['name'] as String).toLowerCase();
      final cat = e['category'] as String? ?? '';
      return (search.isEmpty || name.contains(search)) &&
          (_categoryFilter == 'All' || cat == _categoryFilter);
    }).toList();

    final sub = bill.subtotal();
    final disc = _disc();
    final tax = bill.taxAmount(s, (sub - disc).clamp(0.0, double.infinity));
    final ship = _shipping();
    final pack = _packaging();
    final total =
        bill.totalAfterDiscountAndTax(s, disc, shipping: ship, packaging: pack);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _kBg,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(bill, isEditing),
        body: Column(children: [
          _buildTopBanner(bill, sym, total),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerCard(sym),
                    const SizedBox(height: 10),
                    _buildDateCard(),
                    const SizedBox(height: 14),
                    _buildSectionLabel('Items', trailing: _newItemBtn()),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    const SizedBox(height: 8),
                    _buildCategoryBar(),
                    const SizedBox(height: 10),
                    _buildItemGrid(filtered, bill, sym),
                    const SizedBox(height: 16),
                    _buildCartHeader(bill),
                    const SizedBox(height: 8),
                    bill.lines.isEmpty
                        ? _EmptyCart()
                        : _buildCartList(bill, sym),
                    const SizedBox(height: 14),
                    _buildExtrasSection(sym, total),
                    const SizedBox(height: 100),
                  ]),
            ),
          ),
        ]),
        bottomNavigationBar: _SaveBar(
          sub: sub,
          disc: disc,
          tax: tax,
          shipping: ship,
          packaging: pack,
          total: total,
          sym: sym,
          isEmpty: bill.lines.isEmpty,
          saving: _saving,
          showQr: _showQr,
          isEditing: isEditing,
          upiQrData: _buildUpiQr(total),
          onToggleQr: () => setState(() => _showQr = !_showQr),
          onSave: _saveBill,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BillingProvider bill, bool isEditing) {
    return AppBar(
      backgroundColor: _kDark,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (bill.lines.isNotEmpty) {
              showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Discard bill?'),
                        content: const Text(
                            'You have items in the cart. Leave anyway?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Stay')),
                          FilledButton(
                              onPressed: () {
                                bill.clear();
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                  backgroundColor: _kRed),
                              child: const Text('Discard')),
                        ],
                      ));
            } else {
              Navigator.pop(context);
            }
          }),
      title: Text(isEditing ? 'Edit Sale Bill' : 'New Sale Bill',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      centerTitle: true,
      actions: [
        IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 22),
            tooltip: 'Add New Item',
            onPressed: _addNewItemDialog),
        IconButton(
            icon: const Icon(Icons.qr_code_rounded, size: 20),
            tooltip: 'UPI QR',
            onPressed: () => setState(() => _showQr = !_showQr)),
      ],
    );
  }

  Widget _buildTopBanner(BillingProvider bill, String sym, double total) {
    final method = _paymentMethod;
    final isPaid = method == 'Cash' || method == 'UPI' || method == 'Card';
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [_kDark, Color(0xFF1A3A6B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_cart_outlined,
                  color: Colors.white70, size: 13),
              const SizedBox(width: 5),
              Text('${bill.lines.length} items',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ])),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Bill Amount',
              style: TextStyle(
                  color: Colors.white54, fontSize: 10, letterSpacing: 0.3)),
          Text('$sym${total.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1)),
        ]),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            final idx = _payMethods.indexOf(_paymentMethod);
            setState(() =>
                _paymentMethod = _payMethods[(idx + 1) % _payMethods.length]);
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: isPaid
                      ? _kAccent.withValues(alpha: 0.25)
                      : _kOrange.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isPaid
                          ? _kAccent.withValues(alpha: 0.5)
                          : _kOrange.withValues(alpha: 0.5))),
              child: Text(method,
                  style: TextStyle(
                      color: isPaid ? const Color(0xFF81C995) : _kOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700))),
        ),
      ]),
    );
  }

  Widget _buildCustomerCard(String sym) {
    return GestureDetector(
      onTap: _pickCustomer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDeco(
            border: _customer != null ? _kPrimary.withValues(alpha: 0.3) : _kBorder),
        child: Row(children: [
          CircleAvatar(
              radius: 18,
              backgroundColor:
                  _customer != null ? _kPrimary.withValues(alpha: 0.1) : _kBg,
              child: Icon(
                  _customer != null
                      ? Icons.person_rounded
                      : Icons.person_add_outlined,
                  size: 18,
                  color: _customer != null ? _kPrimary : _kTextGrey)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_customer?.name ?? 'Walk-in Customer',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _customer != null ? _kTextDark : _kTextGrey)),
                if (_customer != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 11,
                        color: _customer!.balance > 0 ? _kOrange : _kAccent),
                    const SizedBox(width: 3),
                    Text(
                        'Balance: $sym${_customer!.balance.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                _customer!.balance > 0 ? _kOrange : _kAccent)),
                  ]),
                ] else
                  const Text('Tap to select customer',
                      style: TextStyle(fontSize: 11, color: _kTextGrey)),
              ])),
          _PillBtn(
              label: _customer != null ? 'Change' : 'Select', color: _kPrimary),
        ]),
      ),
    );
  }

  Widget _buildDateCard() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _cardDeco(),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.calendar_today_rounded,
                  size: 16, color: _kPrimary)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Bill Date',
                    style: TextStyle(
                        fontSize: 10, color: _kTextGrey, letterSpacing: 0.2)),
                Text(DateFormat('dd MMM yyyy').format(_billDate),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark)),
              ])),
          Text(DateFormat('hh:mm a').format(_billDate),
              style: const TextStyle(fontSize: 11, color: _kTextGrey)),
          const SizedBox(width: 8),
          const _PillBtn(label: 'Change', color: _kPrimary),
        ]),
      ),
    );
  }

  Widget _buildSectionLabel(String label, {Widget? trailing}) {
    return Row(children: [
      Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
              color: _kPrimary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
      const Spacer(),
      if (trailing != null) trailing,
    ]);
  }

  Widget _newItemBtn() {
    return GestureDetector(
      onTap: _addNewItemDialog,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kAccent.withValues(alpha: 0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 14, color: _kAccent),
            SizedBox(width: 4),
            Text('New Item',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kAccent)),
          ])),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.search_rounded, size: 18, color: _kTextGrey),
          hintText: 'Search fish or item...',
          hintStyle: const TextStyle(fontSize: 13, color: _kTextGrey),
          filled: true,
          fillColor: _kCard,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  })
              : null),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final cat = _categories[i];
            final selected = cat == _categoryFilter;
            return GestureDetector(
                onTap: () => setState(() => _categoryFilter = cat),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: selected ? _kPrimary : _kCard,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: selected ? _kPrimary : _kBorder)),
                    child: Text(cat,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : _kTextGrey))));
          }),
    );
  }

  Widget _buildItemGrid(
      List<Map<String, dynamic>> items, BillingProvider bill, String sym) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Text(
              _searchCtrl.text.isNotEmpty
                  ? 'No items match "${_searchCtrl.text}"'
                  : 'No items found',
              style: const TextStyle(color: _kTextGrey, fontSize: 13)),
          const SizedBox(height: 10),
          GestureDetector(
              onTap: _addNewItemDialog,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kAccent.withValues(alpha: 0.3))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_box_outlined, size: 16, color: _kAccent),
                    SizedBox(width: 6),
                    Text('Add New Item',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kAccent)),
                  ]))),
        ]),
      );
    }
    return SizedBox(
      height: 115,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final row = items[i];
            final name = row['name'] as String;
            final price = (row['price'] as num).toDouble();
            final stock = (row['stock'] as num?)?.toDouble() ?? 0;
            final outOfStock = stock <= 0;
            final inCart = bill.lines.any(
                (l) => l.itemId == (row['id'] as int?) && row['id'] != null);
            return GestureDetector(
              onTap: outOfStock ? null : () => _onItemTap(row, bill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 100,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: outOfStock
                        ? const Color(0xFFF8F8F8)
                        : inCart
                            ? const Color(0xFFEAF2FF)
                            : _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: outOfStock
                            ? _kBorder
                            : inCart
                                ? _kPrimary
                                : _kBorder,
                        width: inCart ? 1.5 : 1),
                    boxShadow: inCart
                        ? [
                            BoxShadow(
                                color: _kPrimary.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ]
                        : null),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(outOfStock ? '🚫' : '🐟',
                            style: const TextStyle(fontSize: 15)),
                        const Spacer(),
                        if (inCart)
                          Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                  color: _kPrimary, shape: BoxShape.circle),
                              child: const Icon(Icons.check,
                                  size: 10, color: Colors.white))
                        else if (!outOfStock)
                          Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                  color: _kPrimary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.add,
                                  size: 10, color: _kPrimary)),
                      ]),
                      const SizedBox(height: 6),
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: outOfStock ? _kTextGrey : _kTextDark)),
                      const Spacer(),
                      Text('$sym${price.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: outOfStock ? _kTextGrey : _kAccent)),
                      if (outOfStock)
                        const Text('Out of stock',
                            style: TextStyle(fontSize: 8, color: _kRed))
                      else
                        Text('/Kg',
                            style: TextStyle(
                                fontSize: 9,
                                color: _kTextGrey.withValues(alpha: 0.7))),
                    ]),
              ),
            );
          }),
    );
  }

  Widget _buildCartHeader(BillingProvider bill) {
    return Row(children: [
      Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
              color: _kRed, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 7),
      const Text('Cart',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
      const SizedBox(width: 6),
      if (bill.lines.isNotEmpty)
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: _kRed, borderRadius: BorderRadius.circular(20)),
            child: Text('${bill.lines.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700))),
      const Spacer(),
      if (bill.lines.isNotEmpty)
        GestureDetector(
            onTap: () {
              bill.clear();
              setState(() {});
            },
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kRed.withValues(alpha: 0.2))),
                child: const Text('Clear All',
                    style: TextStyle(
                        fontSize: 11,
                        color: _kRed,
                        fontWeight: FontWeight.w700)))),
    ]);
  }

  Widget _buildCartList(BillingProvider bill, String sym) {
    return Column(
      children: List.generate(bill.lines.length, (index) {
        final line = bill.lines[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: _cardDeco(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () => _editLine(index, bill),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(line.itemName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: _kPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4)),
                            child: const Text('Edit',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: _kPrimary,
                                    fontWeight: FontWeight.w700))),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                          '$sym${line.price.toStringAsFixed(0)} / ${line.unit}',
                          style:
                              const TextStyle(fontSize: 11, color: _kTextGrey)),
                    ]),
              )),
              const SizedBox(width: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(
                    icon: Icons.remove_rounded,
                    bg: _kRed.withValues(alpha: 0.08),
                    iconColor: _kRed,
                    onTap: () {
                      if (line.qty > 0.5) {
                        bill.updateLine(index, qty: line.qty - 0.5);
                      } else {
                        bill.removeLine(index);
                      }
                      setState(() {});
                    }),
                const SizedBox(width: 4),
                GestureDetector(
                    onTap: () => _editLine(index, bill),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                            '${line.qty % 1 == 0 ? line.qty.toInt() : line.qty.toStringAsFixed(1)} ${line.unit}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _kPrimary)))),
                const SizedBox(width: 4),
                _QtyBtn(
                    icon: Icons.add_rounded,
                    bg: _kPrimary.withValues(alpha: 0.08),
                    iconColor: _kPrimary,
                    onTap: () {
                      bill.updateLine(index, qty: line.qty + 0.5);
                      setState(() {});
                    }),
              ]),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$sym${line.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark)),
                const SizedBox(height: 6),
                GestureDetector(
                    onTap: () {
                      bill.removeLine(index);
                      setState(() {});
                    },
                    child: Icon(Icons.close_rounded,
                        size: 16, color: _kRed.withValues(alpha: 0.6))),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildExtrasSection(String sym, double total) {
    return Column(children: [
      _ToggleRow(
          label: 'Discount',
          icon: Icons.discount_outlined,
          color: _kOrange,
          isOn: _showDiscount,
          onToggle: () => setState(() {
                _showDiscount = !_showDiscount;
                if (!_showDiscount) _discountCtrl.text = '0';
              })),
      if (_showDiscount) ...[
        const SizedBox(height: 6),
        _AmountRow(
            label: 'Discount',
            icon: Icons.discount_outlined,
            color: _kOrange,
            ctrl: _discountCtrl,
            sym: sym,
            onChange: () => setState(() {}))
      ],
      const SizedBox(height: 8),
      _ToggleRow(
          label: 'Shipping',
          icon: Icons.local_shipping_outlined,
          color: Colors.blueGrey,
          isOn: _showShipping,
          onToggle: () => setState(() {
                _showShipping = !_showShipping;
                if (!_showShipping) _shippingCtrl.text = '0';
              })),
      if (_showShipping) ...[
        const SizedBox(height: 6),
        _AmountRow(
            label: 'Shipping',
            icon: Icons.local_shipping_outlined,
            color: Colors.blueGrey,
            ctrl: _shippingCtrl,
            sym: sym,
            onChange: () => setState(() {}))
      ],
      const SizedBox(height: 8),
      _ToggleRow(
          label: 'Packaging',
          icon: Icons.inventory_2_outlined,
          color: Colors.purple,
          isOn: _showPackaging,
          onToggle: () => setState(() {
                _showPackaging = !_showPackaging;
                if (!_showPackaging) _packagingCtrl.text = '0';
              })),
      if (_showPackaging) ...[
        const SizedBox(height: 6),
        _AmountRow(
            label: 'Packaging',
            icon: Icons.inventory_2_outlined,
            color: Colors.purple,
            ctrl: _packagingCtrl,
            sym: sym,
            onChange: () => setState(() {}))
      ],
      const SizedBox(height: 12),
      _buildPaymentSection(),
      const SizedBox(height: 10),
      _buildPaidRow(total, sym),
      const SizedBox(height: 10),
      // CHANGED: now calls the new picker-based delivery field
      _buildDeliveryField(),
      const SizedBox(height: 10),
      _buildNotesField(),
    ]);
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.payment_outlined, size: 15, color: _kTextGrey),
          const SizedBox(width: 8),
          const Text('Payment Method',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark)),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _paymentMethod == 'Credit'
                      ? _kOrange.withValues(alpha: 0.12)
                      : _kAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(_paymentMethod,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color:
                          _paymentMethod == 'Credit' ? _kOrange : _kAccent))),
        ]),
        const SizedBox(height: 10),
        Row(
            children: _payMethods.map((m) {
          final sel = m == _paymentMethod;
          return Expanded(
              child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = m),
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                          color: sel ? _kDark : _kBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sel ? _kDark : _kBorder)),
                      child: Text(m,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : _kTextGrey)))));
        }).toList()),
      ]),
    );
  }

  Widget _buildPaidRow(double total, String sym) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDeco(),
      child: Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child:
                const Icon(Icons.payments_outlined, size: 16, color: _kAccent)),
        const SizedBox(width: 10),
        const Text('Amount Paid',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
        const Spacer(),
        SizedBox(
            width: 130,
            child: TextField(
                controller: _paidCtrl,
                keyboardType:
    const TextInputType.numberWithOptions(decimal: true),
inputFormatters: [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
],
textAlign: TextAlign.right,
style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: _kTextDark),
decoration: InputDecoration(
    prefixText: '$sym ',
    prefixStyle:
        const TextStyle(fontSize: 12, color: _kTextGrey),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: _kAccent, width: 1.5))),
onChanged: (_) => setState(() => _paidUserEdited = true))),
      ]),
    );
  }

  // CHANGED: completely replaced — now a GestureDetector that opens a picker sheet
  Widget _buildDeliveryField() {
    return GestureDetector(
      onTap: () async {
        final boys = await DatabaseHelper.instance.getDeliveryBoys();
        if (!mounted) return;
        final picked = await showModalBottomSheet<Map<String, dynamic>?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _DeliveryPickerSheet(
            boys: boys,
            selected: _deliveryPerson,
          ),
        );
        if (picked != null && mounted) {
          setState(() => _deliveryPerson = picked['name'] as String);
          context.read<BillingProvider>().setDeliveryBoy(
            picked['id'] as int?,
            picked['name'] as String?,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDeco(
            border: _deliveryPerson.isNotEmpty
                ? Colors.teal.withValues(alpha: 0.4)
                : _kBorder),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delivery_dining_outlined,
                  size: 16, color: Colors.teal)),
          const SizedBox(width: 10),
          const Text('Delivery Person',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark)),
          const Spacer(),
          Text(
              _deliveryPerson.isEmpty ? 'None (optional)' : _deliveryPerson,
              style: TextStyle(
                  fontSize: 12,
                  color: _deliveryPerson.isEmpty ? _kTextGrey : Colors.teal,
                  fontWeight: _deliveryPerson.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w700)),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: _deliveryPerson.isEmpty ? _kTextGrey : Colors.teal),
        ]),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextField(
        controller: _notesCtrl,
        maxLines: 2,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
            hintText: 'Notes (optional)...',
            hintStyle: const TextStyle(fontSize: 13, color: _kTextGrey),
            filled: true,
            fillColor: _kCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder))));
                
  }

  BoxDecoration _cardDeco({Color? border}) => BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      );
}

// -- SAVE BAR -----------------------------------------------------------------
class _SaveBar extends StatelessWidget {
  final double sub, disc, tax, shipping, packaging, total;
  final String sym;
  final bool isEmpty, saving, showQr, isEditing;
  final String upiQrData;
  final VoidCallback onToggleQr, onSave;

  const _SaveBar(
      {required this.sub,
      required this.disc,
      required this.tax,
      required this.shipping,
      required this.packaging,
      required this.total,
      required this.sym,
      required this.isEmpty,
      required this.saving,
      required this.showQr,
      required this.isEditing,
      required this.upiQrData,
      required this.onToggleQr,
      required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _kCard, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, -4))
      ]),
      child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SumRow(
                  label: 'Subtotal', value: '$sym${sub.toStringAsFixed(2)}'),
              if (disc > 0) ...[
                const SizedBox(height: 3),
                _SumRow(
                    label: 'Discount',
                    value: '- $sym${disc.toStringAsFixed(2)}',
                    valueColor: _kOrange)
              ],
              if (tax > 0) ...[
                const SizedBox(height: 3),
                _SumRow(label: 'Tax', value: '$sym${tax.toStringAsFixed(2)}')
              ],
              if (shipping > 0) ...[
                const SizedBox(height: 3),
                _SumRow(
                    label: 'Shipping',
                    value: '+ $sym${shipping.toStringAsFixed(2)}',
                    valueColor: Colors.blueGrey)
              ],
              if (packaging > 0) ...[
                const SizedBox(height: 3),
                _SumRow(
                    label: 'Packaging',
                    value: '+ $sym${packaging.toStringAsFixed(2)}',
                    valueColor: Colors.purple)
              ],
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: _kBorder)),
              Row(children: [
                const Text('TOTAL',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                        letterSpacing: 0.5)),
                const Spacer(),
                Text('$sym${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _kPrimary,
                        height: 1)),
              ]),
              if (showQr && !isEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder)),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(8)),
                        child: QrImageView(
                            data: upiQrData,
                            version: QrVersions.auto,
                            size: 80)),
                    const SizedBox(width: 14),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Scan & Pay via UPI',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextDark)),
                          const SizedBox(height: 4),
                          const Text('godawarifish@upi',
                              style:
                                  TextStyle(fontSize: 11, color: _kTextGrey)),
                          const SizedBox(height: 4),
                          Text('$sym${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _kAccent)),
                        ]),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                    onPressed: (isEmpty || saving) ? null : onSave,
                    style: FilledButton.styleFrom(
                        backgroundColor: _kRed,
                        disabledBackgroundColor: _kBorder,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(
                                    isEditing
                                        ? Icons.edit_note_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(isEditing ? 'UPDATE BILL' : 'SAVE BILL',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8)),
                              ])),
              ),
            ]),
          )),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _SumRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _kTextGrey)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? _kTextDark)),
        ],
      );
}

// -- SMALL WIDGETS ------------------------------------------------------------
class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
      child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2))));
}

class _PillBtn extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBtn({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w700)));
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color bg, iconColor;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon,
      required this.bg,
      required this.iconColor,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _kBorder)),
          child: Icon(icon, size: 15, color: iconColor)));
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isOn;
  final VoidCallback onToggle;
  const _ToggleRow(
      {required this.label,
      required this.icon,
      required this.color,
      required this.isOn,
      required this.onToggle});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onToggle,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              color: isOn ? color.withValues(alpha: 0.06) : _kCard,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: isOn ? color.withValues(alpha: 0.3) : _kBorder)),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            const Spacer(),
            Icon(isOn ? Icons.keyboard_arrow_up_rounded : Icons.add_rounded,
                size: 18, color: color),
          ])));
}

class _AmountRow extends StatelessWidget {
  final String label, sym;
  final IconData icon;
  final Color color;
  final TextEditingController ctrl;
  final VoidCallback onChange;
  const _AmountRow(
      {required this.label,
      required this.icon,
      required this.color,
      required this.ctrl,
      required this.sym,
      required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
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
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
    prefixText: '$sym ',
    prefixStyle:
        const TextStyle(fontSize: 12, color: _kTextGrey),
    filled: true,
    fillColor: _kCard,
    isDense: true,
    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder))),
                onChanged: (_) => onChange())),
      ]));
}

class _VyTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool numeric, autofocus;
  final TextCapitalization caps;
  const _VyTextField(
      {required this.ctrl,
      required this.label,
      required this.hint,
      required this.icon,
      this.numeric = false,
      this.autofocus = false,
      this.caps = TextCapitalization.none});
  @override
  Widget build(BuildContext context) => TextField(
      controller: ctrl,
      autofocus: autofocus,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      textCapitalization: caps,
      decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5))));
}

class _ChipGroup extends StatelessWidget {
  final String title, selected;
  final List<String> items;
  final Color color;
  final ValueChanged<String> onTap;
  const _ChipGroup(
      {required this.title,
      required this.items,
      required this.selected,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _kTextGrey)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 6,
            children: items.map((item) {
              final sel = item == selected;
              return GestureDetector(
                  onTap: () => onTap(item),
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: sel ? color : _kBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? color : _kBorder)),
                      child: Text(item,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _kTextGrey))));
            }).toList()),
      ]);
}

// -- ADD / EDIT ITEM SHEET ----------------------------------------------------
class _AddItemSheet extends StatefulWidget {
  final String itemName, unit;
  final double initialQty, initialPrice;
  final bool isEdit;
  const _AddItemSheet({
    required this.itemName,
    required this.unit,
    required this.initialQty,
    required this.initialPrice,
    this.isEdit = false,
  });
  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final FocusNode _qtyFocus;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.initialQty % 1 == 0
            ? widget.initialQty.toInt().toString()
            : widget.initialQty.toStringAsFixed(2));
    _priceCtrl =
        TextEditingController(text: widget.initialPrice.toStringAsFixed(2));
    _qtyFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qtyFocus.requestFocus();
      _qtyCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _qtyCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  void _quickSetQty(String v) {
    if (!mounted) return;
    _qtyCtrl.text = v;
    _qtyCtrl.selection = TextSelection.collapsed(offset: v.length);
    setState(() {});
  }

  void _submit() {
    final q = double.tryParse(_qtyCtrl.text) ?? 0;
    final p = double.tryParse(_priceCtrl.text) ?? 0;
    Navigator.of(context).pop(<String, double>{'qty': q, 'price': p});
  }

  @override
  Widget build(BuildContext context) {
    final total = (double.tryParse(_qtyCtrl.text) ?? 0) *
        (double.tryParse(_priceCtrl.text) ?? 0);
    final btnColor = widget.isEdit ? _kPrimary : _kRed;

    return Container(
      decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SheetHandle(),
        const SizedBox(height: 16),
        Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.set_meal_rounded,
                  color: _kPrimary, size: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.itemName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark)),
                Text('Per ${widget.unit}',
                    style: const TextStyle(fontSize: 12, color: _kTextGrey)),
              ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.3))),
              child: Text('Rs.${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kAccent))),
        ]),
        const SizedBox(height: 18),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Qty',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kTextGrey)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ['0.5', '1', '1.5', '2', '2.5', '3', '5', '10']
                  .map((v) => GestureDetector(
                      onTap: () => _quickSetQty(v),
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                              color: _qtyCtrl.text == v ? _kPrimary : _kBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _qtyCtrl.text == v
                                      ? _kPrimary
                                      : _kBorder)),
                          child: Text(v,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _qtyCtrl.text == v
                                      ? Colors.white
                                      : _kTextDark)))))
                  .toList()),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _NumField(
                  label: 'Qty (${widget.unit})',
                  ctrl: _qtyCtrl,
                  focusNode: _qtyFocus,
                  onChanged: () => setState(() {}))),
          const SizedBox(width: 12),
          Expanded(
              child: _NumField(
                  label: 'Price (Rs.)',
                  ctrl: _priceCtrl,
                  onChanged: () => setState(() {}))),
        ]),
        const SizedBox(height: 18),
        SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: btnColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
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
                        fontSize: 14, fontWeight: FontWeight.w700)))),
      ]),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final FocusNode? focusNode;
  final VoidCallback? onChanged;
  const _NumField(
      {required this.label,
      required this.ctrl,
      this.focusNode,
      this.onChanged});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _kTextGrey)),
        const SizedBox(height: 6),
        TextField(
            controller: ctrl,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _kTextDark),
           decoration: InputDecoration(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kPrimary, width: 2))),
            onChanged: (_) => onChanged?.call()),
      ]);
}

// -- EMPTY CART ---------------------------------------------------------------
class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder)),
      child: const Column(children: [
        Icon(Icons.shopping_cart_outlined, size: 38, color: _kBorder),
        SizedBox(height: 8),
        Text('Tap an item to add to cart',
            style: TextStyle(
                fontSize: 12, color: _kTextGrey, fontWeight: FontWeight.w500)),
      ]));
}

// -- CUSTOMER PICKER SHEET ----------------------------------------------------
class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet();
  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    final results = await DatabaseHelper.instance
        .getCustomers(search: q, partyType: 'customer');
    if (mounted) {
      setState(() {
        _customers = results;
        _loading = false;
      });
    }
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController(text: _ctrl.text.trim());
    final phoneCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Customer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
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
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                    ctx, {'name': name, 'phone': phoneCtrl.text.trim()});
              },
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              child: const Text('Save')),
        ],
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    if (result == null || !mounted) return;
    try {
      final now = DateTime.now().toIso8601String();
      final id = await DatabaseHelper.instance.insertCustomer({
        'name': result['name'],
        'phone': result['phone']?.isEmpty == true ? null : result['phone'],
        'balance': 0.0,
        'party_type': 'customer',
        'created_at': now,
        'updated_at': now,
      });
      if (!mounted) return;
      Navigator.pop(
          context,
          CustomerModel(
              id: id,
              name: result['name']!,
              phone: result['phone'],
              balance: 0));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: _kRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        _SheetHandle(),
        const SizedBox(height: 14),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('Select Customer',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark)),
              const Spacer(),
              TextButton.icon(
                  onPressed: () => Navigator.pop(
                      context,
                      CustomerModel(
                          id: null, name: 'Walk-in Customer', balance: 0)),
                  icon: const Icon(Icons.person_outline, size: 14),
                  label: const Text('Walk-in', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: _kPrimary)),
              const SizedBox(width: 4),
              FilledButton.icon(
                  onPressed: _addCustomer,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                      backgroundColor: _kRed,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)))),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: _kTextGrey),
                    hintText: 'Search customer...',
                    hintStyle: const TextStyle(fontSize: 13, color: _kTextGrey),
                    filled: true,
                    fillColor: _kBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder))),
                onChanged: _load)),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                      child: CircularProgressIndicator(color: _kPrimary)))
              : _customers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('No customers found',
                            style: TextStyle(color: _kTextGrey, fontSize: 13)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: _addCustomer,
                            icon: const Icon(Icons.person_add_alt_1_rounded,
                                size: 16),
                            label: const Text('Add New Customer'),
                            style: FilledButton.styleFrom(
                                backgroundColor: _kRed,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)))),
                      ]))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _customers.length,
                      itemBuilder: (_, i) {
                        final c = _customers[i];
                        final bal = (c['balance'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: _kPrimary.withValues(alpha: 0.1),
                                child: Text(
                                    (c['name'] as String)
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _kPrimary))),
                            title: Text(c['name'] as String,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _kTextDark)),
                            subtitle: Text(c['phone'] as String? ?? '',
                                style: const TextStyle(
                                    fontSize: 11, color: _kTextGrey)),
                            trailing: bal > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: _kOrange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        'Due: Rs.${bal.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _kOrange,
                                            fontWeight: FontWeight.w600)))
                                : null,
                            onTap: () => Navigator.pop(
                                context, CustomerModel.fromMap(c)));
                      }),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// -- DELIVERY PICKER SHEET ----------------------------------------------------
class _DeliveryPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> boys;
  final String selected;
  const _DeliveryPickerSheet({required this.boys, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Select Delivery Person',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTextDark)),
        const SizedBox(height: 12),
        // None option
        ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          tileColor: selected.isEmpty ? Colors.teal.withValues(alpha: 0.08) : null,
          leading: const Icon(Icons.do_not_disturb_outlined, color: _kTextGrey),
          title: const Text('None',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          trailing: selected.isEmpty
              ? const Icon(Icons.check_circle_rounded, color: Colors.teal)
              : null,
          onTap: () => Navigator.pop(context, null),
        ),
        const Divider(height: 12),
        ...boys.map((b) {
          final name = b['name'] as String;
          final isSel = name == selected;
          return ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            tileColor: isSel ? Colors.teal.withValues(alpha: 0.08) : null,
            leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.teal.withValues(alpha: 0.12),
                child: Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal))),
        title: Text(name,
    style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
            trailing: isSel
                ? const Icon(Icons.check_circle_rounded, color: Colors.teal)
                : null,
            onTap: () => Navigator.pop(context, {'id': b['id'], 'name': name}),
          );
        }),
      ]),
    );
  }
}