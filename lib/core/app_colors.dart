import 'package:flutter/material.dart';

/// Central color palette for Makan Mana v2.
///
/// Color distribution — 60 : 20 : 20
///   60% — Neutral base     (#F9FAFB light / #12121C dark)
///   20% — Discovery Orange (#FF8C42 light / #FF9E60 dark)  ← primary / CTA
///   20% — Terengganu Teal  (#2F6F7E light / #6AEBFC dark)  ← secondary / brand structure
class AppColors {
  AppColors._();

  // ─────────────────────────────────────────
  // 60% — NEUTRAL CANVAS (Backgrounds & large surface areas)
  // ─────────────────────────────────────────

  /// Scaffold / page background (Light: Off-white)
  static const Color background = Color(0xFFF8F9FA);

  /// Main surface / card background (Light: Pure White)
  static const Color surface = Colors.white;

  /// Slightly elevated surface (input fields, chips) (Light)
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  /// Elevated surface container (Light)
  static const Color surfaceContainer = Color(0xFFE2E8F0);

  // ─────────────────────────────────────────
  // 30% — Brand Structure & Trust (Teal / Slate)
  // ─────────────────────────────────────────

  /// Secondary brand color — Deep Teal (Light)
  static const Color secondary = Color.fromARGB(255, 17, 120, 130);

  /// Secondary variant — Deep Slate / Slate Blue (Light)
  static const Color secondaryLight = Color(0xFF1E293B);

  /// Teal tint — chip backgrounds, tag fills (Light)
  static const Color secondaryTint = Color(0xFFE0F2F1);

  /// Teal container (Light)
  static const Color secondaryContainer = Color(0xFFB2DFDB);

  /// Text / icon on teal backgrounds (Light)
  static const Color onSecondary = Colors.white;

  /// Tertiary — muted green (accent detail only)
  static const Color tertiary = Color.fromARGB(255, 101, 166, 130);

  // ─────────────────────────────────────────
  // 10% — BRAND ACTION / ACCENT (Orange / Saffron)
  // ─────────────────────────────────────────

  /// Primary CTA color — Vibrant Saffron Orange (Light)
  static const Color primary = Color(0xFFFF7A00);

  /// Lighter orange tint — chip fills, tag backgrounds (Light)
  static const Color primaryTint = Color(0xFFFFF0E6);

  /// Orange container — highlighted sections (Light)
  static const Color primaryContainer = Color.fromARGB(255, 252, 198, 153);

  /// Text / icon on orange backgrounds (Light)
  static const Color onPrimary = Colors.white;

  // ─────────────────────────────────────────
  // TEXT COLORS
  // ─────────────────────────────────────────

  /// Primary text — Slate (Light)
  static const Color textPrimary = Color(0xFF1E293B);

  /// Secondary / muted text — Deep Teal (Light)
  static const Color textSecondary = Color.fromARGB(255, 17, 120, 130);

  /// Hint / placeholder text
  static const Color textHint = Color(0xFF94A3B8);

  /// Text on surface (cards, white backgrounds)
  static const Color onSurface = Color.fromARGB(255, 27, 65, 59);

  /// Disabled text
  static const Color disabledText = Color(0xFF64748B);

  // ─────────────────────────────────────────
  // DARK THEME (60% Canvas / 30% Structure / 10% Action)
  // ─────────────────────────────────────────

  /// Dark scaffold background — Gray-ish dark purple
  static const Color darkBackground = Color(0xFF110F1B);

  /// Dark surface — Card background elevated off charcoal with grey-purple tint
  static const Color darkSurface = Color(0xFF1B1929);

  /// Dark elevated surface variant
  static const Color darkSurfaceVariant = Color(0xFF262337);

  /// Primary action in dark mode — Desaturated/Muted Saffron Orange
  static const Color darkPrimary = Color(0xFFE59866);

  /// Secondary brand structure in dark mode — Muted Soft Teal
  static const Color darkSecondary = Color.fromARGB(255, 95, 165, 172);

  /// Tertiary in dark mode — Desaturated muted green
  static const Color darkTertiary = Color.fromARGB(255, 88, 139, 113);

  /// Typography on dark surfaces — Off-white / Ice Blue
  static const Color darkOnSurface = Color(0xFFF5F5F7);

  /// Muted text on dark surfaces — Legible light purple-gray blend
  static const Color darkTextSecondary = Color(0xFF9E9BAE);

  // ─────────────────────────────────────────
  // SEMANTIC / UTILITY
  // ─────────────────────────────────────────

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color star = Color(0xFFF59E0B);
  static const Color favourite = Color(0xFFEF4444);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color scrim = Color(0x80000000);

  // ─────────────────────────────────────────
  // GRADIENTS (60:30:10 Monochromatic / Family Gradients)
  // ─────────────────────────────────────────

  /// "Terengganu Ocean" Gradient — Deep Teal to Fresh Mint (For Headers/Splash Screens)
  static const List<Color> oceanGradient = [
    Color(0xFF084147),
    Color(0xFF127A85),
  ];

  /// "Fresh Makan" Gradient — Deep Tangerine to Bright Saffron (For Primary Actions/Buttons)
  static const List<Color> freshMakanGradient = [
    Color(0xFFE05300),
    Color(0xFFFF8A00),
  ];

  // ─────────────────────────────────────────
  // LDA TOPIC TAG COLORS
  // ─────────────────────────────────────────

  static const Color ldaTagText = Color(0xFF0D5C63);
  static const Color ldaTagBackground = Color(0xFFE0F2F1);
  static const Color ldaTagBorder = Color(0xFF80CBC4);

  // ─────────────────────────────────────────
  // KBF MATCH SCORE COLORS
  // ─────────────────────────────────────────

  static const Color kbfMatchColor = Color(0xFFFF7A00);
  static const Color kbfMatchTrack = Color(0xFFFFD4B0);

  // ─────────────────────────────────────────
  // GANUBOT CHAT COLORS
  // ─────────────────────────────────────────

  static const Color botBubble = Color(0xFFE0F2F1);
  static const Color botBubbleText = Color(0xFF0D5C63);
  static const Color userBubble = Color(0xFFF1F5F9);
  static const Color userBubbleText = Color(0xFF1E293B);
  static const Color chatChipBackground = Color(0xFFFF7A00);

  // ─────────────────────────────────────────
  // ADAPTIVE HELPERS
  // ─────────────────────────────────────────

  /// Returns light or dark primary (orange) based on brightness.
  static Color adaptivePrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPrimary : primary;

  /// Returns light or dark secondary (teal) based on brightness.
  static Color adaptiveSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSecondary
      : secondary;

  /// Returns tertiary based on brightness.
  static Color adaptiveTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTertiary : tertiary;
}
