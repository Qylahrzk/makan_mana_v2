import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/app_utils.dart';
import '../../core/app_constants.dart';
import '../../core/restaurant_image.dart';
import '../../logic/cubits/recommendation_cubit.dart';
import '../../models/restaurant_model.dart';
import '../../data/restaurant_repository.dart';
import '../../data/location_service.dart';
import 'recommendation_screen.dart';
import 'restaurant_detail_screen.dart';
import '../../core/guest_guard.dart';
import '../../logic/cubits/wishlist_cubit.dart';
import '../../logic/cubits/auth_cubit.dart';
import 'map_screen.dart';

class RestaurantSearchScreen extends StatefulWidget {
  const RestaurantSearchScreen({super.key});

  @override
  State<RestaurantSearchScreen> createState() => _RestaurantSearchScreenState();
}

class _RestaurantSearchScreenState extends State<RestaurantSearchScreen> {
  // ─── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _listController = ScrollController();

  // ─── Data ─────────────────────────────────────────────────────────────────
  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _filteredResults = [];
  bool _isLoading = false;
  Restaurant? _selectedRestaurant;

  double userLat = LocationService.fallbackLat;
  double userLon = LocationService.fallbackLon;

  // ─── Filter state ──────────────────────────────────────────────────────────
  Set<String> _activeCuisines = {};
  Set<String> _activeDietary = {};
  Set<String> _activeOccasions = {};
  Set<String> _activeFacilities = {};
  double _activeMinRating = 0.0;
  double _activeMaxDistance = 500.0;
  String _sortBy = 'Nearest';

  // ─── Search history ────────────────────────────────────────────────────────
  final List<String> _searchHistory = [];
  bool _isSearchFocused = false;

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadLocationThenRestaurants();

    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });

    _searchController.addListener(() {
      setState(() {});
      _applyFilters();
    });
  }

  Future<void> _loadLocationThenRestaurants() async {
    try {
      final pos = await LocationService.instance.getPosition();
      if (mounted) {
        userLat = pos.latitude;
        userLon = pos.longitude;
      }
    } catch (_) {}
    if (mounted) await _initialLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listController.dispose();
    super.dispose();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────
  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<RestaurantRepository>();
      final restaurants = await repo.getAllRestaurants();
      if (mounted) {
        setState(() => _allRestaurants = restaurants);
        _applyFilters();
      }
    } catch (e) {
      debugPrint('SearchScreen load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    context.read<RestaurantRepository>().clearCache();
    await _initialLoad();
  }

  // ─── Search history ────────────────────────────────────────────────────────
  void _addToHistory(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _searchHistory.remove(q);
      _searchHistory.insert(0, q);
      if (_searchHistory.length > 8) _searchHistory.removeLast();
    });
  }

  void _removeFromHistory(String query) {
    setState(() => _searchHistory.remove(query));
  }

  void _clearHistory() {
    setState(() => _searchHistory.clear());
  }

  void _applyHistoryItem(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _searchFocusNode.unfocus();
    _addToHistory(query);
    _applyFilters();
  }

  // ─── Distance helper ──────────────────────────────────────────────────────
  double _getDistance(Restaurant r) => AppUtils.calculateDistance(
    userLat,
    userLon,
    r.lat ?? userLat,
    r.lon ?? userLon,
  );

  // ─── Attribute matchers (UPDATED TO MATCH CONSTANTS) ──────────────────────
  bool _matchesDietary(Restaurant r, String label) {
    switch (label) {
      case DietaryOptions.halal:
        return r.isHalal;
      case DietaryOptions.vegetarian:
        return r.isVegetarian;
      case DietaryOptions.vegan:
        return r.isVegan;
      default:
        return false;
    }
  }

  bool _matchesOccasion(Restaurant r, String label) {
    switch (label) {
      case OccasionOptions.family:
        return r.isFamilyFriendly;
      case OccasionOptions.group:
        return r.isGroupFriendly;
      case OccasionOptions.casual:
        return r.isCasual;
      case OccasionOptions.romantic:
        return r.isRomantic;
      case OccasionOptions.scenicView:
        return r.hasScenicView;
      default:
        return false;
    }
  }

  bool _matchesFacility(Restaurant r, String label) {
    switch (label) {
      case FacilityOptions.parking:
        return r.hasParking;
      case FacilityOptions.wifi:
        return r.hasWifi;
      case FacilityOptions.ac:
        return r.hasAc;
      case FacilityOptions.accessible:
        return r.isAccessible;
      case FacilityOptions.outdoor:
        return r.hasOutdoor;
      default:
        return false;
    }
  }

  // ─── Filter logic ──────────────────────────────────────────────────────────
  void _applyFilters() {
    final q = _searchController.text.toLowerCase().trim();

    final results = _allRestaurants.where((r) {
      final allCuisines = r.cuisineTypes.join(' ').toLowerCase();
      final matchQuery =
          q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          allCuisines.contains(q) ||
          r.municipality.toLowerCase().contains(q);

      final matchCuisine =
          _activeCuisines.isEmpty ||
          r.matchesAnyCuisine(_activeCuisines.toList());
      final matchRating = r.rating >= _activeMinRating;
      final matchDist = _activeMaxDistance >= 500
          ? true
          : _getDistance(r) <= _activeMaxDistance;
      final matchDietary =
          _activeDietary.isEmpty ||
          _activeDietary.any((f) => _matchesDietary(r, f));
      final matchOccasion =
          _activeOccasions.isEmpty ||
          _activeOccasions.any((f) => _matchesOccasion(r, f));
      final matchFacility =
          _activeFacilities.isEmpty ||
          _activeFacilities.any((f) => _matchesFacility(r, f));

      return matchQuery &&
          matchCuisine &&
          matchRating &&
          matchDist &&
          matchDietary &&
          matchOccasion &&
          matchFacility;
    }).toList();

    if (_sortBy == 'Nearest') {
      results.sort((a, b) => _getDistance(a).compareTo(_getDistance(b)));
    } else {
      results.sort((a, b) => b.rating.compareTo(a.rating));
    }

    setState(() {
      _filteredResults = results;
      _selectedRestaurant = results.isNotEmpty ? results.first : null;
    });
  }

  int _previewFilterCount({
    required Set<String> cuisines,
    required Set<String> dietary,
    required Set<String> occasions,
    required Set<String> facilities,
    required double minRating,
    required double maxDist,
  }) {
    final q = _searchController.text.toLowerCase().trim();
    return _allRestaurants.where((r) {
      final allCuisines = r.cuisineTypes.join(' ').toLowerCase();
      final matchQuery =
          q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          allCuisines.contains(q);
      final matchCuisine =
          cuisines.isEmpty || r.matchesAnyCuisine(cuisines.toList());
      final matchRating = r.rating >= minRating;
      final matchDist = maxDist >= 500 ? true : _getDistance(r) <= maxDist;
      final matchDietary =
          dietary.isEmpty || dietary.any((f) => _matchesDietary(r, f));
      final matchOccasion =
          occasions.isEmpty || occasions.any((f) => _matchesOccasion(r, f));
      final matchFacility =
          facilities.isEmpty || facilities.any((f) => _matchesFacility(r, f));
      return matchQuery &&
          matchCuisine &&
          matchRating &&
          matchDist &&
          matchDietary &&
          matchOccasion &&
          matchFacility;
    }).length;
  }

  void _resetFilters() {
    setState(() {
      _activeCuisines = {};
      _activeDietary = {};
      _activeOccasions = {};
      _activeFacilities = {};
      _activeMinRating = 0.0;
      _activeMaxDistance = 500.0;
      _sortBy = 'Nearest';
      _searchController.clear();
    });
    _applyFilters();
  }

  bool get _hasActiveFilters =>
      _activeCuisines.isNotEmpty ||
      _activeDietary.isNotEmpty ||
      _activeOccasions.isNotEmpty ||
      _activeFacilities.isNotEmpty ||
      _activeMinRating > 0 ||
      _activeMaxDistance < 500;

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  // ─── Derived lists ────────────────────────────────────────────────────────
  List<Restaurant> get _nearbyList =>
      _allRestaurants
          .where(
            (r) => r.lat != null && r.lon != null && _getDistance(r) <= 10.0,
          )
          .toList()
        ..sort((a, b) => _getDistance(a).compareTo(_getDistance(b)));

  List<Restaurant> get _topRatedList =>
      [..._allRestaurants]..sort((a, b) => b.rating.compareTo(a.rating));

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return BlocListener<RecommendationCubit, RecommendationState>(
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
        } else if (state is RecError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: GestureDetector(
        onTap: () => _searchFocusNode.unfocus(),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                _buildTopBar(),

                // ── Main scrollable content ───────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: AppColors.primary,
                          child: CustomScrollView(
                            controller: _listController,
                            slivers: [
                              // Recent searches — shown when focused + empty
                              if (_isSearchFocused &&
                                  _searchHistory.isNotEmpty &&
                                  !_isSearching)
                                SliverToBoxAdapter(
                                  child: _buildRecentSearchesSection(),
                                ),

                              // Cuisine chips — always visible
                              SliverToBoxAdapter(child: _buildCuisineChips()),

                              // ── Searching / filtered mode ─────────────
                              if (_isSearching || _hasActiveFilters) ...[
                                SliverToBoxAdapter(
                                  child: _buildResultsHeader(),
                                ),
                                if (_filteredResults.isEmpty)
                                  SliverFillRemaining(child: _buildEmptyState())
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      120,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (_, i) =>
                                            _buildCard(_filteredResults[i]),
                                        childCount: _filteredResults.length,
                                      ),
                                    ),
                                  ),
                              ]
                              // ── Default browse mode ───────────────────
                              else ...[
                                // Nearby section
                                if (_nearbyList.isNotEmpty) ...[
                                  SliverToBoxAdapter(
                                    child: _buildSectionHeader(
                                      title: 'Nearby',
                                      onSeeAll: () => _pushSeeAll(
                                        _nearbyList.take(50).toList(),
                                        'Nearby Restaurants',
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: _buildHorizontalCardRow(
                                      _nearbyList.take(10).toList(),
                                    ),
                                  ),
                                ],

                                // Top Rated section
                                SliverToBoxAdapter(
                                  child: _buildSectionHeader(
                                    title: 'Top Rated',
                                    onSeeAll: () => _pushSeeAll(
                                      _topRatedList.take(50).toList(),
                                      'Top Rated',
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: _buildHorizontalCardRow(
                                    _topRatedList.take(10).toList(),
                                  ),
                                ),

                                // All Restaurants vertical list
                                SliverToBoxAdapter(
                                  child: _buildSectionHeader(
                                    title: 'All Restaurants',
                                    subtitle:
                                        '${_allRestaurants.length} places',
                                    onSeeAll: null,
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    120,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) => _buildCard(_filteredResults[i]),
                                      childCount: _filteredResults.length,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: title left, map button right ──────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discovery',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Kuala Terengganu',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),

              // Map view button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapScreen()),
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.map_outlined,
                    size: 19,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Row 2: search bar + filter button ────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(
                      color: _isSearchFocused
                          ? AppColors.primary.withValues(alpha: 0.45)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (query) {
                      _addToHistory(query);
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search restaurants, cuisine...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _isSearchFocused
                            ? AppColors.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _hasActiveFilters
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.surfaceContainer
                              .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: _hasActiveFilters
                            ? Colors.white
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      if (_hasActiveFilters)
                        Positioned(
                          top: 9,
                          right: 9,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Recent searches section ───────────────────────────────────────────────
  Widget _buildRecentSearchesSection() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent searches',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _clearHistory,
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._searchHistory
              .take(5)
              .map(
                (query) => GestureDetector(
                  onTap: () => _applyHistoryItem(query),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 17,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            query,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeFromHistory(query),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── Cuisine chips ─────────────────────────────────────────────────────────
  Widget _buildCuisineChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: CuisineOptions.all.length,
        itemBuilder: (_, i) {
          final cuisine = CuisineOptions.all[i];
          final active = cuisine == 'All'
              ? _activeCuisines.isEmpty
              : _activeCuisines.contains(cuisine);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (cuisine == 'All') {
                  _activeCuisines = {};
                } else if (_activeCuisines.contains(cuisine)) {
                  _activeCuisines = Set.from(_activeCuisines)..remove(cuisine);
                } else {
                  _activeCuisines = Set.from(_activeCuisines)..add(cuisine);
                }
              });
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : Theme.of(
                        context,
                      ).colorScheme.surfaceContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cuisine,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Horizontal card row ──────────────────────────────────────────────────
  Widget _buildHorizontalCardRow(List<Restaurant> list) {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: list.length,
        itemBuilder: (_, i) => _buildHorizontalCard(list[i]),
      ),
    );
  }

  // ─── Horizontal card ──────────────────────────────────────────────────────
  Widget _buildHorizontalCard(Restaurant r) {
    final km = _getDistance(r);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: r),
        ),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => _horizontalCardFallback(),
                errorWidget: (_, _, _) => _horizontalCardFallback(),
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                      const SizedBox(width: 3),
                      Text(
                        AppUtils.formatRating(r.rating),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  Text(
                    r.cuisineTypes.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${km.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _horizontalCardFallback() => Container(
    height: 100,
    color: AppColors.primary.withValues(alpha: 0.07),
    child: Center(
      child: Icon(
        Icons.restaurant_rounded,
        size: 26,
        color: AppColors.primary.withValues(alpha: 0.35),
      ),
    ),
  );

  // ─── Results header ────────────────────────────────────────────────────────
  Widget _buildResultsHeader() {
    final count = _filteredResults.length;
    final sort = _sortBy == 'Nearest' ? 'nearest first' : 'top rated first';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            '$count place${count == 1 ? '' : 's'} · $sort',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(
                () => _sortBy = _sortBy == 'Nearest' ? 'Rating' : 'Nearest',
              );
              _applyFilters();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sortBy == 'Nearest'
                        ? Icons.near_me_rounded
                        : Icons.star_rounded,
                    size: 12,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortBy,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
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

  // ─── Vertical restaurant card ──────────────────────────────────────────────
  Widget _buildCard(Restaurant r) {
    final isSelected = _selectedRestaurant?.id == r.id;
    final km = _getDistance(r);
    final attrs = r.activeAttributes;

    return GestureDetector(
      onTap: () {
        if (_searchController.text.trim().isNotEmpty) {
          _addToHistory(_searchController.text.trim());
        }
        setState(() => _selectedRestaurant = r);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: r),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                placeholder: (_, _) => _thumbnailFallback(),
                errorWidget: (_, _, _) => _thumbnailFallback(),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.cuisineTypes.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: AppColors.star),
                      const SizedBox(width: 3),
                      Text(
                        AppUtils.formatRating(r.rating),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${km.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  if (attrs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: attrs
                          .take(2)
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.07,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF2F6F7E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionBtn(
                    icon: Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    onTap: () => context
                        .read<RecommendationCubit>()
                        .getHybridRecommendations(r),
                  ),
                  const SizedBox(height: 6),
                  _actionBtn(
                    icon: Icons.chevron_right_rounded,
                    color: AppColors.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(restaurant: r),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _WishlistButton(restaurant: r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailFallback() => Container(
    width: 76,
    height: 76,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      Icons.restaurant_rounded,
      color: AppColors.primary.withValues(alpha: 0.4),
      size: 24,
    ),
  );

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 16),
    ),
  );

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 34,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No restaurants found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search or adjust your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _resetFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Reset filters',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  // ─── See All navigation ────────────────────────────────────────────────────
  void _pushSeeAll(List<Restaurant> list, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationScreen(
          recommendations: list,
          isFromApi: false,
          relaxedFilters: const [],
        ),
      ),
    );
  }

  // ─── Filter sheet ──────────────────────────────────────────────────────────
  void _showFilterSheet() {
    final tempCuisines = Set<String>.from(_activeCuisines);
    final tempDietary = Set<String>.from(_activeDietary);
    final tempOccasions = Set<String>.from(_activeOccasions);
    final tempFacilities = Set<String>.from(_activeFacilities);
    var tempMinRating = _activeMinRating;
    var tempMaxDist = _activeMaxDistance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final bottomPad = MediaQuery.of(sheetCtx).padding.bottom;
          final previewCount = _previewFilterCount(
            cuisines: tempCuisines,
            dietary: tempDietary,
            occasions: tempOccasions,
            facilities: tempFacilities,
            minRating: tempMinRating,
            maxDist: tempMaxDist,
          );

          void applyAndClose() {
            setState(() {
              _activeCuisines = Set.from(tempCuisines);
              _activeDietary = Set.from(tempDietary);
              _activeOccasions = Set.from(tempOccasions);
              _activeFacilities = Set.from(tempFacilities);
              _activeMinRating = tempMinRating;
              _activeMaxDistance = tempMaxDist;
            });
            _applyFilters();
            Navigator.pop(context);
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 14, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setModal(() {
                          tempCuisines.clear();
                          tempDietary.clear();
                          tempOccasions.clear();
                          tempFacilities.clear();
                          tempMinRating = 0.0;
                          tempMaxDist = 500.0;
                        }),
                        child: const Text(
                          'Reset all',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fsTitle('Cuisine'),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            tempCuisines.isEmpty
                                ? 'All cuisines'
                                : '${tempCuisines.length} selected',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        _fsChips(
                          CuisineOptions.all.where((c) => c != 'All').toList(),
                          (item) => tempCuisines.contains(item),
                          (item, sel) => setModal(
                            () => sel
                                ? tempCuisines.add(item)
                                : tempCuisines.remove(item),
                          ),
                        ),
                        _fsTitle('Max Distance'),
                        _fsSlider(
                          value: tempMaxDist,
                          label: tempMaxDist >= 500
                              ? 'Any'
                              : '${tempMaxDist.toInt()} km',
                          min: 1,
                          max: 500,
                          divisions: 10,
                          color: AppColors.secondary,
                          onChanged: (v) => setModal(() => tempMaxDist = v),
                        ),
                        _fsTitle('Minimum Rating'),
                        _fsSlider(
                          value: tempMinRating,
                          label: tempMinRating == 0
                              ? 'Any'
                              : '${tempMinRating.toStringAsFixed(1)}+',
                          min: 0,
                          max: 5,
                          divisions: 10,
                          color: AppColors.primary,
                          onChanged: (v) => setModal(() => tempMinRating = v),
                        ),
                        _fsTitle('Dietary'),
                        _fsChips(
                          DietaryOptions.all,
                          (item) => tempDietary.contains(item),
                          (item, sel) => setModal(
                            () => sel
                                ? tempDietary.add(item)
                                : tempDietary.remove(item),
                          ),
                        ),
                        _fsTitle('Occasions & Atmosphere'),
                        _fsChips(
                          OccasionOptions.all,
                          (item) => tempOccasions.contains(item),
                          (item, sel) => setModal(
                            () => sel
                                ? tempOccasions.add(item)
                                : tempOccasions.remove(item),
                          ),
                        ),
                        _fsTitle('Facilities'),
                        _fsChips(
                          FacilityOptions.all,
                          (item) => tempFacilities.contains(item),
                          (item, sel) => setModal(
                            () => sel
                                ? tempFacilities.add(item)
                                : tempFacilities.remove(item),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    (bottomPad > 0 ? bottomPad : 16) + 8,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 17,
                          ),
                          label: const Text(
                            'Get AI Recommendations',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () {
                            applyAndClose();
                            if (_filteredResults.isNotEmpty) {
                              context
                                  .read<RecommendationCubit>()
                                  .getHybridRecommendations(
                                    _filteredResults.first,
                                  );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: applyAndClose,
                          child: Text(
                            'Show Results ($previewCount)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fsTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(
      t,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );

  Widget _fsChips(
    List<String> items,
    bool Function(String) isSelected,
    void Function(String, bool) onToggle,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: items.map((item) {
      final sel = isSelected(item);
      return GestureDetector(
        onTap: () => onToggle(item, !sel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.secondary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel ? AppColors.secondary : Theme.of(context).dividerColor,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sel) ...[
                Icon(Icons.check_rounded, size: 12, color: AppColors.secondary),
                const SizedBox(width: 4),
              ],
              Text(
                item,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel
                      ? AppColors.secondary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _fsSlider({
    required double value,
    required String label,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
  }) => Row(
    children: [
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbColor: color,
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.15),
            overlayColor: color.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    ],
  );
}

// ─── Wishlist Button ──────────────────────────────────────────────────────────

class _WishlistButton extends StatelessWidget {
  final Restaurant restaurant;
  const _WishlistButton({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WishlistCubit, WishlistState>(
      builder: (context, state) {
        final saved = state is WishlistLoaded
            ? state.isSaved(restaurant.name)
            : false;
        return GestureDetector(
          onTap: () => GuestGuard.check(
            context,
            featureName: 'save restaurants to your wishlist',
            onAllowed: () {
              final user = context.read<AuthCubit>().currentUser;
              if (user == null) return;
              context.read<WishlistCubit>().toggleWishlist(
                userId: user.id,
                restaurant: restaurant,
              );
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      saved ? 'Removed from wishlist' : '❤️ Saved to wishlist',
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
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: saved
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: saved ? Colors.red : Colors.red.withValues(alpha: 0.45),
              size: 16,
            ),
          ),
        );
      },
    );
  }
}
