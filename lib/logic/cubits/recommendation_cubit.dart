import 'dart:developer';
import 'dart:math' hide log;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_constants.dart';
import '../../core/app_utils.dart';
import '../../data/restaurant_repository.dart';
import '../../data/api_service.dart';
import '../../models/restaurant_model.dart';

part 'recommendation_state.dart';

/// RecommendationCubit — Two recommendation modes
///
/// FIXES in this version:
///   1. Cache invalidation with TTL (5 minutes)
///      - Prevents unbounded memory growth
///      - Automatic refresh after timeout
///
///   2. Explicit cache clearing on certain events
///      - When user changes preferences, cache is invalidated
///      - When app detects major location change, cache is invalidated

class RecommendationCubit extends Cubit<RecommendationState> {
  final RestaurantRepository repository;
  final ApiService _api;

  List<Restaurant> _cachedRestaurants = [];
  DateTime? _cacheTimestamp;

  // Cache TTL — 5 minutes before auto-refresh
  static const Duration _cacheTTL = Duration(minutes: 5);

  RecommendationCubit(this.repository, {ApiService? apiService})
    : _api = apiService ?? ApiService.instance,
      super(RecInitial());

  // ─── CACHE MANAGEMENT ──────────────────────────────────────────────────────

  /// Returns true if the cache is still valid (within TTL)
  bool get _isCacheValid {
    if (_cachedRestaurants.isEmpty || _cacheTimestamp == null) return false;
    final age = DateTime.now().difference(_cacheTimestamp!);
    return age < _cacheTTL;
  }

  /// Invalidates the cache immediately (not time-based)
  void invalidateCache() {
    log('Cache invalidated', name: 'RecCubit');
    _cachedRestaurants.clear();
    _cacheTimestamp = null;
  }

  /// Loads and caches all restaurants if not already cached and valid
  Future<void> loadMasterList() async {
    try {
      // Skip if cache is still valid
      if (_isCacheValid) {
        log(
          'Using cached restaurant list (age=${DateTime.now().difference(_cacheTimestamp!).inSeconds}s)',
          name: 'RecCubit',
        );
        return;
      }

      log('Fetching fresh restaurant list...', name: 'RecCubit');
      _cachedRestaurants = await repository.getAllRestaurants();
      _cacheTimestamp = DateTime.now();
      log(
        '✅ Master list cached: ${_cachedRestaurants.length} restaurants',
        name: 'RecCubit',
      );

      // Warm up API connection in background
      _api.isApiAlive().then(
        (ok) => log(
          'API warm-up: ${ok ? "ready" : "cold/unreachable"}',
          name: 'RecCubit',
        ),
      );
    } catch (e) {
      log('loadMasterList error: $e', name: 'RecCubit');
    }
  }

  // ─── MODE 1: SIMILAR RESTAURANTS ───────────────────────────────────────────

  /// Loads restaurants similar to [target] using a 3-tier fallback strategy.
  /// Used on RestaurantDetailScreen → emits RecLoaded
  Future<void> getHybridRecommendations(Restaurant target) async {
    emit(RecLoading());

    try {
      // ── 1. Try Flask API ──────────────────────────────────────────────────
      final apiResult = await _api.getRecommendations(
        preferredTopic: target.topicLabel,
        district: target.municipality,
        cuisineType: target.cuisineType,
        distanceKm: 500.0,
        halal: target.isHalal,
        vegetarian: target.isVegetarian,
        vegan: target.isVegan,
        parking: target.hasParking,
        wifi: target.hasWifi,
        ac: target.hasAc,
        outdoor: target.hasOutdoor,
        accessible: target.isAccessible,
        familyFriendly: target.isFamilyFriendly,
        groupFriendly: target.isGroupFriendly,
        casual: target.isCasual,
        romantic: target.isRomantic,
        scenicView: target.hasScenicView,
        worthIt: target.isWorthIt,
        fastService: target.isFastService,
      );

      if (apiResult != null && apiResult.restaurants.isNotEmpty) {
        final results = apiResult.restaurants
            .where((r) => r.name != target.name)
            .take(5)
            .toList();
        log(
          'Using API recommendations: ${results.length} results',
          name: 'RecCubit',
        );
        emit(
          RecLoaded(
            recommendations: results,
            targetRestaurant: target,
            source: RecSource.api,
            relaxedFilters: apiResult.filtersRelaxed,
          ),
        );
        return;
      }
      log(
        'API returned empty — falling back to local algorithm',
        name: 'RecCubit',
      );
    } catch (e) {
      log('API call failed — falling back to local: $e', name: 'RecCubit');
    }

    // ── 2. Local fallback ────────────────────────────────────────────────────
    try {
      final results = await _getLocalRecommendations(target);
      emit(
        RecLoaded(
          recommendations: results,
          targetRestaurant: target,
          source: RecSource.local,
        ),
      );
    } catch (e) {
      log('Local algorithm error: $e', name: 'RecCubit');
      emit(RecError('Could not generate recommendations. Please try again.'));
    }
  }

  // ─── MODE 2: PREFERENCE-BASED RECOMMENDATIONS ──────────────────────────────

  /// Loads restaurants matching user preferences.
  /// Used on HomeScreen → emits RecPreferenceLoaded
  Future<void> getPreferenceRecommendations({
    String? preferredTopic,
    String? district,
    double? userLat,
    double? userLon,
    double? distanceKm,
    String? cuisineType,
    double? minRating,
    bool halal = false,
    bool vegetarian = false,
    bool vegan = false,
    bool parking = false,
    bool wifi = false,
    bool ac = false,
    bool outdoor = false,
    bool accessible = false,
    bool familyFriendly = false,
    bool groupFriendly = false,
    bool casual = false,
    bool romantic = false,
    bool scenicView = false,
    bool worthIt = false,
    bool fastService = false,
  }) async {
    emit(RecLoading());

    try {
      final result = await _api.getRecommendations(
        preferredTopic: preferredTopic,
        district: district,
        userLat: userLat,
        userLon: userLon,
        distanceKm: distanceKm,
        cuisineType: cuisineType,
        minRating: minRating,
        halal: halal,
        vegetarian: vegetarian,
        vegan: vegan,
        parking: parking,
        wifi: wifi,
        ac: ac,
        outdoor: outdoor,
        accessible: accessible,
        familyFriendly: familyFriendly,
        groupFriendly: groupFriendly,
        casual: casual,
        romantic: romantic,
        scenicView: scenicView,
        worthIt: worthIt,
        fastService: fastService,
      );

      if (result != null) {
        log(
          'API preference recs: ${result.restaurants.length} results',
          name: 'RecCubit',
        );
        emit(
          RecPreferenceLoaded(
            recommendations: result.restaurants,
            filtersRelaxed: result.filtersRelaxed,
            relaxedMessage: result.relaxedFiltersMessage,
            weighting: result.weighting,
          ),
        );
        return;
      }
    } catch (e) {
      log('getPreferenceRecommendations API error: $e', name: 'RecCubit');
    }

    // Client-side fallback
    await _clientSideFallback(
      district: district,
      cuisineType: cuisineType,
      minRating: minRating,
      isHalal: halal,
      isVegetarian: vegetarian,
      isVegan: vegan,
      hasParking: parking,
      hasWifi: wifi,
      hasAc: ac,
      hasOutdoor: outdoor,
      isAccessible: accessible,
      isFamilyFriendly: familyFriendly,
      isGroupFriendly: groupFriendly,
      isCasual: casual,
      isRomantic: romantic,
      hasScenicView: scenicView,
      isWorthIt: worthIt,
      isFastService: fastService,
    );
  }

  // ─── CLIENT-SIDE FALLBACK ──────────────────────────────────────────────────

  Future<void> _clientSideFallback({
    String? district,
    String? cuisineType,
    double? minRating,
    bool isHalal = false,
    bool isVegetarian = false,
    bool isVegan = false,
    bool hasParking = false,
    bool hasWifi = false,
    bool hasAc = false,
    bool hasOutdoor = false,
    bool isAccessible = false,
    bool isFamilyFriendly = false,
    bool isGroupFriendly = false,
    bool isCasual = false,
    bool isRomantic = false,
    bool hasScenicView = false,
    bool isWorthIt = false,
    bool isFastService = false,
  }) async {
    try {
      final restaurants = await repository.getFilteredRestaurants(
        municipality: district,
        cuisineType: cuisineType,
        minRating: minRating,
        isHalal: isHalal ? true : null,
        isVegetarian: isVegetarian ? true : null,
        isVegan: isVegan ? true : null,
        hasParking: hasParking ? true : null,
        hasWifi: hasWifi ? true : null,
        hasAc: hasAc ? true : null,
        hasOutdoor: hasOutdoor ? true : null,
        isAccessible: isAccessible ? true : null,
        isFamilyFriendly: isFamilyFriendly ? true : null,
        isGroupFriendly: isGroupFriendly ? true : null,
        isCasual: isCasual ? true : null,
        isRomantic: isRomantic ? true : null,
        hasScenicView: hasScenicView ? true : null,
        isWorthIt: isWorthIt ? true : null,
        isFastService: isFastService ? true : null,
        limit: 10,
      );
      log(
        'Client-side fallback: ${restaurants.length} results',
        name: 'RecCubit',
      );
      emit(
        RecPreferenceLoaded(
          recommendations: restaurants,
          filtersRelaxed: [],
          relaxedMessage: '',
          weighting: '30% KBF + 70% LDA (offline)',
        ),
      );
    } catch (e) {
      emit(RecError('Could not load recommendations. Please try again.'));
    }
  }

  // ─── LOCAL ALGORITHM ───────────────────────────────────────────────────────

  Future<List<Restaurant>> _getLocalRecommendations(Restaurant target) async {
    if (!_isCacheValid) {
      await loadMasterList();
    }

    final scored =
        _cachedRestaurants.where((r) => r.name != target.name).map((res) {
          final double sTopic =
              (res.dominantTopic == target.dominantTopic &&
                  !target.hasNoReviews)
              ? 1.0
              : 0.0;
          final double sRating = AppUtils.normalizeRating(res.rating);

          double sDist = 0.0;
          if (target.lat != null &&
              target.lon != null &&
              res.lat != null &&
              res.lon != null) {
            final km = AppUtils.calculateDistance(
              target.lat!,
              target.lon!,
              res.lat!,
              res.lon!,
            );
            sDist = max(0.0, 1.0 - (km / RecConfig.maxDistKm));
          } else {
            sDist = (res.municipality == target.municipality) ? 0.8 : 0.0;
          }

          double bonus = 0.0;
          if (res.isHalal && target.isHalal) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isVegetarian && target.isVegetarian) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isVegan && target.isVegan) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.hasParking && target.hasParking) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.hasWifi && target.hasWifi) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.hasAc && target.hasAc) bonus += RecConfig.booleanMatchBonus;
          if (res.hasOutdoor && target.hasOutdoor) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isAccessible && target.isAccessible) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isFamilyFriendly && target.isFamilyFriendly) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isGroupFriendly && target.isGroupFriendly) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isCasual && target.isCasual) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isRomantic && target.isRomantic) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.hasScenicView && target.hasScenicView) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isWorthIt && target.isWorthIt) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.isFastService && target.isFastService) {
            bonus += RecConfig.booleanMatchBonus;
          }
          if (res.cuisineType.isNotEmpty &&
              res.cuisineType == target.cuisineType) {
            bonus += RecConfig.booleanMatchBonus;
          }

          final score =
              (sTopic * RecConfig.wTopic) +
              (sRating * RecConfig.wRating) +
              (sDist * RecConfig.wDist) +
              bonus;

          return {'restaurant': res, 'score': score};
        }).toList()..sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double),
        );

    return scored.take(5).map((e) => e['restaurant'] as Restaurant).toList();
  }

  // ─── RESET ─────────────────────────────────────────────────────────────────

  void reset() {
    invalidateCache();
    emit(RecInitial());
  }
}
