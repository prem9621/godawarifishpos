import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';
import 'delivery_boys_screen.dart';
import 'invoice_print_settings_screen.dart';
import 'store_management_screen.DART';
import 'user_management_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kNavDark = Color(0xFF0D1B2A);
const _kAccent = Color(0xFF1565C0);
const _kAccentLight = Color(0xFFE8F0FE);
const _kSurface = Color(0xFFF5F7FA);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE2E8F4);
const _kTextPrimary = Color(0xFF1A1F2E);
const _kTextSecondary = Color(0xFF6B7280);
const _kGreen = Color(0xFF16A34A);
const _kRed = Color(0xFFDC2626);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _upiIdCtrl = TextEditingController();
  final _footerMessageCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  String _currencySymbol = AppConstants.defaultCurrency;
  int _paperWidth = AppConstants.defaultThermalMm;
  double _receiptFontSize = 1.0;
  bool _printLogo = true;
  bool _showFooterMessage = true;
  bool _showQrCode = false;
  bool _autoCutPaper = false;
  bool _printShopName = true;
  bool _printShopAddress = true;
  bool _printShopPhone = true;
  bool _printSignature = true;
  bool _printTotalQuantity = true;
  bool _printAmountWithDecimal = true;
  bool _printReceivedAmount = true;
  bool _printBalanceAmount = true;

  String _selectedPrinterAddress = '';
  String _selectedPrinterLabel = 'Not selected';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final s = context.read<SettingsProvider>();
    _shopNameCtrl.text = s.shopName;
    _shopPhoneCtrl.text = s.shopPhone;
    _shopAddressCtrl.text = s.shopAddress;
    _upiIdCtrl.text = s.upiId;
    _footerMessageCtrl.text = s.footerMessage;
    _currencySymbol = s.currencySymbol;
    _paperWidth = s.thermalPaperWidthMm;
    _receiptFontSize = s.receiptFontSize;
    _printLogo = s.printLogo;
    _showFooterMessage = s.showFooterMessage;
    _showQrCode = s.showQrCode;
    _autoCutPaper = s.autoCutPaper;
    _printShopName = s.printShopName;
    _printShopAddress = s.printShopAddress;
    _printShopPhone = s.printShopPhone;
    _printSignature = s.printSignature;
    _printTotalQuantity = s.printTotalQuantity;
    _printAmountWithDecimal = s.printAmountWithDecimal;
    _printReceivedAmount = s.printReceivedAmount;
    _printBalanceAmount = s.printBalanceAmount;
    _selectedPrinterAddress = s.bluetoothPrinter;
    _selectedPrinterLabel =
        s.bluetoothPrinter.isEmpty ? 'Not selected' : s.bluetoothPrinter;
    _loaded = true;
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _upiIdCtrl.dispose();
    _footerMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _chooseBluetoothPrinter() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final connect = await Permission.bluetoothConnect.request();
      final scan = await Permission.bluetoothScan.request();
      if (!connect.isGranted || !scan.isGranted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Bluetooth permissions needed to list printers.'),
        ));
        return;
      }
      final bonded = await BlueThermalPrinter.instance.getBondedDevices();
      if (!mounted) return;
      if (bonded.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Pair your thermal printer in phone settings first.'),
        ));
        return;
      }
      final chosen = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.print_outlined, color: _kAccent),
              SizedBox(width: 10),
              Text('Choose Printer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final device in bonded)
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kAccentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.print_outlined,
                          color: _kAccent, size: 20),
                    ),
                    title: Text(device.name ?? 'Unknown Printer',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(device.address ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: _kTextSecondary)),
                    onTap: () => Navigator.pop(ctx, device),
                  ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || chosen?.address == null) return;
      setState(() {
        _selectedPrinterAddress = chosen!.address!;
        _selectedPrinterLabel =
            chosen.name?.trim().isNotEmpty == true
                ? '${chosen.name} (${chosen.address})'
                : chosen.address!;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Bluetooth error: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final s = context.read<SettingsProvider>();
    try {
      await s.updateShopInfo(
        name: _shopNameCtrl.text.trim(),
        phone: _shopPhoneCtrl.text.trim(),
        address: _shopAddressCtrl.text.trim(),
      );
      await s.setUpiId(_upiIdCtrl.text.trim());
      await s.updateInvoiceSettings(currency: _currencySymbol);
      await s.setBluetoothPrinter(_selectedPrinterAddress.trim());
      await s.setThermalPaperWidthMm(_paperWidth);
      await s.setReceiptFontSize(_receiptFontSize);
      await s.setPrintLogo(_printLogo);
      await s.setShowQrCode(_showQrCode);
      await s.setShowFooterMessage(_showFooterMessage);
      await s.setFooterMessage(_footerMessageCtrl.text.trim());
      await s.updateInvoicePrintSettings(
        autoCutPaper: _autoCutPaper,
        printShopName: _printShopName,
        printShopAddress: _printShopAddress,
        printShopPhone: _printShopPhone,
        printSignature: _printSignature,
        printTotalQuantity: _printTotalQuantity,
        printAmountWithDecimal: _printAmountWithDecimal,
        printReceivedAmount: _printReceivedAmount,
        printBalanceAmount: _printBalanceAmount,
        showFooterMessage: _showFooterMessage,   // FIXED: now a valid param
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Settings saved successfully'),
          ],
        ),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save: $e'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kNavDark,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: canPop,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // ── BUSINESS ────────────────────────────────────────────────────
          _sectionLabel('Business', Icons.storefront_rounded),
          _card([
            _inputField(_shopNameCtrl, 'Shop name', Icons.store_outlined),
            _inputField(_shopPhoneCtrl, 'Phone', Icons.call_outlined,
                keyboardType: TextInputType.phone),
            _inputField(_shopAddressCtrl, 'Address', Icons.location_on_outlined),
          ]),
          const SizedBox(height: 20),

          // ── RECEIPT & PRINTER ────────────────────────────────────────────
          _sectionLabel('Receipt & Printer', Icons.receipt_long_rounded),
          _card([
            _printerTile(),
            _inputField(_upiIdCtrl, 'UPI ID', Icons.qr_code_2_outlined),
            _inputField(_footerMessageCtrl, 'Footer message', Icons.format_quote_outlined),
            _dropdownRow<int>(
              label: 'Paper width',
              icon: Icons.straighten_outlined,
              value: _paperWidth,
              items: const [58, 76, 80],
              itemLabel: (v) {
                if (v == 58) return '58mm  (2 inch)';
                if (v == 76) return '76mm  (3 inch)';
                return '80mm  (3 inch)';
              },
              onChanged: (v) => setState(() => _paperWidth = v),
            ),
            _dropdownRow<String>(
              label: 'Currency',
              icon: Icons.currency_rupee_outlined,
              value: _currencySymbol,
              items: const ['Rs.', '₹', 'INR '],
              itemLabel: (v) => v,
              onChanged: (v) => setState(() => _currencySymbol = v),
            ),
            _fontSizeSlider(),
          ]),
          const SizedBox(height: 20),

          // ── WHAT TO PRINT ────────────────────────────────────────────────
          _sectionLabel('What to Print', Icons.tune_rounded),
          _card([
            _switchRow(
              label: 'Print logo',
              subtitle: 'Show shop logo at top of receipt',
              icon: Icons.image_outlined,
              value: _printLogo,
              onChanged: (v) => setState(() => _printLogo = v),
            ),
            _switchRow(
              label: 'Shop name',
              subtitle: 'Print shop name as text (disable if using logo)',
              icon: Icons.store_outlined,
              value: _printShopName,
              onChanged: (v) => setState(() => _printShopName = v),
            ),
            _switchRow(
              label: 'Shop address',
              icon: Icons.location_on_outlined,
              value: _printShopAddress,
              onChanged: (v) => setState(() => _printShopAddress = v),
            ),
            _switchRow(
              label: 'Shop phone',
              icon: Icons.call_outlined,
              value: _printShopPhone,
              onChanged: (v) => setState(() => _printShopPhone = v),
            ),
            _switchRow(
              label: 'Total quantity',
              icon: Icons.numbers_outlined,
              value: _printTotalQuantity,
              onChanged: (v) => setState(() => _printTotalQuantity = v),
            ),
            _switchRow(
              label: 'Amounts with decimals',
              subtitle: 'e.g. Rs. 100.00 instead of Rs. 100',
              icon: Icons.onetwothree,   // FIXED: was Icons.decimal_increase_outlined
              value: _printAmountWithDecimal,
              onChanged: (v) => setState(() => _printAmountWithDecimal = v),
            ),
            _switchRow(
              label: 'Received amount',
              icon: Icons.payments_outlined,
              value: _printReceivedAmount,
              onChanged: (v) => setState(() => _printReceivedAmount = v),
            ),
            _switchRow(
              label: 'Balance amount',
              icon: Icons.account_balance_wallet_outlined,
              value: _printBalanceAmount,
              onChanged: (v) => setState(() => _printBalanceAmount = v),
            ),
            _switchRow(
              label: 'Signature lines',
              subtitle: 'Received Sign & Auth. Sign at bottom',
              icon: Icons.draw_outlined,
              value: _printSignature,
              onChanged: (v) => setState(() => _printSignature = v),
            ),
            _switchRow(
              label: 'Footer message',
              subtitle: _footerMessageCtrl.text.trim().isEmpty
                  ? 'Set footer message above'
                  : _footerMessageCtrl.text.trim(),
              icon: Icons.format_quote_outlined,
              value: _showFooterMessage,
              onChanged: (v) => setState(() => _showFooterMessage = v),
            ),
            _switchRow(
              label: 'Payment QR code',
              subtitle: 'UPI QR at bottom of receipt',
              icon: Icons.qr_code_outlined,
              value: _showQrCode,
              onChanged: (v) => setState(() => _showQrCode = v),
            ),
            _switchRow(
              label: 'Auto-cut paper',
              subtitle: 'Printer cuts after each receipt',
              icon: Icons.content_cut_outlined,
              value: _autoCutPaper,
              onChanged: (v) => setState(() => _autoCutPaper = v),
            ),
          ]),
          const SizedBox(height: 20),

          // ── MANAGEMENT ───────────────────────────────────────────────────
          _sectionLabel('Management', Icons.admin_panel_settings_outlined),
          _card([
            _navRow('Stores', Icons.store_mall_directory_outlined,
                'Manage store profiles', const StoreManagementScreen()),
            if (settings.isAdmin)
              _navRow('Users', Icons.people_alt_outlined,
                  'Add or edit staff accounts', const UserManagementScreen()),
            _navRow('Delivery Boys', Icons.delivery_dining_outlined,
                'Manage delivery staff', const DeliveryBoysScreen()),
            _navRow('Invoice Print', Icons.receipt_long_outlined,
                'Advanced print layout settings',
                const InvoicePrintSettingsScreen()),
          ]),
          const SizedBox(height: 28),

          // ── SAVE BUTTON ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(
                _saving ? 'Saving…' : 'Save Settings',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
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
            color: Colors.black.withOpacity(0.04),
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

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: _kTextPrimary),
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
      ),
    );
  }

  Widget _printerTile() {
    final isSelected = _selectedPrinterAddress.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? _kAccentLight : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSelected ? Icons.print_rounded : Icons.print_disabled_outlined,
              size: 20,
              color: isSelected ? _kAccent : _kTextSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bluetooth printer',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  _selectedPrinterLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? _kAccent : _kTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _chooseBluetoothPrinter,
            style: TextButton.styleFrom(
              foregroundColor: _kAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              isSelected ? 'Change' : 'Choose',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _fontSizeSlider() {
    final labels = ['Small', 'Medium', 'Large'];
    final thumbIdx = _receiptFontSize <= 0.9
        ? 0
        : _receiptFontSize >= 1.2
            ? 2
            : 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields_outlined, size: 18, color: _kAccent),
              const SizedBox(width: 10),
              const Text('Font size',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAccentLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  labels[thumbIdx],
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kAccent),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kAccent,
              inactiveTrackColor: _kBorder,
              thumbColor: _kAccent,
              overlayColor: _kAccent.withOpacity(0.12),
              trackHeight: 3,
            ),
            child: Slider(
              min: 0.85,
              max: 1.35,
              divisions: 10,
              value: _receiptFontSize,
              onChanged: (v) => setState(() => _receiptFontSize = v),
            ),
          ),
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

  Widget _navRow(String title, IconData icon, String subtitle, Widget screen) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
          context, MaterialPageRoute<void>(builder: (_) => screen)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kAccentLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: _kAccent),
            ),
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
            const Icon(Icons.chevron_right_rounded,
                color: _kTextSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}