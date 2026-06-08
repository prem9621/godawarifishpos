import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../services/firebase_sync_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users  = [];
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
    final db      = DatabaseHelper.instance;
    final results = await Future.wait([db.getUsers(), db.getStores()]);
    if (!mounted) return;
    setState(() {
      _users   = results[0];
      _stores  = results[1];
      _loading = false;
    });
  }

  String _storeName(int storeId) {
    final s = _stores.where((s) => s['id'] == storeId).toList();
    return s.isNotEmpty ? s.first['name'] as String : 'Store $storeId';
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
          'User Management',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (settings.isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_rounded, size: 22),
              onPressed: () => _showUserDialog(context),
              tooltip: 'Add User',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _UserCard(
                      user         : _users[i],
                      storeName    : _storeName(_users[i]['store_id'] as int),
                      isCurrentUser: settings.currentUserId == _users[i]['id'],
                      isAdmin      : settings.isAdmin,
                      onEdit       : () => _showUserDialog(context, user: _users[i]),
                      onDelete     : () => _deleteUser(_users[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No users yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400)),
          const SizedBox(height: 6),
          Text('Tap + to add a user',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ── Add / Edit Dialog ─────────────────────────────────────────────────────
  Future<void> _showUserDialog(BuildContext ctx,
      {Map<String, dynamic>? user}) async {
    final nameCtrl  = TextEditingController(text: user?['name']  as String? ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] as String? ?? '');
    final pinCtrl   = TextEditingController();
    String role     = user?['role']     as String? ?? 'staff';
    int    storeId  = user?['store_id'] as int?    ?? 1;

    final isEdit  = user != null;
    final formKey = GlobalKey<FormState>();

    // ✅ FIX: use a local copy of stores so the dialog is self-contained
    final stores = List<Map<String, dynamic>>.from(_stores);

    final saved = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEdit ? 'Edit User' : 'Add User',
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
                    label     : 'Full Name',
                    icon      : Icons.person_outline_rounded,
                    validator : (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    controller  : phoneCtrl,
                    label       : 'Phone (optional)',
                    icon        : Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    controller  : pinCtrl,
                    label       : isEdit
                        ? 'New PIN (leave blank to keep)'
                        : '4-digit PIN',
                    icon        : Icons.lock_outline_rounded,
                    keyboardType: TextInputType.number,
                    maxLength   : 4,
                    obscure     : true,
                    validator   : (v) {
                      if (!isEdit && (v == null || v.trim().length != 4)) {
                        return 'PIN must be 4 digits';
                      }
                      if (isEdit &&
                          v != null &&
                          v.trim().isNotEmpty &&
                          v.trim().length != 4) {
                        return 'PIN must be 4 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _InlineDropdown<String>(
                    label    : 'Role',
                    icon     : Icons.admin_panel_settings_outlined,
                    value    : role,
                    items    : const ['admin', 'staff'],
                    itemLabel: (v) => v == 'admin' ? '👑 Admin' : '👤 Staff',
                    onChanged: (v) {
                      if (v != null) setDState(() => role = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (stores.isNotEmpty)
                    _InlineDropdown<int>(
                      label    : 'Store',
                      icon     : Icons.store_outlined,
                      value    : storeId,
                      items    : stores.map((s) => s['id'] as int).toList(),
                      itemLabel: (v) {
                        final s = stores.where((s) => s['id'] == v).toList();
                        return s.isNotEmpty
                            ? s.first['name'] as String
                            : 'Store $v';
                      },
                      onChanged: (v) {
                        if (v != null) setDState(() => storeId = v);
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              // ✅ FIX: use dctx (dialog context), not outer ctx
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dctx, true); // ✅ FIX: use dctx
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue),
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );

    final name  = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final pin   = pinCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    pinCtrl.dispose();

    if (saved != true || !mounted) return;

    try {
      final db = DatabaseHelper.instance;
      if (isEdit) {
        final userId = user['id'] as int;
        final data = <String, dynamic>{
          'name'    : name,
          'phone'   : phone,
          'role'    : role,
          'store_id': storeId,
        };
        if (pin.isNotEmpty) data['pin'] = pin;
        await db.updateUser(userId, data);
        final saved = await db.getUserById(userId);
        if (saved != null) await FirebaseSyncService.instance.pushUser(saved);
      } else {
        final userId = await db.insertUser({
          'name'    : name,
          'phone'   : phone,
          'pin'     : pin,
          'role'    : role,
          'store_id': storeId,
        });
        final saved = await db.getUserById(userId);
        if (saved != null) await FirebaseSyncService.instance.pushUser(saved);
      }
      await _load();
      if (mounted) {
        _showSnack(isEdit ? 'User updated!' : 'User added!', success: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog( // ✅ FIX: use dctx everywhere inside
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Delete "${user['name']}"? This cannot be undone.'),
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
      final db = DatabaseHelper.instance;
      final userId = user['id'] as int;
      await db.deleteUser(userId);
      final saved = await db.getUserById(userId);
      if (saved != null) await FirebaseSyncService.instance.pushUser(saved);
      await _load();
      if (mounted) _showSnack('User deleted', success: true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      behavior       : SnackBarBehavior.floating,
      shape          : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String       storeName;
  final bool         isCurrentUser;
  final bool         isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.storeName,
    required this.isCurrentUser,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAdminRole = user['role'] == 'admin';
    final roleColor   = isAdminRole
        ? Colors.orange.shade700
        : Colors.blueGrey.shade600;

    return Container(
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border      : isCurrentUser
            ? Border.all(color: AppTheme.primaryBlue, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width : 44,
          height: 44,
          decoration: BoxDecoration(
            color       : roleColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              (user['name'] as String).isNotEmpty
                  ? (user['name'] as String)[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize  : 20,
                fontWeight: FontWeight.w800,
                color     : roleColor,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              user['name'] as String,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color       : AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                      color     : Colors.white,
                      fontSize  : 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color       : roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAdminRole ? '👑 Admin' : '👤 Staff',
                    style: TextStyle(
                        fontSize  : 11,
                        fontWeight: FontWeight.w600,
                        color     : roleColor),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.store_outlined,
                    size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(storeName,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            if ((user['phone'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(user['phone'] as String,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
        ),
        trailing: isAdmin
            ? PopupMenuButton<String>(
                icon : Icon(Icons.more_vert_rounded,
                    color: Colors.grey.shade500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit')   onEdit();
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
                      Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOG FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     label;
  final IconData                   icon;
  final TextInputType              keyboardType;
  final int?                       maxLength;
  final bool                       obscure;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.obscure   = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller  : controller,
      keyboardType: keyboardType,
      maxLength   : maxLength,
      obscureText : obscure,
      validator   : validator,
      style       : const TextStyle(fontSize: 14),
      decoration  : InputDecoration(
        labelText : label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        filled    : true,
        fillColor : Colors.grey.shade50,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : const BorderSide(
                color: AppTheme.primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : const BorderSide(color: Colors.red)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INLINE DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────
class _InlineDropdown<T> extends StatelessWidget {
  final String          label;
  final IconData        icon;
  final T               value;
  final List<T>         items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _InlineDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText : label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        filled    : true,
        fillColor : Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value    : value,
          isExpanded: true,
          items    : items
              .map((i) => DropdownMenuItem<T>(
                    value: i,
                    child: Text(itemLabel(i)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
