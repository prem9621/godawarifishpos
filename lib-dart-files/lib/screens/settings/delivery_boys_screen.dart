import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../core/theme/app_theme.dart';

class DeliveryBoysScreen extends StatefulWidget {
  const DeliveryBoysScreen({super.key});

  @override
  State<DeliveryBoysScreen> createState() => _DeliveryBoysScreenState();
}

class _DeliveryBoysScreenState extends State<DeliveryBoysScreen> {
  List<Map<String, dynamic>> _boys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await DatabaseHelper.instance.getDeliveryBoys();
    if (mounted) {
      setState(() {
      _boys = result;
      _loading = false;
    });
    }
  }

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Delivery Boy',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && name.isNotEmpty) {
      try {
        await DatabaseHelper.instance.insertDeliveryBoy(name);
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete?'),
        content: Text('Remove "$name" from delivery boys?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.instance.deleteDeliveryBoy(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Delivery Boys',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add',
            onPressed: _add,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _boys.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delivery_dining_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No delivery boys yet',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add First'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _boys.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = _boys[i];
                    final name = b['name'] as String;
                    final id = b['id'] as int;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.withValues(alpha: 0.12),
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.teal),
                          ),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 20),
                          onPressed: () => _delete(id, name),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Delivery Boy',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}