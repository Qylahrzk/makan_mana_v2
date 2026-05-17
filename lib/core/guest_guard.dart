import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/app_colors.dart';
import '../logic/cubits/auth_cubit.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/signup_screen.dart';

/// GuestGuard
///
/// Reusable utility that intercepts any action requiring authentication.
/// If the user is a guest → shows a bottom sheet prompting Sign In / Sign Up.
/// If the user is authenticated → proceeds with the intended action.

class GuestGuard {
  GuestGuard._();

  static void check(
    BuildContext context, {
    required VoidCallback onAllowed,
    String? featureName,
  }) {
    final authCubit = context.read<AuthCubit>();

    if (!authCubit.isAuthenticated) {
      _showGuestSheet(context, featureName: featureName);
    } else {
      onAllowed();
    }
  }

  static void _showGuestSheet(BuildContext context, {String? featureName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuestBottomSheet(featureName: featureName),
    );
  }
}

// ─── Guest Bottom Sheet ───────────────────────────────────────────────────────

class _GuestBottomSheet extends StatelessWidget {
  final String? featureName;

  const _GuestBottomSheet({this.featureName});

  @override
  Widget build(BuildContext context) {
    final feature = featureName ?? 'use this feature';

    return Container(
      padding: EdgeInsets.fromLTRB(
        28,
        12,
        28,
        MediaQuery.of(context).padding.bottom + 28,
      ),
      decoration: BoxDecoration(
        // ✅ FIX: Use theme surface color instead of hardcoded white
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ─────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              // ✅ FIX: Use theme color instead of hardcoded grey[200]
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // ── Lock icon ──────────────────────────────────────────────
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ──────────────────────────────────────────────────
          Text(
            'Sign Up to Continue',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              // ✅ FIX: Use theme color instead of hardcoded Color(0xFF1A1A1A)
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),

          // ── Subtitle ───────────────────────────────────────────────
          Text(
            'Create a free account to $feature\nand unlock the full Makan Mana experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              // ✅ FIX: Use theme color instead of hardcoded grey[500]
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // ── Feature highlights ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FeatureChip(
                icon: Icons.favorite_rounded,
                label: 'Save Favourites',
                color: AppColors.primary,
              ),
              _FeatureChip(
                icon: Icons.person_rounded,
                label: 'Your Profile',
                color: AppColors.secondary,
              ),
              _FeatureChip(
                icon: Icons.recommend_rounded,
                label: 'Personalised',
                color: AppColors.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Sign Up button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Create Free Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Sign In button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                // ✅ FIX: Brighter color for Sign In text in dark mode
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors
                          .darkSecondary // Bright cyan for dark mode
                    : AppColors.secondary, // Regular teal for light mode
                side: BorderSide(
                  color:
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSecondary
                              : AppColors.secondary)
                          .withValues(alpha: 0.35),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Maybe Later ────────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  // ✅ FIX: Use theme color instead of hardcoded grey[400]
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature chip ─────────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            // ✅ FIX: Use theme color instead of hardcoded grey[600]
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
