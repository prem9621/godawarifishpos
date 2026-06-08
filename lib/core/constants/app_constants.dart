/// Central configuration for Godawari Fish POS.
/// All magic strings and numbers live here — never hardcode elsewhere.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ── App Identity ──────────────────────────────────────────────────────────
  static const String appName = 'Godawari Fish POS';
  static const String shopName = 'GODAWARI FISH';

  // ── CHANGED: matches Vyapar hard copy receipt
  static const String shopTagline = 'The Real Taste Of Fresh Fish';

  static const String shopAddress = 'Fish Market, Central Naka, MH-20';

  static const String shopPhone = '9371306189';
  static const String shopEmail = 'godawarifish@gmail.com';

  static const String defaultUpiId = '9371306189@ibl';

  // ── Database ──────────────────────────────────────────────────────────────
  static const String dbName = 'godawari_fish.db';
  static const int dbVersion = 10;

  // ── Table Names ───────────────────────────────────────────────────────────
  static const String tableItems = 'items';
  static const String tableInvoices = 'invoices';
  static const String tableInvoiceItems = 'invoice_items';
  static const String tableCustomers = 'customers';
  static const String tableExpenses = 'expenses';
  static const String tablePartyPayments = 'party_payments';
  static const String tablePurchases = 'purchases';
  static const String tablePurchaseItems = 'purchase_items';
  static const String tableSaleReturns = 'sale_returns';
  static const String tableSaleReturnItems = 'sale_return_items';

  // ── SharedPreferences Keys ────────────────────────────────────────────────
  static const String keyThemeMode = 'theme_mode';
  static const String keyColorTheme = 'color_theme';
  static const String keyShopName = 'shop_name';
  static const String keyShopAddress = 'shop_address';
  static const String keyShopPhone = 'shop_phone';
  static const String keyShopEmail = 'shop_email';
  static const String keyInvoicePrefix = 'invoice_prefix';
  static const String keyLastInvoiceNo = 'last_invoice_no';
  static const String keyReceiptTheme = 'receipt_theme';
  static const String keyTaxEnabled = 'tax_enabled';
  static const String keyTaxPercent = 'tax_percent';
  static const String keyGstEnabled = 'gst_enabled';
  static const String keyGstNo = 'gst_no';
  static const String keyUpiId = 'upi_id';
  static const String keyShowPaymentQr = 'show_payment_qr';
  static const String keyDiscountEnabled = 'discount_enabled';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyDueDateDays = 'due_date_days';
  static const String keyBluetoothPrinter = 'bluetooth_printer';
  static const String keyThermalPaperMm = 'thermal_paper_mm';
  static const String keyPurchasePrefix = 'purchase_prefix';
  static const String keyLastPurchaseNo = 'last_purchase_no';
  static const String keyReturnPrefix = 'return_prefix';
  static const String keyLastReturnNo = 'last_return_no';

  // ── Domain Lists ──────────────────────────────────────────────────────────
  static const List<String> fishUnits = [
    'Kg',
    'Gram',
    'Piece',
    'Dozen',
    'Box',
  ];

  static const List<String> fishCategories = [
    'Fresh Water Fish',
    'Sea Water Fish',
    'Prawn & Shrimp',
    'Crab & Lobster',
    'Squid & Octopus',
    'Chicken',
    'Mutton',
    'Other',
  ];

  // ── Defaults ──────────────────────────────────────────────────────────────

  // ── CHANGED: Rs. to match Vyapar receipt style
  static const String defaultCurrency = 'Rs.';

  static const String defaultPrefix = 'GFC';
  static const String defaultPurchasePrefix = 'GFP';
  static const String defaultReturnPrefix = 'GSR';

  static const int defaultDueDays = 15;
  static const int defaultThermalMm = 80;
  static const double defaultTaxPercent = 0.0;

  // ── UI / Layout ───────────────────────────────────────────────────────────
  static const double paddingS = 8.0;
  static const double paddingM = 12.0;
  static const double paddingL = 16.0;
  static const double paddingXL = 24.0;

  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;

  // ── Timeouts & Limits ─────────────────────────────────────────────────────
  static const int maxInvoiceItems = 50;
  static const Duration snackDuration = Duration(seconds: 3);
  static const Duration splashDuration = Duration(seconds: 2);
}
