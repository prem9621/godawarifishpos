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
        onSurface: Colors.black87,
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
        indicatorColor: vyaparRed.withValues(alpha: 0.1),
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
        shadowColor: Colors.black.withValues(alpha: 0.06),
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

// ────────────────────────────────────────────────────────────────────────────
//  APP COLORS — the slate/gray palette used in the clean-SaaS reference design.
//  Use these instead of scattered Colors.grey.shadeXXX so every screen pulls
//  from one source.
// ────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Slate scale (matches the Bhakriwala-style reference look)
  static const Color slate900 = Color(0xFF1A1F2E); // primary text
  static const Color slate700 = Color(0xFF334155); // secondary text (dark)
  static const Color slate500 = Color(0xFF64748B); // secondary text
  static const Color slate400 = Color(0xFF94A3B8); // tertiary / muted text
  static const Color slate300 = Color(0xFFCBD5E1); // disabled / icons
  static const Color slate200 = Color(0xFFE2E8F0); // borders, dividers
  static const Color slate100 = Color(0xFFF1F5F9); // subtle fills
  static const Color slate50  = Color(0xFFF8FAFC); // page background

  static const Color border   = slate200;
  static const Color divider  = slate100;
  static const Color surface  = Colors.white;
  static const Color bg       = slate50;

  static const Color textPrimary   = slate900;
  static const Color textSecondary = slate500;
  static const Color textMuted     = slate400;

  static const Color success = Color(0xFF2E7D32);
  static const Color danger  = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFE65100);
}

// ────────────────────────────────────────────────────────────────────────────
//  APP TEXT — a tight, consistent type scale. Pick the smallest style that
//  fits the role instead of guessing an inline fontSize. All screens should
//  use these instead of ad-hoc `TextStyle(fontSize: 11/12/13/14...)`.
//
//  Scale (compact, phone-optimized):
//   caption   10px  — timestamps, helper text under inputs
//   label     11px  — field labels, chip text, table headers
//   body      12px  — default body / list subtitle text
//   bodyLg    13px  — primary list-tile title text
//   subtitle  14px  — card section headers, emphasized rows
//   title     16px  — screen/section titles
//   heading   18px  — app bar titles, big numbers
//   display   22px  — hero numbers (today's sales, totals)
// ────────────────────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  static TextStyle get caption => GoogleFonts.poppins(
      fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted);

  static TextStyle get label => GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary);

  static TextStyle get body => GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textPrimary);

  static TextStyle get bodyMuted => GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);

  static TextStyle get bodyLg => GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  static TextStyle get subtitle => GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  static TextStyle get title => GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

  static TextStyle get heading => GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary);

  static TextStyle get display => GoogleFonts.poppins(
      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary);

  /// Helper for the common "value with a colored accent" pattern
  /// (totals, balances, stat-card numbers) without retyping fontWeight/size.
  static TextStyle valueOf(Color color, {double size = 14}) => GoogleFonts.poppins(
      fontSize: size, fontWeight: FontWeight.w800, color: color);
}