import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_utils.dart';
import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';

/// Sales summary + top items (Reports → Summary tab).
class ReportsSummaryTab extends StatefulWidget {
  const ReportsSummaryTab({super.key});

  @override
  State<ReportsSummaryTab> createState() => _ReportsSummaryTabState();
}

class _ReportsSummaryTabState extends State<ReportsSummaryTab> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _topItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 7));
    final monthStart = DateTime(to.year, to.month, 1);
    final daily = await _db.getSalesReport(from, to);
    final top = await _db.getTopItems(monthStart, to);
    if (mounted) {
      setState(() {
        _daily = daily;
        _topItems = top;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Last 7 days',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_daily.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No bills in this range', style: TextStyle(color: Colors.grey.shade600)),
              ),
            )
          else
            ..._daily.map((row) {
              final dateStr = row['date'] as String? ?? '';
              final total = (row['total'] as num?)?.toDouble() ?? 0;
              final count = (row['count'] as num?)?.toInt() ?? 0;
              return Card(
                child: ListTile(
                  title: Text(dateStr),
                  subtitle: Text('$count bills'),
                  trailing: Text(
                    AppUtils.formatCurrency(total, symbol: sym),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          Text(
            'Top items (this month)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_topItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No item sales yet', style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            ..._topItems.map((row) {
              final name = row['item_name'] as String? ?? '';
              final qty = (row['total_qty'] as num?)?.toDouble() ?? 0;
              final amt = (row['total_amount'] as num?)?.toDouble() ?? 0;
              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text('Qty: ${qty.toStringAsFixed(2)}'),
                  trailing: Text(
                    AppUtils.formatCurrency(amt, symbol: sym),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
