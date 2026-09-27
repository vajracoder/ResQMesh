import 'package:flutter/material.dart';

/// Modern high-visibility Emergency Theme for ResQMesh.
/// Optimized for low-light survival scenarios and low-power battery conservation.
class AppTheme {
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color cardBackground = Color(0xFF181C24);
  static const Color cardBorder = Color(0xFF282F3D);

  static const Color sosRed = Color(0xFFFF334B);
  static const Color sosRedMuted = Color(0x33FF334B);
  static const Color alertAmber = Color(0xFFFFB300);
  static const Color alertAmberMuted = Color(0x33FFB300);
  static const Color activeGreen = Color(0xFF00E676);
  static const Color activeGreenMuted = Color(0x2200E676);
  static const Color meshCyan = Color(0xFF00D2FF);

  static const Color textPrimary = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: meshCyan,
        secondary: sosRed,
        surface: cardBackground,
        error: sosRed,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: meshCyan,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF13171F),
        selectedItemColor: meshCyan,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
