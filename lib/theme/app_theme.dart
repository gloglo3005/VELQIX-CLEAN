import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Couleurs de marque (identiques en clair et en sombre) ─────────────────
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF0A2E6E);
  static const Color accent = Color(0xFFFF6F00);
  static const Color accentLight = Color(0xFFFFB300);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Palette claire (constantes) ───────────────────────────────────────────
  static const Color _lBackground    = Color(0xFFF5F7FA);
  static const Color _lSurface       = Color(0xFFFFFFFF);
  static const Color _lCardBg        = Color(0xFFFFFFFF);
  static const Color _lTextPrimary   = Color(0xFF1A1A2E);
  static const Color _lTextSecondary = Color(0xFF6B7280);
  static const Color _lTextHint      = Color(0xFFADB5BD);
  static const Color _lDivider       = Color(0xFFE5E7EB);
  static const Color _lBorder        = Color(0xFFD1D5DB);

  // ─── Palette sombre (constantes) ───────────────────────────────────────────
  static const Color darkBg      = Colors.transparent; // conservé pour compatibilité
  static const Color darkBgSolid = Color(0xFF1A1F2E);  // fond principal
  static const Color darkSurface = Color(0xFF242B3D);  // cards/surfaces
  static const Color darkCard    = Color(0xFF2D3548);  // cards légèrement plus claires
  static const Color darkTxt     = Color(0xFFFFFFFF);  // texte principal
  static const Color darkTxtSec  = Color(0xFFB0BEC5);  // texte secondaire
  static const Color darkTxtHint = Color(0xFF8A94A6);  // texte discret
  static const Color darkDivider = Color(0xFF3A4258);  // séparateurs / bordures

  /// true quand le thème sombre est actif. Mis à jour par VelQixApp (main.dart)
  /// à chaque changement de thème : c'est ce qui permet aux couleurs ci-dessous
  /// de s'adapter partout, même dans les écrans qui les utilisent directement.
  static bool isDark = false;

  // ─── Couleurs adaptatives (clair OU sombre selon le thème actif) ───────────
  // ⚠️ Avant : `static const` (toujours claires) → en mode sombre, cartes
  // blanches et textes illisibles sur tous les écrans qui les utilisaient.
  // Ce sont maintenant des getters : ils ne peuvent plus servir dans une
  // expression `const` (supprimer le `const` devant le widget concerné).
  static Color get background    => isDark ? darkBgSolid : _lBackground;
  static Color get surface       => isDark ? darkSurface : _lSurface;
  static Color get cardBg        => isDark ? darkCard    : _lCardBg;
  static Color get textPrimary   => isDark ? darkTxt     : _lTextPrimary;
  static Color get textSecondary => isDark ? darkTxtSec  : _lTextSecondary;
  static Color get textHint      => isDark ? darkTxtHint : _lTextHint;
  static Color get divider       => isDark ? darkDivider : _lDivider;
  static Color get border        => isDark ? darkDivider : _lBorder;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6F00), Color(0xFFFFB300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        surface: _lSurface,
        error: error,
      ),
      scaffoldBackgroundColor: _lBackground,
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: _lTextPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _lTextPrimary,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _lTextPrimary,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lTextPrimary,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lTextPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _lTextPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lTextPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: _lTextPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _lTextSecondary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: _lTextSecondary,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _lSurface,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lTextPrimary,
        ),
        iconTheme: const IconThemeData(color: _lTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.poppins(
          color: _lTextHint,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.poppins(
          color: _lTextSecondary,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: _lCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lSurface,
        selectedItemColor: primary,
        unselectedItemColor: _lTextHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lBackground,
        selectedColor: primary.withOpacity(0.1),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: _lDivider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ─── Helpers basés sur le contexte (conservés) ─────────────────────────────
  static bool _darkOf(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color adaptiveSurface(BuildContext context)  => _darkOf(context) ? darkSurface : _lSurface;
  static Color adaptiveCard(BuildContext context)     => _darkOf(context) ? darkCard : _lSurface;
  static Color adaptiveBg(BuildContext context)       => _darkOf(context) ? darkBgSolid : _lBackground;
  static Color adaptiveBorder(BuildContext context)   => _darkOf(context) ? darkDivider : _lBorder;
  static Color adaptiveText(BuildContext context)     => _darkOf(context) ? darkTxt : _lTextPrimary;
  static Color adaptiveTextSec(BuildContext context)  => _darkOf(context) ? darkTxtSec : _lTextSecondary;

  static ThemeData get darkTheme {
    const Color surfaceC = darkSurface;
    const Color card     = darkCard;
    const Color txtPrim  = darkTxt;
    const Color txtSec   = darkTxtSec;
    const Color txtHint  = darkTxtHint;
    const Color div      = darkDivider;

    final baseText = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: txtPrim, displayColor: txtPrim);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryLight,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surfaceC,
        onSurface: txtPrim,
        onSurfaceVariant: txtSec,
        outline: div,
      ),
      // ⚠️ Avant : scaffoldBackgroundColor = transparent → fond noir/vide.
      scaffoldBackgroundColor: darkBgSolid,
      canvasColor: darkBgSolid,
      cardColor: card,
      dialogBackgroundColor: surfaceC,
      textTheme: baseText.copyWith(
        bodyLarge:  GoogleFonts.poppins(fontSize: 16, color: txtPrim),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: txtSec),
        bodySmall:  GoogleFonts.poppins(fontSize: 12, color: txtSec),
        titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: txtPrim),
        titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: txtPrim),
        labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: txtPrim),
      ),
      iconTheme: const IconThemeData(color: txtPrim),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBgSolid,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: txtPrim),
        iconTheme: const IconThemeData(color: txtPrim),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: div),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceC,
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: txtPrim),
        contentTextStyle: GoogleFonts.poppins(fontSize: 14, color: txtSec),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceC,
        modalBackgroundColor: surfaceC,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceC,
        textStyle: GoogleFonts.poppins(fontSize: 14, color: txtPrim),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: GoogleFonts.poppins(color: txtPrim),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: txtPrim,
        iconColor: txtSec,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : txtSec),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primaryLight : div),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: primaryLight.withOpacity(0.25),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: txtPrim),
        side: const BorderSide(color: div),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txtPrim,
          side: const BorderSide(color: primaryLight, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: GoogleFonts.poppins(color: txtSec, fontSize: 14),
        hintStyle: GoogleFonts.poppins(color: txtHint, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: div)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: div)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryLight, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: error)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBgSolid,
        selectedItemColor: primaryLight,
        unselectedItemColor: txtHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryLight),
      dividerTheme: const DividerThemeData(color: div, thickness: 1, space: 1),
    );
  }
}