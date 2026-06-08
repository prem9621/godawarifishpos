import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_utils.dart';
import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';

/// Cash / shop expenses (Reports → Expenses tab).
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final list = await _db.getExpenses(from: from, to: now);
    if (mounted) {
      setState(() {
        _rows = list;
        _loading = false;
      });
    }
  }

  Future<void> _addExpense() async {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'Shop';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                TextField(
                  controller: amtCtrl,
                  decoration: const InputDecoration(labelText: 'Amount *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'Shop', child: Text('Shop')),
                    DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                    DropdownMenuItem(value: 'Wages', child: Text('Wages')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final title = titleCtrl.text.trim();
    final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
    if (title.isEmpty || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter title and a valid amount')),
      );
      return;
    }
    await _db.insertExpense({
      'title': title,
      'amount': amt,
      'category': category,
      'notes': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;

    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Center(child: Text('No expenses this month', style: TextStyle(color: Colors.grey.shade600)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        itemBuilder: (context, i) {
                          final r = _rows[i];
                          return Card(
                            child: ListTile(
                              title: Text(r['title'] as String? ?? ''),
                              subtitle: Text(
                                '${r['category'] ?? ''} · ${r['created_at'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                AppUtils.formatCurrency((r['amount'] as num?)?.toDouble() ?? 0, symbol: sym),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.tonalIcon(
            onPressed: _addExpense,
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        ),
      ],
    );
  }
}
