import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../database/database_helper.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _search = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _editStock(Map<String, dynamic> row) async {
    final id = row['id'] as int;
    final stock = (row['stock'] as num?)?.toDouble() ?? 0;
    final ctrl = TextEditingController(text: stock.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock · ${row['name']}'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: 'Quantity (${row['unit'] ?? 'Kg'})'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final v = double.tryParse(ctrl.text);
      if (v == null || v < 0) {
        _toast('Enter a valid stock quantity', error: true);
        return;
      }
      try {
        await context.read<InventoryProvider>().setStock(id, v);
        _toast('Stock updated');
      } catch (e) {
        _toast('Could not update stock: $e', error: true);
      }
    }
  }

  Future<void> _addItem() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final purchasePriceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    String category = AppConstants.fishCategories.first;
    String unit = 'Kg';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add New Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: AppConstants.fishCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: AppConstants.fishUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setLocal(() => unit = v ?? unit),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sale rate (₹) *',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: purchasePriceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Purchase rate (₹)',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockCtrl,
                  decoration: InputDecoration(
                    labelText: 'Opening stock ($unit)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save Item')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Enter item name', error: true);
      return;
    }
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    if (price <= 0) {
      _toast('Enter a valid sale rate', error: true);
      return;
    }
    final purchasePrice = double.tryParse(purchasePriceCtrl.text.trim()) ?? 0;
    final stk = double.tryParse(stockCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final itemData = {
        'name': name,
        'category': category,
        'unit': unit,
        'price': price,
        'purchase_price': purchasePrice,
        'stock': stk,
        'min_stock': 0.0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      };

      await DatabaseHelper.instance.insertItem(itemData);

      if (mounted) {
        await context.read<InventoryProvider>().loadItems();
        _toast('Item added: $name');
      }
    } catch (e) {
      debugPrint('insertItem error: $e');
      if (mounted) _toast('Failed to save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editItem(Map<String, dynamic> row) async {
    final nameCtrl = TextEditingController(text: row['name'] as String? ?? '');
    final priceCtrl = TextEditingController(text: '${(row['price'] as num?)?.toDouble() ?? 0}');
    final purchasePriceCtrl =
        TextEditingController(text: '${(row['purchase_price'] as num?)?.toDouble() ?? 0}');
    String category = row['category'] as String? ?? AppConstants.fishCategories.first;
    String unit = row['unit'] as String? ?? 'Kg';

    if (!AppConstants.fishCategories.contains(category)) {
      category = AppConstants.fishCategories.first;
    }
    if (!AppConstants.fishUnits.contains(unit)) unit = 'Kg';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Item name *', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  isExpanded: true,
                  items: AppConstants.fishCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                  items: AppConstants.fishUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setLocal(() => unit = v ?? unit),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sale rate (₹) *',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: purchasePriceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Purchase rate (₹)',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Enter item name', error: true);
      return;
    }
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    if (price <= 0) {
      _toast('Enter a valid sale rate', error: true);
      return;
    }

    try {
      final updated = {
        'name': name,
        'category': category,
        'unit': unit,
        'price': price,
        'purchase_price': double.tryParse(purchasePriceCtrl.text.trim()) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await DatabaseHelper.instance.updateItem(row['id'] as int, updated);
      if (mounted) {
        await context.read<InventoryProvider>().loadItems();
        _toast('Item updated');
      }
    } catch (e) {
      debugPrint('updateItem error: $e');
      if (mounted) _toast('Update failed: $e', error: true);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete item?'),
        content: Text('Remove "${row['name']}" from your item list? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteItem(row['id'] as int);
        await context.read<InventoryProvider>().loadItems();
        _toast('Item deleted');
      } catch (e) {
        _toast('Could not delete: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;
    final inv = context.watch<InventoryProvider>();

    final list = _search.text.isEmpty
        ? inv.items
        : inv.items
            .where((e) => (e['name'] as String? ?? '').toLowerCase().contains(_search.text.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    hintText: 'Search items…',
                    filled: true,
                    fillColor: Colors.white,
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
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('${list.length} items',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.read<InventoryProvider>().loadItems(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: inv.loading
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                                const SizedBox(height: 14),
                                Text('No items yet',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('Add your first fish or item to get started',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add first item'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppTheme.primaryBlue,
                            onRefresh: () => context.read<InventoryProvider>().loadItems(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final row = list[i];
                                final name = row['name'] as String? ?? 'Item';
                                final price = (row['price'] as num?)?.toDouble() ?? 0;
                                final purchasePrice = (row['purchase_price'] as num?)?.toDouble() ?? 0;
                                final stock = (row['stock'] as num?)?.toDouble() ?? 0;
                                final unit = row['unit'] as String? ?? 'Kg';
                                final outOfStock = stock <= 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFEEF2F7)),
                                  ),
                                  child: InkWell(
                                    onTap: () => _editStock(row),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(13),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 36, height: 36,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryBlue.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(9),
                                                ),
                                                child: const Icon(Icons.set_meal_rounded,
                                                    size: 18, color: AppTheme.primaryBlue),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                      fontSize: 14, fontWeight: FontWeight.w700),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF94A3B8)),
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                onSelected: (v) {
                                                  if (v == 'stock') _editStock(row);
                                                  if (v == 'edit') _editItem(row);
                                                  if (v == 'delete') _confirmDelete(row);
                                                },
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(
                                                    value: 'stock',
                                                    child: Row(children: [
                                                      Icon(Icons.scale_outlined, size: 18),
                                                      SizedBox(width: 10), Text('Adjust stock'),
                                                    ]),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(children: [
                                                      Icon(Icons.edit_outlined, size: 18),
                                                      SizedBox(width: 10), Text('Edit item'),
                                                    ]),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(children: [
                                                      Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFD32F2F)),
                                                      SizedBox(width: 10),
                                                      Text('Delete', style: TextStyle(color: Color(0xFFD32F2F))),
                                                    ]),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _ItemStat(
                                                  label: 'Sale Price',
                                                  value: AppUtils.formatCurrency(price, symbol: sym),
                                                ),
                                              ),
                                              Expanded(
                                                child: _ItemStat(
                                                  label: 'Purchase Price',
                                                  value: AppUtils.formatCurrency(purchasePrice, symbol: sym),
                                                ),
                                              ),
                                              Expanded(
                                                child: _ItemStat(
                                                  label: 'In Stock',
                                                  value: '${stock.toStringAsFixed(1)} $unit',
                                                  valueColor: outOfStock
                                                      ? const Color(0xFFD32F2F)
                                                      : const Color(0xFF2E7D32),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: FilledButton.icon(
              onPressed: _saving ? null : _addItem,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_box_outlined, size: 19),
              label: Text(_saving ? 'Saving…' : 'Add Item'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                elevation: 3,
                shadowColor: AppTheme.primaryBlue.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _ItemStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF1E293B))),
      ],
    );
  }
}