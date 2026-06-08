import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../services/firebase_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../home/main_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _users = [];

  Map<String, dynamic>? _selectedStore;
  Map<String, dynamic>? _selectedUser;

  String _pin = '';
  bool _loading = true;
  bool _pinError = false;
  String _errorMsg = '';

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _loadData();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      try {
        await FirebaseSyncService.instance.pullUsersAndStores();
      } catch (_) {}
      final db = DatabaseHelper.instance;
      final stores = await db.getStores();
      setState(() {
        _stores = stores;
        _selectedStore = stores.isNotEmpty ? stores.first : null;
        _loading = false;
      });
      if (_selectedStore != null) {
        final storeId = _asInt(_selectedStore!['id']);
        if (storeId != null) {
          await _loadUsers(storeId);
        }
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _asText(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _loadUsers(int storeId) async {
    final users = await DatabaseHelper.instance.getUsers(storeId: storeId);
    setState(() {
      _users = users;
      _selectedUser = users.isNotEmpty ? users.first : null;
      _pin = '';
      _pinError = false;
    });
  }

  // ── PIN logic ─────────────────────────────────────────────────────────────
  void _onKey(String key) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _pinError = false;
      _errorMsg = '';
    });
    if (_pin.length == 4) _verifyPin();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = false;
      _errorMsg = '';
    });
  }

  Future<void> _verifyPin() async {
    if (_selectedStore == null || _selectedUser == null) return;

    final storeId = _asInt(_selectedStore!['id']);
    final userId = _asInt(_selectedUser!['id']);
    if (storeId == null || userId == null) {
      setState(() {
        _pin = '';
        _pinError = true;
        _errorMsg = 'Invalid login data. Restart the app.';
      });
      return;
    }
    final user = await DatabaseHelper.instance.loginWithPin(
      _pin,
      storeId: storeId,
      userId: userId,
    );

    if (user == null) {
      // Wrong PIN — shake
      await _shakeCtrl.forward(from: 0);
      setState(() {
        _pin = '';
        _pinError = true;
        _errorMsg = 'Wrong PIN. Try again.';
      });
      return;
    }

    // ✅ Login success
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    await settings.loginUser(
      userId: _asInt(user['id']) ?? userId,
      userName: _asText(user['name'], 'User'),
      userRole: _asText(user['role'], 'user'),
    );
    await settings.switchStore(
      storeId: storeId,
      storeName: _asText(_selectedStore!['name'], 'Store'),
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShellScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D47A1),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            const SizedBox(height: 32),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.set_meal_rounded,
                color: AppTheme.primaryBlue,
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Godawari Fish Ledger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your PIN to continue',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 28),

            // ── Store + User selectors ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  // Store selector
                  Expanded(
                    child: _SelectorCard(
                      icon: Icons.store_rounded,
                      label: 'Store',
                      value: _asText(_selectedStore?['name'], 'No Store'),
                      onTap: _stores.length > 1 ? _pickStore : null,
                      showArrow: _stores.length > 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // User selector
                  Expanded(
                    child: _SelectorCard(
                      icon: Icons.person_rounded,
                      label: 'User',
                      value: _asText(_selectedUser?['name'], 'No User'),
                      onTap: _users.isNotEmpty ? _pickUser : null,
                      showArrow: _users.isNotEmpty,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── PIN dots ────────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (ctx, child) {
                final offset = (_shakeAnim.value *
                    10 *
                    (1 - _shakeAnim.value) *
                    ((_shakeAnim.value * 4).round() % 2 == 0 ? 1 : -1));
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pinError
                          ? Colors.red.shade300
                          : filled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                      border: Border.all(
                        color: _pinError
                            ? Colors.red.shade300
                            : Colors.white.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            if (_pinError) ...[
              const SizedBox(height: 10),
              Text(
                _errorMsg,
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const Spacer(),

            // ── Numpad ──────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _NumRow(keys: const ['1', '2', '3'], onKey: _onKey),
                  const SizedBox(height: 12),
                  _NumRow(keys: const ['4', '5', '6'], onKey: _onKey),
                  const SizedBox(height: 12),
                  _NumRow(keys: const ['7', '8', '9'], onKey: _onKey),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Empty slot
                      const SizedBox(width: 72, height: 72),
                      // 0
                      _NumKey(label: '0', onTap: () => _onKey('0')),
                      // Delete
                      _NumKey(
                        icon: Icons.backspace_outlined,
                        onTap: _onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  Future<void> _pickStore() async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Select Store',
        items: _stores,
        labelKey: 'name',
        icon: Icons.store_rounded,
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _selectedStore = chosen;
        _pin = '';
        _pinError = false;
      });
      final storeId = _asInt(chosen['id']);
      if (storeId != null) {
        await _loadUsers(storeId);
      }
    }
  }

  Future<void> _pickUser() async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Select User',
        items: _users,
        labelKey: 'name',
        icon: Icons.person_rounded,
        subtitleKey: 'role',
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _selectedUser = chosen;
        _pin = '';
        _pinError = false;
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SELECTOR CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SelectorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showArrow;

  const _SelectorCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              Icon(
                Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NUMPAD ROW
// ─────────────────────────────────────────────────────────────────────────────
class _NumRow extends StatelessWidget {
  final List<String> keys;
  final ValueChanged<String> onKey;

  const _NumRow({required this.keys, required this.onKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          keys.map((k) => _NumKey(label: k, onTap: () => onKey(k))).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NUMPAD KEY
// ─────────────────────────────────────────────────────────────────────────────
class _NumKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _NumKey({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 24)
              : Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PICKER BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String labelKey;
  final String? subtitleKey;
  final IconData icon;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelKey,
    required this.icon,
    this.subtitleKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          ...items.map((item) {
            final label = item[labelKey]?.toString() ?? '';
            final subtitle = subtitleKey != null
                ? (item[subtitleKey]?.toString() ?? '')
                : null;
            return ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
              ),
              title: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: subtitle != null
                  ? Text(
                      subtitle.isNotEmpty
                          ? subtitle[0].toUpperCase() + subtitle.substring(1)
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitle == 'admin'
                            ? Colors.orange.shade700
                            : Colors.grey.shade500,
                      ),
                    )
                  : null,
              onTap: () => Navigator.pop(context, item),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
