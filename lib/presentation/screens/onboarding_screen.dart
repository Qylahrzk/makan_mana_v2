import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makan_mana_v2/core/app_colors.dart';
import 'package:makan_mana_v2/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// OnboardingScreen with vibrant teal-to-orange gradients
///
/// Multi-page carousel showing app features with smooth animations

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
      accentColor: AppColors.primary,
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
      accentColor: AppColors.primary,
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
        duration: const Duration(milliseconds: 500),
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _ContentPage(page: _pages[i]),
          ),

          // Skip button (top-right)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 20),
                child: AnimatedOpacity(
                  opacity: _currentPage < _totalPages - 1 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: _completeOnboarding,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _pages[_currentPage].accentColor.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _pages[_currentPage].accentColor.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_currentPage].accentColor.withValues(
                              alpha: 0.1,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: _pages[_currentPage].accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
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
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot indicators with smooth animation
                    Row(
                      children: List.generate(_totalPages, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 8),
                          width: active ? 28 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: active
                                ? _pages[_currentPage].accentColor
                                : _pages[_currentPage].accentColor.withValues(
                                    alpha: 0.25,
                                  ),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: _pages[_currentPage].accentColor
                                          .withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                        );
                      }),
                    ),

                    // Next button with glass morphism
                    GestureDetector(
                      onTap: _nextPage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                          horizontal: _currentPage == _totalPages - 1 ? 32 : 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _pages[_currentPage].accentColor,
                              _pages[_currentPage].accentColor.withValues(
                                alpha: 0.85,
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _pages[_currentPage].accentColor
                                  .withValues(alpha: 0.4),
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
                                _currentPage == _totalPages - 1
                                    ? 'Get Started'
                                    : 'Next',
                                key: ValueKey(_currentPage == _totalPages - 1),
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
                              turns: _currentPage == _totalPages - 1 ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                _currentPage == _totalPages - 1
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
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
    final size = MediaQuery.of(context).size;

    return Container(
      color: widget.page.bgColor,
      child: Stack(
        children: [
          // Glossy blob decorations
          ..._buildBlobDecorations(widget.page.bubbleColor, size),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),

                      // Image section
                      SizedBox(
                        height: size.height * 0.42,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
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

                      // Text content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tag with glossy effect
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: widget.page.accentColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: widget.page.accentColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.page.accentColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.page.tag,
                                style: TextStyle(
                                  color: widget.page.accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            Text(
                              widget.page.title,
                              style: TextStyle(
                                color: const Color(0xFF1A1A1A),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Underline accent
                            Container(
                              width: 48,
                              height: 4,
                              decoration: BoxDecoration(
                                color: widget.page.accentColor.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Subtitle
                            Text(
                              widget.page.subtitle,
                              style: TextStyle(
                                color: const Color(0xFF9CA3AF),
                                fontSize: 14,
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
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBlobDecorations(Color bubbleColor, Size size) {
    return [
      Positioned(
        top: -60,
        right: -70,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bubbleColor.withValues(alpha: 0.4),
            boxShadow: [
              BoxShadow(
                color: bubbleColor.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
      ),
      Positioned(
        top: 60,
        right: -30,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bubbleColor.withValues(alpha: 0.25),
            boxShadow: [
              BoxShadow(
                color: bubbleColor.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
      ),
      Positioned(
        bottom: size.height * 0.25,
        left: -80,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bubbleColor.withValues(alpha: 0.3),
            boxShadow: [
              BoxShadow(
                color: bubbleColor.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
        ),
      ),
      Positioned(
        bottom: size.height * 0.12,
        right: -40,
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bubbleColor.withValues(alpha: 0.2),
            boxShadow: [
              BoxShadow(
                color: bubbleColor.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

// ─── Page data model ──────────────────────────────────────────────────────
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
