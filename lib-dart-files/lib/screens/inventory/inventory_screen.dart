import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/fish_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';

// â”€â”€ Palette â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kNavDark = Color(0xFF0D1B6E);
const _kNavMid = Color(0xFF1A2F9A);
const _kRed = Color(0xFFE31E24);
const _kBlue = Color(0xFF1565C0);
const _kGreen = Color(0xFF059669);
const _kBg = Color(0xFFF4F6FB);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE8ECF4);
const _kText1 = Color(0xFF0F172A);
const _kText2 = Color(0xFF64748B);
const _kText3 = Color(0xFFB0BAD0);

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;
  String _sortBy = 'name';
  bool _showLowStockOnly = false;
  int? _loadedStoreId;
  late AnimationController _fabAnim;
  Timer? _searchDebounce;

  static const _categories = [
    'All',
    'Fish',
    'Prawns',
    'Crab',
    'Dry Fish',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200), value: 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadItems();
    });
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeId = context.watch<SettingsProvider>().currentStoreId;
    if (_loadedStoreId == storeId) return;
    _loadedStoreId = storeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InventoryProvider>().loadItems(
            search: _searchCtrl.text.trim().isEmpty
                ? null
                : _searchCtrl.text.trim(),
            category: _selectedCategory == 'All' ? null : _selectedCategory,
          );
    });
  }

  void _onSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<InventoryProvider>().loadItems(
            search: _searchCtrl.text.trim().isEmpty
                ? null
                : _searchCtrl.text.trim(),
            category: _selectedCategory == 'All' ? null : _selectedCategory,
          );
    });
  }

  void _selectCategory(String cat) {
    setState(() => _selectedCategory = cat == 'All' ? null : cat);
    context.read<InventoryProvider>().loadItems(
          search:
              _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
          category: cat == 'All' ? null : cat,
        );
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> items) {
    final list = _showLowStockOnly
        ? items.where((i) {
            final stock = (i['stock'] as num?)?.toDouble() ?? 0;
            final min = (i['min_stock'] as num?)?.toDouble() ?? 0;
            return stock <= min && min > 0;
          }).toList()
        : List<Map<String, dynamic>>.from(items);

    list.sort((a, b) {
      switch (_sortBy) {
        case 'price':
          return ((b['price'] as num?)?.toDouble() ?? 0)
              .compareTo((a['price'] as num?)?.toDouble() ?? 0);
        case 'stock':
          return ((b['stock'] as num?)?.toDouble() ?? 0)
              .compareTo((a['stock'] as num?)?.toDouble() ?? 0);
        default:
          return ((a['name'] as String?) ?? '')
              .compareTo((b['name'] as String?) ?? '');
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(sym),
          _buildSearchAndFilter(),
          Expanded(child: _buildItemList(sym)),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FloatingActionButton.extended(
            onPressed: () => _showItemSheet(context, sym),
            backgroundColor: _kRed,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            label: const Text('Add Item',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.3)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // â”€â”€ HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader(String sym) {
    return Consumer<InventoryProvider>(
      builder: (_, prov, __) {
        final items = prov.items;
        final totalItems = items.length;
        final lowStock = items.where((i) {
          final stock = (i['stock'] as num?)?.toDouble() ?? 0;
          final min = (i['min_stock'] as num?)?.toDouble() ?? 0;
          return stock <= min && min > 0;
        }).length;
        final totalVal = items.fold<double>(
          0,
          (s, i) =>
              s +
              ((i['price'] as num?)?.toDouble() ?? 0) *
                  ((i['stock'] as num?)?.toDouble() ?? 0),
        );

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kNavDark, _kNavMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 1),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('Inventory',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3)),
                  const Spacer(),
                  _HeaderBtn(
                    icon: Icons.sort_rounded,
                    onTap: () => _showSortSheet(context),
                    tooltip: 'Sort',
                  ),
                  const SizedBox(width: 8),
                  _HeaderBtn(
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.read<InventoryProvider>().loadItems(
                            search: _searchCtrl.text.trim().isEmpty
                                ? null
                                : _searchCtrl.text.trim(),
                            category: _selectedCategory,
                          );
                    },
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 4),
                ]),
              ),

              // Stat pills
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  _HeaderPill(
                    label: 'Items',
                    value: '$totalItems',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF7DD3FC),
                  ),
                  const SizedBox(width: 8),
                  _HeaderPill(
                    label: 'Stock Value',
                    value: '$sym ${_fmtK(totalVal)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF6EE7B7),
                  ),
                  if (lowStock > 0) ...[
                    const SizedBox(width: 8),
                    _HeaderPill(
                      label: 'Low Stock',
                      value: '$lowStock',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFFBBF24),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  // â”€â”€ SEARCH + FILTER (combined) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSearchAndFilter() {
    return Container(
      color: _kCard,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search itemsâ€¦',
                hintStyle: const TextStyle(color: _kText3, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: _kText3, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 17, color: _kText2),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, color: _kText1),
            ),
          ),

          // Category chips + filter row
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == _categories.length) {
                    // Low stock toggle chip
                    return GestureDetector(
                      onTap: () => setState(
                          () => _showLowStockOnly = !_showLowStockOnly),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showLowStockOnly
                              ? const Color(0xFFFFF3E0)
                              : _kBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _showLowStockOnly
                                ? Colors.orange.shade400
                                : _kBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 13,
                                color: _showLowStockOnly
                                    ? Colors.orange.shade700
                                    : _kText3),
                            const SizedBox(width: 5),
                            Text('Low Stock',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _showLowStockOnly
                                        ? Colors.orange.shade700
                                        : _kText2)),
                          ],
                        ),
                      ),
                    );
                  }
                  final cat = _categories[i];
                  final selected =
                      (cat == 'All' && _selectedCategory == null) ||
                          cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => _selectCategory(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? _kRed : _kBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _kRed : _kBorder,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _kText2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Count row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(children: [
              Consumer<InventoryProvider>(
                builder: (_, prov, __) => Text(
                  '${_sorted(prov.items).length} items',
                  style: const TextStyle(
                      fontSize: 11,
                      color: _kText3,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),

          const Divider(height: 1, color: _kBorder),
        ],
      ),
    );
  }

  // â”€â”€ ITEM LIST â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildItemList(String sym) {
    return Consumer<InventoryProvider>(
      builder: (_, prov, __) {
        if (prov.loading) {
          return const Center(
              child: CircularProgressIndicator(color: _kRed, strokeWidth: 2.5));
        }

        final sorted = _sorted(prov.items);

        if (sorted.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 36, color: _kRed),
                ),
                const SizedBox(height: 16),
                const Text('No items found',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText1)),
                const SizedBox(height: 6),
                const Text('Add your first item using the + button',
                    style: TextStyle(fontSize: 12, color: _kText3)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final item = sorted[i];
            final fish = FishModel.fromMap(item);
            return _ItemCard(
              fish: fish,
              sym: sym,
              onEdit: () => _showItemSheet(context, sym, fish: fish),
              onAdjustStock: () => _showStockSheet(context, fish),
              onDeactivate: () => _confirmDeactivate(context, fish),
            );
          },
        );
      },
    );
  }

  // â”€â”€ SORT SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.sort_rounded, color: _kBlue, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Sort By',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),
            ...[
              ('name', 'Name (Aâ€“Z)', Icons.sort_by_alpha_rounded),
              ('price', 'Price (Highâ€“Low)', Icons.currency_rupee_rounded),
              ('stock', 'Stock (Highâ€“Low)', Icons.scale_rounded),
            ].map((opt) {
              final selected = _sortBy == opt.$1;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected ? _kRed.withValues(alpha: 0.08) : _kBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(opt.$3, color: selected ? _kRed : _kText2, size: 17),
                ),
                title: Text(opt.$2,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? _kText1 : _kText2)),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: _kRed, size: 18)
                    : null,
                onTap: () {
                  setState(() => _sortBy = opt.$1);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // â”€â”€ ADD / EDIT SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showItemSheet(BuildContext context, String sym, {FishModel? fish}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ItemFormSheet(
        fish: fish,
        sym: sym,
        onSave: (updated) async {
          final prov = context.read<InventoryProvider>();
          String? err;
          if (fish == null) {
            err = await prov.addItem(updated.toMap());
          } else {
            err = await prov.updateItem(updated.id!, updated.toMap());
          }
          if (err != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $err'),
              backgroundColor: const Color(0xFFEF4444),
            ));
          }
        },
      ),
    );
  }

  // â”€â”€ STOCK SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showStockSheet(BuildContext context, FishModel fish) {
    final ctrl = TextEditingController(text: fish.stock.toStringAsFixed(2));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(_).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10)),
                child:
                    const Icon(Icons.scale_outlined, color: _kGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adjust Stock â€“ ${fish.name}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(
                          'Current: ${fish.stock.toStringAsFixed(2)} ${fish.unit}',
                          style: const TextStyle(fontSize: 11, color: _kText2)),
                    ]),
              ),
            ]),
            const SizedBox(height: 18),
            _FormField(
              label: 'New Stock (${fish.unit})',
              ctrl: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final val = double.tryParse(ctrl.text.trim());
                  if (val == null || fish.id == null) return;
                  await context
                      .read<InventoryProvider>()
                      .setStock(fish.id!, val);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Update Stock',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ CONFIRM DEACTIVATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _confirmDeactivate(BuildContext context, FishModel fish) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Item',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(
            'Remove "${fish.name}" from inventory? This cannot be undone.',
            style: const TextStyle(fontSize: 13, color: _kText2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (fish.id != null) {
                await context
                    .read<InventoryProvider>()
                    .deactivateItem(fish.id!);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Remove',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _fmtK(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// â”€â”€ ITEM CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ItemCard extends StatelessWidget {
  final FishModel fish;
  final String sym;
  final VoidCallback onEdit, onAdjustStock, onDeactivate;

  const _ItemCard({
    required this.fish,
    required this.sym,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onDeactivate,
  });

  Color get _catColor {
    switch ((fish.category ?? '').toLowerCase()) {
      case 'fish':
        return const Color(0xFF1565C0);
      case 'prawns':
        return const Color(0xFFF59E0B);
      case 'crab':
        return const Color(0xFFEF4444);
      case 'dry fish':
        return const Color(0xFF92400E);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockPct =
        fish.minStock > 0 ? (fish.stock / fish.minStock).clamp(0.0, 2.0) : 1.0;
    final isLow = fish.isLowStock;
    final catColor = _catColor;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: isLow
            ? Border.all(color: Colors.orange.shade300, width: 1.5)
            : Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        // Main content
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: catColor.withValues(alpha: 0.2), width: 1),
                ),
                child: Center(
                  child: Text(
                    fish.name.isNotEmpty ? fish.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: catColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(fish.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kText1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isLow)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 10, color: Colors.orange.shade700),
                              const SizedBox(width: 3),
                              Text('Low',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade700)),
                            ],
                          ),
                        ),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      if (fish.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(fish.category!,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: catColor)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text('per ${fish.unit}',
                          style: const TextStyle(fontSize: 10, color: _kText3)),
                    ]),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sym ${fish.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kGreen),
                  ),
                  const SizedBox(height: 2),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 18, color: _kText3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'stock') onAdjustStock();
                      if (v == 'delete') onDeactivate();
                    },
                    itemBuilder: (_) => [
                      _menuItem(
                          'edit', Icons.edit_outlined, 'Edit Item', _kBlue),
                      _menuItem('stock', Icons.scale_outlined, 'Adjust Stock',
                          _kGreen),
                      _menuItem('delete', Icons.delete_outline_rounded,
                          'Remove', _kRed),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Stock bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Column(children: [
            Row(children: [
              Text(
                'Stock: ${fish.stock.toStringAsFixed(2)} ${fish.unit}',
                style: const TextStyle(
                    fontSize: 11, color: _kText2, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (fish.minStock > 0)
                Text(
                  'Min: ${fish.minStock.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11, color: _kText3),
                ),
            ]),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stockPct.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isLow
                      ? Colors.orange.shade400
                      : stockPct > 1.5
                          ? const Color(0xFF10B981)
                          : _kBlue,
                ),
              ),
            ),
          ]),
        ),

        // Action strip footer â€” pill style
        Container(
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            border: Border(
              top: BorderSide(color: _kBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            _ActionBtn(
              icon: Icons.edit_outlined,
              label: 'Edit',
              color: _kBlue,
              onTap: onEdit,
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.scale_outlined,
              label: 'Stock',
              color: _kGreen,
              onTap: onAdjustStock,
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.delete_outline_rounded,
              label: 'Remove',
              color: _kRed,
              onTap: onDeactivate,
            ),
          ]),
        ),
      ]),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// â”€â”€ ACTION BUTTON (pill style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ ITEM FORM SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ItemFormSheet extends StatefulWidget {
  final FishModel? fish;
  final String sym;
  final Future<void> Function(FishModel) onSave;

  const _ItemFormSheet({this.fish, required this.sym, required this.onSave});

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();
  String _unit = 'Kg';
  String? _category;
  bool _saving = false;

  static const _units = ['Kg', 'g', 'Piece', 'Dozen', 'L', 'ml'];
  static const _cats = ['Fish', 'Prawns', 'Crab', 'Dry Fish', 'Other'];

  @override
  void initState() {
    super.initState();
    final f = widget.fish;
    if (f != null) {
      _nameCtrl.text = f.name;
      _priceCtrl.text = f.price.toStringAsFixed(2);
      _stockCtrl.text = f.stock.toStringAsFixed(2);
      _minStockCtrl.text = f.minStock.toStringAsFixed(2);
      _unit = f.unit;
      _category = f.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name and price are required'),
            backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }
    setState(() => _saving = true);
    final fish = FishModel(
      id: widget.fish?.id,
      name: name,
      category: _category,
      unit: _unit,
      price: price,
      stock: double.tryParse(_stockCtrl.text.trim()) ?? 0,
      minStock: double.tryParse(_minStockCtrl.text.trim()) ?? 0,
    );
    await widget.onSave(fish);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.fish != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: isEdit
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                    color: isEdit ? _kBlue : _kRed,
                    size: 19),
              ),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Item' : 'Add New Item',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 18),
            _FormField(label: 'Item Name *', ctrl: _nameCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _FormField(
                  label: 'Price (${widget.sym}) *',
                  ctrl: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DropdownField(
                  label: 'Unit',
                  value: _unit,
                  items: _units,
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _FormField(
                  label: 'Opening Stock',
                  ctrl: _stockCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(
                  label: 'Min Stock Alert',
                  ctrl: _minStockCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Category',
              value: _category,
              items: _cats,
              onChanged: (v) => setState(() => _category = v),
              hint: 'Select category',
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isEdit ? _kBlue : _kRed,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Add Item',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ FORM HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? keyboardType;

  const _FormField(
      {required this.label, required this.ctrl, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _kText2)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType ?? TextInputType.text,
          style: const TextStyle(fontSize: 13, color: _kText1),
          decoration: InputDecoration(
            filled: true,
            fillColor: _kBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBlue, width: 1.5)),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? hint;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _kText2)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          hint: hint != null
              ? Text(hint!,
                  style: const TextStyle(fontSize: 13, color: _kText3))
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: _kBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBlue, width: 1.5)),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13, color: _kText1),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// â”€â”€ Header pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _HeaderPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _HeaderPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

// â”€â”€ Header icon button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HeaderBtn(
      {required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
