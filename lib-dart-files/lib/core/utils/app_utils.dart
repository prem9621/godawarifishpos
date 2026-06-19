import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Stateless utility helpers — no state, no dependencies.
/// Import this anywhere without side-effects.
class AppUtils {
  AppUtils._(); // Prevent instantiation

  // ── Currency ───────────────────────────────────────────────────────────────
  static String formatCurrency(double amount, {String symbol = '₹'}) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return '$symbol${formatter.format(amount)}';
  }

  /// Short form — no decimals for whole numbers (e.g. ₹1,500 vs ₹1,500.50)
  static String formatCurrencySmart(double amount, {String symbol = '₹'}) {
    if (amount == amount.truncateToDouble()) {
      final formatter = NumberFormat('#,##,##0', 'en_IN');
      return '$symbol${formatter.format(amount)}';
    }
    return formatCurrency(amount, symbol: symbol);
  }

  // ── Date / Time ────────────────────────────────────────────────────────────
  static String formatDate(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat('dd/MM/yyyy hh:mm a').format(date);

  static String formatTime(DateTime date) =>
      DateFormat('hh:mm a').format(date);

  static String shortDate(DateTime date) =>
      DateFormat('dd-MM-yyyy').format(date);

  /// e.g. "15 Jan 2025"
  static String longDate(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);

  /// e.g. "Today", "Yesterday", or "12 Jan"
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final diff  = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return DateFormat('EEEE').format(date); // e.g. "Monday"
    return DateFormat('dd MMM').format(date);
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static DateTime addDays(DateTime date, int days) =>
      date.add(Duration(days: days));

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

  // ── Number Helpers ─────────────────────────────────────────────────────────
  static double roundTo2(double value) =>
      double.parse(value.toStringAsFixed(2));

  /// Safe parse — returns 0.0 if null or invalid
  static double safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  // ── Invoice / Number Generation ────────────────────────────────────────────
  static String generateInvoiceNo(String prefix, int number) =>
      '$prefix${number.toString().padLeft(4, '0')}';

  // ── Validation ─────────────────────────────────────────────────────────────
  static String? validateRequired(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) return 'Enter a valid amount';
    return null;
  }

  static String? validatePositiveAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) return 'Amount must be greater than zero';
    return null;
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────
  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static Future<bool> confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Delete',
    bool isDanger = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDanger
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Text Helpers ───────────────────────────────────────────────────────────
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Mask phone: 98765 → ×××65
  static String maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    return '×' * (phone.length - 4) + phone.substring(phone.length - 4);
  }
}