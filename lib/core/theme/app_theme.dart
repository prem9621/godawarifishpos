import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Vyapar Exact Brand Colors ─────────────────────────────────────────────
  static const Color vyaparRed       = Color(0xFFE31E24); // Vyapar primary red
  static const Color vyaparNavy      = Color(0xFF1A237E); // Vyapar header navy
  static const Color vyaparShellBlue = Color(0xFFDDEBF7); // Vyapar light blue shell
  static const Color primaryBlue     = Color(0xFF1565C0); // Secondary actions
  static const Color primaryOrange   = Color(0xFFE65100); // To-receive accent
  static const Color primaryTeal     = Color(0xFF00695C);
  static const Color accentGold      = Color(0xFFFFC107);
  static const Color fishBlue        = Color(0xFF0D47A1);

  // ── Text Theme ────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme([TextTheme? base]) {
    return GoogleFonts.poppinsTextTheme(base).copyWith(
      bodyLarge:   GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400),
      bodyMedium:  GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400),
      bodySmall:   GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w400),
      labelLarge:  GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
      labelSmall:  GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
      titleLarge:  GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall:  GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: vyaparRed,
        brightness: Brightness.light,
        primary: vyaparRed,
        secondary: primaryBlue,
        tertiary: accentGold,
        surface: Colors.white,
        // ignore: deprecated_member_use
        background: const Color(0xFFF2F6FA),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F6FA),
      textTheme: _buildTextTheme(),

      // AppBar — Vyapar navy
      appBarTheme: AppBarTheme(
        backgroundColor: vyaparNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),

      // NavigationBar — Vyapar red indicator
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: vyaparRed.withOpacity(0.1),
        elevation: 8,
        height: 62,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: selected ? vyaparRed : Colors.grey.shade500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? vyaparRed : Colors.grey.shade500,
            size: 22,
          );
        }),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06),
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),

      // Elevated Button — Vyapar red
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vyaparRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          minimumSize: const Size(0, 44),
        ),
      ),

      // FilledButton — Vyapar red
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: vyaparRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
          minimumSize: const Size(0, 44),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: vyaparRed,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          minimumSize: const Size(0, 40),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: vyaparRed,
          side: const BorderSide(color: vyaparRed, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          minimumSize: const Size(0, 44),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryBlue, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.8)),
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
        errorStyle: GoogleFonts.poppins(fontSize: 11),
      ),

      // FAB — Vyapar red
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: vyaparRed,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 0.5,
        space: 1,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
        subtitleTextStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
        contentTextStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
        elevation: 8,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: GoogleFonts.poppins(fontSize: 13),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
      ),
    );
  }

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const darkSurface    = Color(0xFF1E1E2E);
    const darkBackground = Color(0xFF12121C);
    const darkAppBar     = Color(0xFF1A1A2E);
    const darkCard       = Color(0xFF252535);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: vyaparRed,
        brightness: Brightness.dark,
        primary: vyaparRed,
        secondary: const Color(0xFFFFCC80),
        surface: darkSurface,
        // ignore: deprecated_member_use
        background: darkBackground,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),

      appBarTheme: AppBarTheme(
        backgroundColor: darkAppBar,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),

      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3A3A5E))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3A3A5E))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: vyaparRed, width: 1.8)),
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
        hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: vyaparRed,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A3E),
        thickness: 0.5,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        subtitleTextStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
      ),
    );
  }

  // ── Color Theme Presets ───────────────────────────────────────────────────
  static const List<AppColorTheme> colorThemes = [
    AppColorTheme('Vyapar Red',    vyaparRed,        primaryBlue),
    AppColorTheme('Ocean Blue',    primaryBlue,      Color(0xFFE65100)),
    AppColorTheme('Forest Green',  Color(0xFF2E7D32), Color(0xFFFF8F00)),
    AppColorTheme('Deep Purple',   Color(0xFF4527A0), Color(0xFFFF6F00)),
    AppColorTheme('Teal Wave',     Color(0xFF00695C), Color(0xFFE65100)),
  ];
}

class AppColorTheme {
  final String name;
  final Color  primary;
  final Color  accent;
  const AppColorTheme(this.name, this.primary, this.accent);
}