import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TheBridge Premium Design System
/// Glassmorphic, modern, mobile-first design language
class AppTheme {
  // ========== COLOR PALETTE ==========

  // Primary gradient colors
  static const Color primaryStart = Color(0xFF6366F1); // Indigo
  static const Color primaryEnd = Color(0xFF8B5CF6);   // Purple
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentTeal = Color(0xFF14B8A6);

  // Dark theme colors
  static const Color darkBg = Color(0xFF0F0F23);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color darkElevated = Color(0xFF1E2A4A);

  // Glassmorphism
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassSubtle = Color(0x0DFFFFFF);

  // Status colors
  static const Color online = Color(0xFF22C55E);
  static const Color away = Color(0xFFF59E0B);
  static const Color busy = Color(0xFFEF4444);
  static const Color offline = Color(0xFF6B7280);

  // Message bubbles
  static const Color myMessageBg = Color(0xFF6366F1);
  static const Color otherMessageBg = Color(0xFF1E2A4A);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ========== GRADIENTS ==========

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentCyan, accentTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [darkBg, Color(0xFF0A0A1A), Color(0xFF0F0F23)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x1A6366F1), Color(0x0D6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [Color(0x00FFFFFF), Color(0x15FFFFFF), Color(0x00FFFFFF)],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  // ========== DECORATIONS ==========

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: glassWhite,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: glassBorder, width: 0.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 20,
        spreadRadius: -5,
      ),
    ],
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: glassBorder, width: 0.5),
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: darkElevated,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: glassBorder, width: 0.5),
    boxShadow: [
      BoxShadow(
        color: primaryStart.withValues(alpha: 0.1),
        blurRadius: 20,
        spreadRadius: -5,
      ),
    ],
  );

  // ========== THEME DATA ==========

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: primaryStart,
      secondary: accentCyan,
      surface: darkSurface,
      onSurface: textPrimary,
      error: busy,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBg.withValues(alpha: 0.8),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface.withValues(alpha: 0.95),
      selectedItemColor: primaryStart,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glassWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glassBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glassBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryStart, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryStart,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: glassBorder, width: 0.5),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: glassBorder,
      thickness: 0.5,
    ),
    iconTheme: const IconThemeData(
      color: textSecondary,
      size: 24,
    ),
  );
}
