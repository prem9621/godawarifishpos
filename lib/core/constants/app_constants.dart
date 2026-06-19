class AppConstants {
  AppConstants._();

  // App info
  static const String shopName = 'Godawari Fish';
  static const String shopTagline = 'The Real Taste Of Fresh Fish';
  static const String shopAddress = 'Fish Market, Central Naka';
  static const String shopPhone = '93706189';
  static const String shopEmail = 'godawarifish@gmail.com';

  // Database
  static const String dbName = 'godawari_fish_pos.db';
  static const int dbVersion = 1;

  // Invoice defaults
  static const String defaultPrefix = 'GFC';
  static const String defaultPurchasePrefix = 'PUR';
  static const String defaultReturnPrefix = 'RET';
  static const int defaultDueDays = 15;
  static const String defaultCurrency = 'Rs.';
  static const int defaultThermalMm = 80;
  static const String defaultUpiId = '';

  // Fish data
  static const List<String> fishCategories = [
    'Fresh Fish',
    'Dry Fish',
    'Seafood',
    'Chicken',
    'Mutton',
  ];

  static const List<String> fishUnits = [
    'Kg',
    'g',
    'Piece',
    'Dozen',
  ];

  // Database table names
  static const String tableInvoices = 'invoices';
  static const String tableInvoiceItems = 'invoice_items';
  static const String tableItems = 'items';
  static const String tableCustomers = 'customers';
  static const String tablePartyPayments = 'party_payments';
  static const String tablePurchases = 'purchases';
  static const String tablePurchaseItems = 'purchase_items';
  static const String tableSaleReturns = 'sale_returns';
  static const String tableSaleReturnItems = 'sale_return_items';
  static const String tableExpenses = 'expenses';

  // Shared Preferences Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyColorTheme = 'color_theme';
  static const String keyShopName = 'shop_name';
  static const String keyShopAddress = 'shop_address';
  static const String keyShopPhone = 'shop_phone';
  static const String keyShopEmail = 'shop_email';
  static const String keyInvoicePrefix = 'invoice_prefix';
  static const String keyLastInvoiceNo = 'last_invoice_no';
  static const String keyPurchasePrefix = 'purchase_prefix';
  static const String keyLastPurchaseNo = 'last_purchase_no';
  static const String keyReturnPrefix = 'return_prefix';
  static const String keyLastReturnNo = 'last_return_no';
  static const String keyReceiptTheme = 'receipt_theme';
  static const String keyTaxEnabled = 'tax_enabled';
  static const String keyTaxPercent = 'tax_percent';
  static const String keyGstEnabled = 'gst_enabled';
  static const String keyGstNo = 'gst_no';
  static const String keyUpiId = 'upi_id';
  static const String keyShowPaymentQr = 'show_payment_qr';
  static const String keyShowQrCode = 'show_qr_code';
  static const String keyDiscountEnabled = 'discount_enabled';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyDueDateDays = 'due_date_days';
  static const String keyBluetoothPrinter = 'bluetooth_printer';
  static const String keyThermalPaperMm = 'thermal_paper_mm';
}
