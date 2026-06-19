import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_utils.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sale_return_provider.dart';
import '../../providers/settings_provider.dart';

// ── Vyapar palette ────────────────────────────────────────────────────────────
const _kNavDark = Color(0xFF1A237E);
const _kNavMid  = Color(0xFF283593);
const _kRed     = Color(0xFFE31E24);
const _kBlue    = Color(0xFF1565C0);
const _kBg      = Color(0xFFF2F6FA);
const _kCard    = Colors.white;
const _kBorder  = Color(0xFFEEF1F6);
const _kText1   = Color(0xFF111827);
const _kText2   = Color(0xFF6B7280);
const _kText3   = Color(0xFF9CA3AF);

class SaleReturnScreen extends StatefulWidget {
  const SaleReturnScreen({super.key});

  @override
  State<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends State<SaleReturnScreen> {
  final _search = TextEditingController();
  CustomerModel? _customer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final list = context
        .read<CustomerProvider>()
        .customers
        .where((c) => c.isCustomer)
        .toList();

    final chosen = await showModalBottomSheet<CustomerModel?>(
      context       : context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sym = ctx.read<SettingsProvider>().currencySymbol;
        return Container(
          decoration: const BoxDecoration(
            color        : _kCard,
            borderRadius : BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width : 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color        : Colors.grey.shade300,
                      borderRadius : BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  Container(
                    width : 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color        : const Color(0xFFEFF6FF),
                        borderRadius : BorderRadius.circular(8)),
                    child: const Icon(Icons.people_alt_outlined,
                        color: _kBlue, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Select Customer',
                      style: TextStyle(
                          fontSize  : 15,
                          fontWeight: FontWeight.w800,
                          color     : _kText1)),
                ]),
              ),
              const Divider(height: 1, color: _kBorder),

              // Walk-in option
              ListTile(
                leading: Container(
                  width : 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color        : _kBg,
                      borderRadius : BorderRadius.circular(8)),
                  child: const Icon(Icons.person_off_outlined,
                      color: _kText2, size: 17),
                ),
                title: const Text('Walk-in',
                    style: TextStyle(
                        fontSize  : 13,
                        fontWeight: FontWeight.w600,
                        color     : _kText1)),
                subtitle: const Text('No party balance change',
                    style: TextStyle(fontSize: 11, color: _kText3)),
                onTap: () => Navigator.pop(ctx, null),
              ),
              const Divider(height: 1, color: _kBorder),

              // Customer list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: ListView(
                  padding       : const EdgeInsets.only(bottom: 24),
                  shrinkWrap    : true,
                  children: list.map((c) {
                    final bal = c.balance;
                    return ListTile(
                      leading: Container(
                        width : 34,
                        height: 34,
                        decoration: const BoxDecoration(
                            color       : Color(0xFFFDE8E8),
                            shape       : BoxShape.circle),
                        child: Center(
                          child: Text(
                            c.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                fontSize  : 14,
                                fontWeight: FontWeight.w800,
                                color     : _kRed),
                          ),
                        ),
                      ),
                      title: Text(c.name,
                          style: const TextStyle(
                              fontSize  : 13,
                              fontWeight: FontWeight.w600,
                              color     : _kText1)),
                      subtitle: Text(
                        'Due ${AppUtils.formatCurrency(bal, symbol: sym)}',
                        style: TextStyle(
                            fontSize: 11,
                            color   : bal > 0
                                ? const Color(0xFFE65100)
                                : _kText3),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          size: 16, color: _kText3),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) setState(() => _customer = chosen);
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final settings = context.read<SettingsProvider>();
    final sr       = context.read<SaleReturnProvider>();
    final inv      = context.read<InventoryProvider>();
    final err      = await sr.saveReturn(
        settings: settings, inventory: inv, customer: _customer);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content        : Text(err),
        backgroundColor: _kRed,
        behavior       : SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    await context.read<CustomerProvider>().loadCustomers();
    if (!mounted) return;
    setState(() => _customer = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : const Text('✅ Return saved · stock increased'),
      backgroundColor: Colors.green.shade700,
      behavior       : SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sym      = context.watch<SettingsProvider>().currencySymbol;
    final sr       = context.watch<SaleReturnProvider>();
    final inv      = context.watch<InventoryProvider>();

    final filtered = _search.text.isEmpty
        ? inv.items
        : inv.items
            .where((e) => (e['name'] as String)
                .toLowerCase()
                .contains(_search.text.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Gradient header ───────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kNavDark, _kNavMid],
                begin : Alignment.topLeft,
                end   : Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(children: [
                  // Back button
                  if (Navigator.of(context).canPop())
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width : 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color        : Colors.white.withValues(alpha: 0.15),
                          borderRadius : BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2), width: 1),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 17),
                      ),
                    )
                  else
                    Container(
                      width : 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color        : Colors.white.withValues(alpha: 0.15),
                        borderRadius : BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_return_outlined,
                          color: Colors.white, size: 17),
                    ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Sale Return',
                        style: TextStyle(
                            fontSize  : 16,
                            fontWeight: FontWeight.w800,
                            color     : Colors.white)),
                  ),
                  // Items count badge
                  if (sr.lines.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color        : Colors.white.withValues(alpha: 0.15),
                        borderRadius : BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Text(
                        '${sr.lines.length} item${sr.lines.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color     : Colors.white,
                            fontSize  : 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
              ),
            ),
          ),

          // ── Customer selector ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: GestureDetector(
              onTap: _pickCustomer,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color        : _kCard,
                  borderRadius : BorderRadius.circular(10),
                  border       : Border.all(color: _kBorder),
                  boxShadow: [
                    BoxShadow(
                        color     : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset    : const Offset(0, 2))
                  ],
                ),
                child: Row(children: [
                  Container(
                    width : 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _customer != null
                          ? const Color(0xFFFDE8E8)
                          : _kBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _customer != null
                          ? Text(
                              _customer!.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                  fontSize  : 14,
                                  fontWeight: FontWeight.w800,
                                  color     : _kRed),
                            )
                          : const Icon(Icons.person_outline,
                              color: _kText3, size: 17),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        _customer != null ? _customer!.name : 'Select Customer',
                        style: TextStyle(
                            fontSize  : 13,
                            fontWeight: FontWeight.w700,
                            color     : _customer != null
                                ? _kText1
                                : _kText2),
                      ),
                      Text(
                        _customer != null
                            ? 'Tap to change'
                            : 'Walk-in if not selected',
                        style: const TextStyle(
                            fontSize: 10, color: _kText3),
                      ),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: _kText3),
                ]),
              ),
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              controller: _search,
              onChanged : (_) => setState(() {}),
              decoration: InputDecoration(
                hintText  : 'Search items to return…',
                hintStyle : const TextStyle(color: _kText3, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _kText3, size: 20),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 17, color: _kText2),
                        onPressed: () =>
                            setState(() => _search.clear()),
                      )
                    : null,
                filled      : true,
                fillColor   : _kCard,
                border      : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide  : const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide  : const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide  : const BorderSide(
                        color: _kBlue, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),

          // ── Item chips ────────────────────────────────────────────────
          SizedBox(
            height: 56,
            child: inv.loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _kRed, strokeWidth: 2))
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No items found',
                            style: TextStyle(
                                fontSize: 12, color: _kText3)),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding       : const EdgeInsets.fromLTRB(
                            14, 8, 14, 4),
                        itemCount     : filtered.length,
                        itemBuilder   : (_, i) {
                          final row = filtered[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => context
                                  .read<SaleReturnProvider>()
                                  .addFromItem(row),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color       : const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.orange.shade200),
                                ),
                                child: Row(children: [
                                  Icon(Icons.add_circle_outline,
                                      size : 13,
                                      color: Colors.orange.shade700),
                                  const SizedBox(width: 5),
                                  Text('${row['name']}',
                                      style: TextStyle(
                                          fontSize  : 12,
                                          fontWeight: FontWeight.w600,
                                          color     : Colors.orange
                                              .shade800)),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          const Divider(height: 1, color: _kBorder),

          // ── Return lines list ─────────────────────────────────────────
          Expanded(
            child: sr.lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width : 64,
                          height: 64,
                          decoration: const BoxDecoration(
                              color: Color(0xFFFFF7ED),
                              shape: BoxShape.circle),
                          child: Icon(
                              Icons.assignment_return_outlined,
                              size : 30,
                              color: Colors.orange.shade400),
                        ),
                        const SizedBox(height: 12),
                        const Text('No items added yet',
                            style: TextStyle(
                                fontSize  : 13,
                                fontWeight: FontWeight.w600,
                                color     : _kText2)),
                        const SizedBox(height: 4),
                        const Text('Tap an item above to add it',
                            style: TextStyle(
                                fontSize: 11, color: _kText3)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding   : const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    itemCount : sr.lines.length,
                    itemBuilder: (_, index) {
                      final line = sr.lines[index];
                      final step = line.unit.toLowerCase() == 'kg'
                          ? 0.25
                          : 1.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color        : _kCard,
                          borderRadius : BorderRadius.circular(10),
                          border       : Border.all(color: _kBorder),
                          boxShadow: [
                            BoxShadow(
                                color     : Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset    : const Offset(0, 2))
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Row(children: [
                            // Item avatar
                            Container(
                              width : 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color        : const Color(0xFFFFF7ED),
                                borderRadius : BorderRadius.circular(9),
                              ),
                              child: Icon(
                                  Icons.assignment_return_outlined,
                                  size : 18,
                                  color: Colors.orange.shade600),
                            ),
                            const SizedBox(width: 10),

                            // Name + price
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(line.itemName,
                                      style: const TextStyle(
                                          fontSize  : 13,
                                          fontWeight: FontWeight.w700,
                                          color     : _kText1),
                                      maxLines : 1,
                                      overflow : TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${line.qty.toStringAsFixed(2)} ${line.unit} × '
                                    '${AppUtils.formatCurrency(line.price, symbol: sym)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: _kText2),
                                  ),
                                ],
                              ),
                            ),

                            // Qty controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _QtyBtn(
                                  icon : Icons.remove_rounded,
                                  color: const Color(0xFFFDE8E8),
                                  iconColor: _kRed,
                                  onTap: () => context
                                      .read<SaleReturnProvider>()
                                      .setQty(index, line.qty - step),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    line.qty.toStringAsFixed(
                                        line.unit.toLowerCase() == 'kg'
                                            ? 2
                                            : 0),
                                    style: const TextStyle(
                                        fontSize  : 13,
                                        fontWeight: FontWeight.w800,
                                        color     : _kText1),
                                  ),
                                ),
                                _QtyBtn(
                                  icon : Icons.add_rounded,
                                  color: const Color(0xFFECFDF5),
                                  iconColor: const Color(0xFF059669),
                                  onTap: () => context
                                      .read<SaleReturnProvider>()
                                      .setQty(index, line.qty + step),
                                ),
                                const SizedBox(width: 6),
                                _QtyBtn(
                                  icon     : Icons.delete_outline_rounded,
                                  color    : _kBg,
                                  iconColor: _kText3,
                                  onTap    : () => context
                                      .read<SaleReturnProvider>()
                                      .removeAt(index),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),

          // ── Footer ────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color : _kCard,
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Credit total row
                  Row(children: [
                    Container(
                      width : 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color        : const Color(0xFFFFF7ED),
                        borderRadius : BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.assignment_return_outlined,
                          size: 17, color: Colors.orange.shade600),
                    ),
                    const SizedBox(width: 10),
                    const Text('Credit Total',
                        style: TextStyle(
                            fontSize  : 13,
                            color     : _kText2,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      AppUtils.formatCurrency(
                          sr.subtotal(), symbol: sym),
                      style: const TextStyle(
                          fontSize  : 18,
                          fontWeight: FontWeight.w900,
                          color     : _kText1),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Save button
                  FilledButton.icon(
                    onPressed: sr.lines.isEmpty ? null : _save,
                    style    : FilledButton.styleFrom(
                      backgroundColor: sr.lines.isEmpty
                          ? Colors.grey.shade300
                          : Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape  : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon : const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                    label: const Text('Save Return',
                        style: TextStyle(
                            fontSize  : 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Qty button helper ─────────────────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color, iconColor;
  final VoidCallback onTap;

  const _QtyBtn({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width : 30,
        height: 30,
        decoration: BoxDecoration(
          color        : color,
          borderRadius : BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 15, color: iconColor),
      ),
    );
  }
}