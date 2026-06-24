import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/app_colors.dart';
import '../../core/app_utils.dart';
import '../../core/restaurant_image.dart';
import '../../data/restaurant_repository.dart';
import '../../data/api_service.dart';
import '../../data/location_service.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/user_preferences_cubit.dart';
import '../../models/restaurant_model.dart';
import '../../models/user_preferences_model.dart';
import 'restaurant_detail_screen.dart';
import 'personalisation_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// Smart Recommendation view wrapper class containing match metrics and explanations
class SmartRecommendation {
  final Restaurant restaurant;
  final double distanceKm;
  final int matchScore; // overall match score (e.g. 94)
  final int cuisineMatch; // e.g. 95%
  final int budgetMatch; // vibe / facility matching
  final int distanceMatch; // distance score
  final int topicMatch; // rating / topic similarity
  final List<String> reasons;

  SmartRecommendation({
    required this.restaurant,
    required this.distanceKm,
    required this.matchScore,
    required this.cuisineMatch,
    required this.budgetMatch,
    required this.distanceMatch,
    required this.topicMatch,
    required this.reasons,
  });
}

class SmartRecommendScreen extends StatefulWidget {
  const SmartRecommendScreen({super.key});

  @override
  State<SmartRecommendScreen> createState() => _SmartRecommendScreenState();
}

class _SmartRecommendScreenState extends State<SmartRecommendScreen>
    with SingleTickerProviderStateMixin {
  bool _generated = false;
  bool _isLoading = false;
  List<SmartRecommendation> _recommendations = [];
  double _userLat = LocationService.fallbackLat;
  double _userLon = LocationService.fallbackLon;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await LocationService.instance.getPosition();
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLon = pos.longitude;
        });
      }
    } catch (_) {}
  }

  Future<void> _generateRecommendations() async {
    setState(() {
      _isLoading = true;
      _generated = true;
    });

    try {
      final authState = context.read<AuthCubit>().state;
      String userId = '';
      if (authState is AuthAuthenticated) {
        userId = authState.user.id;
      }

      final prefs =
          context.read<UserPreferencesCubit>().current ??
          UserPreferencesModel.empty(userId);
      final repo = context.read<RestaurantRepository>();

      // 1. Fetch restaurants from API or fall back to DB
      List<Restaurant> sourceRestaurants = [];
      final isApiUp = await ApiService.instance.isApiAlive();

      if (isApiUp) {
        final selectedCuisines = prefs.cuisineTypes;
        final singleCuisine = selectedCuisines.length == 1
            ? selectedCuisines.first
            : null;

        final apiResult = await ApiService.instance.getRecommendations(
          userLat: _userLat,
          userLon: _userLon,
          distanceKm: prefs.defaultRadius,
          halal: prefs.halal,
          vegetarian: prefs.vegetarian,
          vegan: prefs.vegan,
          parking: prefs.hasParking,
          wifi: prefs.hasWifi,
          ac: prefs.hasAc,
          outdoor: prefs.hasOutdoor,
          accessible: prefs.accessible,
          familyFriendly: prefs.familyFriendly,
          groupFriendly: prefs.groupFriendly,
          casual: prefs.casual,
          romantic: prefs.romantic,
          scenicView: prefs.scenicView,
          worthIt: prefs.worthIt,
          fastService: prefs.fastService,
          cuisineType: singleCuisine,
        );

        if (apiResult != null && apiResult.restaurants.isNotEmpty) {
          sourceRestaurants = apiResult.restaurants;
        }
      }

      // Fall back to local DB if API is unreachable or returned empty
      if (sourceRestaurants.isEmpty) {
        sourceRestaurants = await repo.getAllRestaurants();
      }

      // 2. Perform detailed client-side match calculation & reasoning
      final scoredList = _analyzeAndRank(sourceRestaurants, prefs);

      if (mounted) {
        setState(() {
          _recommendations = scoredList.take(8).toList();
          _isLoading = false;
        });
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      debugPrint('Error generating recommendations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to generate recommendations. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<SmartRecommendation> _analyzeAndRank(
    List<Restaurant> restaurants,
    UserPreferencesModel prefs,
  ) {
    final List<SmartRecommendation> recs = [];

    for (final r in restaurants) {
      double distance = 0.0;
      if (r.lat != null && r.lon != null) {
        distance = AppUtils.calculateDistance(
          _userLat,
          _userLon,
          r.lat!,
          r.lon!,
        );
      }

      final reasons = <String>[];

      // A. Cuisine Match
      int cuisineMatch = 50;
      if (prefs.cuisineTypes.isNotEmpty) {
        final matches = r.cuisineTypes
            .where(
              (c) => prefs.cuisineTypes.any(
                (p) => p.toLowerCase() == c.toLowerCase(),
              ),
            )
            .toList();
        if (matches.isNotEmpty) {
          cuisineMatch = 100;
          reasons.add('Matches your preferred ${matches.join(", ")} cuisine');
        } else {
          cuisineMatch = 20;
        }
      } else {
        cuisineMatch = 90; // "Any" preferred
      }

      // B. Vibe & Attributes matching (KBF details)
      int kbfTotal = 0;
      int kbfMatches = 0;

      void checkMatch(bool prefValue, bool restValue, String matchReason) {
        if (prefValue) {
          kbfTotal++;
          if (restValue) {
            kbfMatches++;
            reasons.add(matchReason);
          }
        }
      }

      checkMatch(prefs.halal, r.isHalal, 'Matches your Halal requirement');
      checkMatch(
        prefs.vegetarian,
        r.isVegetarian,
        'Vegetarian options available',
      );
      checkMatch(prefs.vegan, r.isVegan, 'Vegan options available');
      checkMatch(prefs.hasParking, r.hasParking, 'Has parking available');
      checkMatch(prefs.hasWifi, r.hasWifi, 'Has free WiFi');
      checkMatch(prefs.hasAc, r.hasAc, 'Air-conditioned seating');
      checkMatch(prefs.hasOutdoor, r.hasOutdoor, 'Outdoor seating available');
      checkMatch(prefs.accessible, r.isAccessible, 'Wheelchair accessible');
      checkMatch(
        prefs.familyFriendly,
        r.isFamilyFriendly,
        'Matches your Family Friendly vibe',
      );
      checkMatch(
        prefs.groupFriendly,
        r.isGroupFriendly,
        'Matches your Group Friendly vibe',
      );
      checkMatch(prefs.casual, r.isCasual, 'Matches your Casual style');
      checkMatch(prefs.romantic, r.isRomantic, 'Perfect for Romantic dining');
      checkMatch(prefs.scenicView, r.hasScenicView, 'Offers a Scenic View');
      checkMatch(
        prefs.worthIt,
        r.isWorthIt,
        'Matches your value preference ("Worth It")',
      );
      checkMatch(prefs.fastService, r.isFastService, 'Quick and Fast Service');

      int vibeMatch = 100;
      if (kbfTotal > 0) {
        vibeMatch = ((kbfMatches / kbfTotal) * 100).round();
      } else {
        vibeMatch = (r.rating * 20).round().clamp(0, 100);
      }

      // C. Budget Match (Image 3 features matches budget preference)
      // Check price level (cheap/moderate <= 2 is budget friendly)
      if (r.priceLevel == null || r.priceLevel! <= 2) {
        reasons.add('Matches your budget preference');
      }

      // D. Distance Match
      int distanceMatch = 100;
      if (distance > 0) {
        distanceMatch = (100 - (distance * 3)).round().clamp(10, 100);
      }

      // E. Topic Similarity / Quality Rating Match
      int topicMatch = 80;
      if (r.rating >= 4.5) {
        topicMatch = 95;
      } else if (r.rating >= 4.0) {
        topicMatch = 85;
      } else if (r.rating >= 3.0) {
        topicMatch = 70;
      } else {
        topicMatch = 50;
      }

      // Baseline matches if explanations are completely empty
      if (reasons.isEmpty) {
        if (r.rating >= 4.5) {
          reasons.add('Highly rated by local foodies');
        }
        if (r.isHalal) {
          reasons.add('Halal certified/friendly dining');
        }
        if (r.cuisineTypes.isNotEmpty) {
          reasons.add('Popular choice for ${r.cuisineType} food');
        }
      }

      // Weighted average calculation
      double overall =
          (cuisineMatch * 0.35) +
          (vibeMatch * 0.35) +
          (distanceMatch * 0.15) +
          (topicMatch * 0.15);
      int overallScore = overall.round().clamp(
        50,
        99,
      ); // Max 99% for realistic score

      recs.add(
        SmartRecommendation(
          restaurant: r,
          distanceKm: distance,
          matchScore: overallScore,
          cuisineMatch: cuisineMatch,
          budgetMatch: vibeMatch,
          distanceMatch: distanceMatch,
          topicMatch: topicMatch,
          reasons: reasons.toSet().toList(), // Deduplicate
        ),
      );
    }

    // Sort by match score descending
    recs.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return recs;
  }

  void _navigateToPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<UserPreferencesCubit>()),
            BlocProvider.value(value: context.read<AuthCubit>()),
          ],
          child: const PersonalisationScreen(),
        ),
      ),
    ).then((_) {
      // Refresh preference screen settings when returning
      setState(() {});
    });
  }

  Widget _gradientThumbnailFallback(Restaurant r) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.18),
          AppColors.secondary.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(
      Icons.restaurant_rounded,
      color: AppColors.primary,
      size: 24,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthCubit>().state;
    final bool isGuest = authState is! AuthAuthenticated;
    String userId = '';
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }

    final prefs =
        context.watch<UserPreferencesCubit>().current ??
        UserPreferencesModel.empty(userId);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0F19)
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.oceanGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: Center(
          child: GestureDetector(
            onTap: () {
              if (_generated && !_isLoading && !isGuest) {
                setState(() => _generated = false);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        title: Text(
          isGuest
              ? 'Smart Recommend'
              : (_generated ? 'Your Smart Recommendations' : 'Smart Recommend'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: const [SizedBox(width: 48)],
      ),
      body: isGuest
          ? _buildLockedGuestState()
          : (_isLoading
                ? _buildLoadingState()
                : !_generated
                ? _buildPreparationState(prefs)
                : _buildResultsState()),
    );
  }

  Widget _buildLockedGuestState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Shield Lock Icon Card
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_person_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Unlock Smart Choices',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Personalized recommendations use your custom taste profile, budget limit, and dietary vibes to match you with the perfect dining options.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Sign Up Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Create Free Account',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.darkSecondary
                      : AppColors.secondary,
                  side: BorderSide(
                    color:
                        (isDark ? AppColors.darkSecondary : AppColors.secondary)
                            .withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dual State: Preparation (Image 2) ─────────────────────────────────────

  Widget _buildPreparationState(UserPreferencesModel prefs) {
    final hasCuisines = prefs.cuisineTypes.isNotEmpty;
    final cuisinesStr = hasCuisines ? prefs.cuisineTypes.join(', ') : 'Any';

    // Parse dietary
    final dietaryStr = prefs.dietarySummary != 'Not set'
        ? prefs.dietarySummary
        : 'None';

    // Parse vibe
    final vibeList = <String>[];
    if (prefs.familyFriendly) vibeList.add('Family Friendly');
    if (prefs.groupFriendly) vibeList.add('Group Friendly');
    if (prefs.casual) vibeList.add('Casual');
    if (prefs.romantic) vibeList.add('Romantic');
    if (prefs.scenicView) vibeList.add('Scenic View');
    final vibeStr = vibeList.isNotEmpty ? vibeList.join(', ') : 'Any';

    // Budget
    final budgetStr =
        r'$$'; // Default representation representing moderate price levels

    // Distance
    final distanceStr = prefs.defaultRadius >= 500
        ? 'Any distance'
        : '${prefs.defaultRadius.toInt()} km';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Large orange sparkles icon card
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.freshMakanGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Find your perfect meal',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Our hybrid engine combines knowledge-based filtering with LDA topic modelling.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Signal Rows list
          _buildSignalRow('Favourite cuisines', cuisinesStr),
          _buildSignalRow('Dietary', dietaryStr),
          _buildSignalRow('Vibe', vibeStr),
          _buildSignalRow('Budget', budgetStr),
          _buildSignalRow('Max distance', distanceStr),

          const SizedBox(height: 16),

          // Generate Recommendations Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _generateRecommendations,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adaptivePrimary(context),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Generate Recommendations',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Edit Preferences link
          GestureDetector(
            onTap: _navigateToPreferences,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Edit preferences →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSignalRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16222F)
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dual State: Results (Image 3) ─────────────────────────────────────────

  Widget _buildResultsState() {
    if (_recommendations.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Sub-header badge and subtitle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C42).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF8C42).withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 10,
                        color: Color(0xFFFF8C42),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'HYBRID AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF8C42),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your Smart Recommendations',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.4,
                      fontFamily: 'OpenSans',
                    ),
                    children: const [
                      TextSpan(text: 'Ranked using '),
                      TextSpan(
                        text: 'LDA topic similarity',
                        style: TextStyle(
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' + knowledge-based filtering on your preferences.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // List of recommendations
        SliverList(
          delegate: SliverChildBuilderDelegate((ctx, index) {
            final rec = _recommendations[index];
            final delay = (index * 0.06).clamp(0.0, 0.8);

            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final progress = Curves.easeOutCubic.transform(
                  ((_animationController.value - delay) / (1.0 - delay)).clamp(
                    0.0,
                    1.0,
                  ),
                );
                return Opacity(
                  opacity: progress,
                  child: Transform.translate(
                    offset: Offset(0, 32 * (1 - progress)),
                    child: child,
                  ),
                );
              },
              child: _buildRecommendationCard(rec, index),
            );
          }, childCount: _recommendations.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildRecommendationCard(SmartRecommendation rec, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = rec.restaurant;
    final rating = r.rating > 0 ? AppUtils.formatRating(r.rating) : 'N/A';
    final dist = rec.distanceKm > 0
        ? '${rec.distanceKm.toStringAsFixed(1)} km'
        : '0.0 km';
    final priceStr = r.priceLevel != null ? '\$' * r.priceLevel! : '\$\$';
    final primaryColor = AppColors.adaptivePrimary(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Core Restaurant Card Row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail with Rank Badge overlay
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: RestaurantImage.getUrl(
                          r.cuisineType,
                          seed: r.id,
                        ),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _gradientThumbnailFallback(r),
                        errorWidget: (_, _, _) => _gradientThumbnailFallback(r),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      left: -6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Info details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${r.categories} · ${r.cuisineType}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.star,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dist,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            priceStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.45),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Match Score Circle Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C42).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF8C42).withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${rec.matchScore}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF8C42),
                        ),
                      ),
                      const Text(
                        'MATCH',
                        style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF8C42),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Matching Reasons breakdown (Image 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indented Reasons section container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A2332)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WHY RECOMMENDED',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF8C42),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...rec.reasons.map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '✓',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : Colors.black.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // See Full Analysis button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(
                          restaurant: r,
                          userLat: _userLat,
                          userLon: _userLon,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'See full analysis',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading Skeleton (React matches loading states) ──────────────────────

  Widget _buildLoadingState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 3,
      itemBuilder: (ctx, index) => Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A26) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 90,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 110,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C42).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 42,
                color: Color(0xFFFF8C42),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No smart recommendations found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try updating your favourite cuisines or dietary restrictions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _navigateToPreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adaptivePrimary(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Edit Preferences'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
