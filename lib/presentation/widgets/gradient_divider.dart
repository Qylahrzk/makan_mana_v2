import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Theme-aware gradient divider with WCAG AA contrast
///
/// Automatically selects the appropriate gradient based on light/dark theme:
/// - Light Mode: Ocean gradient (teal → cyan)
/// - Dark Mode: Dark ocean gradient (dark teal → cyan)
///
/// Ensures visibility and accessibility in both modes.
class GradientDivider extends StatelessWidget {
  final double height;
  final double thickness;
  final EdgeInsetsGeometry? margin;
  final String? style; // 'ocean', 'warm', 'vibrant', or null for default

  const GradientDivider({
    super.key,
    this.height = 16,
    this.thickness = 1,
    this.margin,
    this.style,
  });

  /// Get gradient colors based on theme and style
  List<Color> _getGradientColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      // Dark mode: Use dark-optimized gradients
      switch (style) {
        case 'ocean':
          return AppColors.darkOceanGradient;
        case 'warm':
          return AppColors.darkWarmGradient;
        case 'vibrant':
          return [AppColors.darkSecondary, AppColors.darkPrimary];
        default:
          return AppColors.darkOceanGradient;
      }
    } else {
      // Light mode: Use light-optimized gradients
      switch (style) {
        case 'ocean':
          return AppColors.oceanGradient;
        case 'warm':
          return AppColors.freshMakanGradient;
        case 'vibrant':
          return [AppColors.secondary, AppColors.primary];
        default:
          return AppColors.oceanGradient;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors(context);

    return Container(
      margin: margin ?? EdgeInsets.symmetric(vertical: height / 2),
      height: thickness,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}
