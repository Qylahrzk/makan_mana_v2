import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:makan_mana_v2/core/app_router.dart';
import '../../core/app_colors.dart';
import '../../core/app_utils.dart';
import '../../core/nav_tab_proxy.dart';
import '../../core/guest_guard.dart';
import '../../core/restaurant_image.dart';
import '../../data/restaurant_repository.dart';
import '../../data/api_service.dart';
import '../../data/location_service.dart';
import '../../data/motion_service.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/favourite_cubit.dart';
import '../../logic/cubits/recommendation_cubit.dart';
import '../../logic/cubits/user_preferences_cubit.dart';
import '../../models/restaurant_model.dart';
import '../../models/user_preferences_model.dart';
import 'restaurant_detail_screen.dart';
import 'recommendation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _userLat = LocationService.fallbackLat;
  double _userLon = LocationService.fallbackLon;

  String _locationLabel = 'Terengganu, MY';
  bool _locationLoading = false;

  List<Restaurant> _recommended = [];
  List<Restaurant> _allPopular = [];
  List<Restaurant> _popular = [];
  List<Restaurant> _nearby = [];
  bool _loadingRecommended = true;
  bool _loadingPopular = true;
  bool _loadingNearby = true;
  bool _errorRecommended = false;
  bool _errorPopular = false;

  double? _minRatingFilter;

  static const List<(String, double?)> _ratingOptions = [
    ('All', null),
    ('3.0+', 3.0),
    ('4.0+', 4.0),
    ('4.5+', 4.5),
  ];

  bool _isWalking = false;
  StreamSubscription<bool>? _motionSub;

  @override
  void initState() {
    super.initState();
    _startMotionSensor();
    _loadPreferencesThenSections();
  }

  void _startMotionSensor() {
    MotionService.instance.start();
    _motionSub = MotionService.instance.isMoving.listen((moving) {
      if (mounted) setState(() => _isWalking = moving);
    });
  }

  @override
  void dispose() {
    _motionSub?.cancel();
    MotionService.instance.stop();
    super.dispose();
  }

  Future<void> _loadPreferencesThenSections() async {
    UserPreferencesModel? loadedPrefs;
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      loadedPrefs = await context.read<UserPreferencesCubit>().loadPreferences(
        authState.user.id,
      );
    }
    await _loadSections(preloadedPrefs: loadedPrefs);
  }

  Future<void> _loadLocation() async {
    setState(() => _locationLoading = true);
    try {
      final pos = await LocationService.instance.getPosition();
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLon = pos.longitude;
        });
        await _reverseGeocode(pos.latitude, pos.longitude);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty || !mounted) return;

      String? neighbourhood;
      String? city;
      String? state;

      for (final place in placemarks) {
        final sub = place.subLocality?.trim();
        final loc = place.locality?.trim();
        final subAdmin = place.subAdministrativeArea?.trim();
        final admin = place.administrativeArea?.trim();

        neighbourhood ??= (sub?.isNotEmpty == true) ? sub : null;
        city ??= (loc?.isNotEmpty == true)
            ? loc
            : (subAdmin?.isNotEmpty == true ? subAdmin : null);
        state ??= (admin?.isNotEmpty == true) ? admin : null;

        if (neighbourhood != null && city != null) break;
        if (city != null && state != null) break;
      }

      final parts = <String>[];
      if (neighbourhood != null && neighbourhood.isNotEmpty) {
        parts.add(neighbourhood);
        if (city != null && city != neighbourhood) parts.add(city);
      } else if (city != null && city.isNotEmpty) {
        parts.add(city);
        if (state != null && state.isNotEmpty && state != city) {
          parts.add(state);
        }
      } else if (state != null && state.isNotEmpty) {
        parts.add(state);
      }

      if (parts.isNotEmpty && mounted) {
        setState(() => _locationLabel = parts.join(', '));
      }
    } catch (_) {}
  }

  Future<void> _loadSections({
    bool isRefresh = false,
    UserPreferencesModel? preloadedPrefs,
  }) async {
    if (!mounted) return;
    setState(() {
      _loadingRecommended = true;
      _loadingPopular = true;
      _loadingNearby = true;
      _errorRecommended = false;
      _errorPopular = false;
    });
    if (isRefresh) {
      context.read<RestaurantRepository>().clearCache();
    }
    await _loadLocation();
    await Future.wait([
      _loadRecommended(preloadedPrefs: preloadedPrefs),
      _loadPopular(),
      _loadNearby(),
    ]);
  }

  Future<void> _loadRecommended({UserPreferencesModel? preloadedPrefs}) async {
    try {
      final prefs =
          preloadedPrefs ?? context.read<UserPreferencesCubit>().current;
      final selectedCuisines = prefs?.cuisineTypes ?? [];
      final singleCuisine = selectedCuisines.length == 1
          ? selectedCuisines.first
          : null;

      final result = await ApiService.instance.getRecommendations(
        userLat: _userLat,
        userLon: _userLon,
        district: 'Kuala Terengganu',
        distanceKm: prefs?.defaultRadius ?? 500.0,
        halal: prefs?.halal ?? false,
        vegetarian: prefs?.vegetarian ?? false,
        vegan: prefs?.vegan ?? false,
        parking: prefs?.hasParking ?? false,
        wifi: prefs?.hasWifi ?? false,
        ac: prefs?.hasAc ?? false,
        outdoor: prefs?.hasOutdoor ?? false,
        accessible: prefs?.accessible ?? false,
        familyFriendly: prefs?.familyFriendly ?? false,
        groupFriendly: prefs?.groupFriendly ?? false,
        casual: prefs?.casual ?? false,
        romantic: prefs?.romantic ?? false,
        scenicView: prefs?.scenicView ?? false,
        worthIt: prefs?.worthIt ?? false,
        fastService: prefs?.fastService ?? false,
        cuisineType: singleCuisine,
      );

      var restaurants = result?.restaurants ?? [];

      if (selectedCuisines.isNotEmpty) {
        var filtered = restaurants
            .where((r) => r.matchesAnyCuisine(selectedCuisines))
            .toList();
        if (filtered.isEmpty) {
          final allLocal = await context
              .read<RestaurantRepository>()
              .getAllRestaurants();
          filtered =
              allLocal
                  .where((r) => r.matchesAnyCuisine(selectedCuisines))
                  .toList()
                ..sort((a, b) => b.rating.compareTo(a.rating));
          filtered = filtered.take(10).toList();
        }
        restaurants = filtered;
      }

      if (mounted) {
        setState(() {
          _recommended = restaurants;
          _loadingRecommended = false;
        });
      }
    } catch (e) {
      debugPrint('HomeScreen._loadRecommended error: $e');
      if (mounted) {
        setState(() {
          _loadingRecommended = false;
          _errorRecommended = true;
        });
      }
    }
  }

  Future<void> _loadPopular() async {
    try {
      final repo = context.read<RestaurantRepository>();
      final all = await repo.getAllRestaurants();
      final sorted = [...all]..sort((a, b) => b.rating.compareTo(a.rating));

      if (mounted) {
        setState(() {
          _allPopular = sorted;
          _popular = _applyRatingFilter(sorted);
          _loadingPopular = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPopular = false;
          _errorPopular = true;
        });
      }
    }
  }

  Future<void> _loadNearby() async {
    try {
      final repo = context.read<RestaurantRepository>();
      final all = await repo.getAllRestaurants();
      final withDist =
          all
              .where((r) => r.lat != null && r.lon != null)
              .map(
                (r) => MapEntry(
                  r,
                  AppUtils.calculateDistance(
                    _userLat,
                    _userLon,
                    r.lat!,
                    r.lon!,
                  ),
                ),
              )
              .where((e) => e.value <= 30.0)
              .toList()
            ..sort((a, b) => a.value.compareTo(b.value));
      if (mounted) {
        setState(() {
          _nearby = withDist.take(10).map((e) => e.key).toList();
          _loadingNearby = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNearby = false);
    }
  }

  /// Returns up to 20 restaurants for the active filter.
  ///
  /// "All" — diversified mix: 4 excellent (≥4.5), 3 very good (4.0–4.49),
  ///          2 good (3.0–3.99), 1 below-avg (<3.0). Surplus from a sparse
  ///          band is reallocated to the next-lower band.
  ///
  /// "3.0+" — show 3.0–3.99 restaurants FIRST (ascending rating so lowest
  ///           come first and users can actually discover them), then
  ///           append higher-rated restaurants to fill to 20.
  ///
  /// "4.0+" — show 4.0–4.49 first, then ≥4.5.
  ///
  /// "4.5+" — show ≥4.5 ascending so there's still some variety.
  List<Restaurant> _applyRatingFilter(List<Restaurant> list) {
    // ── Specific filter active ────────────────────────────────────────
    if (_minRatingFilter != null) {
      final min = _minRatingFilter!;

      if (min == 3.0) {
        // 3.0–3.99 ascending first, then 4.0+ descending
        final band =
            list.where((r) => r.rating >= 3.0 && r.rating < 4.0).toList()
              ..sort((a, b) => a.rating.compareTo(b.rating));
        final above = list.where((r) => r.rating >= 4.0).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        return [...band, ...above].take(20).toList();
      }

      if (min == 4.0) {
        // 4.0–4.49 ascending first, then ≥4.5 descending
        final band =
            list.where((r) => r.rating >= 4.0 && r.rating < 4.5).toList()
              ..sort((a, b) => a.rating.compareTo(b.rating));
        final above = list.where((r) => r.rating >= 4.5).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        return [...band, ...above].take(20).toList();
      }

      if (min == 4.5) {
        // ≥4.5 ascending so we see 4.5 restaurants, not just 5.0
        return (list.where((r) => r.rating >= 4.5).toList()
              ..sort((a, b) => a.rating.compareTo(b.rating)))
            .take(20)
            .toList();
      }

      // Generic fallback
      return list.where((r) => r.rating >= min).take(20).toList();
    }

    // ── "All" — diversified mix ───────────────────────────────────────
    final excellent = list.where((r) => r.rating >= 4.5).toList();
    final veryGood = list
        .where((r) => r.rating >= 4.0 && r.rating < 4.5)
        .toList();
    final good = list.where((r) => r.rating >= 3.0 && r.rating < 4.0).toList();
    final belowAvg = list.where((r) => r.rating < 3.0).toList();

    const quotas = [4, 3, 2, 1];
    final bands = [excellent, veryGood, good, belowAvg];
    final result = <Restaurant>[];
    int surplus = 0;

    for (int i = 0; i < bands.length; i++) {
      final wanted = quotas[i] + surplus;
      final taken = bands[i].take(wanted).toList();
      result.addAll(taken);
      surplus = (wanted - taken.length).clamp(0, 5);
    }

    return result.take(10).toList();
  }

  void _switchToExploreTab() {
    final proxy = context.findAncestorStateOfType<NavTabProxy>();
    if (proxy != null) {
      proxy.switchTab(1);
    } else {
      Navigator.pushNamed(context, '/search');
    }
  }

  Future<void> _onCategoryTap(String cuisine) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      final result = await ApiService.instance.getRecommendations(
        cuisineType: cuisine == 'All' ? null : cuisine,
        userLat: _userLat,
        userLon: _userLon,
        distanceKm: 500.0,
      );
      if (!mounted) return;
      Navigator.pop(context);
      final restaurants = result?.restaurants ?? [];
      if (restaurants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No $cuisine restaurants found nearby'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecommendationScreen(
            recommendations: restaurants,
            isFromApi: true,
            relaxedFilters: result?.filtersRelaxed ?? [],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load restaurants. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openDetail(Restaurant r) {
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
  }

  void _findSimilar(Restaurant r) {
    context.read<RecommendationCubit>().getHybridRecommendations(r);
  }

  void _toggleWishlist(Restaurant r) {
    GuestGuard.check(
      context,
      featureName: 'save restaurants to your wishlist',
      onAllowed: () {
        final user = context.read<AuthCubit>().currentUser;
        if (user == null) return;
        context.read<FavouriteCubit>().toggleFavourite(
          userId: user.id,
          restaurant: r,
        );
        final nowSaved = context.read<FavouriteCubit>().isSaved(r.name);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                nowSaved ? '❤️ Saved to wishlist' : 'Removed from wishlist',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Bottom nav bar height + safe area — so the last section isn't clipped
    final bottomNavClearance = MediaQuery.of(context).padding.bottom + 80;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<RecommendationCubit, RecommendationState>(
          listener: (ctx, state) {
            if (state is RecLoaded) {
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => RecommendationScreen(
                    selectedRestaurant: state.targetRestaurant,
                    recommendations: state.recommendations,
                    isFromApi: state.isFromApi,
                    relaxedFilters: state.relaxedFilters,
                  ),
                ),
              );
            }
          },
        ),
        BlocListener<UserPreferencesCubit, UserPreferencesState>(
          listenWhen: (previous, current) =>
              previous is PreferencesSaving && current is PreferencesLoaded,
          listener: (ctx, state) {
            if (!mounted) return;
            setState(() {
              _loadingRecommended = true;
              _errorRecommended = false;
            });
            _loadRecommended();
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () => _loadSections(isRefresh: true),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              if (_isWalking) SliverToBoxAdapter(child: _buildWalkingBanner()),

              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '🍽️',
                  title: 'Browse by Category',
                ),
              ),
              SliverToBoxAdapter(child: _buildCategoryRow()),

              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '📍',
                  title: 'Nearby Restaurants',
                  subtitle: 'Within 30 km from you',
                  showSeeAll: _nearby.isNotEmpty,
                  onSeeAll: _nearby.isNotEmpty
                      ? () => Navigator.pushNamed(
                          context,
                          '/recommendation',
                          arguments: RecommendationArgs(
                            recommendations: _nearby,
                            isFromApi: false,
                          ),
                        )
                      : null,
                ),
              ),
              SliverToBoxAdapter(
                child: _loadingNearby
                    ? _buildSkeletonRow()
                    : _nearby.isEmpty
                    ? _buildNearbyEmptyState()
                    : _buildCardRow(_nearby),
              ),

              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '✨',
                  title: 'Recommended For You',
                  subtitle: 'Powered by AI · LDA + KBF',
                  showSeeAll: true,
                  onSeeAll: _recommended.isNotEmpty
                      ? () => Navigator.pushNamed(
                          context,
                          '/recommendation',
                          arguments: RecommendationArgs(
                            recommendations: _recommended,
                            isFromApi: true,
                          ),
                        )
                      : null,
                ),
              ),
              SliverToBoxAdapter(
                child: _loadingRecommended
                    ? _buildSkeletonRow()
                    : _errorRecommended
                    ? _buildOfflineState(
                        onRetry: () {
                          setState(() {
                            _loadingRecommended = true;
                            _errorRecommended = false;
                          });
                          _loadRecommended();
                        },
                      )
                    : _recommended.isEmpty
                    ? _buildEmptyRecommendations()
                    : _buildCardRow(_recommended, showFindSimilar: true),
              ),

              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '🔥',
                  title: 'Most Popular',
                  subtitle: _popularSubtitle(),
                  showSeeAll: true,
                  onSeeAll: _allPopular.isNotEmpty
                      ? () => Navigator.pushNamed(
                          context,
                          '/recommendation',
                          arguments: RecommendationArgs(
                            recommendations: _allPopular,
                            isFromApi: false,
                          ),
                        )
                      : null,
                ),
              ),

              SliverToBoxAdapter(child: _buildRatingFilterRow()),

              SliverToBoxAdapter(
                child: _loadingPopular
                    ? _buildSkeletonRow()
                    : _errorPopular
                    ? _buildOfflineState(
                        onRetry: () {
                          setState(() {
                            _loadingPopular = true;
                            _errorPopular = false;
                          });
                          _loadPopular();
                        },
                      )
                    : _popular.isEmpty
                    ? _buildEmptyState('No restaurants found for this filter')
                    : _buildCardRow(_popular),
              ),

              // FIX: Dynamic bottom clearance so the last section is
              // never hidden behind the floating nav bar.
              SliverToBoxAdapter(child: SizedBox(height: bottomNavClearance)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Subtitle helper ────────────────────────────────────────────────────────

  String _popularSubtitle() {
    if (_minRatingFilter == null) {
      return 'A mix of picks across Terengganu';
    }
    if (_minRatingFilter == 3.0) {
      return 'Showing 3.0–3.99 ⭐ restaurants first';
    }
    if (_minRatingFilter == 4.0) {
      return 'Showing 4.0–4.49 ⭐ restaurants first';
    }
    if (_minRatingFilter == 4.5) {
      return 'Showing 4.5+ ⭐ restaurants (lowest first)';
    }
    return '${_popular.length} restaurants rated '
        '${_minRatingFilter!.toStringAsFixed(1)}+';
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0A5260),
                Color(0xFF15687A),
                Color(0xFF1E8599),
                Color(0xFFFF8C42),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _locationLoading ? null : _loadLocation,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            if (_locationLoading)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white70,
                                ),
                              )
                            else
                              Text(
                                _locationLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (_, state) {
                          final name = state is AuthAuthenticated
                              ? state.user.fullName
                              : '';
                          return Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _initials(name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (_, state) {
                      final name = state is AuthAuthenticated
                          ? state.user.firstName
                          : 'there';
                      return Text(
                        '${_greeting()}, $name! 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _switchToExploreTab,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Search restaurants, cuisine...',
                              style: TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: AppColors.primary,
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
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: CustomPaint(
            size: const Size(double.infinity, 56),
            painter: _ConvexBottomCurvePainter(bgColor: scaffoldBg),
          ),
        ),
      ],
    );
  }

  // ── Rating filter row ──────────────────────────────────────────────────────

  Widget _buildRatingFilterRow() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        itemCount: _ratingOptions.length,
        itemBuilder: (_, i) {
          final (label, value) = _ratingOptions[i];
          final active = _minRatingFilter == value;
          return GestureDetector(
            onTap: () {
              if (_minRatingFilter == value) return;
              setState(() {
                _minRatingFilter = value;
                _popular = _applyRatingFilter(_allPopular);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.star.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? AppColors.star
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.12),
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null) ...[
                    Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: active
                          ? AppColors.star
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppColors.star
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Walking banner ─────────────────────────────────────────────────────────

  Widget _buildWalkingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFFFF6B35)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_walk_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "You're on the move! Showing restaurants near you.",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isWalking = false),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ── Nearby empty state ─────────────────────────────────────────────────────

  Widget _buildNearbyEmptyState() {
    final outsideTerengganu =
        _userLat < 3.8 ||
        _userLat > 6.2 ||
        _userLon < 102.3 ||
        _userLon > 103.5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Text(
              outsideTerengganu ? '✈️' : '📍',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outsideTerengganu
                        ? "You're outside Terengganu"
                        : 'No restaurants nearby',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    outsideTerengganu
                        ? "Showing all Terengganu restaurants above — plan your next visit!"
                        : 'Try expanding your search radius in the filter.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty recommendations ──────────────────────────────────────────────────

  Widget _buildEmptyRecommendations() {
    final prefs = context.read<UserPreferencesCubit>().current;
    final hasCuisine = prefs?.cuisineTypes.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Text(
              hasCuisine ? '🍽️' : '✨',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCuisine
                        ? 'No ${prefs!.cuisineTypes.join(" or ")} restaurants found'
                        : 'No recommendations yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasCuisine
                        ? 'The AI server may not have results for your cuisine preference right now. Try pulling down to refresh.'
                        : 'Set your cuisine preferences in Profile → My Preferences.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String emoji,
    required String title,
    String? subtitle,
    bool showSeeAll = false,
    VoidCallback? onSeeAll,
    double topPad = 4,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (showSeeAll)
                GestureDetector(
                  onTap: onSeeAll ?? _switchToExploreTab,
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Category row ───────────────────────────────────────────────────────────

  static const Map<String, String> _categoryEmoji = {
    'All': '🍽️',
    'Malay': '🍛',
    'Seafood': '🦞',
    'Western': '🍔',
    'Cafe': '☕',
    'Chinese': '🥢',
    'Thai': '🌶️',
    'Fast Food': '🍟',
    'BBQ': '🍖',
    'Dessert': '🍰',
    'Japanese': '🍱',
    'Middle Eastern': '🫔',
    'Indonesian': '🍜',
    'Korean': '🥘',
  };

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        itemCount: _categoryEmoji.length,
        itemBuilder: (_, i) {
          final cat = _categoryEmoji.keys.toList()[i];
          final emoji = _categoryEmoji[cat]!;
          return _CategoryChip(
            label: cat,
            emoji: emoji,
            onTap: () => _onCategoryTap(cat),
          );
        },
      ),
    );
  }

  // ── Card row ───────────────────────────────────────────────────────────────

  Widget _buildCardRow(List<Restaurant> list, {bool showFindSimilar = false}) {
    return SizedBox(
      height: showFindSimilar ? 280 : 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        itemCount: list.length,
        itemBuilder: (_, i) => _RestaurantCard(
          restaurant: list[i],
          userLat: _userLat,
          userLon: _userLon,
          showFindSimilar: showFindSimilar,
          onTap: () => _openDetail(list[i]),
          onWishlist: () => _toggleWishlist(list[i]),
          onFindSimilar: showFindSimilar ? () => _findSimilar(list[i]) : null,
        ),
      ),
    );
  }

  // ── Offline state ──────────────────────────────────────────────────────────

  Widget _buildOfflineState({required VoidCallback onRetry}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Could not reach server',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The AI server may be waking up. Try again.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Skeleton row ───────────────────────────────────────────────────────────

  Widget _buildSkeletonRow() {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        itemCount: 4,
        itemBuilder: (_, i) => _SkeletonCard(key: ValueKey(i)),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

// ─── Convex Curve Painter ─────────────────────────────────────────────────────

class _ConvexBottomCurvePainter extends CustomPainter {
  const _ConvexBottomCurvePainter({required this.bgColor});
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    const offsets = [0.0, 1.5, -1.5];
    for (final dy in offsets) {
      final path = Path();
      path.moveTo(0, size.height);
      path.lineTo(0, size.height * 0.55 + dy);
      path.cubicTo(
        size.width * 0.20,
        size.height * 0.55 + dy - 6,
        size.width * 0.80,
        size.height * 0.55 + dy - 6,
        size.width,
        size.height * 0.55 + dy,
      );
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ConvexBottomCurvePainter old) => old.bgColor != bgColor;
}

// ─── Category Chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Restaurant Card ──────────────────────────────────────────────────────────

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final double userLat;
  final double userLon;
  final bool showFindSimilar;
  final VoidCallback onTap;
  final VoidCallback onWishlist;
  final VoidCallback? onFindSimilar;

  const _RestaurantCard({
    required this.restaurant,
    required this.userLat,
    required this.userLon,
    required this.showFindSimilar,
    required this.onTap,
    required this.onWishlist,
    this.onFindSimilar,
  });

  Widget _gradientFallback() => Container(
    height: 108,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.75),
          AppColors.primary.withValues(alpha: 0.55),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 4),
          Text(
            restaurant.cuisineType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final km = (r.lat != null && r.lon != null)
        ? AppUtils.calculateDistance(userLat, userLon, r.lat!, r.lon!)
        : null;
    final attrs = r.activeAttributes;
    final isSaved = context.watch<FavouriteCubit>().isSaved(r.name);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: RestaurantImage.getUrl(
                      r.cuisineType.isNotEmpty ? r.cuisineType : 'Other',
                      seed: r.id,
                    ),
                    height: 108,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    placeholder: (_, _) => _gradientFallback(),
                    errorWidget: (_, _, _) => _gradientFallback(),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      r.cuisineType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onWishlist,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 16,
                        color: isSaved
                            ? Colors.red
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          AppUtils.formatRating(r.rating),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          r.municipality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      if (km != null)
                        Text(
                          '${km.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                  if (attrs.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: attrs
                          .take(2)
                          .map(
                            (a) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (showFindSimilar) ...[
                    const SizedBox(height: 7),
                    GestureDetector(
                      onTap: onFindSimilar,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Find Similar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton Card ────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard({super.key});
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: 190,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 108,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: _anim.value),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(130, 12),
                  const SizedBox(height: 6),
                  _box(90, 10),
                  const SizedBox(height: 8),
                  _box(60, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: _anim.value),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}
