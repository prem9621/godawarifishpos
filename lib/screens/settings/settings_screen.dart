import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../login/login_screen.dart';
import 'store_management_screen.dart';
import 'user_management_screen.dart';
import 'delivery_boys_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shopNameCtrl      = TextEditingController();
  final _shopPhoneCtrl     = TextEditingController();
  final _shopAddressCtrl   = TextEditingController();
  final _shopEmailCtrl     = TextEditingController();
  final _upiIdCtrl         = TextEditingController();
  final _invoicePrefixCtrl = TextEditingController();
  final _dueDaysCtrl       = TextEditingController();
  final _footerMessageCtrl = TextEditingController();

  bool   _loaded             = false;
  bool   _savingReceiptSetup = false;
  String _currencySymbol     = AppConstants.defaultCurrency;
  int    _paperWidth         = AppConstants.defaultThermalMm;
  int    _receiptTheme       = 5;
  double _receiptFontSize    = 1.0;
  bool   _printLogo          = true;
  bool   _showFooterMessage  = true;
  bool   _showPaymentQr      = false;
  String _selectedPrinterAddress = '';
  String _selectedPrinterLabel   = '';

  bool _nativeLanguagePrinting = true;
  int  _extraLinesAtPrintEnd   = 0;
  int  _numberOfCopies         = 1;
  bool _autoCutPaper           = false;
  bool _openCashDrawer         = false;
  bool _printShopName          = true;
  bool _printShopAddress       = true;
  bool _printShopEmail         = true;
  bool _printShopPhone         = true;
  bool _printGstin             = true;
  bool _printBillOfSupply      = false;
  bool _printSNo               = true;
  bool _printHsn               = true;
  bool _printUnit              = true;
  bool _printMrp               = true;
  bool _printDescription       = true;
  bool _printTotalQuantity     = true;
  bool _printAmountWithDecimal = true;
  bool _printReceivedAmount    = true;
  bool _printBalanceAmount     = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final s = context.read<SettingsProvider>();
    _shopNameCtrl.text      = s.shopName;
    _shopPhoneCtrl.text     = s.shopPhone;
    _shopAddressCtrl.text   = s.shopAddress;
    _shopEmailCtrl.text     = s.shopEmail;
    _upiIdCtrl.text         = s.upiId;
    _invoicePrefixCtrl.text = s.invoicePrefix;
    _dueDaysCtrl.text       = s.dueDateDays.toString();
    _footerMessageCtrl.text = s.footerMessage;
    _currencySymbol         = s.currencySymbol;
    _paperWidth             = s.thermalPaperWidthMm;
    _receiptTheme           = s.receiptTheme;
    _receiptFontSize        = s.receiptFontSize;
    _printLogo              = s.printLogo;
    _showFooterMessage      = s.showFooterMessage;
    _showPaymentQr          = s.showPaymentQr;
    _selectedPrinterAddress = s.bluetoothPrinter;
    _selectedPrinterLabel   = s.bluetoothPrinter.isEmpty
        ? 'Not selected'
        : s.bluetoothPrinter;

    _nativeLanguagePrinting = s.nativeLanguagePrinting;
    _extraLinesAtPrintEnd   = s.extraLinesAtPrintEnd;
    _numberOfCopies         = s.numberOfCopies;
    _autoCutPaper           = s.autoCutPaper;
    _openCashDrawer         = s.openCashDrawer;
    _printShopName          = s.printShopName;
    _printShopAddress       = s.printShopAddress;
    _printShopEmail         = s.printShopEmail;
    _printShopPhone         = s.printShopPhone;
    _printGstin             = s.printGstin;
    _printBillOfSupply      = s.printBillOfSupply;
    _printSNo               = s.printSNo;
    _printHsn               = s.printHsn;
    _printUnit              = s.printUnit;
    _printMrp               = s.printMrp;
    _printDescription       = s.printDescription;
    _printTotalQuantity     = s.printTotalQuantity;
    _printAmountWithDecimal = s.printAmountWithDecimal;
    _printReceivedAmount    = s.printReceivedAmount;
    _printBalanceAmount     = s.printBalanceAmount;
    _loaded = true;
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopEmailCtrl.dispose();
    _upiIdCtrl.dispose();
    _invoicePrefixCtrl.dispose();
    _dueDaysCtrl.dispose();
    _footerMessageCtrl.dispose();
    super.dispose();
  }

  // ── Bluetooth picker ──────────────────────────────────────────────────────
  Future<void> _chooseBluetoothPrinter() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final c  = await Permission.bluetoothConnect.request();
        final sc = await Permission.bluetoothScan.request();
        if (!c.isGranted || !sc.isGranted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Bluetooth permissions needed to list printers.'),
          ));
          return;
        }
      }

      // ✅ Use print_bluetooth_thermal API
      final isOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isOn) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Bluetooth is off. Please turn on Bluetooth first.'),
        ));
        return;
      }

      final bonded = await PrintBluetoothThermal.pairedBluetooths;

      if (!mounted) return;
      if (bonded.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
            'No paired Bluetooth devices. Pair your thermal printer in phone Settings first.',
          ),
        ));
        return;
      }

      // ✅ Dialog now uses BluetoothInfo instead of BluetoothDevice
      final chosen = await showDialog<BluetoothInfo>(
        context: context,
        builder: (ctx) => SimpleDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Choose Printer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          children: [
            for (final d in bonded)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width : 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color       : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.print_outlined,
                        color: AppTheme.primaryBlue, size: 18),
                  ),
                  title: Text(
                    d.name.trim().isNotEmpty ? d.name : 'Unknown Printer',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(d.macAdress,
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
      );

      // ✅ BluetoothInfo uses .macAdress and .name (no nullability)
      if (chosen != null && mounted) {
        setState(() {
          _selectedPrinterAddress = chosen.macAdress;
          _selectedPrinterLabel   = chosen.name.trim().isNotEmpty
              ? '${chosen.name} (${chosen.macAdress})'
              : chosen.macAdress;
        });
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Bluetooth error: $e')));
    }
  }

  // ── Save receipt setup ────────────────────────────────────────────────────
  Future<void> _saveReceiptSetup() async {
    final s         = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final dueDays   = int.tryParse(_dueDaysCtrl.text.trim());
    if (dueDays == null || dueDays <= 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Enter a valid due days value.')));
      return;
    }
    setState(() => _savingReceiptSetup = true);
    try {
      await s.updateShopInfo(
        name   : _shopNameCtrl.text.trim(),
        phone  : _shopPhoneCtrl.text.trim(),
        address: _shopAddressCtrl.text.trim(),
        email  : _shopEmailCtrl.text.trim(),
      );
      await s.setUpiId(_upiIdCtrl.text.trim());
      await s.updateInvoiceSettings(
        prefix  : _invoicePrefixCtrl.text.trim().toUpperCase(),
        dueDays : dueDays,
        currency: _currencySymbol,
      );
      await s.setBluetoothPrinter(_selectedPrinterAddress.trim());
      await s.setThermalPaperWidthMm(_paperWidth);
      await s.setReceiptTheme(_receiptTheme);
      await s.setReceiptFontSize(_receiptFontSize);
      await s.setPrintLogo(_printLogo);
      await s.setShowPaymentQr(_showPaymentQr);
      await s.setShowFooterMessage(_showFooterMessage);
      await s.setFooterMessage(_footerMessageCtrl.text.trim());
      await s.updateInvoicePrintSettings(
        nativeLanguagePrinting: _nativeLanguagePrinting,
        extraLinesAtPrintEnd  : _extraLinesAtPrintEnd,
        numberOfCopies        : _numberOfCopies,
        autoCutPaper          : _autoCutPaper,
        openCashDrawer        : _openCashDrawer,
        printShopName         : _printShopName,
        printShopAddress      : _printShopAddress,
        printShopEmail        : _printShopEmail,
        printShopPhone        : _printShopPhone,
        printGstin            : _printGstin,
        printBillOfSupply     : _printBillOfSupply,
        printSNo              : _printSNo,
        printHsn              : _printHsn,
        printUnit             : _printUnit,
        printMrp              : _printMrp,
        printDescription      : _printDescription,
        printTotalQuantity    : _printTotalQuantity,
        printAmountWithDecimal: _printAmountWithDecimal,
        printReceivedAmount   : _printReceivedAmount,
        printBalanceAmount    : _printBalanceAmount,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content        : const Text('Receipt settings saved successfully.'),
        backgroundColor: Colors.green.shade700,
        behavior       : SnackBarBehavior.floating,
        shape          : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => _savingReceiptSetup = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<SettingsProvider>().logoutUser();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();

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
        title: const Text('Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ══════════════════════════════════════════════════════════════
          //  ACCOUNT SECTION
          // ══════════════════════════════════════════════════════════════
          const _SectionHeader(
            icon : Icons.account_circle_rounded,
            title: 'Account',
            color: AppTheme.primaryBlue,
          ),
          _SettingsCard(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Container(
                    width : 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color       : AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        s.currentUserName.isNotEmpty
                            ? s.currentUserName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize  : 20,
                          fontWeight: FontWeight.w800,
                          color     : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.currentUserName.isNotEmpty
                              ? s.currentUserName
                              : 'Not logged in',
                          style: const TextStyle(
                              fontSize  : 14,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.isAdmin
                                    ? Colors.orange.shade50
                                    : Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.isAdmin ? '👑 Admin' : '👤 Staff',
                                style: TextStyle(
                                  fontSize  : 11,
                                  fontWeight: FontWeight.w600,
                                  color     : s.isAdmin
                                      ? Colors.orange.shade700
                                      : Colors.blueGrey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.store_outlined,
                                size : 12,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                s.currentStoreName.isNotEmpty
                                    ? s.currentStoreName
                                    : 'Store ${s.currentStoreId}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color   : Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _divider(),
            _NavigationTile(
              icon     : Icons.people_alt_rounded,
              iconColor: const Color(0xFF1565C0),
              label    : 'Manage Users',
              subtitle : 'Add, edit or remove staff & admins',
              onTap    : () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const UserManagementScreen())),
            ),
            _divider(),
            _NavigationTile(
              icon     : Icons.store_mall_directory_rounded,
              iconColor: const Color(0xFF00695C),
              label    : 'Manage Stores',
              subtitle : 'Add, edit or switch between stores',
              onTap    : () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const StoreManagementScreen())),
                      
            ),
            _divider(),
_NavigationTile(
  icon     : Icons.delivery_dining_rounded,
  iconColor: const Color(0xFF00897B),
  label    : 'Manage Delivery Boys',
  subtitle : 'Add or remove delivery staff',
  onTap    : () => Navigator.push(context,
      MaterialPageRoute(
          builder: (_) => const DeliveryBoysScreen())),
),
            _divider(),
            _NavigationTile(
              icon     : Icons.logout_rounded,
              iconColor: const Color(0xFFE53935),
              label    : 'Logout',
              subtitle : 'Switch user or store',
              onTap    : _logout,
              textColor: const Color(0xFFE53935),
            ),
          ]),

          const SizedBox(height: 16),

          // ══════════════════════════════════════════════════════════════
          //  THERMAL PRINTER
          // ══════════════════════════════════════════════════════════════
          const _SectionHeader(
            icon : Icons.print_rounded,
            title: 'Thermal Printer Settings',
            color: AppTheme.primaryBlue,
          ),
          _SettingsCard(children: [
            _PickerTile(
              icon       : Icons.bluetooth_rounded,
              iconColor  : const Color(0xFF1565C0),
              label      : 'Set default thermal printer',
              value      : _selectedPrinterLabel,
              valueColor : _selectedPrinterAddress.isEmpty
                  ? Colors.red.shade400
                  : const Color(0xFF757575),
              actionLabel: _selectedPrinterAddress.isEmpty
                  ? 'Choose Printer'
                  : 'Change Printer',
              onTap      : _chooseBluetoothPrinter,
            ),
            _divider(),
            _SwitchTile(
              label    : 'Native language printing',
              subtitle : 'Print in local language if supported',
              value    : _nativeLanguagePrinting,
              onChanged: (v) =>
                  setState(() => _nativeLanguagePrinting = v),
            ),
            _divider(),
           _InlineDropdown<int>(
  label           : 'Thermal printer page size',
  icon            : Icons.straighten_outlined,
  value           : _paperWidth,
  items           : const [58, 76, 80],
  itemLabelBuilder: (v) {
    if (v == 58) return '2 inch (58mm)';
    if (v == 76) return '3 inch import (76-78mm)';
    return '3 inch (80mm)';
  },
  onChanged: (v) {
    if (v != null) setState(() => _paperWidth = v);
  },
),
            _divider(),
            _CounterTile(
              label    : 'Extra lines at print end',
              value    : _extraLinesAtPrintEnd,
              onChanged: (v) =>
                  setState(() => _extraLinesAtPrintEnd = v),
            ),
            _divider(),
            _CounterTile(
              label    : 'Number of copies',
              value    : _numberOfCopies,
              onChanged: (v) => setState(() => _numberOfCopies = v),
            ),
            _divider(),
            _SwitchTile(
              label    : 'Auto cut paper after printing',
              value    : _autoCutPaper,
              onChanged: (v) => setState(() => _autoCutPaper = v),
            ),
            _divider(),
            _SwitchTile(
              label    : 'Open cash drawer after printing',
              value    : _openCashDrawer,
              onChanged: (v) => setState(() => _openCashDrawer = v),
            ),
          ]),

          const SizedBox(height: 16),

          // ── THEMES ────────────────────────────────────────────────────
          const _SectionHeader(
              icon: Icons.style_rounded,
              title: 'Themes',
              color: Colors.purple),
          _SettingsCard(children: [
            _InlineDropdown<int>(
              label           : 'Change Thermal printer theme',
              icon            : Icons.style_outlined,
              value           : _receiptTheme,
              items           : const [1, 2, 3, 4, 5, 6],
              itemLabelBuilder: (v) => 'Theme $v',
              onChanged: (v) {
                if (v != null) setState(() => _receiptTheme = v);
              },
            ),
          ]),

          const SizedBox(height: 16),

          // ── PRINTER SETTINGS ──────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.settings_rounded,
              title: 'Printer Settings',
              color: Colors.blueGrey),
          _SettingsCard(children: [
            _InlineDropdown<double>(
              label           : 'Print text size',
              icon            : Icons.text_fields_rounded,
              value           : _receiptFontSize,
              items           : const [0.85, 1.0, 1.15, 1.35],
              itemLabelBuilder: (v) {
                if (v <= 0.85) return 'Small';
                if (v <= 1.0)  return 'Medium';
                if (v <= 1.15) return 'Large';
                return 'Extra Large';
              },
              onChanged: (v) {
                if (v != null) setState(() => _receiptFontSize = v);
              },
            ),
          ]),

          const SizedBox(height: 16),

          // ── PRINT COMPANY INFO ────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.business_rounded,
              title: 'Print Company Info/Header',
              color: Colors.indigo),
          _SettingsCard(children: [
            _SwitchTile(
                label    : 'Print Company Name',
                value    : _printShopName,
                onChanged: (v) => setState(() => _printShopName = v)),
            _divider(),
            _SwitchTile(
                label    : 'Company logo',
                value    : _printLogo,
                onChanged: (v) => setState(() => _printLogo = v)),
            _divider(),
            _SwitchTile(
                label    : 'Address',
                value    : _printShopAddress,
                onChanged: (v) => setState(() => _printShopAddress = v)),
            _divider(),
            _SwitchTile(
                label    : 'Email',
                value    : _printShopEmail,
                onChanged: (v) => setState(() => _printShopEmail = v)),
            _divider(),
            _SwitchTile(
                label    : 'Phone number',
                value    : _printShopPhone,
                onChanged: (v) => setState(() => _printShopPhone = v)),
            _divider(),
            _SwitchTile(
                label    : 'GSTIN on Sale',
                value    : _printGstin,
                onChanged: (v) => setState(() => _printGstin = v)),
            _divider(),
            _SwitchTile(
              label    : 'Print Bill of Supply for non tax invoices',
              value    : _printBillOfSupply,
              onChanged: (v) => setState(() => _printBillOfSupply = v),
            ),
          ]),

          const SizedBox(height: 16),

          // ── ITEM TABLE ────────────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.table_chart_rounded,
              title: 'Item Table',
              color: Colors.teal),
          _SettingsCard(children: [
            _SwitchTile(
                label    : 'S.No',
                value    : _printSNo,
                onChanged: (v) => setState(() => _printSNo = v)),
            _divider(),
            _SwitchTile(
                label    : 'HSN/SAC code',
                value    : _printHsn,
                onChanged: (v) => setState(() => _printHsn = v)),
            _divider(),
            _SwitchTile(
                label    : 'Units of Measurement',
                value    : _printUnit,
                onChanged: (v) => setState(() => _printUnit = v)),
            _divider(),
            _SwitchTile(
                label    : 'MRP',
                value    : _printMrp,
                onChanged: (v) => setState(() => _printMrp = v)),
            _divider(),
            _SwitchTile(
                label    : 'Description',
                value    : _printDescription,
                onChanged: (v) => setState(() => _printDescription = v)),
          ]),

          const SizedBox(height: 16),

          // ── TOTALS & TAXES ────────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.summarize_rounded,
              title: 'Totals & Taxes',
              color: Colors.deepOrange),
          _SettingsCard(children: [
            _SwitchTile(
                label    : 'Total Item Quantity',
                value    : _printTotalQuantity,
                onChanged: (v) =>
                    setState(() => _printTotalQuantity = v)),
            _divider(),
            _SwitchTile(
              label    : 'Amount with Decimal (eg 0.00)',
              value    : _printAmountWithDecimal,
              onChanged: (v) =>
                  setState(() => _printAmountWithDecimal = v),
            ),
            _divider(),
            _SwitchTile(
                label    : 'Received amount',
                value    : _printReceivedAmount,
                onChanged: (v) =>
                    setState(() => _printReceivedAmount = v)),
            _divider(),
            _SwitchTile(
                label    : 'Balance amount',
                value    : _printBalanceAmount,
                onChanged: (v) =>
                    setState(() => _printBalanceAmount = v)),
          ]),

          const SizedBox(height: 16),

          // ── QR CODE ───────────────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.qr_code_rounded,
              title: 'QR Code Settings',
              color: Colors.blue),
          _SettingsCard(children: [
            _SwitchTile(
              label   : 'Show Payment QR on Receipt',
              subtitle: 'Turns on QR on both hard and soft copies',
              value   : _showPaymentQr,
              onChanged: (v) => setState(() => _showPaymentQr = v),
            ),
            if (_showPaymentQr) ...[
              _divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _SettingsInput(
                  controller: _upiIdCtrl,
                  label     : 'UPI ID for QR',
                  icon      : Icons.qr_code_2_rounded,
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ── SHOP DETAILS ──────────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.store_rounded,
              title: 'Shop Details',
              color: Colors.brown),
          _SettingsCard(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SettingsInput(
                      controller: _shopNameCtrl,
                      label     : 'Shop Name',
                      icon      : Icons.store_outlined),
                  const SizedBox(height: 12),
                  _SettingsInput(
                    controller  : _shopPhoneCtrl,
                    label       : 'Phone',
                    icon        : Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _SettingsInput(
                    controller: _shopAddressCtrl,
                    label     : 'Address',
                    icon      : Icons.location_on_outlined,
                    maxLines  : 2,
                  ),
                  const SizedBox(height: 12),
                  _SettingsInput(
                    controller  : _shopEmailCtrl,
                    label       : 'Email',
                    icon        : Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SettingsInput(
                          controller        : _invoicePrefixCtrl,
                          label             : 'Invoice Prefix',
                          icon              : Icons.tag_rounded,
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SettingsInput(
                          controller  : _dueDaysCtrl,
                          label       : 'Due Days',
                          icon        : Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InlineDropdown<String>(
                    label    : 'Currency Symbol',
                    icon     : Icons.currency_rupee_rounded,
                    value    : _currencySymbol,
                    items    : const ['Rs.', '₹', '\$', '€', '£', '¥'],
                    onChanged: (v) {
                      if (v != null) setState(() => _currencySymbol = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Footer Message',
                        style: TextStyle(
                            fontSize  : 13,
                            fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Print thank you or footer text at the bottom',
                        style: TextStyle(fontSize: 11)),
                    value           : _showFooterMessage,
                    activeThumbColor: AppTheme.primaryBlue,
                    onChanged       : (v) =>
                        setState(() => _showFooterMessage = v),
                  ),
                  if (_showFooterMessage) ...[
                    const SizedBox(height: 8),
                    _SettingsInput(
                      controller: _footerMessageCtrl,
                      label     : 'Footer Message',
                      icon      : Icons.message_outlined,
                    ),
                  ],
                ],
              ),
            ),
          ]),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _savingReceiptSetup ? null : _saveReceiptSetup,
              icon: _savingReceiptSetup
                  ? const SizedBox(
                      width : 16,
                      height: 16,
                      child : CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_savingReceiptSetup
                  ? 'Saving...'
                  : 'Save All Settings'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding        : const EdgeInsets.symmetric(vertical: 16),
                shape          : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── TAX & DISCOUNT ────────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.percent_rounded,
              title: 'Tax & Discount',
              color: Color(0xFFE65100)),
          _SettingsCard(children: [
            _SwitchTile(
              icon     : Icons.calculate_outlined,
              iconColor: Colors.orange.shade700,
              label    : 'Tax on Bills',
              subtitle : s.taxEnabled
                  ? '${s.taxPercent.toStringAsFixed(1)}% applied'
                  : 'Disabled',
              value    : s.taxEnabled,
              onChanged: (v) => s.updateTaxSettings(enabled: v),
            ),
            if (s.taxEnabled) ...[
              _divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax Rate',
                            style: TextStyle(
                                fontSize: 12,
                                color   : Color(0xFF757575))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color       : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${s.taxPercent.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize  : 12,
                                fontWeight: FontWeight.w700,
                                color     : Color(0xFFE65100)),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value      : s.taxPercent.clamp(0, 28),
                      min        : 0,
                      max        : 28,
                      divisions  : 56,
                      activeColor: Colors.orange.shade700,
                      label      : '${s.taxPercent.toStringAsFixed(1)}%',
                      onChanged  : (x) =>
                          s.updateTaxSettings(percent: x),
                    ),
                  ],
                ),
              ),
            ],
            _divider(),
            _SwitchTile(
              icon     : Icons.discount_outlined,
              iconColor: Colors.purple,
              label    : 'Allow Discount on Sale',
              subtitle : s.discountEnabled ? 'Enabled' : 'Disabled',
              value    : s.discountEnabled,
              onChanged: (v) => s.setDiscountEnabled(v),
            ),
            _divider(),
            _SwitchTile(
              icon     : Icons.business_outlined,
              iconColor: Colors.indigo,
              label    : 'GST on Bills',
              subtitle : s.gstEnabled
                  ? s.gstNo.isEmpty
                      ? 'Enabled (no GSTIN)'
                      : 'GSTIN: ${s.gstNo}'
                  : 'Disabled',
              value    : s.gstEnabled,
              onChanged: (v) => s.updateTaxSettings(gstEnabled: v),
            ),
            if (s.gstEnabled) ...[
              _divider(),
              _EditTile(
                icon     : Icons.numbers_rounded,
                iconColor: Colors.indigo,
                label    : 'GSTIN',
                value    : s.gstNo.isEmpty ? 'Enter GSTIN' : s.gstNo,
                onTap    : () => _editGstin(context, s),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ── APPEARANCE ────────────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.palette_outlined,
              title: 'Appearance',
              color: Colors.deepPurple),
          _SettingsCard(children: [
            _SwitchTile(
              icon     : Icons.dark_mode_outlined,
              iconColor: Colors.deepPurple,
              label    : 'Dark Mode',
              subtitle : s.themeMode == ThemeMode.dark ? 'On' : 'Off',
              value    : s.themeMode == ThemeMode.dark,
              onChanged: (v) =>
                  s.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
          ]),

          const SizedBox(height: 16),

          // ── ABOUT ─────────────────────────────────────────────────────
          const _SectionHeader(
              icon : Icons.info_outline_rounded,
              title: 'About',
              color: Color(0xFF757575)),
          _SettingsCard(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width : 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color       : AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.set_meal_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Godawari Fish POS',
                          style: TextStyle(
                              fontSize  : 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(AppConstants.appName,
                          style: TextStyle(
                              fontSize: 11,
                              color   : Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── GSTIN dialog ──────────────────────────────────────────────────────────
  static Future<void> _editGstin(
      BuildContext context, SettingsProvider s) async {
    final ctrl = TextEditingController(text: s.gstNo);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('GSTIN',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: _dialogField(ctrl, 'Enter 15-digit GSTIN',
            Icons.numbers_rounded,
            maxLength: 15, caps: TextCapitalization.characters),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final value = ctrl.text.trim().toUpperCase();
    ctrl.dispose();
    if (ok == true && context.mounted) {
      await s.updateTaxSettings(gstNo: value);
    }
  }

  static Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines       = 1,
    int? maxLength,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return TextField(
      controller        : ctrl,
      keyboardType      : type,
      maxLines          : maxLines,
      maxLength         : maxLength,
      textCapitalization: caps,
      style             : const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText  : hint,
        hintStyle : const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        filled    : true,
        fillColor : Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : const BorderSide(
                color: AppTheme.primaryBlue, width: 1.5)),
      ),
    );
  }

  static Widget _divider() =>
      const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16);
}

// ─────────────────────────────────────────────────────────────────────────────
//  NAVIGATION TILE
// ─────────────────────────────────────────────────────────────────────────────
class _NavigationTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       label;
  final String?      subtitle;
  final VoidCallback onTap;
  final Color?       textColor;

  const _NavigationTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width : 34,
              height: 34,
              decoration: BoxDecoration(
                color       : iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize  : 13,
                          fontWeight: FontWeight.w600,
                          color     : textColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 11,
                            color   : Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size : 18,
                color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED WIDGETS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsInput extends StatelessWidget {
  final TextEditingController controller;
  final String     label;
  final IconData   icon;
  final TextInputType keyboardType;
  final int        maxLines;
  final TextCapitalization textCapitalization;

  const _SettingsInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType       = TextInputType.text,
    this.maxLines           = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller        : controller,
      keyboardType      : keyboardType,
      maxLines          : maxLines,
      textCapitalization: textCapitalization,
      style             : const TextStyle(fontSize: 14),
      decoration        : InputDecoration(
        labelText : label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF757575)),
        filled    : true,
        fillColor : Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : const BorderSide(
                color: AppTheme.primaryBlue, width: 1.5)),
      ),
    );
  }
}

class _InlineDropdown<T> extends StatelessWidget {
  final String   label;
  final IconData icon;
  final T        value;
  final List<T>  items;
  final String Function(T)? itemLabelBuilder;
  final ValueChanged<T?> onChanged;

  const _InlineDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText : label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF757575)),
        filled    : true,
        fillColor : Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide  : BorderSide(color: Colors.grey.shade300)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value     : value,
          isExpanded: true,
          items     : items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                        itemLabelBuilder?.call(item) ?? '$item'),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       label;
  final String       value;
  final String       actionLabel;
  final Color?       valueColor;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onTap,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width  : double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border      : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize  : 13,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color   : valueColor ?? const Color(0xFF757575))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon : const Icon(
                  Icons.bluetooth_searching_rounded, size: 16),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Color    color;

  const _SectionHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize     : 12,
                fontWeight   : FontWeight.w700,
                color        : color,
                letterSpacing: 0.3)),
      ]),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow   : [
          BoxShadow(
              color     : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset    : const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children          : children),
    );
  }
}

class _EditTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       label, value;
  final VoidCallback onTap;

  const _EditTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width : 34,
            height: 34,
            decoration: BoxDecoration(
              color       : iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize  : 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 11,
                        color   : Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size : 18,
              color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData?  icon;
  final Color?     iconColor;
  final String     label;
  final String?    subtitle;
  final bool       value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    this.icon,
    this.iconColor,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            width : 34,
            height: 34,
            decoration: BoxDecoration(
              color       : (iconColor ?? Colors.grey)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(icon, color: iconColor ?? Colors.grey, size: 18),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize  : 13,
                      fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 11,
                        color   : Colors.grey.shade500)),
              ],
            ],
          ),
        ),
        Switch(
          value           : value,
          onChanged       : onChanged,
          activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.4),
          activeThumbColor: AppTheme.primaryBlue,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

class _CounterTile extends StatelessWidget {
  final String label;
  final int    value;
  final ValueChanged<int> onChanged;

  const _CounterTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            color       : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children    : [
              IconButton(
                onPressed  : value > 0
                    ? () => onChanged(value - 1)
                    : null,
                icon       : const Icon(Icons.remove, size: 18),
                padding    : EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
              Text('$value',
                  style: const TextStyle(
                      fontSize  : 14,
                      fontWeight: FontWeight.w700)),
              IconButton(
                onPressed  : () => onChanged(value + 1),
                icon       : const Icon(Icons.add, size: 18),
                padding    : EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}