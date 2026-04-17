import 'package:flutter/material.dart';

class AppTheme {
  // 1. Color Palette (Metallic & Glass base)
  static const Color deepCarbon = Color(0xFF1E1F22);
  static const Color metallicGray = Color(0xFF3A3D40);
  static const Color glassWhite = Colors.white;
  static const Color textMuted = Color(0xFFA0AAB2);

  // 2. Main ThemeData to inject into MaterialApp
  static ThemeData get darkMetallicTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Helvetica', 
      scaffoldBackgroundColor: deepCarbon,
      
      // Global Text Styling
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: glassWhite, letterSpacing: -0.5),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: glassWhite),
        bodyLarge: TextStyle(fontSize: 16, color: glassWhite),
        bodyMedium: TextStyle(fontSize: 14, color: textMuted),
      ),
      
      // Global Button Styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: glassWhite.withOpacity(0.08),
          foregroundColor: glassWhite,
          elevation: 0, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: glassWhite.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        ),
      ),

      // Global TextField Styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassWhite.withOpacity(0.05),
        hintStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}