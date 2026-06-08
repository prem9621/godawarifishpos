import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  int _colorThemeIndex = 0;

  String _shopName = AppConstants.shopName;
  String _shopAddress = AppConstants.shopAddress;
  String _shopPhone = AppConstants.shopPhone;
  String _shopEmail = AppConstants.shopEmail;

  String _invoicePrefix = AppConstants.defaultPrefix;
  int _lastInvoiceNo = 4207;
  String _purchasePrefix = AppConstants.defaultPurchasePrefix;
  int _lastPurchaseNo = 1000;
  String _returnPrefix = AppConstants.defaultReturnPrefix;
  int _lastReturnNo = 1000;

  int _receiptTheme = 5;
  bool _taxEnabled = false;
  double _taxPercent = 0;
  bool _gstEnabled = false;
  String _gstNo = '';
  String _upiId = AppConstants.defaultUpiId;
  bool _showPaymentQr = false;
  bool _discountEnabled = true;
  String _currencySymbol = AppConstants.defaultCurrency;
  int _dueDateDays = AppConstants.defaultDueDays;
  String _bluetoothPrinter = '';
  int _thermalPaperWidthMm = 80;
  double _receiptFontSize = 1.0;
  bool _printLogo = true;
  bool _showFooterMessage = true;
  String _footerMessage = 'Thank You Visit Again';

  bool _nativeLanguagePrinting = true;
  int _extraLinesAtPrintEnd = 0;
  int _numberOfCopies = 1;
  bool _autoCutPaper = false;
  bool _openCashDrawer = false;
  bool _printShopName = true;
  bool _printShopAddress = true;
  bool _printShopEmail = true;
  bool _printShopPhone = true;
  bool _printGstin = true;
  bool _printBillOfSupply = false;
  bool _printSNo = true;
  bool _printHsn = true;
  bool _printUnit = true;
  bool _printMrp = true;
  bool _printDescription = true;
  bool _printTotalQuantity = true;
  bool _printAmountWithDecimal = true;
  bool _printReceivedAmount = true;
  bool _printBalanceAmount = true;

  int _currentStoreId = 1;
  String _currentStoreName = '';
  int _currentUserId = 0;
  String _currentUserName = '';
  String _currentUserRole = '';

  ThemeMode get themeMode => _themeMode;
  int get colorThemeIndex => _colorThemeIndex;
  String get shopName => _shopName;
  String get shopAddress => _shopAddress;
  String get shopPhone => _shopPhone;
  String get shopEmail => _shopEmail;
  String get invoicePrefix => _invoicePrefix;
  int get lastInvoiceNo => _lastInvoiceNo;
  String get purchasePrefix => _purchasePrefix;
  int get lastPurchaseNo => _lastPurchaseNo;
  String get returnPrefix => _returnPrefix;
  int get lastReturnNo => _lastReturnNo;
  int get receiptTheme => _receiptTheme;
  bool get taxEnabled => _taxEnabled;
  double get taxPercent => _taxPercent;
  bool get gstEnabled => _gstEnabled;
  String get gstNo => _gstNo;
  String get upiId => _upiId;
  bool get showPaymentQr => _showPaymentQr;
  bool get discountEnabled => _discountEnabled;
  String get currencySymbol => _currencySymbol;
  int get dueDateDays => _dueDateDays;
  String get bluetoothPrinter => _bluetoothPrinter;
  int get thermalPaperWidthMm => _thermalPaperWidthMm;
  double get receiptFontSize => _receiptFontSize;
  bool get printLogo => _printLogo;
  bool get showFooterMessage => _showFooterMessage;
  String get footerMessage => _footerMessage;
  bool get nativeLanguagePrinting => _nativeLanguagePrinting;
  int get extraLinesAtPrintEnd => _extraLinesAtPrintEnd;
  int get numberOfCopies => _numberOfCopies;
  bool get autoCutPaper => _autoCutPaper;
  bool get openCashDrawer => _openCashDrawer;
  bool get printShopName => _printShopName;
  bool get printShopAddress => _printShopAddress;
  bool get printShopEmail => _printShopEmail;
  bool get printShopPhone => _printShopPhone;
  bool get printGstin => _printGstin;
  bool get printBillOfSupply => _printBillOfSupply;
  bool get printSNo => _printSNo;
  bool get printHsn => _printHsn;
  bool get printUnit => _printUnit;
  bool get printMrp => _printMrp;
  bool get printDescription => _printDescription;
  bool get printTotalQuantity => _printTotalQuantity;
  bool get printAmountWithDecimal => _printAmountWithDecimal;
  bool get printReceivedAmount => _printReceivedAmount;
  bool get printBalanceAmount => _printBalanceAmount;

  int get currentStoreId => _currentStoreId;
  String get currentStoreName => _currentStoreName;
  int get currentUserId => _currentUserId;
  String get currentUserName => _currentUserName;
  String get currentUserRole => _currentUserRole;
  bool get isLoggedIn => _currentUserId > 0;
  bool get isAdmin => _currentUserRole == 'admin';

  SettingsProvider();

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt(AppConstants.keyThemeMode) ?? 0];
    _colorThemeIndex = prefs.getInt(AppConstants.keyColorTheme) ?? 0;
    _shopName =
        prefs.getString(AppConstants.keyShopName) ?? AppConstants.shopName;
    _shopAddress = prefs.getString(AppConstants.keyShopAddress) ??
        AppConstants.shopAddress;
    _shopPhone =
        prefs.getString(AppConstants.keyShopPhone) ?? AppConstants.shopPhone;
    _shopEmail =
        prefs.getString(AppConstants.keyShopEmail) ?? AppConstants.shopEmail;
    _invoicePrefix = prefs.getString(AppConstants.keyInvoicePrefix) ??
        AppConstants.defaultPrefix;
    _lastInvoiceNo = prefs.getInt(AppConstants.keyLastInvoiceNo) ?? 4207;
    _purchasePrefix = prefs.getString(AppConstants.keyPurchasePrefix) ??
        AppConstants.defaultPurchasePrefix;
    _lastPurchaseNo = prefs.getInt(AppConstants.keyLastPurchaseNo) ?? 1000;
    _returnPrefix = prefs.getString(AppConstants.keyReturnPrefix) ??
        AppConstants.defaultReturnPrefix;
    _lastReturnNo = prefs.getInt(AppConstants.keyLastReturnNo) ?? 1000;
    _receiptTheme = prefs.getInt(AppConstants.keyReceiptTheme) ?? 5;
    _taxEnabled = prefs.getBool(AppConstants.keyTaxEnabled) ?? false;
    _taxPercent = prefs.getDouble(AppConstants.keyTaxPercent) ?? 0;
    _gstEnabled = prefs.getBool(AppConstants.keyGstEnabled) ?? false;
    _gstNo = prefs.getString(AppConstants.keyGstNo) ?? '';
    _upiId =
        prefs.getString(AppConstants.keyUpiId) ?? AppConstants.defaultUpiId;
    _showPaymentQr = prefs.getBool(AppConstants.keyShowPaymentQr) ?? false;
    _discountEnabled = prefs.getBool(AppConstants.keyDiscountEnabled) ?? true;
    _currencySymbol = prefs.getString(AppConstants.keyCurrencySymbol) ??
        AppConstants.defaultCurrency;
    _dueDateDays = prefs.getInt(AppConstants.keyDueDateDays) ??
        AppConstants.defaultDueDays;
    _bluetoothPrinter = prefs.getString(AppConstants.keyBluetoothPrinter) ?? '';
_thermalPaperWidthMm = prefs.getInt(AppConstants.keyThermalPaperMm) ?? 80;
if (_thermalPaperWidthMm != 58 &&
    _thermalPaperWidthMm != 76 &&
    _thermalPaperWidthMm != 80) {
  _thermalPaperWidthMm = 80;
}
    _receiptFontSize = prefs.getDouble('receipt_font_size') ?? 1.0;
    _printLogo = prefs.getBool('print_logo') ?? true;
    _showFooterMessage = prefs.getBool('show_footer_message') ?? true;
    _footerMessage =
        prefs.getString('footer_message') ?? 'Thank You Visit Again';
    _nativeLanguagePrinting = prefs.getBool('native_language_printing') ?? true;
    _extraLinesAtPrintEnd = prefs.getInt('extra_lines_at_print_end') ?? 0;
    _numberOfCopies = prefs.getInt('number_of_copies') ?? 1;
    _autoCutPaper = prefs.getBool('auto_cut_paper') ?? false;
    _openCashDrawer = prefs.getBool('open_cash_drawer') ?? false;
    _printShopName = prefs.getBool('print_shop_name') ?? true;
    _printShopAddress = prefs.getBool('print_shop_address') ?? true;
    _printShopEmail = prefs.getBool('print_shop_email') ?? true;
    _printShopPhone = prefs.getBool('print_shop_phone') ?? true;
    _printGstin = prefs.getBool('print_gstin') ?? true;
    _printBillOfSupply = prefs.getBool('print_bill_of_supply') ?? false;
    _printSNo = prefs.getBool('print_s_no') ?? true;
    _printHsn = prefs.getBool('print_hsn') ?? true;
    _printUnit = prefs.getBool('print_unit') ?? true;
    _printMrp = prefs.getBool('print_mrp') ?? true;
    _printDescription = prefs.getBool('print_description') ?? true;
    _printTotalQuantity = prefs.getBool('print_total_quantity') ?? true;
    _printAmountWithDecimal =
        prefs.getBool('print_amount_with_decimal') ?? true;
    _printReceivedAmount = prefs.getBool('print_received_amount') ?? true;
    _printBalanceAmount = prefs.getBool('print_balance_amount') ?? true;
    _currentStoreId = prefs.getInt('current_store_id') ?? 1;
    _currentStoreName = prefs.getString('current_store_name') ?? '';
    _currentUserId = prefs.getInt('current_user_id') ?? 0;
    _currentUserName = prefs.getString('current_user_name') ?? '';
    _currentUserRole = prefs.getString('current_user_role') ?? '';
    await _loadCurrentStoreProfile();
    notifyListeners();
  }

  Future<void> _loadCurrentStoreProfile() async {
    try {
      final store = await DatabaseHelper.instance.getStoreById(_currentStoreId);
      if (store == null) return;
      final name = store['name']?.toString().trim() ?? '';
      _shopName = name.isNotEmpty ? name : AppConstants.shopName;
      _shopPhone = store['phone']?.toString().trim() ?? '';
      _shopAddress = store['address']?.toString().trim() ?? '';
      _shopEmail = store['email']?.toString().trim() ?? '';
      _currentStoreName = _shopName;
    } catch (e) {
      debugPrint('Store profile load failed: $e');
    }
  }

  Future<void> switchStore(
      {required int storeId, required String storeName}) async {
    _currentStoreId = storeId;
    _currentStoreName = storeName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_store_id', storeId);
    await prefs.setString('current_store_name', storeName);
    await _loadCurrentStoreProfile();
    notifyListeners();
  }

  Future<void> loginUser(
      {required int userId,
      required String userName,
      required String userRole}) async {
    _currentUserId = userId;
    _currentUserName = userName;
    _currentUserRole = userRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', userId);
    await prefs.setString('current_user_name', userName);
    await prefs.setString('current_user_role', userRole);
    notifyListeners();
  }

  Future<void> logoutUser() async {
    _currentUserId = 0;
    _currentUserName = '';
    _currentUserRole = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', 0);
    await prefs.setString('current_user_name', '');
    await prefs.setString('current_user_role', '');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setColorTheme(int index) async {
    _colorThemeIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyColorTheme, index);
    notifyListeners();
  }

  Future<void> setReceiptTheme(int theme) async {
    _receiptTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyReceiptTheme, theme);
    notifyListeners();
  }

  Future<void> setReceiptFontSize(double value) async {
    _receiptFontSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('receipt_font_size', value);
    notifyListeners();
  }

  Future<void> setPrintLogo(bool value) async {
    _printLogo = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('print_logo', value);
    notifyListeners();
  }

  Future<void> setShowFooterMessage(bool value) async {
    _showFooterMessage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_footer_message', value);
    notifyListeners();
  }

  Future<void> setFooterMessage(String value) async {
    _footerMessage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('footer_message', value);
    notifyListeners();
  }

  Future<void> updateShopInfo(
      {String? name, String? address, String? phone, String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _shopName = name;
      await prefs.setString(AppConstants.keyShopName, name);
    }
    if (address != null) {
      _shopAddress = address;
      await prefs.setString(AppConstants.keyShopAddress, address);
    }
    if (phone != null) {
      _shopPhone = phone;
      await prefs.setString(AppConstants.keyShopPhone, phone);
    }
    if (email != null) {
      _shopEmail = email;
      await prefs.setString(AppConstants.keyShopEmail, email);
    }
    await DatabaseHelper.instance.updateStore(_currentStoreId, {
      'name': _shopName,
      'address': _shopAddress,
      'phone': _shopPhone,
      'email': _shopEmail,
    });
    _currentStoreName = _shopName;
    await prefs.setString('current_store_name', _currentStoreName);
    notifyListeners();
  }

  Future<void> updateInvoiceSettings(
      {String? prefix, int? dueDays, String? currency}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefix != null) {
      _invoicePrefix = prefix;
      await prefs.setString(AppConstants.keyInvoicePrefix, prefix);
    }
    if (dueDays != null) {
      _dueDateDays = dueDays;
      await prefs.setInt(AppConstants.keyDueDateDays, dueDays);
    }
    if (currency != null) {
      _currencySymbol = currency;
      await prefs.setString(AppConstants.keyCurrencySymbol, currency);
    }
    notifyListeners();
  }

  Future<void> updatePurchasePrefix(String prefix) async {
    _purchasePrefix = prefix;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyPurchasePrefix, prefix);
    notifyListeners();
  }

  Future<void> updateReturnPrefix(String prefix) async {
    _returnPrefix = prefix;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyReturnPrefix, prefix);
    notifyListeners();
  }

  Future<void> updateTaxSettings(
      {bool? enabled, double? percent, bool? gstEnabled, String? gstNo}) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) {
      _taxEnabled = enabled;
      await prefs.setBool(AppConstants.keyTaxEnabled, enabled);
    }
    if (percent != null) {
      _taxPercent = percent;
      await prefs.setDouble(AppConstants.keyTaxPercent, percent);
    }
    if (gstEnabled != null) {
      _gstEnabled = gstEnabled;
      await prefs.setBool(AppConstants.keyGstEnabled, gstEnabled);
    }
    if (gstNo != null) {
      _gstNo = gstNo;
      await prefs.setString(AppConstants.keyGstNo, gstNo);
    }
    notifyListeners();
  }

  Future<void> setDiscountEnabled(bool value) async {
    _discountEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyDiscountEnabled, value);
    notifyListeners();
  }

  Future<void> setBluetoothPrinter(String address) async {
    _bluetoothPrinter = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyBluetoothPrinter, address);
    notifyListeners();
  }

  Future<void> updateInvoicePrintSettings({
    bool? nativeLanguagePrinting,
    int? extraLinesAtPrintEnd,
    int? numberOfCopies,
    bool? autoCutPaper,
    bool? openCashDrawer,
    bool? printShopName,
    bool? printShopAddress,
    bool? printShopEmail,
    bool? printShopPhone,
    bool? printGstin,
    bool? printBillOfSupply,
    bool? printSNo,
    bool? printHsn,
    bool? printUnit,
    bool? printMrp,
    bool? printDescription,
    bool? printTotalQuantity,
    bool? printAmountWithDecimal,
    bool? printReceivedAmount,
    bool? printBalanceAmount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (nativeLanguagePrinting != null) {
      _nativeLanguagePrinting = nativeLanguagePrinting;
      await prefs.setBool('native_language_printing', nativeLanguagePrinting);
    }
    if (extraLinesAtPrintEnd != null) {
      _extraLinesAtPrintEnd = extraLinesAtPrintEnd;
      await prefs.setInt('extra_lines_at_print_end', extraLinesAtPrintEnd);
    }
    if (numberOfCopies != null) {
      _numberOfCopies = numberOfCopies;
      await prefs.setInt('number_of_copies', numberOfCopies);
    }
    if (autoCutPaper != null) {
      _autoCutPaper = autoCutPaper;
      await prefs.setBool('auto_cut_paper', autoCutPaper);
    }
    if (openCashDrawer != null) {
      _openCashDrawer = openCashDrawer;
      await prefs.setBool('open_cash_drawer', openCashDrawer);
    }
    if (printShopName != null) {
      _printShopName = printShopName;
      await prefs.setBool('print_shop_name', printShopName);
    }
    if (printShopAddress != null) {
      _printShopAddress = printShopAddress;
      await prefs.setBool('print_shop_address', printShopAddress);
    }
    if (printShopEmail != null) {
      _printShopEmail = printShopEmail;
      await prefs.setBool('print_shop_email', printShopEmail);
    }
    if (printShopPhone != null) {
      _printShopPhone = printShopPhone;
      await prefs.setBool('print_shop_phone', printShopPhone);
    }
    if (printGstin != null) {
      _printGstin = printGstin;
      await prefs.setBool('print_gstin', printGstin);
    }
    if (printBillOfSupply != null) {
      _printBillOfSupply = printBillOfSupply;
      await prefs.setBool('print_bill_of_supply', printBillOfSupply);
    }
    if (printSNo != null) {
      _printSNo = printSNo;
      await prefs.setBool('print_s_no', printSNo);
    }
    if (printHsn != null) {
      _printHsn = printHsn;
      await prefs.setBool('print_hsn', printHsn);
    }
    if (printUnit != null) {
      _printUnit = printUnit;
      await prefs.setBool('print_unit', printUnit);
    }
    if (printMrp != null) {
      _printMrp = printMrp;
      await prefs.setBool('print_mrp', printMrp);
    }
    if (printDescription != null) {
      _printDescription = printDescription;
      await prefs.setBool('print_description', printDescription);
    }
    if (printTotalQuantity != null) {
      _printTotalQuantity = printTotalQuantity;
      await prefs.setBool('print_total_quantity', printTotalQuantity);
    }
    if (printAmountWithDecimal != null) {
      _printAmountWithDecimal = printAmountWithDecimal;
      await prefs.setBool('print_amount_with_decimal', printAmountWithDecimal);
    }
    if (printReceivedAmount != null) {
      _printReceivedAmount = printReceivedAmount;
      await prefs.setBool('print_received_amount', printReceivedAmount);
    }
    if (printBalanceAmount != null) {
      _printBalanceAmount = printBalanceAmount;
      await prefs.setBool('print_balance_amount', printBalanceAmount);
    }
    notifyListeners();
  }

 Future<void> setThermalPaperWidthMm(int mm) async {
  final v = (mm == 58 || mm == 76 || mm == 80) ? mm : 80;
  _thermalPaperWidthMm = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(AppConstants.keyThermalPaperMm, v);
  notifyListeners();
}

  Future<void> setUpiId(String id) async {
    _upiId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUpiId, id);
    notifyListeners();
  }

  Future<void> setShowPaymentQr(bool value) async {
    _showPaymentQr = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyShowPaymentQr, value);
    notifyListeners();
  }

  // ── BILL COUNTERS ──────────────────────────────────────────────────────────
  // Fixed: queries DB to skip numbers already used by Firebase-synced invoices

  Future<int> getNextInvoiceNo() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT invoice_no FROM invoices WHERE invoice_no LIKE ?',
      ['$_invoicePrefix%'],
    );
    final used = <int>{};
    for (final r in rows) {
      final suffix =
          (r['invoice_no'] as String? ?? '').replaceFirst(_invoicePrefix, '');
      final n = int.tryParse(suffix);
      if (n != null) used.add(n);
    }
    var next = _lastInvoiceNo + 1;
    while (used.contains(next)) {
      next++;
    }
    _lastInvoiceNo = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyLastInvoiceNo, _lastInvoiceNo);
    return _lastInvoiceNo;
  }

  Future<int> getNextPurchaseNo() async {
    _lastPurchaseNo++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyLastPurchaseNo, _lastPurchaseNo);
    notifyListeners();
    return _lastPurchaseNo;
  }

  Future<int> getNextReturnNo() async {
    _lastReturnNo++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyLastReturnNo, _lastReturnNo);
    notifyListeners();
    return _lastReturnNo;
  }
}
