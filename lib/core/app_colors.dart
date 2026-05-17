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
  // 60% — NEUTRAL BASE
  // ─────────────────────────────────────────

  /// Scaffold / page background
  static const Color background = Color(0xFFF9FAFB);

  /// Main surface / card background
  static const Color surface = Colors.white;

  /// Slightly elevated surface (input fields, chips)
  static const Color surfaceVariant = Color(0xFFF0F2F4);

  /// Elevated surface container
  static const Color surfaceContainer = Color(0xFFF3F4F6);

  // ─────────────────────────────────────────
  // 20% — DISCOVERY ORANGE (Primary / CTA)
  // Used for: ElevatedButton, "See All", active nav pill,
  //           FAB, rating chips, primary gradients.
  // ─────────────────────────────────────────

  /// Primary CTA color — Discovery Orange
  static const Color primary = Color(0xFFFF8C42);

  /// Lighter orange tint — chip fills, tag backgrounds
  static const Color primaryTint = Color(0xFFFFF0E6);

  /// Orange container — highlighted sections
  static const Color primaryContainer = Color(0xFFFFD4B0);

  /// Text / icon on orange backgrounds
  static const Color onPrimary = Colors.white;

  // ─────────────────────────────────────────
  // 20% — TERENGGANU TEAL (Secondary / Brand Structure)
  // Used for: headers, map pins, attribute badges,
  //           section markers, compass, tags.
  // ─────────────────────────────────────────

  /// Secondary brand color — Terengganu Teal
  static const Color secondary = Color(0xFF2F6F7E);

  /// Lighter teal variant — for large header surfaces
  static const Color secondaryLight = Color(0xFF3D8A9E);

  /// Teal tint — chip backgrounds, tag fills
  static const Color secondaryTint = Color(0xFFE0F2F1);

  /// Teal container — highlighted info sections
  static const Color secondaryContainer = Color(0xFFB2DFDB);

  /// Text / icon on teal backgrounds
  static const Color onSecondary = Colors.white;

  /// Tertiary — muted green (accent detail only)
  static const Color tertiary = Color(0xFF4E7F64);

  // ─────────────────────────────────────────
  // TEXT COLORS
  // ─────────────────────────────────────────

  /// Primary text — warm dark
  static const Color textPrimary = Color(0xFF3A2F2F);

  /// Secondary / muted text
  static const Color textSecondary = Color(0xFF4096AA);

  /// Hint / placeholder text
  static const Color textHint = Color(0xFF90A4AE);

  /// Text on surface (cards, white backgrounds)
  static const Color onSurface = Color(0xFF3A2F2F);

  /// Disabled text
  static const Color disabledText = Color(0xFF9CA3AF);

  // ─────────────────────────────────────────
  // DARK THEME
  // ─────────────────────────────────────────

  /// Dark scaffold background
  static const Color darkBackground = Color(0xFF12121C);

  /// Dark surface — card / sheet background
  static const Color darkSurface = Color(0xFF1E1E2E);

  /// Dark elevated surface
  static const Color darkSurfaceVariant = Color(0xFF2A2A3E);

  /// Primary in dark mode — Soft Orange (high contrast on dark bg)
  static const Color darkPrimary = Color(0xFFFF9E60);

  /// Secondary in dark mode — High-visibility Cyan/Teal
  static const Color darkSecondary = Color(0xFF6AEBFC);

  /// Tertiary in dark mode — Muted green
  static const Color darkTertiary = Color(0xFF6BA685);

  /// Text on dark surfaces
  static const Color darkOnSurface = Color(0xFFE8E8F0);

  /// Muted text on dark surfaces
  static const Color darkTextSecondary = Color(0xFFB0BEC5);

  // ─────────────────────────────────────────
  // SEMANTIC / UTILITY
  // ─────────────────────────────────────────

  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFFACC15);
  static const Color star = Color(0xFFFBBF24);
  static const Color favourite = Color(0xFFEF4444);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color disabled = Color(0xFFD1D5DB);
  static const Color scrim = Color(0x80000000);

  // ─────────────────────────────────────────
  // LDA TOPIC TAG COLORS
  // ─────────────────────────────────────────

  static const Color ldaTagText = Color(0xFF2F6F7E);
  static const Color ldaTagBackground = Color(0xFFE0F2F1);
  static const Color ldaTagBorder = Color(0xFF80CBC4);

  // ─────────────────────────────────────────
  // KBF MATCH SCORE COLORS
  // ─────────────────────────────────────────

  static const Color kbfMatchColor = Color(0xFFFF8C42);
  static const Color kbfMatchTrack = Color(0xFFFFD4B0);

  // ─────────────────────────────────────────
  // GANUBOT CHAT COLORS
  // ─────────────────────────────────────────

  static const Color botBubble = Color(0xFFE0F2F1);
  static const Color botBubbleText = Color(0xFF1A3A40);
  static const Color userBubble = Color(0xFFF0F2F4);
  static const Color userBubbleText = Color(0xFF3A2F2F);
  static const Color chatChipBackground = Color(0xFFFF8C42);

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
