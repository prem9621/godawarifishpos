import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
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

class DayBookScreen extends StatefulWidget {
  const DayBookScreen({super.key});

  @override
  State<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends State<DayBookScreen> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _rows    = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getDayBook(limit: 200);
    if (mounted) {
      setState(() {
        _rows   = rows;
        _loading = false;
      });
    }
  }

  // ── txn config ──────────────────────────────────────────────────────────────
  _TxnCfg _cfg(String kind) {
    switch (kind.toLowerCase()) {
      case 'sale':
      case 'invoice':
        return const _TxnCfg(
          icon    : Icons.receipt_long_rounded,
          color   : Color(0xFF059669),
          bg      : Color(0xFFECFDF5),
          label   : 'Sale',
          sign    : '+',
          amtColor: Color(0xFF059669),
        );
      case 'purchase':
        return const _TxnCfg(
          icon    : Icons.local_shipping_outlined,
          color   : Color(0xFFF59E0B),
          bg      : Color(0xFFFFFBEB),
          label   : 'Purchase',
          sign    : '-',
          amtColor: Color(0xFFD97706),
        );
      case 'return':
      case 'sale_return':
        return const _TxnCfg(
          icon    : Icons.assignment_return_outlined,
          color   : Color(0xFFF97316),
          bg      : Color(0xFFFFF7ED),
          label   : 'Return',
          sign    : '-',
          amtColor: Color(0xFFEA580C),
        );
      case 'expense':
        return const _TxnCfg(
          icon    : Icons.money_off_rounded,
          color   : Color(0xFFEF4444),
          bg      : Color(0xFFFEF2F2),
          label   : 'Expense',
          sign    : '-',
          amtColor: Color(0xFFDC2626),
        );
      case 'payment':
      case 'payment_in':
        return const _TxnCfg(
          icon    : Icons.south_west_rounded,
          color   : Color(0xFF3B82F6),
          bg      : Color(0xFFEFF6FF),
          label   : 'Payment In',
          sign    : '+',
          amtColor: Color(0xFF2563EB),
        );
      case 'payment_out':
        return const _TxnCfg(
          icon    : Icons.north_east_rounded,
          color   : Color(0xFF8B5CF6),
          bg      : Color(0xFFF5F3FF),
          label   : 'Payment Out',
          sign    : '-',
          amtColor: Color(0xFF7C3AED),
        );
      default:
        return _TxnCfg(
          icon    : Icons.swap_horiz_rounded,
          color   : const Color(0xFF6B7280),
          bg      : const Color(0xFFF9FAFB),
          label   : kind,
          sign    : '',
          amtColor: const Color(0xFF374151),
        );
    }
  }

  // ── totals ──────────────────────────────────────────────────────────────────
  Map<String, double> get _totals {
    double inflow = 0, outflow = 0;
    for (final r in _rows) {
      final kind   = (r['kind'] as String? ?? '').toLowerCase();
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final cfg    = _cfg(kind);
      if (cfg.sign == '+') {
        inflow += amount;
      } else if (cfg.sign == '-') {
        outflow += amount;
      }
    }
    return {'inflow': inflow, 'outflow': outflow, 'net': inflow - outflow};
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(sym),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _kRed, strokeWidth: 2.5))
                : RefreshIndicator(
                    color    : _kRed,
                    onRefresh: _load,
                    child    : _rows.isEmpty
                        ? _buildEmpty()
                        : _buildList(sym),
                  ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(String sym) {
    final t   = _totals;
    final net = t['net'] ?? 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavDark, _kNavMid],
          begin : Alignment.topLeft,
          end   : Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // ── Title row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
            child: Row(children: [
              // Back button if pushed onto nav stack
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
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: const Icon(Icons.menu_book_outlined,
                      color: Colors.white, size: 17),
                ),
              const SizedBox(width: 10),
              const Text('Day Book',
                  style: TextStyle(
                      fontSize  : 16,
                      fontWeight: FontWeight.w800,
                      color     : Colors.white)),
              const Spacer(),
              // Date label
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color        : Colors.white.withValues(alpha: 0.12),
                  borderRadius : BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2), width: 1),
                ),
                child: Text(
                  DateFormat('d MMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                      color     : Colors.white,
                      fontSize  : 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh btn
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _load();
                },
                child: Container(
                  width : 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color        : Colors.white.withValues(alpha: 0.15),
                    borderRadius : BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 17),
                ),
              ),
              const SizedBox(width: 4),
            ]),
          ),

          // ── Summary stat boxes ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              _StatBox(
                label: 'Cash In',
                value: '$sym${_fmtK(t['inflow'] ?? 0)}',
                icon : Icons.south_west_rounded,
                color: Colors.greenAccent.shade200,
              ),
              const SizedBox(width: 8),
              _StatBox(
                label: 'Cash Out',
                value: '$sym${_fmtK(t['outflow'] ?? 0)}',
                icon : Icons.north_east_rounded,
                color: Colors.redAccent.shade200,
              ),
              const SizedBox(width: 8),
              _StatBox(
                label: net >= 0 ? 'Net Profit' : 'Net Loss',
                value: '$sym${_fmtK(net.abs())}',
                icon : net >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: net >= 0
                    ? Colors.greenAccent.shade400
                    : Colors.orangeAccent.shade200,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── EMPTY STATE ─────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return ListView(
      physics : const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(children: [
            Container(
              width : 68,
              height: 68,
              decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E8), shape: BoxShape.circle),
              child: const Icon(Icons.menu_book_outlined,
                  size: 32, color: _kRed),
            ),
            const SizedBox(height: 14),
            const Text('No transactions yet',
                style: TextStyle(
                    fontSize  : 14,
                    fontWeight: FontWeight.w700,
                    color     : _kText1)),
            const SizedBox(height: 5),
            const Text('Pull down to refresh',
                style: TextStyle(fontSize: 12, color: _kText3)),
          ]),
        ),
      ],
    );
  }

  // ── LIST ────────────────────────────────────────────────────────────────────
  Widget _buildList(String sym) {
    // Group rows by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final r in _rows) {
      final tsRaw = r['ts'] as String? ?? r['date'] as String? ?? '';
      String dateKey = 'Today';
      try {
        final dt = DateTime.parse(tsRaw);
        dateKey  = DateFormat('EEE, d MMM yyyy').format(dt);
      } catch (_) {}
      grouped.putIfAbsent(dateKey, () => []).add(r);
    }

    final sections = grouped.entries.toList();

    return ListView.builder(
      physics    : const AlwaysScrollableScrollPhysics(),
      padding    : const EdgeInsets.fromLTRB(14, 12, 14, 40),
      itemCount  : sections.length,
      itemBuilder: (_, si) {
        final section = sections[si];
        final dateLabel = section.key;
        final items     = section.value;

        // Day total
        double dayIn = 0, dayOut = 0;
        for (final r in items) {
          final cfg    = _cfg((r['kind'] as String? ?? '').toLowerCase());
          final amount = (r['amount'] as num?)?.toDouble() ?? 0;
          if (cfg.sign == '+') dayIn  += amount;
          if (cfg.sign == '-') dayOut += amount;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date header ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(children: [
                Container(
                  width : 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color        : _kRed,
                    borderRadius : BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(dateLabel,
                    style: const TextStyle(
                        fontSize  : 12,
                        fontWeight: FontWeight.w800,
                        color     : _kText1)),
                const Spacer(),
                // Day inflow/outflow summary
                Text('+$sym${_fmtK(dayIn)}',
                    style: const TextStyle(
                        fontSize  : 11,
                        fontWeight: FontWeight.w700,
                        color     : Color(0xFF059669))),
                const SizedBox(width: 8),
                Text('-$sym${_fmtK(dayOut)}',
                    style: const TextStyle(
                        fontSize  : 11,
                        fontWeight: FontWeight.w700,
                        color     : Color(0xFFDC2626))),
              ]),
            ),

            // ── Transactions card ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color        : _kCard,
                borderRadius : BorderRadius.circular(12),
                border       : Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color     : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset    : const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final idx  = entry.key;
                  final r    = entry.value;
                  final kind = (r['kind'] as String? ?? '').toLowerCase();
                  final cfg  = _cfg(kind);

                  final title    = r['title']    as String? ?? '';
                  final subtitle = r['subtitle'] as String? ?? '';
                  final tsRaw    = r['ts']       as String? ??
                      r['date']                  as String? ?? '';
                  String timeStr = '';
                  try {
                    final dt = DateTime.parse(tsRaw);
                    timeStr  = DateFormat('h:mm a').format(dt);
                  } catch (_) {}

                  final amount =
                      (r['amount'] as num?)?.toDouble() ?? 0;

                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(children: [
                        // Icon circle
                        Container(
                          width : 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color        : cfg.bg,
                            borderRadius : BorderRadius.circular(10),
                          ),
                          child: Icon(cfg.icon,
                              color: cfg.color, size: 17),
                        ),
                        const SizedBox(width: 10),

                        // Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontSize  : 13,
                                      fontWeight: FontWeight.w600,
                                      color     : _kText1),
                                  maxLines : 1,
                                  overflow : TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(children: [
                                // Type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color        : cfg.bg,
                                    borderRadius : BorderRadius.circular(4),
                                  ),
                                  child: Text(cfg.label,
                                      style: TextStyle(
                                          fontSize  : 9,
                                          fontWeight: FontWeight.w700,
                                          color     : cfg.color)),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(subtitle,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color   : _kText3),
                                        maxLines : 1,
                                        overflow : TextOverflow
                                            .ellipsis),
                                  ),
                                ],
                                if (timeStr.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(timeStr,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color   : _kText3)),
                                ],
                              ]),
                            ],
                          ),
                        ),

                        // Amount
                        Text(
                          '${cfg.sign}$sym${_fmtK(amount)}',
                          style: TextStyle(
                            fontSize  : 13,
                            fontWeight: FontWeight.w800,
                            color     : cfg.amtColor,
                          ),
                        ),
                      ]),
                    ),
                    if (idx < items.length - 1)
                      const Divider(
                          height : 1,
                          indent : 60,
                          color  : Color(0xFFF3F4F6)),
                  ]);
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),
          ],
        );
      },
    );
  }

  String _fmtK(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Stat box inside header ────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color        : Colors.white.withValues(alpha: 0.12),
          borderRadius : BorderRadius.circular(8),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: const TextStyle(
                      color     : Colors.white60,
                      fontSize  : 8,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      color     : Colors.white,
                      fontSize  : 11,
                      fontWeight: FontWeight.w800),
                  maxLines : 1,
                  overflow : TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Txn config data class ─────────────────────────────────────────────────────
class _TxnCfg {
  final IconData icon;
  final Color color, bg, amtColor;
  final String label, sign;
  const _TxnCfg({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.sign,
    required this.amtColor,
  });
}