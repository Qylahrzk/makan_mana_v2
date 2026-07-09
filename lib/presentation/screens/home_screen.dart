import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:makan_mana_v2/core/app_router.dart';
import '../../core/app_constants.dart';
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
import '../widgets/curved_header_painter.dart';
import 'restaurant_detail_screen.dart';
import 'recommendation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _userLat = LocationService.instance.cachedLat;
  double _userLon = LocationService.instance.cachedLon;

  bool get _isGuest => !context.read<AuthCubit>().isAuthenticated;

  String _locationLabel = 'Terengganu, MY';
  bool _locationLoading = false;

  List<Restaurant> _recommended = [];
  List<Restaurant> _allPopular = [];
  List<Restaurant> _nearby = [];

  bool _loadingRecommended = true;
  bool _loadingPopular = true;
  bool _loadingNearby = true;
  bool _errorRecommended = false;
  bool _errorPopular = false;

  // ── Nearby rating filter ───────────────────────────────────────────────────
  final double _nearbyMinRating = 0.0;

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

  Future<void> _loadLocation({
    bool forceRefresh = false,
    UserPreferencesModel? preloadedPrefs,
  }) async {
    if (!mounted) return;
    setState(() => _locationLoading = true);
    try {
      final pos = await LocationService.instance.getPosition(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        final double oldLat = _userLat;
        final double oldLon = _userLon;

        setState(() {
          _userLat = pos.latitude;
          _userLon = pos.longitude;
        });

        await _reverseGeocode(pos.latitude, pos.longitude);

        if (!mounted) return;

        // If real GPS coordinates were resolved (different from fallback or previous ones),
        // refresh recommended and nearby sections.
        final resolvedRealLocation =
            pos.latitude != LocationService.fallbackLat ||
            pos.longitude != LocationService.fallbackLon;
        final locationChanged =
            pos.latitude != oldLat || pos.longitude != oldLon;

        if (resolvedRealLocation && locationChanged) {
          final tasks = <Future<void>>[_loadNearby()];
          if (!_isGuest) {
            setState(() {
              _loadingRecommended = true;
            });
            tasks.add(_loadRecommended(preloadedPrefs: preloadedPrefs));
          }
          setState(() {
            _loadingNearby = true;
          });
          await Future.wait(tasks);
        }
      }
    } catch (e) {
      debugPrint('HomeScreen._loadLocation error: $e');
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
      }
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

    final isGuestUser = _isGuest;

    setState(() {
      _loadingRecommended = !isGuestUser;
      _loadingPopular = true;
      _loadingNearby = true;
      _errorRecommended = false;
      _errorPopular = false;
    });

    if (isRefresh) {
      context.read<RestaurantRepository>().clearCache();
      LocationService.instance.clearCache();
    }

    // Load data synchronously with whatever coordinates we currently have (fallback or cached)

    final tasks = <Future<void>>[_loadPopular(), _loadNearby()];
    if (!isGuestUser) {
      tasks.add(_loadRecommended(preloadedPrefs: preloadedPrefs));
    }

    await Future.wait(tasks);

    // Kick off location retrieval asynchronously in the background so it doesn't block startup
    _loadLocation(forceRefresh: isRefresh, preloadedPrefs: preloadedPrefs);
  }

  Future<void> _loadRecommended({UserPreferencesModel? preloadedPrefs}) async {
    final prefsCubit = context.read<UserPreferencesCubit>();
    final restaurantRepo = context.read<RestaurantRepository>();
    try {
      final prefs = preloadedPrefs ?? prefsCubit.current;
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

      // Apply local constraints (budget & crowded vibe)
      if (prefs?.budget != null) {
        restaurants = restaurants
            .where(
              (r) => r.priceLevel == null || r.priceLevel! <= prefs!.budget!,
            )
            .toList();
      }
      if (prefs?.isCrowded == true) {
        restaurants = restaurants.where((r) => r.isCrowded).toList();
      }

      if (selectedCuisines.isNotEmpty) {
        var filtered = restaurants
            .where((r) => r.matchesAnyCuisine(selectedCuisines))
            .toList();
        if (filtered.isEmpty) {
          final allLocal = await restaurantRepo.getAllRestaurants();
          filtered = allLocal
              .where((r) => r.matchesAnyCuisine(selectedCuisines))
              .toList();
          // Filter by budget & crowded on local fallback too
          if (prefs?.budget != null) {
            filtered = filtered
                .where(
                  (r) =>
                      r.priceLevel == null || r.priceLevel! <= prefs!.budget!,
                )
                .toList();
          }
          if (prefs?.isCrowded == true) {
            filtered = filtered.where((r) => r.isCrowded).toList();
          }
          filtered.sort((a, b) => b.rating.compareTo(a.rating));
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
          _allPopular = sorted.take(20).toList();
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

  /// Filters nearby restaurants by minimum rating
  List<Restaurant> _applyNearbyRatingFilter(List<Restaurant> list) {
    if (_nearbyMinRating == 0.0) {
      return list;
    }
    return list.where((r) => r.rating >= _nearbyMinRating).toList();
  }

  void _switchToExploreTab() {
    final proxy = context.findAncestorStateOfType<NavTabProxy>();
    if (proxy != null) {
      proxy.switchTab(1);
    } else {
      Navigator.pushNamed(context, '/search');
    }
  }

  // Link category tap to search screen with filtering
  void _onCategoryTap(String cuisine) {
    final proxy = context.findAncestorStateOfType<NavTabProxy>();
    if (proxy != null) {
      proxy.switchTab(1, cuisine: cuisine);
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

  void _toggleFavourite(Restaurant r) {
    GuestGuard.check(
      context,
      featureName: 'save restaurants to your favourites',
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
                nowSaved ? 'Removed from favourites' : '❤️ Saved to favourites',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              duration: const Duration(seconds: 1),
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
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
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

              SliverToBoxAdapter(child: _buildHeroRecommendCard()),

              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '',
                  title: 'Browse by Category',
                ),
              ),
              SliverToBoxAdapter(child: _buildCategoryRow()),

              // ── NEARBY SECTION WITH RATING FILTER ──────────────────────
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '',
                  title: 'Nearby Restaurants',
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
                    : _buildCardRow(_applyNearbyRatingFilter(_nearby)),
              ),

              // ── RECOMMENDED SECTION ────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '',
                  title: 'Recommended For You',
                  showSeeAll: !_isGuest && _recommended.isNotEmpty,
                  onSeeAll: !_isGuest && _recommended.isNotEmpty
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
                child: _isGuest
                    ? _buildGuestRecommendationBanner()
                    : (_loadingRecommended
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
                          : _buildCardRow(_recommended, showFindSimilar: true)),
              ),

              // ── MOST POPULAR SECTION (NO RATING FILTER) ────────────────
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  emoji: '',
                  title: 'Most Popular',
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
                    : _allPopular.isEmpty
                    ? _buildEmptyState('No popular restaurants found')
                    : _buildCardRow(_allPopular),
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipPath(
          clipper: const HeaderCurveClipper(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.oceanGradient,
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
                          onTap: _locationLoading
                              ? null
                              : () => _loadLocation(forceRefresh: true),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1.5),
                                blurRadius: 4.0,
                                color: Colors.black26,
                              ),
                            ],
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
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
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
        ),
        Positioned(
          bottom: -1,
          left: -1,
          right: -1,
          child: CustomPaint(
            size: const Size(double.infinity, 48),
            painter: CurvedHeaderPainter.adaptive(context),
          ),
        ),
      ],
    );
  }

  // ── Walking banner ─────────────────────────────────────────────────────────

  Widget _buildWalkingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.oceanGradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.2),
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

  Widget _buildHeroRecommendCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        GuestGuard.check(
          context,
          featureName: 'get personalized AI recommendations',
          onAllowed: () {
            Navigator.pushNamed(context, AppRoutes.smartRecommend);
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFFFF7A00), Color(0xFFD07E50)]
                : const [Color(0xFFFF9E40), Color(0xFFFFC78C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isDark
                          ? Color.fromARGB(255, 252, 160, 100)
                          : Color.fromARGB(255, 255, 158, 64))
                      .withValues(alpha: isDark ? 0.12 : 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AI-POWERED',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5C2D00),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Get smart recommendations',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3B1E00),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Explainable matches based on your taste & topic similarity.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B3C0E),
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Try MakanMana AI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B1E00),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: Color(0xFF3B1E00),
                        ),
                      ],
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

  Widget _buildGuestRecommendationBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF16222F), const Color(0xFF0F172A)]
              : [const Color(0xFFE6F4F6), const Color(0xFFD0EDF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.secondary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unlock Custom Choices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Create an account to tell us what you like! Get custom choices based on your preferred cuisines, budget limits, and dietary options.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                GuestGuard.check(
                  context,
                  featureName: 'personalize your recommendations',
                  onAllowed: () {},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Personalize Now',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
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
          onFavourite: () => _toggleFavourite(list[i]),
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
  final VoidCallback onFavourite;
  final VoidCallback? onFindSimilar;

  const _RestaurantCard({
    required this.restaurant,
    required this.userLat,
    required this.userLon,
    required this.showFindSimilar,
    required this.onTap,
    required this.onFavourite,
    this.onFindSimilar,
  });

  Widget _gradientFallback(BuildContext context) => Container(
    height: 108,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.8),
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.4),
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
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.20
                    : 0.04,
              ),
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
                    placeholder: (_, _) => _gradientFallback(context),
                    errorWidget: (_, _, _) => _gradientFallback(context),
                  ),
                ),
                // ✅ FIX: Reduced overlay opacity from 0.3 to 0.15 for lighter effect
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
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.15),
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
                    onTap: onFavourite,
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
                            colors: AppColors.freshMakanGradient,
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
