import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_utils.dart';
import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/invoice_detail_sheet.dart';

/// Past bills with open detail + print (Reports → Bills tab).
class BillsListTab extends StatefulWidget {
  const BillsListTab({super.key});

  @override
  State<BillsListTab> createState() => _BillsListTabState();
}

class _BillsListTabState extends State<BillsListTab> {
  final _db = DatabaseHelper.instance;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  DateTime _from = DateTime.now().subtract(const Duration(days: 90));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _db.getInvoices(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        from: _from,
        to: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _rows = list;
          _loading = false;
        });
      }
    } catch (e) {
      // ✅ FIX: a failed query used to leave the spinner running forever.
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _from = picked);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Bill no / party',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'From date',
                onPressed: _pickFromDate,
                icon: const Icon(Icons.date_range_outlined),
              ),
              IconButton.filled(
                tooltip: 'Search',
                onPressed: _load,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'From ${_from.day}/${_from.month}/${_from.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Center(child: Text('No bills found', style: TextStyle(color: Colors.grey.shade600)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        itemBuilder: (context, i) {
                          final r = _rows[i];
                          final id = r['id'] as int?;
                          if (id == null) return const SizedBox.shrink();
                          final no = r['invoice_no'] as String? ?? '';
                          final name = r['customer_name'] as String? ?? '';
                          final total = (r['total'] as num?)?.toDouble() ?? 0;
                          final status = r['status'] as String? ?? '';
                          final created = r['created_at'] as String? ?? '';
                          return Card(
                            child: ListTile(
                              title: Text(no),
                              subtitle: Text('$name · $created'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppUtils.formatCurrency(total, symbol: sym),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    status,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                              onTap: () => showInvoiceDetailSheet(context, id),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}