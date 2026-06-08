import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_utils.dart';
import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';

/// Rough month view: sales − purchases − expenses (Vyapar-style snapshot).
class ProfitReportTab extends StatefulWidget {
  const ProfitReportTab({super.key});

  @override
  State<ProfitReportTab> createState() => _ProfitReportTabState();
}

class _ProfitReportTabState extends State<ProfitReportTab> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  double _sales = 0;
  double _purchases = 0;
  double _expenses = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dash = await _db.getDashboardStats();
    final p = await _db.getMonthPurchaseTotal();
    final e = await _db.getMonthExpenseTotal();
    if (mounted) {
      setState(() {
        _sales = (dash['month_total'] as num?)?.toDouble() ?? 0;
        _purchases = p;
        _expenses = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;
    final net = _sales - _purchases - _expenses;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('This month (estimate)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _row(context, 'Total sales (bills)', _sales, sym),
          _row(context, 'Total purchases', _purchases, sym, negative: true),
          _row(context, 'Total expenses', _expenses, sym, negative: true),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Approx. gross margin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: Text(
              AppUtils.formatCurrency(net, symbol: sym),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: net >= 0 ? Colors.green.shade800 : Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Uses bill totals minus recorded purchases and expenses. Taxes and opening stock are not included.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double amount, String sym, {bool negative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(
            negative ? '- ${AppUtils.formatCurrency(amount, symbol: sym)}' : AppUtils.formatCurrency(amount, symbol: sym),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
