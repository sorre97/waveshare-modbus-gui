import 'package:flutter/material.dart';

// ── Palette (from relayctrl_pro_integrated_dashboard/code.html) ─────────────
const Color kBgBody = Color(0xFF050505);
const Color kSurface = Color(0xFF0B1326);
const Color kSurfaceContainer = Color(0xFF171F33);
const Color kSurfaceContainerHigh = Color(0xFF222A3D);
const Color kSurfaceContainerHighest = Color(0xFF2D3449);
const Color kSurfaceVariant = Color(0xFF2D3449);
const Color kPrimary = Color(0xFF6BFB9A); // neon green
const Color kPrimaryDim = Color(
  0xFF4ADE80,
); // slightly dimmer green (used in glows)
const Color kOnSurface = Color(0xFFDAE2FD);
const Color kOnSurfaceVariant = Color(0xFFBCCABB);
const Color kOutline = Color(0xFF869486);
const Color kSecondary = Color(0xFFD0BCFF); // purple accent (for RX in console)
const Color kError = Color(0xFFFFB4AB);

// Glow values (for BoxDecoration)
const Color kNeonGlowBorder = Color(0x664ADE80); // rgba(74,222,128,0.4)
const Color kNeonGlowBg = Color(0x144ADE80); // rgba(74,222,128,0.08)
const Color kNeonGlowShadow = Color(0x334ADE80); // rgba(74,222,128,0.2)

// ── Theme ─────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBgBody,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      primary: kPrimary,
      surface: kSurface,
      onSurface: kOnSurface,
      secondary: kSecondary,
      error: kError,
    ),
    textTheme: const TextTheme(
      // h1: 32px
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: kOnSurface,
      ),
      // h2: 24px
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: kOnSurface,
      ),
      // body-md: 16px
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: kOnSurface,
      ),
      // body-sm: 14px
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: kOnSurfaceVariant,
      ),
      // label-caps: 12px Space Grotesk, tracked
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        fontFamily: 'SpaceGrotesk',
        color: kOnSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(
        color: kOnSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  );
}
