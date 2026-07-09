import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
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
import '../../logic/cubits/favourite_cubit.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/discovery_filter_sheet.dart';
import '../widgets/gradient_divider.dart';
import '../widgets/curved_header_painter.dart';
import 'map_screen.dart';
import '../../models/user_preferences_model.dart';

class RestaurantSearchScreen extends StatefulWidget {
  const RestaurantSearchScreen({super.key});

  @override
  State<RestaurantSearchScreen> createState() => RestaurantSearchScreenState();
}

class RestaurantSearchScreenState extends State<RestaurantSearchScreen> {
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
  int? _activeMaxPriceLevel;
  String _sortBy = 'Nearest';

  // ─── Search history ────────────────────────────────────────────────────────
  final List<String> _searchHistory = [];
  bool _isSearchFocused = false;

  // ─── Debounce ─────────────────────────────────────────────────────────────
  Timer? _searchDebounce;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadLocationThenRestaurants();

    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });

    _searchController.addListener(() {
      setState(() {}); // Update UI to show clear button
      _debouncedSearch();
    });
  }

  void _debouncedSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_debounceDuration, _applyFilters);
  }

  Future<void> _loadLocationThenRestaurants() async {
    if (mounted) {
      await _initialLoad();
    }

    LocationService.instance
        .getPosition()
        .then((pos) {
          if (mounted) {
            setState(() {
              userLat = pos.latitude;
              userLon = pos.longitude;
            });
            _applyFilters();
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  // ─── Query matching ───────────────────────────────────────────────────────
  bool _matchesQuery(Restaurant r, String query) {
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase().trim();

    // Match restaurant name
    if (r.name.toLowerCase().contains(lowerQuery)) return true;

    // Match municipality (location)
    if (r.municipality.toLowerCase().contains(lowerQuery)) return true;

    // Match any individual cuisine type
    for (final cuisine in r.cuisineTypes) {
      if (cuisine.toLowerCase().contains(lowerQuery)) return true;
    }

    return false;
  }

  // ─── Attribute matchers ───────────────────────────────────────────────────
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
      case OccasionOptions.crowded:
        return r.isCrowded;
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

  void setCategory(String category) {
    setState(() {
      _searchController.clear();
      _activeDietary.clear();
      _activeOccasions.clear();
      _activeFacilities.clear();
      _activeMinRating = 0.0;
      _activeMaxDistance = 500.0;
      _activeMaxPriceLevel = null;

      if (category == 'All') {
        _activeCuisines = {};
      } else {
        _activeCuisines = {category};
      }
    });
    _applyFilters();
  }

  // ─── Filter logic ──────────────────────────────────────────────────────────
  void _applyFilters() {
    final q = _searchController.text.toLowerCase().trim();

    final results = _allRestaurants.where((r) {
      final matchQuery = _matchesQuery(r, q);
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
      final matchPrice =
          _activeMaxPriceLevel == null ||
          r.priceLevel == null ||
          r.priceLevel! <= _activeMaxPriceLevel!;

      return matchQuery &&
          matchCuisine &&
          matchRating &&
          matchDist &&
          matchDietary &&
          matchOccasion &&
          matchFacility &&
          matchPrice;
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
    int? maxPriceLevel,
  }) {
    final q = _searchController.text.toLowerCase().trim();
    return _allRestaurants.where((r) {
      final matchQuery = _matchesQuery(r, q);
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
      final matchPrice =
          maxPriceLevel == null ||
          r.priceLevel == null ||
          r.priceLevel! <= maxPriceLevel;
      return matchQuery &&
          matchCuisine &&
          matchRating &&
          matchDist &&
          matchDietary &&
          matchOccasion &&
          matchFacility &&
          matchPrice;
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
      _activeMaxPriceLevel = null;
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
      _activeMaxDistance < 500 ||
      _activeMaxPriceLevel != null;

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

  // ─── SHOW FILTER SHEET (Using DiscoveryFilterSheet) ──────────────────────
  Future<void> _showFilterSheet() async {
    // Build temporary preferences from current filter state
    final tempPrefs = UserPreferencesModel(
      userId: 'temp',
      cuisineTypes: _activeCuisines.toList(),
      halal: _activeDietary.contains(DietaryOptions.halal),
      vegetarian: _activeDietary.contains(DietaryOptions.vegetarian),
      vegan: _activeDietary.contains(DietaryOptions.vegan),
      hasParking: _activeFacilities.contains(FacilityOptions.parking),
      hasWifi: _activeFacilities.contains(FacilityOptions.wifi),
      hasAc: _activeFacilities.contains(FacilityOptions.ac),
      accessible: _activeFacilities.contains(FacilityOptions.accessible),
      hasOutdoor: _activeFacilities.contains(FacilityOptions.outdoor),
      familyFriendly: _activeOccasions.contains(OccasionOptions.family),
      groupFriendly: _activeOccasions.contains(OccasionOptions.group),
      casual: _activeOccasions.contains(OccasionOptions.casual),
      romantic: _activeOccasions.contains(OccasionOptions.romantic),
      scenicView: _activeOccasions.contains(OccasionOptions.scenicView),
      isCrowded: _activeOccasions.contains(OccasionOptions.crowded),
      worthIt: false,
      fastService: false,
      defaultRadius: _activeMaxDistance,
      budget: _activeMaxPriceLevel,
    );

    final result = await showDiscoveryFilterSheet(
      context,
      initialPreferences: tempPrefs,
      isQuickMode: false,
    );

    if (result != null && result.applied) {
      setState(() {
        _activeCuisines = Set.from(result.preferences.cuisineTypes);
        _activeDietary.clear();
        if (result.preferences.halal) _activeDietary.add(DietaryOptions.halal);
        if (result.preferences.vegetarian)
          _activeDietary.add(DietaryOptions.vegetarian);
        if (result.preferences.vegan) _activeDietary.add(DietaryOptions.vegan);

        _activeFacilities.clear();
        if (result.preferences.hasParking)
          _activeFacilities.add(FacilityOptions.parking);
        if (result.preferences.hasWifi)
          _activeFacilities.add(FacilityOptions.wifi);
        if (result.preferences.hasAc) _activeFacilities.add(FacilityOptions.ac);
        if (result.preferences.accessible)
          _activeFacilities.add(FacilityOptions.accessible);
        if (result.preferences.hasOutdoor)
          _activeFacilities.add(FacilityOptions.outdoor);

        _activeOccasions.clear();
        if (result.preferences.familyFriendly)
          _activeOccasions.add(OccasionOptions.family);
        if (result.preferences.groupFriendly)
          _activeOccasions.add(OccasionOptions.group);
        if (result.preferences.casual)
          _activeOccasions.add(OccasionOptions.casual);
        if (result.preferences.romantic)
          _activeOccasions.add(OccasionOptions.romantic);
        if (result.preferences.scenicView)
          _activeOccasions.add(OccasionOptions.scenicView);
        if (result.preferences.isCrowded)
          _activeOccasions.add(OccasionOptions.crowded);

        _activeMaxDistance = result.preferences.defaultRadius;
        _activeMaxPriceLevel = result.preferences.budget;
      });
      _applyFilters();
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
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
          extendBodyBehindAppBar: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    controller: _listController,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 154,
                        ),
                      ),
                      // Recent searches
                      if (_isSearchFocused &&
                          _searchHistory.isNotEmpty &&
                          !_isSearching)
                        SliverToBoxAdapter(
                          child: _buildRecentSearchesSection(),
                        ),

                      // Cuisine chips
                      SliverToBoxAdapter(child: _buildCuisineChips()),

                      // Searching / filtered mode
                      if (_isSearching || _hasActiveFilters) ...[
                        SliverToBoxAdapter(child: _buildResultsHeader()),
                        if (_filteredResults.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: RestaurantCard(
                                    restaurant: _filteredResults[i],
                                    variant: RestaurantCardVariant.standard,
                                    userLat: userLat,
                                    userLon: userLon,
                                    onTap: () {
                                      if (_searchController.text
                                          .trim()
                                          .isNotEmpty) {
                                        _addToHistory(
                                          _searchController.text.trim(),
                                        );
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RestaurantDetailScreen(
                                                restaurant: _filteredResults[i],
                                                userLat: userLat,
                                                userLon: userLon,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                childCount: _filteredResults.length,
                              ),
                            ),
                          ),
                      ]
                      // Default browse mode
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
                            child: _buildHorizontalCardRow(_nearbyList),
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
                          child: _buildHorizontalCardRow(_topRatedList),
                        ),

                        // All Restaurants
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            title: 'All Restaurants',
                            subtitle: '${_allRestaurants.length} places',
                            onSeeAll: null,
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: RestaurantCard(
                                  restaurant: _allRestaurants[i],
                                  variant: RestaurantCardVariant.standard,
                                  userLat: userLat,
                                  userLon: userLon,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RestaurantDetailScreen(
                                        restaurant: _allRestaurants[i],
                                        userLat: userLat,
                                        userLon: userLon,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              childCount: _allRestaurants.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: 82,
      title: const Padding(
        padding: EdgeInsets.only(left: 18),
        child: Text(
          'Discovery',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                offset: Offset(0, 1.5),
                blurRadius: 4.0,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ),
      actions: [
        Center(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            ),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 19,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: Stack(
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
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    onSubmitted: (query) {
                      _addToHistory(query);
                      _applyFilters();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search restaurants, cuisines...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFAAAAAA),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showFilterSheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: _hasActiveFilters
                              ? Colors.white
                              : AppColors.primary,
                        ),
                        if (_hasActiveFilters)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 5,
                              height: 5,
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
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
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
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
              constraints: const BoxConstraints(minWidth: 70),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : Theme.of(
                        context,
                      ).colorScheme.surfaceContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  cuisine,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
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
              color: Theme.of(context).colorScheme.onSurface,
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
                ).colorScheme.onSurface.withValues(alpha: 0.7),
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
                  color: AppColors.primary,
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
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: list.take(10).length,
        itemBuilder: (_, i) => RestaurantCard(
          restaurant: list[i],
          variant: RestaurantCardVariant.portrait,
          userLat: userLat,
          userLon: userLon,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantDetailScreen(
                restaurant: list[i],
                userLat: userLat,
                userLon: userLon,
              ),
            ),
          ),
        ),
      ),
    );
  }

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
              ).colorScheme.onSurface.withValues(alpha: 0.75),
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

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/no_results.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildFallbackEmptyIcon(),
          ),
          const SizedBox(height: 20),
          const Text(
            'No restaurants found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or adjust your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
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

  Widget _buildFallbackEmptyIcon() => Container(
    width: 120,
    height: 120,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.07),
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.search_off_rounded,
      size: 48,
      color: AppColors.primary.withValues(alpha: 0.4),
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
}
