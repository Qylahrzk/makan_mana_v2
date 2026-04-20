import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makan_mana_v2/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static const List<_PageData> _pages = [
    _PageData(
      imagePath: 'assets/images/onboard_2.png',
      accentColor: Color(0xFFFF8C42),
      bgColor: Color(0xFFFFF5EE),
      bubbleColor: Color(0xFFFFD5B3),
      tag: 'AI-POWERED',
      title: 'Discover Your\nFavourite Meal',
      subtitle:
          'Find the best restaurants around you based on your food preferences only with one click.',
    ),
    _PageData(
      imagePath: 'assets/images/onboard_1.png',
      accentColor: Color(0xFF2F6F7E),
      bgColor: Color(0xFFEFF8FA),
      bubbleColor: Color(0xFFB8DFE8),
      tag: 'DISCOVERY',
      title: 'Not sure what\nto eat here?',
      subtitle:
          'Bookmark restaurants you love and get directions right from the app — just like Google Maps.',
    ),
    _PageData(
      imagePath: 'assets/images/onboard_3.png',
      accentColor: Color(0xFFFF8C42),
      bgColor: Color(0xFFFFF5EE),
      bubbleColor: Color(0xFFFFD5B3),
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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  /// Saves the flag so onboarding never shows again, then routes to
  /// home (if signed in) or welcome/login screen.
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // ── Page view ──────────────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _ContentPage(page: _pages[i]),
          ),

          // ── Skip button ────────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 20),
                child: AnimatedOpacity(
                  opacity: _currentPage < _totalPages - 1 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _completeOnboarding, // ← was _goToWelcome
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _pages[_currentPage].accentColor.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _pages[_currentPage].accentColor.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: _pages[_currentPage].accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom nav ─────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(_totalPages, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? _pages[_currentPage].accentColor
                                : _pages[_currentPage].accentColor.withValues(
                                    alpha: 0.25,
                                  ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    // Next / Get Started button
                    GestureDetector(
                      onTap: _nextPage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                          horizontal: _currentPage == _totalPages - 1 ? 28 : 22,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _pages[_currentPage].accentColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: _pages[_currentPage].accentColor
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _currentPage == _totalPages - 1
                                    ? 'Get Started'
                                    : 'Next',
                                key: ValueKey(_currentPage == _totalPages - 1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _totalPages - 1
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Content page widget ──────────────────────────────────────────────────
class _ContentPage extends StatefulWidget {
  final _PageData page;
  const _ContentPage({required this.page});

  @override
  State<_ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<_ContentPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      color: widget.page.bgColor,
      child: Stack(
        children: [
          // ── Pastel bubble decorations ──────────────────────────────────
          ..._buildBubbles(widget.page.bubbleColor, size),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 72),

                    SizedBox(
                      height: size.height * 0.42,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Image.asset(
                            widget.page.imagePath,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: widget.page.accentColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.page.accentColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.page.tag,
                              style: TextStyle(
                                color: widget.page.accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            widget.page.title,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Container(
                            width: 44,
                            height: 3,
                            decoration: BoxDecoration(
                              color: widget.page.accentColor.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            widget.page.subtitle,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                              height: 1.65,
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
        ],
      ),
    );
  }
}

// ─── Bubble decorator ────────────────────────────────────────────────────────
List<Widget> _buildBubbles(Color bubbleColor, Size size) {
  return [
    Positioned(
      top: -80,
      right: -70,
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bubbleColor.withValues(alpha: 0.35),
        ),
      ),
    ),
    Positioned(
      top: 60,
      right: -30,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bubbleColor.withValues(alpha: 0.2),
        ),
      ),
    ),
    Positioned(
      bottom: size.height * 0.22,
      left: -70,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bubbleColor.withValues(alpha: 0.25),
        ),
      ),
    ),
    Positioned(
      bottom: size.height * 0.10,
      right: -35,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bubbleColor.withValues(alpha: 0.18),
        ),
      ),
    ),
  ];
}

// ─── Page data model ──────────────────────────────────────────────────────────
class _PageData {
  final String imagePath;
  final Color accentColor;
  final Color bgColor;
  final Color bubbleColor;
  final String tag;
  final String title;
  final String subtitle;

  const _PageData({
    required this.imagePath,
    required this.accentColor,
    required this.bgColor,
    required this.bubbleColor,
    required this.tag,
    required this.title,
    required this.subtitle,
  });
}
