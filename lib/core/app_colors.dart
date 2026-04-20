import 'package:flutter/material.dart';

/// Central color palette for Terengganu Restaurant Recommender.
/// All colors are derived from the theme defined in main.dart.
class AppColors {
  AppColors._(); // Prevent instantiation

  // ─────────────────────────────────────────
  // LIGHT THEME COLORS
  // ─────────────────────────────────────────

  /// Primary brand color — Orange
  static const Color primary = Color(0xFFFF8C42);

  /// Secondary brand color — Teal
  static const Color secondary = Color(0xFF2F6F7E);

  /// Accent color — Green
  static const Color tertiary = Color(0xFF4E7F64);

  /// Main surface / card background
  static const Color surface = Colors.white;

  /// Scaffold / page background
  static const Color background = Color(0xFFF9FAFB);

  /// Primary text color
  static const Color textPrimary = Color(0xFF3A2F2F);

  /// Secondary / muted text color
  static const Color textSecondary = Color(0xFF4096AA);

  /// Text on top of primary color (e.g. white text on orange button)
  static const Color onPrimary = Colors.white;

  /// Text on top of secondary color
  static const Color onSecondary = Colors.white;

  /// Text on top of surface/card
  static const Color onSurface = Color(0xFF3A2F2F);

  // ─────────────────────────────────────────
  // DARK THEME COLORS
  // ─────────────────────────────────────────

  /// Primary color in dark mode — lighter orange
  static const Color darkPrimary = Color(0xFFFF9E60);

  /// Secondary color in dark mode — lighter teal
  static const Color darkSecondary = Color(0xFF4096AA);

  /// Accent color in dark mode — lighter green
  static const Color darkTertiary = Color(0xFF6BA685);

  /// Surface color in dark mode
  static const Color darkSurface = Color(0xFF1A1C1E);

  /// Text color on dark surfaces
  static const Color darkOnSurface = Color(0xFFE2E2E6);

  /// AppBar background in dark mode
  static const Color darkAppBar = Color(0xFF1A1C1E);

  // ─────────────────────────────────────────
  // SEMANTIC / UTILITY COLORS
  // ─────────────────────────────────────────

  /// Success state — e.g. saved to wishlist
  static const Color success = Color(0xFF22C55E);

  /// Error state — e.g. login failed
  static const Color error = Color(0xFFEF4444);

  /// Warning state
  static const Color warning = Color(0xFFFACC15);

  /// Divider / border lines
  static const Color divider = Color(0xFFE5E7EB);

  /// Disabled button or input
  static const Color disabled = Color(0xFFD1D5DB);

  /// Disabled text
  static const Color disabledText = Color(0xFF9CA3AF);

  /// Star rating color
  static const Color star = Color(0xFFFBBF24);

  /// Overlay scrim (e.g. behind modals)
  static const Color scrim = Color(0x80000000);

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  /// Returns primary or darkPrimary based on current brightness
  static Color adaptivePrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary
        : primary;
  }

  /// Returns secondary or darkSecondary based on current brightness
  static Color adaptiveSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSecondary
        : secondary;
  }
}