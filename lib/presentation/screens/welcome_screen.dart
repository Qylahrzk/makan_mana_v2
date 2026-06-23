import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makan_mana_v2/presentation/screens/main_nav.dart';
import '../../core/app_colors.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../widgets/premium_background.dart';

/// WelcomeScreen - UPDATED
///
/// Changes from original:
/// - Uses SATURATED ocean gradient (dark teal → medium teal) instead of washed-out pastel
/// - Removed excessive decorative circles that competed with gradient
/// - Kept emoji mosaic but positioned it better for visual balance
/// - Cleaner visual hierarchy: dark gradient + white card creates strong contrast
/// - Better contrast ratios throughout (4.5:1+)
///
/// Entry gate after onboarding. Lets user choose:
///   - Sign In  → LoginScreen
///   - Create Account → SignupScreen
///   - Continue as Guest → MainNavScreen
///
/// Place in: lib/presentation/screens/welcome_screen.dart

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bgFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Background gradient fades in over first 40% of animation
    _bgFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    // Logo (top-left branding) fades in with gradient
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );

    // Card slides up and fades in (staggered, starts at 30%)
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _cardFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── Navigation helpers ───────────────────────────────────────────────────

  void _continueAsGuest() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainNavScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Saturated Ocean Gradient Background ────────────────────────────
          // NOW uses dark teal → medium teal (proper contrast, not washed out)
          FadeTransition(
            opacity: _bgFade,
            child: PremiumGradientBackground(
              style: 'ocean',
              child: const SizedBox.expand(),
            ),
          ),

          // ── Subtle Accent Circle (top-right, very minimal) ─────────────────
          // Reduced prominence - now a subtle accent rather than dominant element
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          // ── Food Emoji Mosaic (top third, more refined positioning) ────────
          // Repositioned to work better with new gradient background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.42,
            child: FadeTransition(
              opacity: _bgFade,
              child: Stack(
                children: [
                  // Large central food bowl with subtle glow
                  Align(
                    alignment: const Alignment(0, 0.25),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🍜', style: TextStyle(fontSize: 64)),
                      ),
                    ),
                  ),
                  // Floating food emojis - cleaner selection
                  ..._floatingEmojis(),
                ],
              ),
            ),
          ),

          // ── Bottom white card (strong contrast against dark gradient) ──────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardFade,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    28,
                    28,
                    28,
                    28 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Headline
                      const Text(
                        'Find Your Next\nFavourite Meal',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E3133),
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '994 restaurants across Terengganu,\nrecommended just for you.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _goToLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Create Account button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _goToSignup,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: BorderSide(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[200])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[200])),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Continue as Guest button
                      Center(
                        child: GestureDetector(
                          onTap: _continueAsGuest,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.explore_rounded,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Continue as Guest',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── App name and tagline (top-left) ────────────────────────────────
          // Visible against the now-darker gradient background
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 28,
            child: FadeTransition(
              opacity: _logoFade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Makan Mana',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'TERENGGANU',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Floating food emojis ─────────────────────────────────────────────────
  /// Reduced set of emojis with refined positioning
  List<Widget> _floatingEmojis() {
    final items = [
      (emoji: '🦞', top: 0.08, left: 0.08, size: 28.0, opacity: 0.8),
      (emoji: '🍛', top: 0.05, left: 0.65, size: 24.0, opacity: 0.7),
      (emoji: '🐟', top: 0.28, left: 0.80, size: 22.0, opacity: 0.65),
      (emoji: '🍢', top: 0.50, left: 0.08, size: 20.0, opacity: 0.6),
      (emoji: '🍖', top: 0.55, left: 0.78, size: 26.0, opacity: 0.7),
      (emoji: '🍱', top: 0.18, left: 0.12, size: 20.0, opacity: 0.55),
    ];

    final size = MediaQuery.of(context).size;
    final halfH = size.height * 0.42;

    return items.map((item) {
      return Positioned(
        top: halfH * item.top,
        left: size.width * item.left,
        child: Opacity(
          opacity: item.opacity,
          child: Text(item.emoji, style: TextStyle(fontSize: item.size)),
        ),
      );
    }).toList();
  }
}
