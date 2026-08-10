import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color tokens ──────────────────────────────────────────
// 减重助手 — 运动测量仪器的视觉语言
// 不是典型的健康App绿色，而是电光绿+深墨+珊瑚的搭配

class C {
  C._();

  static const ink = Color(0xFF1A1B23);       // Deep Ink — 主文字、深色面
  static const paper = Color(0xFFF5F6FA);     // Paper White — 主背景
  static const lime = Color(0xFFC6FF3D);      // Electric Lime — 签名强调色
  static const coral = Color(0xFFFF6B47);     // Coral Flame — 卡路里、食物
  static const steel = Color(0xFF2D9CDB);     // Sky Steel — 跑步、数据
  static const slate = Color(0xFF9CA3AF);     // Muted Slate — 次要文字
  static const ink2 = Color(0xFF2A2B33);      // 次级深色面
  static const line = Color(0xFFE8E9EE);      // 分割线
  static const limeDim = Color(0xFF7BCC1F);   // 暗化的电光绿
  static const coralDim = Color(0xFFD4502E);  // 暗化的珊瑚
}

// ─── Text styles ───────────────────────────────────────────

class T {
  T._();

  // Display — SpaceGrotesk: 几何、运动感，用于标题和大数字
  static TextStyle get display => GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        color: C.ink,
        height: 1.1,
      );

  // Mono — SpaceMono: 表格数字，用于数据读数（体重、卡路里、距离）
  static TextStyle get mono => GoogleFonts.spaceMono(
        fontWeight: FontWeight.w700,
        color: C.ink,
      );

  // Body — 系统默认字体（iOS PingFang / Android Noto Sans SC）
  static const TextStyle body = TextStyle(
    fontFamily: null,
    color: C.ink,
    height: 1.5,
  );

  // 预设组合
  static TextStyle get h1 => display.copyWith(fontSize: 34, letterSpacing: -0.5);
  static TextStyle get h2 => display.copyWith(fontSize: 26, letterSpacing: -0.3);
  static TextStyle get h3 => display.copyWith(fontSize: 20);
  static TextStyle get h4 => display.copyWith(fontSize: 17, fontWeight: FontWeight.w600);

  static TextStyle get numXl => mono.copyWith(fontSize: 48, letterSpacing: -2);
  static TextStyle get numLg => mono.copyWith(fontSize: 32, letterSpacing: -1);
  static TextStyle get numMd => mono.copyWith(fontSize: 22, letterSpacing: -0.5);
  static TextStyle get numSm => mono.copyWith(fontSize: 16);

  static TextStyle get bodyL => body.copyWith(fontSize: 16);
  static TextStyle get bodyM => body.copyWith(fontSize: 14, color: C.ink);
  static TextStyle get bodyS => body.copyWith(fontSize: 13, color: C.slate);
  static TextStyle get caption => body.copyWith(fontSize: 11, color: C.slate);

  static TextStyle get label => body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: C.ink,
      );
  static TextStyle get labelSlate => body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: C.slate,
      );
}

// ─── Theme ─────────────────────────────────────────────────

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: C.paper,
        colorScheme: const ColorScheme.light(
          primary: C.limeDim,
          secondary: C.steel,
          tertiary: C.coral,
          surface: Colors.white,
          error: C.coral,
          onPrimary: C.ink,
          onSecondary: Colors.white,
          onSurface: C.ink,
          outline: C.line,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: C.paper,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: T.h3,
          iconTheme: const IconThemeData(color: C.ink),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.limeDim, width: 2),
          ),
          labelStyle: T.bodyM,
          hintStyle: T.bodyS,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: C.ink,
          unselectedItemColor: C.slate,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: C.line,
          thickness: 1,
          space: 1,
        ),
      );
}
