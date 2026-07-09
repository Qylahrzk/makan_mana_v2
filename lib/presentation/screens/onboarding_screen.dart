import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makan_mana_v2/core/app_colors.dart';
import 'package:makan_mana_v2/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Onboarding Screen — Clean, Neutral Design
///
/// Design Approach:
///   - Neutral white/light backgrounds (no gradients)
///   - Teal accent elements (tags, underlines, illustrations)
///   - Orange buttons for CTAs (consistent across all pages)
///   - Clear visual hierarchy: background → content → action
///
/// Color Usage:
///   - Background: AppColors.background (light) / AppColors.darkBackground (dark)
///   - Accents: Teal (secondary color) for tags, underlines, illustrations
///   - CTAs: Orange (primary color) for all buttons
///   - Text: Dark on light, light on dark (WCAG AA compliant)

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

  // ─── Named constants ────────────────────────────────────────────────────
  static const double _imageHeightFraction = 0.42;
  static const double _titleFontSize = 34;
  static const double _subtitleFontSize = 14;
  static const double _accentUnderlineWidth = 48;
  static const double _accentUnderlineHeight = 5;
  static const double _accentUnderlineRadius = 2;
  static const double _tagFontSize = 11;
  static const double _tagLetterSpacing = 1.8;
  static const double _tagPaddingH = 14;
  static const double _tagPaddingV = 7;
  static const double _tagRadius = 24;
  static const double _tagBorderWidth = 1.5;
  static const double _bottomPaddingContent = 100;
  static const double _bottomPaddingNav = 30;
  static const double _dotSize = 10;
  static const double _dotMargin = 8;
  static const double _activeDotWidth = 28;
  static const double _contentTopPadding = 60;
  static const double _pageTransitionDuration = 500;

  static const List<_PageData> _pages = [
    _PageData(
      imagePath: 'assets/images/onboard_2.png',
      tag: 'AI-POWERED',
      title: 'Discover Your\nFavourite Meal',
      subtitle:
          'Find the best restaurants around you based on your food preferences only with one click.',
    ),
    _PageData(
      imagePath: 'assets/images/onboard_1.png',
      tag: 'DISCOVERY',
      title: 'Not sure what\nto eat here?',
      subtitle:
          'Bookmark restaurants you love and get directions right from the app — just like Google Maps.',
    ),
    _PageData(
      imagePath: 'assets/images/onboard_3.png',
      tag: 'PERSONALISED',
      title: 'Save Your\nFavourites',
      subtitle:
          'Build your personal wishlist, filter by halal, cuisine type, distance, and find the perfect spot every time.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: _pageTransitionDuration.round()),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    Navigator.pushReplacementNamed(
      context,
      session != null ? AppRoutes.home : AppRoutes.welcome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDark
            ? AppColors.darkBackground
            : AppColors.background,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      // Neutral background — no gradients
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Semantics(
        label: 'Onboarding carousel',
        child: Stack(
          children: [
            // Page view
            PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) =>
                  _ContentPage(page: _pages[i], isDark: isDark),
            ),

            // Skip button (top-right) — only show if NOT on last page
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 20),
                  child: AnimatedOpacity(
                    opacity: _currentPage < _totalPages - 1 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      // Prevent tapping invisible skip button on last page
                      ignoring: _currentPage == _totalPages - 1,
                      child: _SkipButton(onTap: _completeOnboarding),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom navigation
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    28,
                    20,
                    28,
                    _bottomPaddingNav,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dot indicators
                      _DotIndicators(
                        currentPage: _currentPage,
                        totalPages: _totalPages,
                      ),

                      // Next button
                      _NextButton(
                        isLastPage: _currentPage == _totalPages - 1,
                        onTap: _nextPage,
                      ),
                    ],
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

// ─── Content page widget ────────────────────────────────────────────────────
class _ContentPage extends StatefulWidget {
  final _PageData page;
  final bool isDark;

  const _ContentPage({required this.page, required this.isDark});

  @override
  State<_ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<_ContentPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: _OnboardingScreenState._contentTopPadding,
                ),

                // Image section
                SizedBox(
                  height:
                      MediaQuery.of(context).size.height *
                      _OnboardingScreenState._imageHeightFraction,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Image.asset(
                        widget.page.imagePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        semanticLabel: widget.page.tag,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Text content
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    28,
                    0,
                    28,
                    _OnboardingScreenState._bottomPaddingContent,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag with teal accent
                      _EnhancedTag(
                        label: widget.page.tag,
                        isDark: widget.isDark,
                      ),
                      const SizedBox(height: 16),

                      // Title — WCAG AA compliant
                      Text(
                        widget.page.title,
                        style: TextStyle(
                          color: widget.isDark
                              ? AppColors.darkOnSurface
                              : AppColors.textPrimary,
                          fontSize: _OnboardingScreenState._titleFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Underline accent — Teal (consistent on all pages)
                      Container(
                        width: _OnboardingScreenState._accentUnderlineWidth,
                        height: _OnboardingScreenState._accentUnderlineHeight,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? AppColors.darkSecondary
                              : AppColors.secondary,
                          borderRadius: BorderRadius.circular(
                            _OnboardingScreenState._accentUnderlineRadius,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Subtitle — WCAG AA compliant
                      Text(
                        widget.page.subtitle,
                        style: TextStyle(
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                          fontSize: _OnboardingScreenState._subtitleFontSize,
                          height: 1.7,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Enhanced tag widget ────────────────────────────────────────────────────
/// Tag with teal glassmorphism accent (all pages consistent)
class _EnhancedTag extends StatelessWidget {
  final String label;
  final bool isDark;

  const _EnhancedTag({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Teal accent color (consistent across all pages)
    final accentColor = isDark ? AppColors.darkSecondary : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _OnboardingScreenState._tagPaddingH,
        vertical: _OnboardingScreenState._tagPaddingV,
      ),
      decoration: BoxDecoration(
        // Glassmorphism effect: semi-transparent background with border
        color: accentColor.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(_OnboardingScreenState._tagRadius),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.3 : 0.25),
          width: _OnboardingScreenState._tagBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor,
          fontSize: _OnboardingScreenState._tagFontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: _OnboardingScreenState._tagLetterSpacing,
        ),
      ),
    );
  }
}

// ─── Dot indicators widget ───────────────────────────────────────────────────
/// Progress indicators — Teal active state, muted inactive
class _DotIndicators extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _DotIndicators({required this.currentPage, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Teal accent for indicators (secondary color)
    final accentColor = isDark ? AppColors.darkSecondary : AppColors.secondary;

    return Row(
      children: List.generate(totalPages, (i) {
        final active = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(
            right: _OnboardingScreenState._dotMargin,
          ),
          width: active
              ? _OnboardingScreenState._activeDotWidth
              : _OnboardingScreenState._dotSize,
          height: _OnboardingScreenState._dotSize,
          decoration: BoxDecoration(
            color: active
                ? accentColor
                : accentColor.withValues(alpha: isDark ? 0.25 : 0.2),
            borderRadius: BorderRadius.circular(
              _OnboardingScreenState._dotSize / 2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}

// ─── Skip button widget ──────────────────────────────────────────────────────
/// Skip button with teal accent (visible only on pages 1-2)
class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Teal accent (secondary color)
    final accentColor = isDark ? AppColors.darkSecondary : AppColors.secondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: isDark ? 0.12 : 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.3 : 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          'Skip',
          style: TextStyle(
            color: accentColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Next button widget ──────────────────────────────────────────────────────
/// Action button with ORANGE color (consistent across all pages)
/// This is the primary CTA color that must stand out on neutral background
class _NextButton extends StatelessWidget {
  final bool isLastPage;
  final VoidCallback onTap;

  const _NextButton({required this.isLastPage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ORANGE primary color for all buttons (consistent across all 3 pages)
    final ctaColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isLastPage ? 32 : 24,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ctaColor, ctaColor.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: ctaColor.withValues(alpha: isDark ? 0.3 : 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                isLastPage ? 'Get Started' : 'Next',
                key: ValueKey(isLastPage),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedRotation(
              turns: isLastPage ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isLastPage
                    ? Icons.rocket_launch_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page data model ────────────────────────────────────────────────────────
class _PageData {
  final String imagePath;
  final String tag;
  final String title;
  final String subtitle;

  const _PageData({
    required this.imagePath,
    required this.tag,
    required this.title,
    required this.subtitle,
  });
}
