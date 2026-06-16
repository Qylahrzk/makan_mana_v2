import 'package:flutter/material.dart';

class PremiumGradientBackground extends StatelessWidget {
  final Widget child;

  const PremiumGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // ── 1. Base Gradient Canvas ─────────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: isDark
                    ? const [
                        Color(0xFF127A85),
                        Color(0xFFFF8A00),
                      ] // Soft deep slate teal/orange blend
                    : const [
                        Color(0xFFF3FCFD),
                        Color(0xFFFFFDF6),
                      ], // Softer light teal/cream blend
              ),
            ),
          ),
        ),

        // ── 2. Onboarding Bubble 1 (Top-Right Orange) ───────────────────
        Positioned(
          top: -80,
          right: -70,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFFFF8A00,
              ).withValues(alpha: isDark ? 0.08 : 0.05),
            ),
          ),
        ),

        // ── 3. Onboarding Bubble 2 (Bottom-Left Teal) ───────────────────
        Positioned(
          bottom: -90,
          left: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF127A85,
              ).withValues(alpha: isDark ? 0.07 : 0.04),
            ),
          ),
        ),

        // ── 4. Onboarding Bubble 3 (Middle-Right Orange) ────────────────
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          right: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFFFF8A00,
              ).withValues(alpha: isDark ? 0.05 : 0.03),
            ),
          ),
        ),

        // ── 5. Onboarding Bubble 4 (Top-Left Teal) ──────────────────────
        Positioned(
          top: 60,
          left: -40,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF127A85,
              ).withValues(alpha: isDark ? 0.05 : 0.03),
            ),
          ),
        ),

        // ── 6. Content Layer ─────────────────────────────────────────────
        Positioned.fill(child: child),
      ],
    );
  }
}
