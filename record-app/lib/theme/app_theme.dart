import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 主色调 - 健康绿色系
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color lightGreen = Color(0xFF81C784);
  static const Color darkGreen = Color(0xFF388E3C);
  static const Color accentGreen = Color(0xFFE8F5E8);
  
  // 辅助色彩
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color warmOrange = Color(0xFFFF9800);
  static const Color softPurple = Color(0xFF9C27B0);
  static const Color softRed = Color(0xFFF44336);
  static const Color softYellow = Color(0xFFFFEB3B);
  
  // 中性色彩
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  
  // 渐变色彩
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightGreen, primaryGreen],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
  );
  
  // 文字样式
  static TextTheme get textTheme => TextTheme(
    displayLarge: GoogleFonts.pingFangSc(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: GoogleFonts.pingFangSc(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: textPrimary,
      letterSpacing: -0.5,
    ),
    displaySmall: GoogleFonts.pingFangSc(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: -0.25,
    ),
    headlineLarge: GoogleFonts.pingFangSc(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineMedium: GoogleFonts.pingFangSc(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineSmall: GoogleFonts.pingFangSc(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleLarge: GoogleFonts.pingFangSc(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleMedium: GoogleFonts.pingFangSc(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    titleSmall: GoogleFonts.pingFangSc(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    bodyLarge: GoogleFonts.pingFangSc(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textPrimary,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.pingFangSc(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textPrimary,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.pingFangSc(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: textSecondary,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.pingFangSc(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    labelMedium: GoogleFonts.pingFangSc(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    labelSmall: GoogleFonts.pingFangSc(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: textSecondary,
    ),
  );
  
  // 主题数据
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      primaryContainer: accentGreen,
      secondary: accentBlue,
      secondaryContainer: Color(0xFFE3F2FD),
      tertiary: warmOrange,
      tertiaryContainer: Color(0xFFFFF3E0),
      surface: surface,
      surfaceVariant: Color(0xFFF5F5F5),
      background: background,
      error: softRed,
      errorContainer: Color(0xFFFFEBEE),
      onPrimary: Colors.white,
      onPrimaryContainer: darkGreen,
      onSecondary: Colors.white,
      onSecondaryContainer: Color(0xFF0D47A1),
      onTertiary: Colors.white,
      onTertiaryContainer: Color(0xFFE65100),
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      onBackground: textPrimary,
      onError: Colors.white,
      onErrorContainer: Color(0xFFB71C1C),
      outline: divider,
      shadow: Colors.black12,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.headlineMedium,
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: softRed, width: 1),
      ),
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: textHint),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primaryGreen,
      unselectedItemColor: textSecondary,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

// 常用样式快捷访问类
class AppTextStyles {
  // 标题样式
  static TextStyle get heading1 => AppTheme.textTheme.displayLarge!;
  static TextStyle get heading2 => AppTheme.textTheme.displayMedium!;
  static TextStyle get heading3 => AppTheme.textTheme.displaySmall!;
  static TextStyle get subtitle1 => AppTheme.textTheme.headlineMedium!;
  static TextStyle get subtitle2 => AppTheme.textTheme.headlineSmall!;
  
  // 正文样式
  static TextStyle get bodyLarge => AppTheme.textTheme.bodyLarge!;
  static TextStyle get bodyMedium => AppTheme.textTheme.bodyMedium!;
  static TextStyle get bodySmall => AppTheme.textTheme.bodySmall!;
  
  // 标签样式
  static TextStyle get labelLarge => AppTheme.textTheme.labelLarge!;
  static TextStyle get labelMedium => AppTheme.textTheme.labelMedium!;
  static TextStyle get labelSmall => AppTheme.textTheme.labelSmall!;
  
  // 卡片标题
  static TextStyle get cardTitle => AppTheme.textTheme.titleLarge!;
  static TextStyle get cardSubtitle => AppTheme.textTheme.bodyMedium!;
}