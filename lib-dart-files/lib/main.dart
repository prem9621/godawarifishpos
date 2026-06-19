import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

// ── Desktop-only import (guarded at runtime) ─────────────────────────────────
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    if (dart.library.html) 'shims/sqflite_ffi_stub.dart';

import 'core/theme/app_theme.dart';
import 'database/database_helper.dart';
import 'providers/billing_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/sale_return_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shell_provider.dart';
import 'screens/home/main_shell_screen.dart';
import 'screens/login/login_screen.dart';
import 'services/firebase_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    } catch (e) {
      debugPrint('[DB Init] Skipping FFI init: $e');
    }
  }

  await Future.wait([
    initializeDateFormatting('en_IN', null),
    if (!kIsWeb) DatabaseHelper.instance.preWarm(),
  ]);

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  // ── Flutter framework error handler ─────────────────────────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (!kDebugMode) {
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    }
  };

  // ── Async / platform error handler ──────────────────────────────────────
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    return true;
  };

  // ── Portrait lock ────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── System UI styling ────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Custom crash screen ──────────────────────────────────────────────────
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.grey.shade100,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 52, color: Colors.orange.shade700),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 10),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(GodawariFishPOS(settingsProvider: settingsProvider));
  unawaited(_startFirebaseSyncInBackground());
}

Future<void> _startFirebaseSyncInBackground() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    debugPrint('Firebase initialized');
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 8));
      debugPrint('Firebase anonymous auth signed in');
    }
    await FirebaseSyncService.instance.init();
    debugPrint('Firebase sync started');
  } catch (e) {
    debugPrint('Firebase background sync skipped: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class GodawariFishPOS extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const GodawariFishPOS({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ShellProvider>(create: (_) => ShellProvider()),
        ChangeNotifierProvider<CustomerProvider>(
            create: (_) => CustomerProvider()),
        ChangeNotifierProvider<InventoryProvider>(
            create: (_) => InventoryProvider()),
        ChangeNotifierProvider<BillingProvider>(
            create: (_) => BillingProvider()),
        ChangeNotifierProvider<PurchaseProvider>(
            create: (_) => PurchaseProvider()),
        ChangeNotifierProvider<SaleReturnProvider>(
            create: (_) => SaleReturnProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Godawari Fish Ledger',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            home: settings.isLoggedIn
                ? const MainShellScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
