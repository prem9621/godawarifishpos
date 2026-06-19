import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../database/database_helper.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shell_provider.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final stores = await DatabaseHelper.instance.getStores();
    if (!mounted) return;
    setState(() {
      _stores = stores;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Store Management',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (settings.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_business_rounded, size: 22),
              onPressed: () => _showStoreDialog(context),
              tooltip: 'Add Store',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stores.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final store = _stores[i];
                      final isActive =
                          settings.currentStoreId == (store['id'] as int);
                      return _StoreCard(
                        store: store,
                        isActive: isActive,
                        isAdmin: settings.isAdmin,
                        onSwitch: () => _switchStore(store),
                        onEdit: () => _showStoreDialog(context, store: store),
                        onDelete: () => _deleteStore(store),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_mall_directory_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No stores yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400)),
          const SizedBox(height: 6),
          Text('Tap + to add a store',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ── Switch store ──────────────────────────────────────────────────────────
  Future<void> _switchStore(Map<String, dynamic> store) async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    await settings.switchStore(
      storeId: store['id'] as int,
      storeName: store['name'] as String,
    );
    if (!mounted) return;
    await Future.wait([
      context.read<CustomerProvider>().loadCustomers(),
      context.read<InventoryProvider>().loadItems(),
    ]);
    if (mounted) context.read<ShellProvider>().bumpHomeRefresh();
    if (mounted) {
      _showSnack('Switched to ${store['name']}', success: true);
    }
  }

  // ── Add / Edit Dialog ─────────────────────────────────────────────────────
  Future<void> _showStoreDialog(BuildContext ctx,
      {Map<String, dynamic>? store}) async {
    final nameCtrl =
        TextEditingController(text: store?['name'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: store?['phone'] as String? ?? '');
    final addressCtrl =
        TextEditingController(text: store?['address'] as String? ?? '');
    final emailCtrl =
        TextEditingController(text: store?['email'] as String? ?? '');

    final isEdit = store != null;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        // ✅ use dctx inside builder
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEdit ? 'Edit Store' : 'Add Store',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                  controller: nameCtrl,
                  label: 'Store Name',
                  icon: Icons.store_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Store name required'
                      : null,
                ),
                const SizedBox(height: 12),
                _DialogField(
                  controller: phoneCtrl,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _DialogField(
                  controller: addressCtrl,
                  label: 'Address',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _DialogField(
                  controller: emailCtrl,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false), // ✅ dctx
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dctx, true); // ✅ dctx
              }
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final email = emailCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    emailCtrl.dispose();

    if (saved != true || !mounted) return;

    try {
      final db = DatabaseHelper.instance;
      if (isEdit) {
        await db.updateStore(store!['id'] as int, {
          'name': name,
          'phone': phone,
          'address': address,
          'email': email,
        });
        if (mounted) {
          final settings = context.read<SettingsProvider>();
          if (settings.currentStoreId == (store['id'] as int)) {
            await settings.switchStore(
              storeId: store['id'] as int,
              storeName: name,
            );
          }
        }
      } else {
        await db.insertStore({
          'name': name,
          'phone': phone,
          'address': address,
          'email': email,
        });
      }
      await _load();
      if (mounted) {
        _showSnack(isEdit ? 'Store updated!' : 'Store added!', success: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteStore(Map<String, dynamic> store) async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();

    if (settings.currentStoreId == (store['id'] as int)) {
      _showSnack('Cannot delete the active store. Switch first.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        // ✅ use dctx
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Store',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            'Delete "${store['name']}"? All data linked to this store will be hidden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false), // ✅ dctx
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true), // ✅ dctx
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await DatabaseHelper.instance.deleteStore(store['id'] as int);
      await _load();
      if (mounted) _showSnack('Store deleted', success: true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STORE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final bool isActive;
  final bool isAdmin;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StoreCard({
    required this.store,
    required this.isActive,
    required this.isAdmin,
    required this.onSwitch,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: AppTheme.primaryBlue, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryBlue : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.store_rounded,
                color: isActive ? Colors.white : Colors.grey.shade500,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store['name'] as String,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  if ((store['phone'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(store['phone'] as String,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                  if ((store['address'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            store['address'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (!isActive)
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: onSwitch,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                        label: const Text('Switch to this store',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          side: const BorderSide(color: AppTheme.primaryBlue),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                icon:
                    Icon(Icons.more_vert_rounded, color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOG FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }
}
