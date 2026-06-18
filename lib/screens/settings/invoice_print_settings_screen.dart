import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kNavDark = Color(0xFF0D1B2A);
const _kAccent = Color(0xFF1565C0);
const _kAccentLight = Color(0xFFE8F0FE);
const _kSurface = Color(0xFFF5F7FA);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE2E8F4);
const _kTextPrimary = Color(0xFF1A1F2E);
const _kTextSecondary = Color(0xFF6B7280);

class InvoicePrintSettingsScreen extends StatefulWidget {
  const InvoicePrintSettingsScreen({super.key});

  @override
  State<InvoicePrintSettingsScreen> createState() =>
      _InvoicePrintSettingsScreenState();
}

class _InvoicePrintSettingsScreenState
    extends State<InvoicePrintSettingsScreen> {
  final List<String> _themes = [
    'Theme 1', 'Theme 2', 'Theme 3',
    'Theme 4', 'Theme 5', 'Theme 6',
  ];
  final List<String> _textSizes = ['Small', 'Medium', 'Large'];

  int _receiptTheme = 4;
  int _textSizeIndex = 1;

  // Company Info / Header
  bool _printShopName = true;
  bool _printLogo = true;
  bool _printShopAddress = true;
  bool _printShopEmail = true;
  bool _printShopPhone = true;
  bool _printGstin = true;
  bool _printBillOfSupply = false;

  // Item Table
  bool _printSNo = true;
  bool _printHsn = true;
  bool _printUnit = true;
  bool _printMrp = true;
  bool _printDescription = true;

  // Totals & Taxes
  bool _printTotalQuantity = true;
  bool _printAmountWithDecimal = true;
  bool _printReceivedAmount = true;
  bool _printBalanceAmount = true;

  // Footer & Signature
  bool _printSignature = true;
  bool _showFooterMessage = true;

  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final s = context.read<SettingsProvider>();
    _receiptTheme = s.receiptTheme.clamp(1, _themes.length);
    _textSizeIndex = _fontSizeToIndex(s.receiptFontSize);
    _printShopName = s.printShopName;
    _printLogo = s.printLogo;
    _printShopAddress = s.printShopAddress;
    _printShopEmail = s.printShopEmail;
    _printShopPhone = s.printShopPhone;
    _printGstin = s.printGstin;
    _printBillOfSupply = s.printBillOfSupply;
    _printSNo = s.printSNo;
    _printHsn = s.printHsn;
    _printUnit = s.printUnit;
    _printMrp = s.printMrp;
    _printDescription = s.printDescription;
    _printTotalQuantity = s.printTotalQuantity;
    _printAmountWithDecimal = s.printAmountWithDecimal;
    _printReceivedAmount = s.printReceivedAmount;
    _printBalanceAmount = s.printBalanceAmount;
    _printSignature = s.printSignature;
    _showFooterMessage = s.showFooterMessage;
    _loaded = true;
  }

  int _fontSizeToIndex(double v) {
    if (v <= 0.9) return 0;
    if (v >= 1.2) return 2;
    return 1;
  }

  double _indexToFontSize(int i) {
    if (i == 0) return 0.85;
    if (i == 2) return 1.35;
    return 1.0;
  }

  Future<void> _updateTheme(int theme) async {
    setState(() => _receiptTheme = theme);
    await context.read<SettingsProvider>().setReceiptTheme(theme);
  }

  Future<void> _updateTextSize(int idx) async {
    setState(() => _textSizeIndex = idx);
    await context.read<SettingsProvider>().setReceiptFontSize(_indexToFontSize(idx));
  }

  Future<void> _updateCompanyInfo() async {
    final s = context.read<SettingsProvider>();
    await s.updateInvoicePrintSettings(
      printShopName: _printShopName,
      printShopAddress: _printShopAddress,
      printShopEmail: _printShopEmail,
      printShopPhone: _printShopPhone,
      printGstin: _printGstin,
      printBillOfSupply: _printBillOfSupply,
    );
    await s.setPrintLogo(_printLogo);
  }

  Future<void> _updateItemTable() async {
    await context.read<SettingsProvider>().updateInvoicePrintSettings(
      printSNo: _printSNo,
      printHsn: _printHsn,
      printUnit: _printUnit,
      printMrp: _printMrp,
      printDescription: _printDescription,
    );
  }

  Future<void> _updateTotals() async {
    await context.read<SettingsProvider>().updateInvoicePrintSettings(
      printTotalQuantity: _printTotalQuantity,
      printAmountWithDecimal: _printAmountWithDecimal,
      printReceivedAmount: _printReceivedAmount,
      printBalanceAmount: _printBalanceAmount,
    );
  }

  Future<void> _updateFooter() async {
    await context.read<SettingsProvider>().updateInvoicePrintSettings(
      printSignature: _printSignature,
      showFooterMessage: _showFooterMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kNavDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Invoice Print',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── THEME ────────────────────────────────────────────────────────
          _sectionLabel('Layout & Theme', Icons.palette_outlined),
          _card([
            _dropdownRow(
              label: 'Receipt theme',
              icon: Icons.style_outlined,
              value: _themes[_receiptTheme - 1],
              items: _themes,
              itemLabel: (v) => v,
              onChanged: (val) => _updateTheme(_themes.indexOf(val) + 1),
            ),
            _dropdownRow(
              label: 'Text size',
              icon: Icons.text_fields_outlined,
              value: _textSizes[_textSizeIndex],
              items: _textSizes,
              itemLabel: (v) => v,
              onChanged: (val) => _updateTextSize(_textSizes.indexOf(val)),
            ),
          ]),
          const SizedBox(height: 20),

          // ── COMPANY INFO / HEADER ────────────────────────────────────────
          _sectionLabel('Company Info / Header', Icons.business_outlined),
          _card([
            _switchRow(
              label: 'Company logo',
              subtitle: 'Print logo image at top of receipt',
              icon: Icons.image_outlined,
              value: _printLogo,
              onChanged: (v) { setState(() => _printLogo = v); _updateCompanyInfo(); },
            ),
            _switchRow(
              label: 'Company name',
              subtitle: 'Shown as text (skip if logo has name)',
              icon: Icons.store_outlined,
              value: _printShopName,
              onChanged: (v) { setState(() => _printShopName = v); _updateCompanyInfo(); },
            ),
            _switchRow(
              label: 'Address',
              icon: Icons.location_on_outlined,
              value: _printShopAddress,
              onChanged: (v) { setState(() => _printShopAddress = v); _updateCompanyInfo(); },
            ),
            _switchRow(
              label: 'Email',
              icon: Icons.email_outlined,
              value: _printShopEmail,
              onChanged: (v) { setState(() => _printShopEmail = v); _updateCompanyInfo(); },
            ),
            _switchRow(
              label: 'Phone number',
              icon: Icons.call_outlined,
              value: _printShopPhone,
              onChanged: (v) { setState(() => _printShopPhone = v); _updateCompanyInfo(); },
            ),
            _switchRow(
              label: 'GSTIN',
              subtitle: 'Show GST number on sale invoices',
              icon: Icons.receipt_outlined,
              value: _printGstin,
              onChanged: (v) { setState(() => _printGstin = v); _updateCompanyInfo(); },
            ),
            _switchRow(
              label: 'Bill of Supply',
              subtitle: 'For non-taxable invoices',
              icon: Icons.description_outlined,
              value: _printBillOfSupply,
              onChanged: (v) { setState(() => _printBillOfSupply = v); _updateCompanyInfo(); },
            ),
            _navRow('Transaction names', 'Customise label text', () {}),
          ]),
          const SizedBox(height: 20),

          // ── ITEM TABLE ───────────────────────────────────────────────────
          _sectionLabel('Item Table', Icons.table_rows_outlined),
          _card([
            _switchRow(
              label: 'S.No',
              subtitle: 'Serial number column',
              icon: Icons.format_list_numbered_outlined,
              value: _printSNo,
              onChanged: (v) { setState(() => _printSNo = v); _updateItemTable(); },
            ),
            _switchRow(
              label: 'HSN / SAC code',
              icon: Icons.numbers_outlined,
              value: _printHsn,
              onChanged: (v) { setState(() => _printHsn = v); _updateItemTable(); },
            ),
            _switchRow(
              label: 'Unit of measurement',
              subtitle: 'Kg, Piece, etc.',
              icon: Icons.scale_outlined,
              value: _printUnit,
              onChanged: (v) { setState(() => _printUnit = v); _updateItemTable(); },
            ),
            _switchRow(
              label: 'MRP',
              icon: Icons.sell_outlined,
              value: _printMrp,
              onChanged: (v) { setState(() => _printMrp = v); _updateItemTable(); },
            ),
            _switchRow(
              label: 'Item description',
              icon: Icons.notes_outlined,
              value: _printDescription,
              onChanged: (v) { setState(() => _printDescription = v); _updateItemTable(); },
            ),
            _navRow('Additional item details', 'Extra columns & fields', () {}),
          ]),
          const SizedBox(height: 20),

          // ── TOTALS & TAXES ───────────────────────────────────────────────
          _sectionLabel('Totals & Taxes', Icons.calculate_outlined),
          _card([
            _switchRow(
              label: 'Total item quantity',
              icon: Icons.inventory_2_outlined,
              value: _printTotalQuantity,
              onChanged: (v) { setState(() => _printTotalQuantity = v); _updateTotals(); },
            ),
            _switchRow(
              label: 'Decimal amounts',
              subtitle: 'e.g. Rs. 1000.00 vs Rs. 1000',
              icon: Icons.onetwothree,   // FIXED: was Icons.decimal_increase_outlined
              value: _printAmountWithDecimal,
              onChanged: (v) { setState(() => _printAmountWithDecimal = v); _updateTotals(); },
            ),
            _switchRow(
              label: 'Received amount',
              icon: Icons.payments_outlined,
              value: _printReceivedAmount,
              onChanged: (v) { setState(() => _printReceivedAmount = v); _updateTotals(); },
            ),
            _switchRow(
              label: 'Balance amount',
              icon: Icons.account_balance_wallet_outlined,
              value: _printBalanceAmount,
              onChanged: (v) { setState(() => _printBalanceAmount = v); _updateTotals(); },
            ),
          ]),
          const SizedBox(height: 20),

          // ── FOOTER & SIGNATURE ───────────────────────────────────────────
          _sectionLabel('Footer & Signature', Icons.draw_outlined),
          _card([
            _switchRow(
              label: 'Signature lines',
              subtitle: '"Received Sign" and "Auth. Sign" at bottom',
              icon: Icons.draw_outlined,
              value: _printSignature,
              onChanged: (v) { setState(() => _printSignature = v); _updateFooter(); },
            ),
            _switchRow(
              label: 'Footer message',
              subtitle: 'e.g. "Thank You Visit Again"',
              icon: Icons.format_quote_outlined,
              value: _showFooterMessage,
              onChanged: (v) { setState(() => _showFooterMessage = v); _updateFooter(); },
            ),
          ]),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kAccentLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: _kAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Changes here save immediately and apply to new prints.',
                    style: TextStyle(fontSize: 12, color: _kAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── UI COMPONENTS ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kAccentLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: _kAccent),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _kTextPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: children[i],
            ),
            if (i != children.length - 1)
              const Divider(height: 1, color: _kBorder, indent: 14),
          ],
        ],
      ),
    );
  }

  Widget _switchRow({
    required String label,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? _kAccent : _kTextSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: _kAccent,
              activeTrackColor: _kAccentLight,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kAccent, width: 1.5)),
          prefixIcon: Icon(icon, size: 18, color: _kAccent),
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: _kTextSecondary),
          floatingLabelStyle: const TextStyle(fontSize: 13, color: _kAccent),
        ),
        style: const TextStyle(fontSize: 14, color: _kTextPrimary),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }

  Widget _navRow(String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.tune_outlined, size: 18, color: _kTextSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kTextSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}  