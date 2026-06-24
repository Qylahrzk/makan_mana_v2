import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// A reusable, theme-aware gradient background widget.
///
/// CRITICAL FIX: Now uses SATURATED gradients for light mode instead of washed-out pastels.
///
/// Features:
/// - Theme-aware: Automatically adapts colors for light/dark modes
/// - WCAG AA compliant: All gradients have 4.5:1+ contrast
/// - Customizable: Control gradient style and direction
/// - Efficient: Minimal overhead, respects constraints
///
/// Available Styles:
/// - 'ocean' (default): Deep teal → medium teal (saturated, good contrast)
/// - 'warm': Orange → coral pink (warm accent)
/// - 'vibrant': Secondary brand → primary brand
///
/// Usage:
/// ```dart
/// PremiumGradientBackground(
///   style: 'ocean',
///   child: Scaffold(body: YourContent()),
/// )
/// ```
class PremiumGradientBackground extends StatelessWidget {
  final String style;
  final Widget child;
  final Alignment? beginAlignment;
  final Alignment? endAlignment;

  const PremiumGradientBackground({
    super.key,
    this.style = 'ocean',
    required this.child,
    this.beginAlignment,
    this.endAlignment,
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
        case 'soft':
          return AppColors.darkOceanGradient;
        default:
          return AppColors.darkOceanGradient;
      }
    } else {
      // Light mode: Use SATURATED gradients (NOT washed-out pastels)
      switch (style) {
        case 'ocean':
          return AppColors.oceanGradient; // Now properly saturated
        case 'warm':
          return AppColors.freshMakanGradient;
        case 'vibrant':
          return [AppColors.secondary, AppColors.primary];
        case 'soft':
          return [const Color(0xFFEBF5F6), AppColors.background];
        default:
          return AppColors.oceanGradient;
      }
    }
  }

  /// Get alignment based on style (can be overridden)
  Alignment _getBeginAlignment() => beginAlignment ?? Alignment.topLeft;

  Alignment _getEndAlignment() => endAlignment ?? Alignment.bottomRight;

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: _getBeginAlignment(),
          end: _getEndAlignment(),
        ),
      ),
      child: child,
    );
  }
}

/// Variant: Stack backgrounds (gradient + additional overlay effect)
/// Useful for adding subtle depth or reducing saturation if needed.
class PremiumGradientBackgroundWithOverlay extends StatelessWidget {
  final String style;
  final Widget child;
  final Color? overlayColor;
  final double overlayOpacity;
  final Alignment? beginAlignment;
  final Alignment? endAlignment;

  const PremiumGradientBackgroundWithOverlay({
    super.key,
    this.style = 'ocean',
    required this.child,
    this.overlayColor,
    this.overlayOpacity = 0.1,
    this.beginAlignment,
    this.endAlignment,
  });

  List<Color> _getGradientColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      switch (style) {
        case 'ocean':
          return AppColors.darkOceanGradient;
        case 'warm':
          return AppColors.darkWarmGradient;
        case 'vibrant':
          return [AppColors.darkSecondary, AppColors.darkPrimary];
        case 'soft':
          return AppColors.darkOceanGradient;
        default:
          return AppColors.darkOceanGradient;
      }
    } else {
      switch (style) {
        case 'ocean':
          return AppColors.oceanGradient;
        case 'warm':
          return AppColors.freshMakanGradient;
        case 'vibrant':
          return [AppColors.secondary, AppColors.primary];
        case 'soft':
          return [const Color(0xFFEBF5F6), AppColors.background];
        default:
          return AppColors.oceanGradient;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultOverlay = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: beginAlignment ?? Alignment.topLeft,
          end: endAlignment ?? Alignment.bottomRight,
        ),
      ),
      child: Container(
        color: (overlayColor ?? defaultOverlay).withValues(
          alpha: overlayOpacity,
        ),
        child: child,
      ),
    );
  }
}

/// A decorative animated blob widget that floats organic-like in the background.
class AnimatedBlob extends StatefulWidget {
  final Color color;
  final double size;
  final Alignment alignment;

  const AnimatedBlob({
    super.key,
    required this.color,
    required this.size,
    required this.alignment,
  });

  @override
  State<AnimatedBlob> createState() => _AnimatedBlobState();
}

class _AnimatedBlobState extends State<AnimatedBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shiftAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _shiftAnimation = Tween<double>(
      begin: -15.0,
      end: 15.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            widget.alignment == Alignment.topRight
                ? _shiftAnimation.value
                : -_shiftAnimation.value,
            _shiftAnimation.value,
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: 15,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
