import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makan_mana_v2/core/app_colors.dart';
import 'package:makan_mana_v2/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_screen.dart';
import '../widgets/premium_background.dart';

///
/// Design Rationale:
///   - Dark ocean teal = premium, confident, appetite-inducing
///
/// Animation Sequence:
///   - 0-600ms: Logo scale-in + fade
///   - 300-800ms: Logo pulse (subtle)
///   - 800-1200ms: Tagline + subtitle slide-in
///   - 1200-2400ms: Hold + loading indicator
///   - 2400ms+: Navigate to onboarding or main

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _dotsOpacity;

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
      duration: const Duration(milliseconds: 2400),
    );

    // ─── Logo entrance: scale + fade (0-600ms) ────────────────────────────
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.elasticOut),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    // ─── Pulse effect on logo (300-800ms) ─────────────────────────────────
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeInOut),
      ),
    );

    // ─── Main tagline entrance (800-1200ms) ───────────────────────────────
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.33, 0.65, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.33, 0.65, curve: Curves.easeOutCubic),
          ),
        );

    // ─── Subtitle entrance (900-1300ms) ───────────────────────────────────
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    // ─── Loading dots (1200ms onward) ──────────────────────────────────────
    _dotsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 3000), _navigateNext);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const OnboardingScreen(),
          transitionDuration: const Duration(milliseconds: 700),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      final session = Supabase.instance.client.auth.currentSession;
      Navigator.pushReplacementNamed(
        context,
        session != null ? AppRoutes.home : AppRoutes.welcome,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumGradientBackground(
        style: 'ocean', // ← Dark teal ocean (NOT light pastel)
        child: Stack(
          children: [
            // ─── Subtle background blobs (very low opacity) ────────────────
            // These should be barely visible - supporting cast only
            Positioned(
              top: -80,
              right: -100,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.02),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.04),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.02),
                      blurRadius: 40,
                      spreadRadius: 15,
                    ),
                  ],
                ),
              ),
            ),

            // ─── Main content (center) ────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with scale, fade, and pulse
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, _) => FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Transform.scale(
                          scale: _pulseAnim.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 50,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Image.asset(
                                'assets/images/main_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ─ Main tagline (large, stacked) ─────────────────────
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, _) => FadeTransition(
                      opacity: _taglineFade,
                      child: SlideTransition(
                        position: _taglineSlide,
                        child: Column(
                          children: [
                            Text(
                              'Makan',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.2,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Mana',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.2,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─ Subtitle (secondary info) ──────────────────────────
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, _) => FadeTransition(
                      opacity: _taglineFade,
                      child: SlideTransition(
                        position: _subtitleSlide,
                        child: Text(
                          'Discover the best food in Terengganu',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Loading indicator at bottom ──────────────────────────────
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => FadeTransition(
                  opacity: _dotsOpacity,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        // Staggered bounce animation for each dot
                        final delay = i * 0.15;
                        final dotAnim = Tween<double>(begin: 0.5, end: 1.0)
                            .animate(
                              CurvedAnimation(
                                parent: _controller,
                                curve: Interval(
                                  (0.65 + delay).clamp(0.0, 1.0),
                                  (0.95 + delay).clamp(0.0, 1.0),
                                  curve: Curves.easeInOut,
                                ),
                              ),
                            );

                        return Transform.scale(
                          scale: dotAnim.value,
                          child: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 1
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.6),
                              boxShadow: i == 1
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
