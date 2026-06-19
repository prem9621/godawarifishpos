import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/invoice_detail_sheet.dart';

// ──────────────────────────────────────────────────────────────────────────
//  NEW BILL SCREEN
// ──────────────────────────────────────────────────────────────────────────
class NewBillScreen extends StatefulWidget {
  final CustomerModel? preselectedCustomer;
  const NewBillScreen({super.key, this.preselectedCustomer});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final _searchCtrl    = TextEditingController();
  final _discountCtrl  = TextEditingController(text: '0');
  final _paidCtrl      = TextEditingController();
  final _notesCtrl     = TextEditingController();
  final _shippingCtrl  = TextEditingController(text: '0');
  final _packagingCtrl = TextEditingController(text: '0');

  String         _paymentMethod  = 'Cash';
  CustomerModel? _customer;
  bool           _paidUserEdited = false;
  bool           _customerPreset = false;
  bool           _showQr         = false;
  bool           _saving         = false;
  bool           _showDiscount   = false;
  bool           _showShipping   = false;
  bool           _showPackaging  = false;
  bool           _loadingCustomer = false;
  BillingProvider? _billRef;
  String         _categoryFilter = 'All';

  static const _payMethods = ['Cash', 'UPI', 'Card', 'Credit'];
  static const _categories = [
    'All', 'Fresh Water Fish', 'Sea Water Fish',
    'Prawn & Shrimp', 'Crab & Lobster',
    'Squid & Octopus', 'Chicken', 'Mutton',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bill = context.read<BillingProvider>();
      if (bill.editingInvoiceId != null) {
        _shippingCtrl.text  = bill.shipping.toStringAsFixed(2);
        _packagingCtrl.text = bill.packaging.toStringAsFixed(2);
        _showShipping  = bill.shipping > 0;
        _showPackaging = bill.packaging > 0;
        _findAndSetCustomer(bill.editingInvoiceId!);
      }
    });
  }

  Future<void> _findAndSetCustomer(int invoiceId) async {
    if (!mounted) return;
    setState(() => _loadingCustomer = true);
    try {
      final inv = await DatabaseHelper.instance.getInvoiceById(invoiceId);
      if (inv != null && inv['customer_id'] != null) {
        final db = await DatabaseHelper.instance.database;
        final custRows = await db.query(
          AppConstants.tableCustomers,
          where: 'id = ?',
          whereArgs: [inv['customer_id']],
        );
        if (custRows.isNotEmpty && mounted) {
          setState(() => _customer = CustomerModel.fromMap(custRows.first));
        }
      }
    } catch (e) {
      debugPrint('findAndSetCustomer error: $e');
    } finally {
      if (mounted) setState(() => _loadingCustomer = false);
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
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_customerPreset && widget.preselectedCustomer != null) {
      _customer       = widget.preselectedCustomer;
      _customerPreset = true;
    }
    final bill = context.read<BillingProvider>();
    if (!identical(_billRef, bill)) {
      _billRef?.removeListener(_onBillChanged);
      _billRef = bill;
      _billRef!.addListener(_onBillChanged);
    }
    _syncPaid();
  }

  void _onBillChanged() => _syncPaid();

  double _disc() {
    if (!_showDiscount) return 0;
    return double.tryParse(_discountCtrl.text) ?? 0;
  }

  double _shipping() {
    if (!_showShipping) return 0;
    return double.tryParse(_shippingCtrl.text) ?? 0;
  }

  double _packaging() {
    if (!_showPackaging) return 0;
    return double.tryParse(_packagingCtrl.text) ?? 0;
  }

  void _syncPaid() {
    if (!mounted || _paidUserEdited) return;
    final bill  = context.read<BillingProvider>();
    final s     = context.read<SettingsProvider>();
    final total = bill.totalAfterDiscountAndTax(s, _disc());
    final next  = total.toStringAsFixed(2);
    if (_paidCtrl.text != next) {
      _paidCtrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  String _buildUpiQr(double amount) {
    final s = context.read<SettingsProvider>();
    final upi = s.upiId.trim().isEmpty
        ? AppConstants.defaultUpiId
        : s.upiId.trim();
    return 'upi://pay?pa=$upi&pn=${Uri.encodeComponent(s.shopName.isEmpty ? AppConstants.shopName : s.shopName)}'
        '&am=${amount.toStringAsFixed(2)}&cu=INR';
  }

  // ─── CUSTOMER PICKER ────────────────────────────────────────────────────
  Future<void> _pickCustomer() async {
    final result = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (result != null && mounted) setState(() => _customer = result);
  }

  // ─── ITEM TAP ───────────────────────────────────────────────────────────
  Future<void> _onItemTap(Map<String, dynamic> row, BillingProvider bill) async {
    HapticFeedback.lightImpact();
    final name  = row['name'] as String? ?? 'Item';
    final price = (row['price'] as num?)?.toDouble() ?? 0;
    final unit  = row['unit']?.toString() ?? 'Kg';
    final itemId = row['id'] as int?;

    final existIdx = bill.lines.indexWhere(
      (l) => itemId != null && l.itemId == itemId,
    );
    if (existIdx >= 0) {
      await _editLine(existIdx, bill);
      return;
    }

    final qtyCtrl   = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: price.toStringAsFixed(2));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddItemSheet(
          itemName: name, unit: unit,
          qtyCtrl: qtyCtrl, priceCtrl: priceCtrl,
          onSave: () {
            final q = double.tryParse(qtyCtrl.text) ?? 1;
            final p = double.tryParse(priceCtrl.text) ?? price;
            if (q > 0) {
              bill.addManualItem(
                itemId: itemId,
                itemName: name, qty: q, unit: unit, price: p);
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

  Future<void> _editLine(int index, BillingProvider bill) async {
    if (index < 0 || index >= bill.lines.length) return;
    final line      = bill.lines[index];
    final qtyCtrl   = TextEditingController(text: line.qty.toStringAsFixed(2));
    final priceCtrl = TextEditingController(text: line.price.toStringAsFixed(2));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddItemSheet(
          itemName: line.itemName, unit: line.unit,
          qtyCtrl: qtyCtrl, priceCtrl: priceCtrl, isEdit: true,
          onSave: () {
            final q = double.tryParse(qtyCtrl.text) ?? line.qty;
            final p = double.tryParse(priceCtrl.text) ?? line.price;
            if (q <= 0) {
              bill.removeLine(index);
            } else {
              bill.updateLine(index, qty: q, price: p);
            }
            setState(() => _paidUserEdited = false);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  // ─── SAVE BILL ──────────────────────────────────────────────────────────
  Future<void> _saveBill() async {
    final bill = context.read<BillingProvider>();
    final s    = context.read<SettingsProvider>();
    if (bill.lines.isEmpty || _saving) return;

    setState(() => _saving = true);

    try {
      int? customerId = _customer?.id;
      if (customerId == null && _customer != null && _customer!.name != 'Walk-in Customer') {
        customerId = await DatabaseHelper.instance.insertCustomer({
          'name': _customer!.name,
          'phone': _customer!.phone ?? '',
          'balance': 0.0,
          'party_type': 'customer',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        _customer = _customer!.copyWith(id: customerId);
      }

      final disc      = _disc();
      final sub       = bill.subtotal();
      final afterDisc = (sub - disc).clamp(0.0, double.infinity);
      final tax       = bill.taxAmount(s, afterDisc);
      final shipping  = _shipping();
      final packaging = _packaging();
      final total     = bill.totalAfterDiscountAndTax(s, disc);
      final paid      = double.tryParse(_paidCtrl.text) ?? total;
      final balance   = (total - paid).clamp(0.0, double.infinity);

      final prevBal = _customer?.balance ?? 0.0;
      final curBal  = prevBal + balance;

      final now = DateTime.now();
      String invoiceNo;
      final existingInvoiceId = bill.editingInvoiceId;

      if (existingInvoiceId != null) {
        invoiceNo = bill.editingInvoiceNo ?? 'INV-EDIT';
      } else {
        final nextNumber  = await s.getNextInvoiceNo();
        final invoiceCode = s.invoicePrefix.trim().isEmpty
            ? AppConstants.defaultPrefix
            : s.invoicePrefix.trim().toUpperCase();
        invoiceNo = '$invoiceCode$nextNumber';
      }

      final invoiceMap = {
        'invoice_no'       : invoiceNo,
        'customer_id'      : customerId,
        'customer_name'    : _customer?.name ?? 'Walk-in Customer',
        'customer_phone'   : _customer?.phone ?? '',
        'subtotal'         : sub,
        'discount'         : disc,
        'tax'              : tax,
        'shipping'         : shipping,
        'packaging'        : packaging,
        'total'            : total,
        'paid'             : paid,
        'balance'          : balance,
        'previous_balance' : prevBal,
        'current_balance'  : curBal,
        'payment_method'   : _paymentMethod,
        'status'           : balance <= 0 ? 'paid' : 'unpaid',
        'notes'            : _notesCtrl.text.trim(),
        'created_at'       : now.toIso8601String(),
        'updated_at'       : now.toIso8601String(),
      };

      final itemMaps = bill.lines.map((l) => {
        'item_id'  : l.itemId,
        'item_name': l.itemName,
        'quantity' : l.qty,
        'unit'     : l.unit,
        'price'    : l.price,
        'amount'   : l.amount,
      }).toList();

      int finalInvoiceId;
      if (existingInvoiceId != null) {
        await DatabaseHelper.instance.updateInvoice(
          invoiceId: existingInvoiceId,
          invoice: invoiceMap,
          items: itemMaps,
        );
        finalInvoiceId = existingInvoiceId;
      } else {
        finalInvoiceId = await DatabaseHelper.instance.insertInvoice(invoiceMap, itemMaps);
      }

      if (!mounted) return;
      bill.clear();
      _notesCtrl.clear();
      _shippingCtrl.text  = '0';
      _packagingCtrl.text = '0';
      _discountCtrl.text  = '0';
      setState(() {
        _customer       = null;
        _paidUserEdited = false;
        _saving         = false;
        _showDiscount   = false;
        _showShipping   = false;
        _showPackaging  = false;
      });

      Navigator.of(context).pop();

      if (mounted) {
        await showReceiptPopup(context, finalInvoiceId);
      }
    } catch (e, st) {
      debugPrint('Save bill error: $e\n$st');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save bill: $e'),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s    = context.watch<SettingsProvider>();
    final bill = context.watch<BillingProvider>();
    final inv  = context.watch<InventoryProvider>();
    final sym  = s.currencySymbol.isEmpty ? 'Rs.' : s.currencySymbol;

    final isEditing = bill.editingInvoiceId != null;

    final search   = _searchCtrl.text.toLowerCase();
    final filtered = inv.items.where((e) {
      final name = (e['name'] as String? ?? '').toLowerCase();
      final cat  = e['category'] as String? ?? '';
      return (search.isEmpty || name.contains(search)) &&
             (_categoryFilter == 'All' || cat == _categoryFilter);
    }).toList();

    final sub       = bill.subtotal();
    final disc      = _disc();
    final afterDisc = (sub - disc).clamp(0.0, double.infinity);
    final tax       = bill.taxAmount(s, afterDisc);
    final ship      = _shipping();
    final pack      = _packaging();
    final total     = bill.totalAfterDiscountAndTax(s, disc);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F6FC),
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(bill),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ShopHeader(),
                    const SizedBox(height: 12),
                    _CustomerTile(
                      customer: _customer,
                      sym: sym,
                      loading: _loadingCustomer,
                      onTap: _pickCustomer,
                    ),
                    const SizedBox(height: 12),
                    _buildSearchBar(),
                    const SizedBox(height: 10),
                    _buildCategoryBar(),
                    const SizedBox(height: 12),
                    _buildItemGrid(filtered, bill, sym),
                    const SizedBox(height: 16),

                    Row(children: [
                      Text('Cart', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      if (bill.lines.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${bill.lines.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      const Spacer(),
                      if (bill.lines.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            bill.clear();
                            setState(() => _paidUserEdited = false);
                          },
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                          label: const Text('Clear', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD32F2F),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 8),

                    bill.lines.isEmpty
                        ? const _EmptyCart()
                        : _buildCartList(bill, sym),

                    const SizedBox(height: 16),

                    _ToggleSection(
                      label: 'Add Discount',
                      icon: Icons.discount_outlined,
                      color: const Color(0xFFE65100),
                      isOn: _showDiscount,
                      onToggle: () => setState(() {
                        _showDiscount = !_showDiscount;
                        if (!_showDiscount) _discountCtrl.text = '0';
                        _paidUserEdited = false;
                      }),
                    ),
                    if (_showDiscount) ...[
                      const SizedBox(height: 8),
                      _buildDiscountRow(sym),
                    ],

                    const SizedBox(height: 10),

                    _ToggleSection(
                      label: 'Add Shipping',
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xFF607D8B),
                      isOn: _showShipping,
                      onToggle: () => setState(() {
                        _showShipping = !_showShipping;
                        if (!_showShipping) _shippingCtrl.text = '0';
                        _paidUserEdited = false;
                      }),
                    ),
                    if (_showShipping) ...[
                      const SizedBox(height: 8),
                      _buildShippingRow(sym),
                    ],

                    const SizedBox(height: 10),

                    _ToggleSection(
                      label: 'Add Packaging',
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF7B1FA2),
                      isOn: _showPackaging,
                      onToggle: () => setState(() {
                        _showPackaging = !_showPackaging;
                        if (!_showPackaging) _packagingCtrl.text = '0';
                        _paidUserEdited = false;
                      }),
                    ),
                    if (_showPackaging) ...[
                      const SizedBox(height: 8),
                      _buildPackagingRow(sym),
                    ],

                    const SizedBox(height: 12),
                    _buildPaymentMethod(),
                    const SizedBox(height: 12),
                    _buildPaidRow(total, sym),
                    const SizedBox(height: 12),
                    _buildNotesField(),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),

            _BillSummaryBar(
              sub: sub, disc: disc, tax: tax,
              shipping: ship, packaging: pack, total: total, sym: sym,
              isEmpty: bill.lines.isEmpty,
              saving: _saving, showQr: _showQr, isEditing: isEditing,
              upiQrData: _buildUpiQr(total),
              onToggleQr: () => setState(() => _showQr = !_showQr),
              onSave: _saveBill,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BillingProvider bill) {
    final isEditing = bill.editingInvoiceId != null;
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () {
          if (bill.lines.isNotEmpty) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Discard bill?'),
                content: const Text('You have items in the cart. Leave anyway?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Stay')),
                  FilledButton(
                    onPressed: () {
                      bill.clear();
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Text(isEditing ? 'Edit Sale' : 'New Sale',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_rounded, size: 20),
          tooltip: 'Show QR',
          onPressed: () => setState(() => _showQr = !_showQr),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
        hintText: 'Search fish or item…',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5)),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: () { _searchCtrl.clear(); setState(() {}); })
            : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat      = _categories[i];
          final selected = cat == _categoryFilter;
          return GestureDetector(
            onTap: () => setState(() => _categoryFilter = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Text(cat,
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF475569))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemGrid(List<Map<String, dynamic>> items, BillingProvider bill, String sym) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(children: [
          Icon(Icons.search_off_rounded, size: 32, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text('No items found',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
        ]),
      );
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final row        = items[i];
          final name       = row['name'] as String? ?? 'Item';
          final price      = (row['price'] as num?)?.toDouble() ?? 0;
          final stock      = (row['stock'] as num?)?.toDouble() ?? 0;
          final outOfStock = stock <= 0;
          final itemId     = row['id'] as int?;
          final inCart     = bill.lines.any((l) => itemId != null && l.itemId == itemId);

          return GestureDetector(
            onTap: outOfStock ? null : () => _onItemTap(row, bill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 108,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: outOfStock
                    ? const Color(0xFFF8FAFC)
                    : inCart
                        ? AppTheme.primaryBlue.withOpacity(0.06)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: outOfStock
                      ? const Color(0xFFE2E8F0)
                      : inCart
                          ? AppTheme.primaryBlue
                          : const Color(0xFFE2E8F0),
                  width: inCart ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.set_meal_rounded, size: 15,
                        color: outOfStock ? Colors.grey.shade400 : AppTheme.primaryBlue),
                    const Spacer(),
                    if (inCart)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: AppTheme.primaryBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 9, color: Colors.white),
                      )
                    else if (!outOfStock)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.add, size: 9, color: AppTheme.primaryBlue),
                      ),
                  ]),
                  const SizedBox(height: 7),
                  Text(name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2,
                          color: outOfStock ? Colors.grey.shade400 : const Color(0xFF1E293B))),
                  const Spacer(),
                  Text('$sym${price.toStringAsFixed(0)}/Kg',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600,
                          color: outOfStock
                              ? Colors.grey.shade400
                              : const Color(0xFF2E7D32))),
                  if (outOfStock)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('Out of stock',
                          style: TextStyle(fontSize: 9, color: Color(0xFFD32F2F))),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartList(BillingProvider bill, String sym) {
    return Column(
      children: List.generate(bill.lines.length, (index) {
        final line = bill.lines[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEF2F7)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _editLine(index, bill),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.itemName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text('$sym${line.price.toStringAsFixed(0)}/${line.unit}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('Edit',
                              style: TextStyle(
                                  fontSize: 9, color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(
                  icon: Icons.remove_rounded,
                  color: const Color(0xFFFFEBEE), iconColor: const Color(0xFFD32F2F),
                  onTap: () {
                    if (line.qty > 0.5) {
                      bill.updateLine(index, qty: line.qty - 0.5);
                    } else {
                      bill.removeLine(index);
                    }
                    setState(() => _paidUserEdited = false);
                  },
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _editLine(index, bill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(7)),
                    child: Text(
                      '${line.qty % 1 == 0 ? line.qty.toInt() : line.qty.toStringAsFixed(1)} ${line.unit}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _QtyBtn(
                  icon: Icons.add_rounded,
                  color: const Color(0xFFE3F2FD), iconColor: AppTheme.primaryBlue,
                  onTap: () {
                    bill.updateLine(index, qty: line.qty + 0.5);
                    setState(() => _paidUserEdited = false);
                  },
                ),
              ]),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$sym${line.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: () {
                    bill.removeLine(index);
                    setState(() => _paidUserEdited = false);
                  },
                  child: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade300),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildDiscountRow(String sym) => _AmountInputRow(
        icon: Icons.discount_outlined, iconColor: const Color(0xFFE65100),
        label: 'Discount', sym: sym, controller: _discountCtrl,
        borderColor: const Color(0xFFFFE0B2),
        onChanged: () => setState(() => _paidUserEdited = false),
      );

  Widget _buildShippingRow(String sym) => _AmountInputRow(
        icon: Icons.local_shipping_outlined, iconColor: const Color(0xFF607D8B),
        label: 'Shipping', sym: sym, controller: _shippingCtrl,
        borderColor: const Color(0xFFCFD8DC),
        onChanged: () => setState(() => _paidUserEdited = false),
      );

  Widget _buildPackagingRow(String sym) => _AmountInputRow(
        icon: Icons.inventory_2_outlined, iconColor: const Color(0xFF7B1FA2),
        label: 'Packaging', sym: sym, controller: _packagingCtrl,
        borderColor: const Color(0xFFE1BEE7),
        onChanged: () => setState(() => _paidUserEdited = false),
      );

  Widget _buildPaymentMethod() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payment Method',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8, runSpacing: 6,
          children: _payMethods.map((m) {
            final sel = m == _paymentMethod;
            return GestureDetector(
              onTap: () => setState(() => _paymentMethod = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
                ),
                child: Text(m,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : const Color(0xFF475569))),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _buildPaidRow(double total, String sym) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Row(children: [
        const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        const Text('Amount Paid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _paidCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixText: '$sym ',
              prefixStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5)),
            ),
            onChanged: (_) => setState(() => _paidUserEdited = true),
          ),
        ),
      ]),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesCtrl,
      maxLines: 2,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Notes (optional)…',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5)),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  REUSABLE AMOUNT INPUT ROW
// ──────────────────────────────────────────────────────────────────────────
class _AmountInputRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, sym;
  final TextEditingController controller;
  final Color borderColor;
  final VoidCallback onChanged;

  const _AmountInputRow({
    required this.icon, required this.iconColor, required this.label,
    required this.sym, required this.controller,
    required this.borderColor, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        SizedBox(
          width: 110,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '$sym ',
              prefixStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  TOGGLE SECTION (discount / shipping / packaging)
// ──────────────────────────────────────────────────────────────────────────
class _ToggleSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isOn;
  final VoidCallback onToggle;

  const _ToggleSection({
    required this.label, required this.icon, required this.color,
    required this.isOn, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isOn ? color.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isOn ? color.withValues(alpha: 0.35) : const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          Icon(isOn ? Icons.keyboard_arrow_up_rounded : Icons.add_rounded, size: 18, color: color),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  ADD / EDIT ITEM SHEET
// ──────────────────────────────────────────────────────────────────────────
class _AddItemSheet extends StatefulWidget {
  final String itemName, unit;
  final TextEditingController qtyCtrl, priceCtrl;
  final VoidCallback onSave;
  final bool isEdit;

  const _AddItemSheet({
    required this.itemName, required this.unit,
    required this.qtyCtrl, required this.priceCtrl,
    required this.onSave, this.isEdit = false,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late final FocusNode _qtyFocus;

  @override
  void initState() {
    super.initState();
    _qtyFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qtyFocus.requestFocus();
      widget.qtyCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: widget.qtyCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _qtyFocus.dispose();
    super.dispose();
  }

  void _quickSetQty(String v) {
    widget.qtyCtrl.text = v;
    widget.qtyCtrl.selection = TextSelection.collapsed(offset: v.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = (double.tryParse(widget.qtyCtrl.text) ?? 0) *
        (double.tryParse(widget.priceCtrl.text) ?? 0);

    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
        20, 14, 20, MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.set_meal_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.itemName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Per ${widget.unit}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC8E6C9))),
            child: Text('Rs.${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
          ),
        ]),
        const SizedBox(height: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Quantity',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: ['0.5', '1', '1.5', '2', '2.5', '3', '5', '10']
                .map((v) => GestureDetector(
                      onTap: () => _quickSetQty(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: widget.qtyCtrl.text == v
                              ? AppTheme.primaryBlue
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: widget.qtyCtrl.text == v
                                  ? AppTheme.primaryBlue
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(v,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: widget.qtyCtrl.text == v
                                    ? Colors.white
                                    : const Color(0xFF1E293B))),
                      ),
                    ))
                .toList(),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _InputField(
                label: 'Quantity (${widget.unit})',
                ctrl: widget.qtyCtrl,
                focusNode: _qtyFocus,
                onChanged: () => setState(() {})),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InputField(
                label: 'Price (Rs./Kg)',
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
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(
                widget.isEdit ? Icons.edit_rounded : Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              widget.isEdit
                  ? 'Update Item  ·  Rs.${total.toStringAsFixed(0)}'
                  : 'Add to Cart  ·  Rs.${total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final FocusNode? focusNode;
  final VoidCallback? onChanged;

  const _InputField({
    required this.label, required this.ctrl, this.focusNode, this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        focusNode: focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
        ),
        onChanged: (_) => onChanged?.call(),
      ),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  SHOP HEADER
// ──────────────────────────────────────────────────────────────────────────
class _ShopHeader extends StatelessWidget {
  const _ShopHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3F2FD))),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: AppTheme.primaryBlue, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.set_meal_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GODAWARI FISH',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            SizedBox(height: 2),
            Text('Fish Market Central Naka, MH-20',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Ph: 9371306189', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(DateFormat('dd MMM').format(DateTime.now()),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text(DateFormat('hh:mm a').format(DateTime.now()),
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  CUSTOMER TILE
// ──────────────────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final CustomerModel? customer;
  final String sym;
  final bool loading;
  final VoidCallback onTap;
  const _CustomerTile({
    required this.customer, required this.sym, required this.onTap, this.loading = false,
  });

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
              color: customer != null
                  ? AppTheme.primaryBlue.withOpacity(0.35)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: customer != null
                ? AppTheme.primaryBlue.withOpacity(0.1)
                : const Color(0xFFF1F5F9),
            child: loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    customer != null ? Icons.person_rounded : Icons.person_add_outlined,
                    size: 18,
                    color: customer != null ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer?.name ?? 'Walk-in Customer',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: customer != null ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (customer != null) ...[
                const SizedBox(height: 2),
                Text('Balance: $sym${customer!.balance.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: customer!.balance > 0
                            ? const Color(0xFFE65100)
                            : const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600)),
              ] else
                const Text('Tap to select customer',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  EMPTY CART
// ──────────────────────────────────────────────────────────────────────────
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEF2F7))),
      child: Column(children: [
        Icon(Icons.shopping_cart_outlined, size: 38, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text('Tap an item above to add to cart',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  QTY BUTTON
// ──────────────────────────────────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color, iconColor;
  final VoidCallback onTap;
  const _QtyBtn({
    required this.icon, required this.onTap,
    this.color = const Color(0xFFF5F5F5), this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  BILL SUMMARY BAR
// ──────────────────────────────────────────────────────────────────────────
class _BillSummaryBar extends StatelessWidget {
  final double sub, disc, tax, shipping, packaging, total;
  final String sym;
  final bool isEmpty, saving, showQr, isEditing;
  final String upiQrData;
  final VoidCallback onToggleQr, onSave;

  const _BillSummaryBar({
    required this.sub, required this.disc, required this.tax,
    required this.shipping, required this.packaging, required this.total,
    required this.sym, required this.isEmpty, required this.saving,
    required this.showQr, required this.isEditing,
    required this.upiQrData, required this.onToggleQr, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SumRow(label: 'Subtotal', value: '$sym${sub.toStringAsFixed(2)}'),
              if (disc > 0) ...[
                const SizedBox(height: 4),
                _SumRow(label: 'Discount', value: '- $sym${disc.toStringAsFixed(2)}',
                    valueColor: const Color(0xFFE65100)),
              ],
              if (tax > 0) ...[
                const SizedBox(height: 4),
                _SumRow(label: 'Tax', value: '$sym${tax.toStringAsFixed(2)}'),
              ],
              if (shipping > 0) ...[
                const SizedBox(height: 4),
                _SumRow(label: 'Shipping', value: '$sym${shipping.toStringAsFixed(2)}'),
              ],
              if (packaging > 0) ...[
                const SizedBox(height: 4),
                _SumRow(label: 'Packaging', value: '$sym${packaging.toStringAsFixed(2)}'),
              ],
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  Text('$sym${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue)),
                ],
              ),
              if (showQr && !isEmpty) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8)),
                    child: QrImageView(data: upiQrData, version: QrVersions.auto, size: 90),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Scan & Pay via UPI',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Amount: $sym${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
                    ]),
                  ),
                ]),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (isEmpty || saving) ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    saving ? 'Saving…' : (isEditing ? 'UPDATE BILL' : 'SAVE BILL'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _SumRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B))),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  CUSTOMER PICKER SHEET
// ──────────────────────────────────────────────────────────────────────────
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
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results =
          await DatabaseHelper.instance.getCustomers(search: q, partyType: 'customer');
      if (mounted) setState(() { _customers = results; _loading = false; });
    } catch (e) {
      debugPrint('Customer search error: $e');
      if (mounted) setState(() { _customers = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Select Customer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.pop(
                  context, CustomerModel(id: null, name: 'Walk-in Customer', balance: 0)),
              icon: const Icon(Icons.person_outline, size: 14),
              label: const Text('Walk-in', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
              hintText: 'Search customer…',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              filled: true, fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            onChanged: _load,
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()))
              : _customers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No customers found',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _customers.length,
                      itemBuilder: (_, i) {
                        final c   = _customers[i];
                        final bal = (c['balance'] as num?)?.toDouble() ?? 0;
                        final name = c['name'] as String? ?? 'Unknown';
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(c['phone'] as String? ?? '', style: const TextStyle(fontSize: 11)),
                          trailing: bal > 0
                              ? Text('Due: Rs.${bal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600))
                              : null,
                          onTap: () => Navigator.pop(context, CustomerModel.fromMap(c)),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}