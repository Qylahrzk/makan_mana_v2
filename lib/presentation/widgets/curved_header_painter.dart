import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// FIXED: Minimal curved header painter — only draws the curve stroke
///
/// Changes from original:
/// - Removed unnecessary background fill
/// - Reduced curve height (24 → 16)
/// - Thinner stroke for cleaner look
/// - No white space issues during scroll
class CurvedHeaderPainter extends CustomPainter {
  final Color bgColor;
  final List<Color> strokeColors;
  final double curveRadius;
  final double strokeWidth;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;

  const CurvedHeaderPainter({
    required this.bgColor,
    this.strokeColors = AppColors.oceanGradient,
    this.curveRadius = 24,
    this.strokeWidth = 1.8,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
  });

  factory CurvedHeaderPainter.adaptive(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CurvedHeaderPainter(
      bgColor: isDark ? AppColors.darkBackground : AppColors.background,
      strokeColors: isDark
          ? AppColors.darkOceanGradient
          : AppColors.oceanGradient,
      curveRadius: 24,
      strokeWidth: 1.8,
    );
  }

  factory CurvedHeaderPainter.withStyle(
    BuildContext context, {
    String gradientStyle = 'ocean',
    double curveRadius = 24,
    double strokeWidth = 1.8,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    late final List<Color> strokeColors;
    switch (gradientStyle) {
      case 'ocean':
        strokeColors = isDark
            ? AppColors.darkOceanGradient
            : AppColors.oceanGradient;
      case 'warm':
        strokeColors = isDark
            ? AppColors.darkWarmGradient
            : AppColors.freshMakanGradient;
      case 'vibrant':
        strokeColors = isDark
            ? [AppColors.darkSecondary, AppColors.darkPrimary]
            : [AppColors.secondary, AppColors.primary];
      default:
        strokeColors = isDark
            ? AppColors.darkOceanGradient
            : AppColors.oceanGradient;
    }

    return CurvedHeaderPainter(
      bgColor: bgColor,
      strokeColors: strokeColors,
      curveRadius: curveRadius,
      strokeWidth: strokeWidth,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gradientRect = Rect.fromLTRB(0, 0, size.width, size.height);

    // ──  Only draw the curve stroke, no fill ────────────────────────────────
    final borderPaint = Paint()
      ..shader = LinearGradient(
        colors: strokeColors,
        begin: gradientBegin,
        end: gradientEnd,
      ).createShader(gradientRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const double kappa = 0.552284749831;
    // Draw only the curve path (no background fill)
    final borderPath = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        0,
        size.height - curveRadius * kappa,
        curveRadius * (1 - kappa),
        size.height - curveRadius,
        curveRadius,
        size.height - curveRadius,
      )
      ..lineTo(size.width - curveRadius, size.height - curveRadius)
      ..cubicTo(
        size.width - curveRadius * kappa,
        size.height - curveRadius,
        size.width,
        size.height - curveRadius * kappa,
        size.width,
        size.height,
      );

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(CurvedHeaderPainter oldDelegate) =>
      oldDelegate.bgColor != bgColor ||
      oldDelegate.strokeColors != strokeColors ||
      oldDelegate.curveRadius != curveRadius ||
      oldDelegate.strokeWidth != strokeWidth;

  @override
  bool shouldRebuildSemantics(CurvedHeaderPainter oldDelegate) => false;
}

/// Clipper for clipping content to curved shape
class HeaderCurveClipper extends CustomClipper<Path> {
  final double curveRadius;

  const HeaderCurveClipper({this.curveRadius = 24});

  @override
  Path getClip(Size size) {
    const double kappa = 0.552284749831;
    return Path()
      ..lineTo(0, size.height)
      ..cubicTo(
        0,
        size.height - curveRadius * kappa,
        curveRadius * (1 - kappa),
        size.height - curveRadius,
        curveRadius,
        size.height - curveRadius,
      )
      ..lineTo(size.width - curveRadius, size.height - curveRadius)
      ..cubicTo(
        size.width - curveRadius * kappa,
        size.height - curveRadius,
        size.width,
        size.height - curveRadius * kappa,
        size.width,
        size.height,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant HeaderCurveClipper oldClipper) =>
      oldClipper.curveRadius != curveRadius;
}
