import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette extracted from the DashTab design system (`index (2).html`).
class AppColors {
  // Light theme
  static const bg = Color(0xFFF4F5F9);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFF8F9FC);
  static const text = Color(0xFF181B25);
  static const text2 = Color(0xFF5D6577);
  static const text3 = Color(0xFF9AA1B2);
  static const line = Color(0xFFE7E9F0);
  static const line2 = Color(0xFFF0F1F6);

  // Brand
  static const brand = Color(0xFFEA5527);
  static const brand2 = Color(0xFFD64514);
  static const brandT = Color(0xFFFDEEE7);
  static const brandT2 = Color(0xFFF9D9CB);

  // Semantic
  static const green = Color(0xFF17A34A);
  static const greenT = Color(0xFFE4F6EA);
  static const blue = Color(0xFF2563EB);
  static const blueT = Color(0xFFE3EDFD);
  static const amber = Color(0xFFC77414);
  static const amberT = Color(0xFFFCF1DC);
  static const red = Color(0xFFDC2626);
  static const redT = Color(0xFFFCE8E8);
  static const violet = Color(0xFF7C3AED);
  static const violetT = Color(0xFFEFE7FD);
  static const teal = Color(0xFF0D9488);
  static const tealT = Color(0xFFDFF3F1);

  // Sidebar
  static const side = Color(0xFF15161D);
  static const side2 = Color(0xFF1E2029);

  // Dark theme
  static const darkBg = Color(0xFF0E1015);
  static const darkCard = Color(0xFF161922);
  static const darkCard2 = Color(0xFF1B1F2A);
  static const darkText = Color(0xFFECEEF4);
  static const darkText2 = Color(0xFFA6ADBE);
  static const darkText3 = Color(0xFF6E7686);
  static const darkLine = Color(0xFF252A37);
  static const darkLine2 = Color(0xFF1F2430);
  static const darkSide = Color(0xFF101218);
  static const darkSide2 = Color(0xFF181B24);
  static const darkBrandT = Color(0xFF2B1910);
  static const darkBrandT2 = Color(0xFF3C2214);

  // Radius
  static const r = 18.0;
  static const r2 = 14.0;
  static const r3 = 10.0;
}

class AppTheme {
  /// Shadows similar to the HTML `--shadow` token.
  static List<BoxShadow> get _shadow => const [
    BoxShadow(
      color: Color(0x0D141828), // rgba(20,24,40,.05)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x1F141828), // rgba(20,24,40,.12)
      blurRadius: 30,
      offset: Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get _shadowLg => const [
    BoxShadow(
      color: Color(0x40141828), // rgba(20,24,40,.25)
      blurRadius: 60,
      offset: Offset(0, 24),
    ),
  ];

  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.brand2,
      onSecondary: Colors.white,
      error: AppColors.red,
      onError: Colors.white,
      surface: isDark ? AppColors.darkCard : AppColors.card,
      onSurface: isDark ? AppColors.darkText : AppColors.text,
      surfaceContainerHighest: isDark ? AppColors.darkCard2 : AppColors.card2,
      onSurfaceVariant: isDark ? AppColors.darkText2 : AppColors.text2,
      outline: isDark ? AppColors.darkLine : AppColors.line,
      outlineVariant: isDark ? AppColors.darkLine2 : AppColors.line2,
      surfaceContainerLowest: isDark ? AppColors.darkBg : AppColors.bg,
      inverseSurface: isDark ? AppColors.darkText : AppColors.text,
      onInverseSurface: isDark ? AppColors.darkBg : AppColors.bg,
    );

    final baseTextColor = isDark ? AppColors.darkText : AppColors.text;
    final secondaryTextColor = isDark ? AppColors.darkText2 : AppColors.text2;

    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      fontFamily: GoogleFonts.inter().fontFamily,
      canvasColor: isDark ? AppColors.darkCard : AppColors.card,
      dividerColor: isDark ? AppColors.darkLine2 : AppColors.line2,
      splashFactory: InkSparkle.splashFactory,
      shadowColor: AppColors.brand.withValues(alpha: 0.2),
    );

    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
        foregroundColor: baseTextColor,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: baseTextColor,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r),
          side: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
        ),
        shadowColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkLine2 : AppColors.line2,
        thickness: 1,
        space: 1,
      ),
      textTheme: _buildTextTheme(isDark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: baseTextColor,
          side: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkText3 : AppColors.text3,
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.02,
        ),
        prefixIconColor: isDark ? AppColors.darkText3 : AppColors.text3,
        suffixIconColor: isDark ? AppColors.darkText3 : AppColors.text3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkLine : AppColors.line,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkLine : AppColors.line,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.black26,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF181B25),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
        selectedColor: AppColors.brand,
        side: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: TextStyle(
          color: baseTextColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: isDark ? AppColors.darkLine : AppColors.line,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          isDark ? AppColors.darkLine : AppColors.line,
        ),
        radius: const Radius.circular(99),
        thickness: const WidgetStatePropertyAll(8),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: secondaryTextColor,
        textColor: baseTextColor,
      ),
    );
  }

  static TextTheme _buildTextTheme(bool isDark) {
    final base = isDark ? AppColors.darkText : AppColors.text;
    final text2 = isDark ? AppColors.darkText2 : AppColors.text2;
    return TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: base,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: base,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: base,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: base,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: base,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: base,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: base,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: base,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: base,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: base,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: text2,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: base,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: text2,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.04,
        color: text2,
      ),
    );
  }

  /// CSS-style drop shadow used by cards in the design.
  static List<BoxShadow> get shadow => _shadow;
  static List<BoxShadow> get shadowLg => _shadowLg;
}
