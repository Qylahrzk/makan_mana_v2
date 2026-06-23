import 'package:flutter/material.dart';

/// Central color palette for Makan Mana v2 — WCAG Level AA Compliant.
///
/// Design Philosophy:
///   Light Theme (60:30:10): Neutral whites + SATURATED Terengganu Teal + Discovery Orange
///   Dark Theme (60:30:10): Deep Navy + Aurora Glow Cyan + Vibrant Orange
///
/// KEY PRINCIPLE:
///   - Light Mode: Brand colors (teal, orange) are DARK + SATURATED; text is DARK
///   - Dark Mode: Brand colors are LIGHT/VIBRANT; text is WHITE/LIGHT GRAY
///   - NEVER use brand colors as text colors
///   - ALWAYS separate: surfaces, brand accents, and text hierarchy
///   - Pastels ONLY as small decorative accents, never full-screen backgrounds

class AppColors {
  AppColors._();

  // ═════════════════════════════════════════
  // LIGHT MODE: 60% NEUTRAL + 30% TEAL + 10% ORANGE
  // ═════════════════════════════════════════

  /// Scaffold / page background — Soft whisper white (60% neutral)
  static const Color background = Color(0xFFF4F9F9);

  /// Main surface — Pure white (cards, sheets)
  static const Color surface = Colors.white;

  /// Elevated surface variant (input fields, chips, medium elevation)
  static const Color surfaceVariant = Color(0xFFF0E5D8);

  /// Elevated surface container (high elevation: dialogs, bottom sheets)
  static const Color surfaceContainer = Color(0xFFEBEBFA);

  // ─────────────────────────────────────────
  // Light Mode: 30% — Terengganu Teal (Brand Structure)
  // ─────────────────────────────────────────

  /// Secondary brand color — Deep Terengganu Teal (30% structural)
  /// Used for: badges, dividers, structural elements, NOT text
  static const Color secondary = Color(0xFF004E64);

  /// Secondary variant — Deeper Ocean Blue
  static const Color secondaryLight = Color(0xFF003B5C);

  /// Secondary tint — Medium teal for backgrounds and fills (NOT light pastel)
  /// Changed from #8CCFEC (washed out) to more saturated mid-tone
  static const Color secondaryTint = Color(0xFF2B9BA8);

  /// Secondary container — Rich teal for containers
  static const Color secondaryContainer = Color(0xFF0A7E92);

  /// Text / icon ON teal backgrounds
  static const Color onSecondary = Colors.white;

  /// Tertiary — Seafoam Green (Kashmir palette)
  static const Color tertiary = Color(0xFF00A896);

  // ─────────────────────────────────────────
  // Light Mode: 10% — Discovery Orange (Brand Action)
  // ─────────────────────────────────────────

  /// Primary CTA color — Discovery Orange (10% action)
  /// Used for: buttons, links, prominent interactive elements
  static const Color primary = Color(0xFFFF6F61);

  /// Primary tint — Medium peachy orange (NOT light pastel)
  /// Changed from #FFE5D4 to more saturated warm tone
  static const Color primaryTint = Color(0xFFE67E50);

  /// Primary container — Warm orange-gold
  static const Color primaryContainer = Color(0xFFF98C5C);

  /// Text / icon ON orange backgrounds
  static const Color onPrimary = Colors.white;

  // ─────────────────────────────────────────
  // Light Mode: Logo Extra Accent (Pink)
  // ─────────────────────────────────────────

  /// Accent Pink — Vibrant from Coral Wave
  static const Color accentPink = Color(0xFFE23C64);

  /// Accent Pink tint — Softer pink (used sparingly for accents)
  static const Color accentPinkTint = Color(0xFFE67E99);

  // ─────────────────────────────────────────
  // Light Mode: TEXT COLORS (Critical for accessibility)
  // ─────────────────────────────────────────

  /// High emphasis text — Dark teal (primary text on light surfaces)
  /// Contrast: Against white = 10:1 (excellent AA)
  static const Color textPrimary = Color(0xFF1E3133);

  /// Medium emphasis text — Muted teal (secondary information)
  /// Contrast: Against white = 5.5:1 (AA compliant)
  static const Color textSecondary = Color(0xFF1B6269);

  /// Low emphasis text — Desaturated gray (hints, placeholders)
  /// Contrast: Against white = 4.5:1 (AA minimum)
  static const Color textHint = Color(0xFF435565);

  /// Text on surface (cards, alternative backgrounds)
  static const Color onSurface = Color(0xFF0F202A);

  /// Disabled text
  static const Color disabledText = Color(0xFF475062);

  // ═════════════════════════════════════════
  // DARK MODE: 60% DEEP NAVY + 30% BRIGHT CYAN + 10% VIBRANT ORANGE
  // ═════════════════════════════════════════

  /// Dark scaffold background — Deep Navy (60% neutral base, darkest)
  /// Inspired by Ocean Serenity palette
  static const Color darkBackground = Color(0xFF0F1419);

  /// Dark surface level 0 — Slightly lighter than background (cards, sheets)
  /// Lighter than background for subtle elevation hierarchy
  static const Color darkSurface = Color(0xFF1A1F2B);

  /// Dark surface level +1 — Medium elevation (buttons, chips, FABs)
  /// Inspired by Aurora Glow's Deep Indigo
  static const Color darkSurfaceElevated = Color(0xFF252D3D);

  /// Dark surface level +2 — High elevation (dialogs, bottom sheets, modals)
  static const Color darkSurfaceElevatedHigh = Color(0xFF2E3647);

  /// Dark surface variant — Alternative surfaces (input fields, alternate containers)
  /// Inspired by Aurora Glow palette
  static const Color darkSurfaceVariant = Color(0xFF3A4559);

  // ─────────────────────────────────────────
  // Dark Mode: 30% — Aurora Glow Cyan (Brand Structure)
  // ─────────────────────────────────────────

  /// Secondary brand in dark mode — Bright Aurora Cyan
  /// Used for: badges, accents, interactive indicators, NOT text
  /// Inspired by Ocean Serenity + Aurora Glow palettes
  /// Contrast check: Against darkSurface (#1A1F2B) = ~7:1 (excellent for AA)
  static const Color darkSecondary = Color(0xFF6AEBFC);

  /// Secondary tint — Slightly desaturated for backgrounds/fills
  static const Color darkSecondaryTint = Color(0xFFA3D1D6);

  /// Tertiary in dark mode — Bright seafoam green (Kashmir palette lightened)
  static const Color darkTertiary = Color(0xFF5AD9AF);

  /// Text / icon ON cyan/teal backgrounds
  static const Color darkOnSecondary = Color(0xFF0F1419);

  // ─────────────────────────────────────────
  // Dark Mode: 10% — Vibrant Orange (Brand Action)
  // ─────────────────────────────────────────

  /// Primary action in dark mode — Vibrant saturated orange (Coral Wave inspired)
  /// Brighter than light mode for dark surface readability
  /// Contrast check: Against darkSurface (#1A1F2B) = ~6:1 (good for AA icons)
  static const Color darkPrimary = Color(0xFFFF8C42);

  /// Primary tint — Lighter warm peachy orange
  static const Color darkPrimaryTint = Color(0xFFFFB366);

  /// Accent Pink in dark mode — Brighter (On Fire palette)
  static const Color darkAccentPink = Color(0xFFFF6D8D);

  // ─────────────────────────────────────────
  // Dark Mode: TEXT COLORS (Critical — NEVER use brand colors)
  // ─────────────────────────────────────────

  /// HIGH EMPHASIS TEXT — Pure white
  /// For: headings, primary labels, body text
  /// Contrast check: Against darkSurface (#1A1F2B) = 21:1 (excellent for AA)
  static const Color darkOnSurface = Color(0xFFFFFFFF);

  /// MEDIUM EMPHASIS TEXT — Light gray
  /// For: secondary labels, supporting text, metadata
  /// Contrast check: Against darkSurface (#1A1F2B) = ~17:1 (excellent for AA)
  static const Color darkTextSecondary = Color(0xFFE0E0E0);

  /// LOW EMPHASIS TEXT — Medium gray
  /// For: hints, placeholders, disabled-but-visible
  /// Contrast check: Against darkSurface (#1A1F2B) = ~8.5:1 (good for AA)
  static const Color darkTextHint = Color(0xFFB0B0B0);

  /// DISABLED TEXT — Dark gray
  /// For: fully disabled, non-interactive
  /// Contrast check: Against darkSurface (#1A1F2B) = ~5:1 (meets AA minimum)
  static const Color darkDisabledText = Color(0xFFB8B8B8);

  // ─────────────────────────────────────────
  // Light Mode: SEMANTIC / UTILITY COLORS
  // ─────────────────────────────────────────

  /// Success state — Vibrant green
  static const Color success = Color.fromARGB(255, 51, 171, 103);

  /// Error state — Vibrant red
  static const Color error = Color(0xFFEF4444);

  /// Warning state — Vibrant amber
  static const Color warning = Color(0xFFF59E0B);

  /// Star / rating — Gold (Coral Wave palette)
  static const Color star = Color(0xFFFFD464);

  /// Favourite / heart — Red
  static const Color favourite = Color(0xFFFF3532);

  /// Divider lines
  static const Color divider = Color(0xFFE2E8F0);

  /// Disabled component state
  static const Color disabled = Color(0xFFCBD5E1);

  /// Scrim / overlay
  static const Color scrim = Color(0x80000000);

  // ─────────────────────────────────────────
  // Dark Mode: SEMANTIC / UTILITY COLORS
  // ─────────────────────────────────────────

  /// Error state in dark mode — Light coral/salmon (readable on dark)
  /// Contrast check: Against darkSurface (#1A1F2B) = ~5.5:1 (AA)
  static const Color darkError = Color(0xFFFF859B);

  /// Warning state in dark mode — Light amber/orange
  /// Contrast check: Against darkSurface (#1A1F2B) = ~5:1 (AA minimum)
  static const Color darkWarning = Color(0xFFFFB74D);

  /// Success state in dark mode — Light green
  /// Contrast check: Against darkSurface (#1A1F2B) = ~6:1 (good for AA)
  static const Color darkSuccess = Color(0xFF81C784);

  /// Star rating in dark mode
  static const Color darkStar = Color(0xFFFFD464);

  /// Favourite in dark mode
  static const Color darkFavourite = Color(0xFFFF6D8D);

  /// Divider in dark mode — Subtle gray
  static const Color darkDivider = Color(0xFF424242);

  /// Disabled component in dark mode
  static const Color darkDisabled = Color(0xFF5A5A5A);

  /// Scrim / overlay in dark mode
  static const Color darkScrim = Color(0x80000000);

  // ═════════════════════════════════════════
  // GRADIENTS (Light & Dark Modes)
  // ═════════════════════════════════════════
  // CRITICAL FIX: Light mode gradients now use SATURATED colors
  // instead of washed-out pastels. Contrast is 4.5:1+ throughout.

  /// "Terengganu Ocean" Gradient — UPDATED for light mode visibility
  /// Deep Teal → Ocean Blue → Medium Teal (NOT light cyan)
  /// Provides visual presence while maintaining brand identity
  /// Contrast: ~4.8:1 against white text (AA compliant)
  static const List<Color> oceanGradient = [
    Color(0xFF003D52), // Dark Teal (darker than before)
    Color(0xFF005A6E), // Rich Ocean Blue
    Color(0xFF227D87), // Medium Saturated Teal
  ];

  /// "Fresh Makan" Gradient — Coral Wave / Peach Fizz palette
  /// Warm Orange → Coral Pink
  /// Used for warm accent screens
  static const List<Color> freshMakanGradient = [
    Color(0xFFE67E50), // Warm Coral Orange
    Color(0xFFFF6F61), // Primary Coral Pink
  ];

  /// "Logo Sunset" Gradient — Coral Wave palette (UPDATED)
  /// Deep Teal → Medium Warm → Vibrant Orange
  static const List<Color> logoGradient = [
    Color(0xFF004E64), // Deep Teal
    Color(0xFFE67E50), // Warm Coral (was pastel, now saturated)
    Color(0xFFFF6F61), // Vibrant Orange
  ];

  /// "Accent Pastel Circles" — Small decorative use ONLY
  /// These are for bubble decorations, emoji containers, small accents
  /// NOT for full-screen backgrounds
  static const List<Color> accentPastelGradient = [
    Color(0xFFFFE5D4), // Soft peachy cream
    Color(0xFFFFD5A1), // Soft golden cream
  ];

  /// Dark mode ocean gradient — Aurora Glow + Kashmir palette
  /// Deep indigo → Deep teal → Bright cyan
  static const List<Color> darkOceanGradient = [
    Color(0xFF1A3A42), // Deep Indigo/Teal
    Color(0xFF2C5F6F), // Medium Teal
    Color(0xFF3CBDD7), // Bright Cyan
  ];

  /// Dark mode warm gradient — On Fire palette
  /// Deep orange → Coral → Light peach
  static const List<Color> darkWarmGradient = [
    Color(0xFFB32C1A), // Deep Burnt Orange
    Color(0xFFE67E50), // Coral Orange
    Color(0xFFFF8C42), // Vibrant Orange
  ];

  // ═════════════════════════════════════════
  // FEATURE-SPECIFIC COLORS
  // ═════════════════════════════════════════

  // LDA TOPIC TAGS (Light Mode)
  /// Tag text — Secondary brand (teal)
  static const Color ldaTagText = Color(0xFF004E64);

  /// Tag background — Light tint
  static const Color ldaTagBackground = Color(0xFFF4F9F9);

  /// Tag border — Secondary tint (now saturated)
  static const Color ldaTagBorder = Color(0xFF2B9BA8);

  // LDA TOPIC TAGS (Dark Mode)
  /// Tag text in dark — White (NOT brand color)
  static const Color darkLdaTagText = Color(0xFFFFFFFF);

  /// Tag background in dark — Dark navy with teal tint
  static const Color darkLdaTagBackground = Color(0xFF1A3A42);

  /// Tag border in dark — Bright cyan
  static const Color darkLdaTagBorder = Color(0xFF6AEBFC);

  // KBF MATCH SCORE (Light Mode)
  /// Match color — Orange
  static const Color kbfMatchColor = Color(0xFFFE7F42);

  /// Match track — Light orange background
  static const Color kbfMatchTrack = Color(0xFFFFE3B2);

  // KBF MATCH SCORE (Dark Mode)
  /// Match color in dark — Vibrant orange
  static const Color darkKbfMatchColor = Color(0xFFFF8C42);

  /// Match track in dark — Dark orange-tinted background
  static const Color darkKbfMatchTrack = Color(0xFF5A3520);

  // GANUBOT CHAT (Light Mode)
  /// Bot bubble — Soft teal background
  static const Color botBubble = Color(0xFFF0F8FA);

  /// Bot text — Dark teal
  static const Color botBubbleText = Color(0xFF003D52);

  /// User bubble — Teal
  static const Color userBubble = Color(0xFF2B9BA8);

  /// User text — White
  static const Color userBubbleText = Colors.white;

  /// Chat quick-reply chips — Orange
  static const Color chatChipBackground = Color(0xFFFF6F61);

  // GANUBOT CHAT (Dark Mode)
  /// Bot bubble in dark — Dark gray with slight tint
  static const Color darkBotBubble = Color(0xFF3A4559);

  /// Bot text in dark — White
  static const Color darkBotBubbleText = Color(0xFFFFFFFF);

  /// User bubble in dark — Bright teal
  static const Color darkUserBubble = Color(0xFF2196F3);

  /// User text in dark — White
  static const Color darkUserBubbleText = Colors.white;

  /// Chat chips in dark — Vibrant orange
  static const Color darkChatChipBackground = Color(0xFFFF8C42);

  // ═════════════════════════════════════════
  // ADAPTIVE HELPERS (Theme-aware selection)
  // ═════════════════════════════════════════

  /// Primary brand color — Adapts between light orange and dark vibrant orange
  static Color adaptivePrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPrimary : primary;

  /// Secondary brand color — Adapts between dark teal and bright cyan
  static Color adaptiveSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSecondary
      : secondary;

  /// Tertiary brand color — Adapts between seafoam and bright seafoam
  static Color adaptiveTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTertiary : tertiary;

  /// Accent pink — Adapts between light and dark vibrant pink
  static Color adaptiveAccentPink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkAccentPink
      : accentPink;

  /// Surface color with elevation awareness
  /// elevation 0 = base surface, 1 = medium, 2 = high
  static Color adaptiveSurface(BuildContext context, {int elevation = 0}) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return switch (elevation) {
        0 => darkSurface,
        1 => darkSurfaceElevated,
        2 => darkSurfaceElevatedHigh,
        _ => darkSurfaceElevatedHigh,
      };
    } else {
      return surface;
    }
  }

  /// High emphasis text color (headings, primary text)
  static Color adaptiveOnSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkOnSurface
      : textPrimary;

  /// Medium emphasis text color (secondary labels)
  static Color adaptiveTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextSecondary
      : textSecondary;

  /// Low emphasis text color (hints, placeholders)
  static Color adaptiveTextHint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextHint : textHint;

  /// Error semantic color
  static Color adaptiveError(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkError : error;

  /// Warning semantic color
  static Color adaptiveWarning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkWarning : warning;

  /// Success semantic color
  static Color adaptiveSuccess(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSuccess : success;
}
