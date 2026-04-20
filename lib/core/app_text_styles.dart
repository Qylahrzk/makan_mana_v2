import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Central text styles for Terengganu Restaurant Recommender.
/// Follows Material 3 type scale naming conventions.
class AppTextStyles {
  AppTextStyles._(); // Prevent instantiation

  // ─────────────────────────────────────────
  // DISPLAY — Large hero text (onboarding, splash)
  // ─────────────────────────────────────────

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // ─────────────────────────────────────────
  // HEADLINE — Screen titles, section headers
  // ─────────────────────────────────────────

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ─────────────────────────────────────────
  // TITLE — Card titles, restaurant names
  // ─────────────────────────────────────────

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ─────────────────────────────────────────
  // BODY — General content, descriptions
  // ─────────────────────────────────────────

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ─────────────────────────────────────────
  // LABEL — Tags, chips, badges, buttons
  // ─────────────────────────────────────────

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  // ─────────────────────────────────────────
  // SPECIFIC USE CASES
  // ─────────────────────────────────────────

  /// Onboarding screen title
  static const TextStyle onboardingTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Onboarding screen subtitle
  static const TextStyle onboardingSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  /// Primary button text
  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  /// Secondary / outlined button text
  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: 0.2,
  );

  /// AppBar title
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// Restaurant name on card
  static const TextStyle restaurantName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Restaurant cuisine / category tag
  static const TextStyle restaurantTag = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.secondary,
    letterSpacing: 0.2,
  );

  /// Star rating text
  static const TextStyle ratingText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.star,
  );

  /// Input field text
  static const TextStyle inputText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Input field hint text
  static const TextStyle inputHint = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.disabledText,
  );

  /// Input field label
  static const TextStyle inputLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Error text below input fields
  static const TextStyle errorText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  /// "Continue as Guest" or secondary link text
  static const TextStyle linkText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondary,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.secondary,
  );

  // ─────────────────────────────────────────
  // DARK MODE OVERRIDES
  // ─────────────────────────────────────────

  /// Body text for dark mode
  static const TextStyle bodyLargeDark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.darkOnSurface,
    height: 1.5,
  );

  static const TextStyle bodyMediumDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.darkSecondary,
    height: 1.5,
  );

  // ─────────────────────────────────────────
  // HELPER
  // ─────────────────────────────────────────

  /// Returns bodyLarge or bodyLargeDark based on current theme brightness
  static TextStyle adaptiveBody(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bodyLargeDark
        : bodyLarge;
  }
}