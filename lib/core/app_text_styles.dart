import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Central text styles for Makan Mana v2.
///
/// Font roles:
///   Montserrat     — Headlines, restaurant names, screen titles
///   Open Sans      — Body text, descriptions, review summaries
///   JetBrainsMono  — Technical data: match scores, LDA labels, percentages
class AppTextStyles {
  AppTextStyles._();

  // ─────────────────────────────────────────
  // DISPLAY — Montserrat — Hero text
  // ─────────────────────────────────────────

  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // ─────────────────────────────────────────
  // HEADLINE — Montserrat — Screen titles, section headers
  // ─────────────────────────────────────────

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ─────────────────────────────────────────
  // TITLE — Montserrat — Card titles, restaurant names
  // ─────────────────────────────────────────

  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ─────────────────────────────────────────
  // BODY — Open Sans — Content, descriptions, reviews
  // ─────────────────────────────────────────

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ─────────────────────────────────────────
  // LABEL — Open Sans — Chips, tags, badges
  // ─────────────────────────────────────────

  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  // ─────────────────────────────────────────
  // DATA — JetBrains Mono — AI labels, match scores, percentages
  // ─────────────────────────────────────────

  /// KBF match score — e.g. "92% Match"
  static const TextStyle matchScore = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: 0.0,
  );

  /// LDA topic label — e.g. "Family Dining"
  static const TextStyle ldaLabel = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.ldaTagText,
    letterSpacing: 0.2,
  );

  /// Technical data label — e.g. "LDA Analysis", "KBF Score"
  static const TextStyle dataLabel = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  /// Large percentage — e.g. "95%" in the circular match indicator
  static const TextStyle matchPercentage = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: -0.5,
  );

  // ─────────────────────────────────────────
  // SPECIFIC SCREEN STYLES
  // ─────────────────────────────────────────

  static const TextStyle onboardingTitle = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle onboardingSubtitle = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: 0.3,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle restaurantName = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle restaurantTag = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    letterSpacing: 0.2,
  );

  static const TextStyle ratingText = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.star,
  );

  static const TextStyle inputText = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle inputHint = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.disabledText,
  );

  static const TextStyle inputLabel = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  static const TextStyle linkText = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.primary,
  );

  static const TextStyle botMessage = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.botBubbleText,
    height: 1.55,
  );

  static const TextStyle userMessage = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.userBubbleText,
    height: 1.55,
  );

  // ─────────────────────────────────────────
  // DARK MODE OVERRIDES
  // ─────────────────────────────────────────

  static const TextStyle bodyLargeDark = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.darkOnSurface,
    height: 1.6,
  );

  static const TextStyle bodyMediumDark = TextStyle(
    fontFamily: 'OpenSans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.darkTextSecondary,
    height: 1.6,
  );

  // ─────────────────────────────────────────
  // HELPER
  // ─────────────────────────────────────────

  static TextStyle adaptiveBody(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bodyLargeDark
        : bodyLarge;
  }
}