import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand Colours ──────────────────────────────────────────────────────────
  static const Color vyaparRed       = Color(0xFFE31E24);
  static const Color primaryBlue     = Color(0xFF1565C0);
  static const Color primaryOrange   = Color(0xFFE65100);
  static const Color primaryTeal     = Color(0xFF00695C);
  static const Color accentGold      = Color(0xFFFFC107);
  static const Color fishBlue        = Color(0xFF0D47A1);

  // ── Spacing & Radius constants ─────────────────────────────────────────────
  static const double radiusSm  = 8.0;
  static const double radiusMd  = 12.0;
  static const double radiusLg  = 16.0;
  static const double radiusXl  = 20.0;

  // ── Shared Text Theme ──────────────────────────────────────────────────────
  static TextTheme _buildTextTheme([TextTheme? base]) {
    return GoogleFonts.poppinsTextTheme(base).copyWith(
      displayLarge:  GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      displayMedium: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
      displaySmall:  GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
      headlineMedium:GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      titleLarge:    GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
      titleMedium:   GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
      titleSmall:    GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      bodyLarge:     GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium:    GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall:     GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w400, height: 1.4),
      labelLarge:    GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      labelMedium:   GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
      labelSmall:    GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.3),
    );
  }

  // ── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary:    primaryBlue,
        secondary:  primaryOrange,
        tertiary:   accentGold,
        surface:    Colors.white,
        background: const Color(0xFFF2F6FC),
        error:      const Color(0xFFD32F2F),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F6FC),
      textTheme: _buildTextTheme(base.textTheme),
      primaryTextTheme: _buildTextTheme(base.primaryTextTheme),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        iconTheme:        const IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
        toolbarHeight: 56,
      ),

      // Navigation Bar (bottom)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryBlue.withOpacity(0.13),
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? primaryBlue : const Color(0xFF94A3B8),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryBlue : const Color(0xFF94A3B8),
            size: 22,
          );
        }),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.06),
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          minimumSize: const Size(0, 46),
        ),
      ),

      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
          minimumSize: const Size(0, 46),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          minimumSize: const Size(0, 46),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primaryBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.8),
        ),
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
        hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
        errorStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFD32F2F)),
        floatingLabelStyle: GoogleFonts.poppins(fontSize: 12, color: primaryBlue, fontWeight: FontWeight.w500),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: vyaparRed,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        elevation: 0,
        selectedColor: primaryBlue.withOpacity(0.12),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF1F5F9),
        thickness: 1,
        space: 1,
      ),

      // List Tile
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 20,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B),
        ),
        subtitleTextStyle: GoogleFonts.poppins(
          fontSize: 11, color: const Color(0xFF64748B),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B),
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 13, color: const Color(0xFF475569), height: 1.5,
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        contentTextStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        elevation: 4,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: Color(0xFFCBD5E1),
        dragHandleSize: Size(40, 4),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryBlue,
        linearTrackColor: Color(0xFFDBEAFE),
      ),

      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? primaryBlue : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? primaryBlue.withOpacity(0.35)
              : const Color(0xFFCBD5E1);
        }),
      ),

      // Tab Bar
      tabBarTheme: TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: const Color(0xFFF1F5F9),
      ),
    );
  }

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const darkSurface    = Color(0xFF1E1E2E);
    const darkBackground = Color(0xFF12121C);
    const darkAppBar     = Color(0xFF1A1A2E);
    const darkCard       = Color(0xFF252535);
    const darkBorder     = Color(0xFF2D2D45);

    final base = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary:    const Color(0xFF90CAF9),
        secondary:  const Color(0xFFFFCC80),
        surface:    darkSurface,
        background: darkBackground,
        error:      const Color(0xFFEF5350),
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: _buildTextTheme(base.textTheme),

      appBarTheme: AppBarTheme(
        backgroundColor: darkAppBar,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkAppBar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF90CAF9).withOpacity(0.18),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF90CAF9) : const Color(0xFF64748B),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xFF90CAF9) : const Color(0xFF64748B),
            size: 22,
          );
        }),
      ),

      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E30),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFF90CAF9), width: 1.8),
        ),
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
        hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: vyaparRed,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white,
        ),
        subtitleTextStyle: GoogleFonts.poppins(
          fontSize: 11, color: const Color(0xFF94A3B8),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: Color(0xFF3D3D5E),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: const Color(0xFF90CAF9),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF90CAF9),
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: darkBorder,
      ),
    );
  }

  // ── Colour Theme Presets ───────────────────────────────────────────────────
  static const List<AppColorTheme> colorThemes = [
    AppColorTheme('Ocean Blue',   Color(0xFF1565C0), Color(0xFFE65100)),
    AppColorTheme('Forest Green', Color(0xFF2E7D32), Color(0xFFFF8F00)),
    AppColorTheme('Deep Purple',  Color(0xFF4527A0), Color(0xFFFF6F00)),
    AppColorTheme('Crimson Red',  Color(0xFFC62828), Color(0xFF1565C0)),
    AppColorTheme('Teal Wave',    Color(0xFF00695C), Color(0xFFE65100)),
  ];
}

class AppColorTheme {
  final String name;
  final Color  primary;
  final Color  accent;
  const AppColorTheme(this.name, this.primary, this.accent);
}