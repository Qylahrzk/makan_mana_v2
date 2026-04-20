import 'dart:developer';
import 'dart:math' hide log;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_constants.dart';
import '../../core/app_utils.dart';
import '../../data/restaurant_repository.dart';
import '../../data/api_service.dart';
import '../../models/restaurant_model.dart';

part 'recommendation_state.dart';

/// RecommendationCubit
///
/// Two recommendation modes:
///
/// 1. getHybridRecommendations(target)
///    → "Similar restaurants" to a selected restaurant.
///    → Tries Flask API first, falls back to local scoring.
///    → Emits RecLoaded — handled by RestaurantDetailScreen BlocListener.
///
/// 2. getPreferenceRecommendations(...)
///    → "Recommended For You" based on user preferences.
///    → Calls Flask API (30% KBF + 70% LDA), falls back to local filter.
///    → Emits RecPreferenceLoaded — handled by HomeScreen.
///
/// Local algorithm weights (RecConfig):
///   wTopic  = 0.7   LDA topic similarity
///   wRating = 0.1   Rating quality
///   wDist   = 0.2   Distance proximity
///   booleanMatchBonus = 0.1 per matched KBF attribute

class RecommendationCubit extends Cubit<RecommendationState> {
  final RestaurantRepository repository;
  final ApiService _api;

  List<Restaurant> _cachedRestaurants = [];

  RecommendationCubit(this.repository, {ApiService? apiService})
      : _api = apiService ?? ApiService.instance,
        super(RecInitial());

  // ─────────────────────────────────────────
  // CACHE WARM-UP
  // ─────────────────────────────────────────

  Future<void> loadMasterList() async {
    try {
      if (_cachedRestaurants.isEmpty) {
        _cachedRestaurants = await repository.getAllRestaurants();
        log('Master list loaded: ${_cachedRestaurants.length} restaurants');
      }
      _api.isApiAlive().then((ok) =>
          log('API warm-up: ${ok ? "ready" : "cold/unreachable"}'));
    } catch (e) {
      log('loadMasterList error: $e');
    }
  }

  // ─────────────────────────────────────────
  // MODE 1: SIMILAR RESTAURANTS
  // Used on RestaurantDetailScreen → emits RecLoaded
  // ─────────────────────────────────────────

  Future<void> getHybridRecommendations(Restaurant target) async {
    emit(RecLoading());

    try {
      // ── 1. Try Flask API ──────────────────────────────────────────
      final apiResult = await _api.getRecommendations(
        preferredTopic : target.topicLabel,
        district       : target.municipality,
        cuisineType    : target.cuisineType,
        distanceKm     : 500.0,
        halal          : target.isHalal,
        vegetarian     : target.isVegetarian,
        vegan          : target.isVegan,
        parking        : target.hasParking,
        wifi           : target.hasWifi,
        ac             : target.hasAc,
        outdoor        : target.hasOutdoor,
        accessible     : target.isAccessible,
        familyFriendly : target.isFamilyFriendly,
        groupFriendly  : target.isGroupFriendly,
        casual         : target.isCasual,
        romantic       : target.isRomantic,
        scenicView     : target.hasScenicView,
        worthIt        : target.isWorthIt,
        fastService    : target.isFastService,
      );

      if (apiResult != null && apiResult.restaurants.isNotEmpty) {
        final results = apiResult.restaurants
            .where((r) => r.name != target.name)
            .take(5)
            .toList();
        log('Using API recommendations: ${results.length} results');
        emit(RecLoaded(
          recommendations  : results,
          targetRestaurant : target,
          source           : RecSource.api,
          relaxedFilters   : apiResult.filtersRelaxed,
        ));
        return;
      }
      log('API returned empty — falling back to local algorithm');
    } catch (e) {
      log('API call failed — falling back to local: $e');
    }

    // ── 2. Local fallback ────────────────────────────────────────
    try {
      final results = await _getLocalRecommendations(target);
      emit(RecLoaded(
        recommendations  : results,
        targetRestaurant : target,
        source           : RecSource.local,
      ));
    } catch (e) {
      log('Local algorithm error: $e');
      emit(RecError('Could not generate recommendations. Please try again.'));
    }
  }

  // ─────────────────────────────────────────
  // MODE 2: PREFERENCE-BASED RECOMMENDATIONS
  // Used on HomeScreen → emits RecPreferenceLoaded
  // ─────────────────────────────────────────

  Future<void> getPreferenceRecommendations({
    String? preferredTopic,
    String? district,
    double? userLat,
    double? userLon,
    double? distanceKm,
    String? cuisineType,
    double? minRating,
    bool halal          = false,
    bool vegetarian     = false,
    bool vegan          = false,
    bool parking        = false,
    bool wifi           = false,
    bool ac             = false,
    bool outdoor        = false,
    bool accessible     = false,
    bool familyFriendly = false,
    bool groupFriendly  = false,
    bool casual         = false,
    bool romantic       = false,
    bool scenicView     = false,
    bool worthIt        = false,
    bool fastService    = false,
  }) async {
    emit(RecLoading());

    try {
      final result = await _api.getRecommendations(
        preferredTopic : preferredTopic,
        district       : district,
        userLat        : userLat,
        userLon        : userLon,
        distanceKm     : distanceKm,
        cuisineType    : cuisineType,
        minRating      : minRating,
        halal          : halal,
        vegetarian     : vegetarian,
        vegan          : vegan,
        parking        : parking,
        wifi           : wifi,
        ac             : ac,
        outdoor        : outdoor,
        accessible     : accessible,
        familyFriendly : familyFriendly,
        groupFriendly  : groupFriendly,
        casual         : casual,
        romantic       : romantic,
        scenicView     : scenicView,
        worthIt        : worthIt,
        fastService    : fastService,
      );

      if (result != null) {
        log('API preference recs: ${result.restaurants.length} results');
        emit(RecPreferenceLoaded(
          recommendations : result.restaurants,
          filtersRelaxed  : result.filtersRelaxed,
          relaxedMessage  : result.relaxedFiltersMessage,
          weighting       : result.weighting,
        ));
        return;
      }
    } catch (e) {
      log('getPreferenceRecommendations API error: $e');
    }

    // Client-side fallback
    await _clientSideFallback(
      district        : district,
      cuisineType     : cuisineType,
      minRating       : minRating,
      isHalal         : halal,
      isVegetarian    : vegetarian,
      isVegan         : vegan,
      hasParking      : parking,
      hasWifi         : wifi,
      hasAc           : ac,
      hasOutdoor      : outdoor,
      isAccessible    : accessible,
      isFamilyFriendly: familyFriendly,
      isGroupFriendly : groupFriendly,
      isCasual        : casual,
      isRomantic      : romantic,
      hasScenicView   : scenicView,
      isWorthIt       : worthIt,
      isFastService   : fastService,
    );
  }

  // ─────────────────────────────────────────
  // CLIENT-SIDE FALLBACK
  // ─────────────────────────────────────────

  Future<void> _clientSideFallback({
    String? district,
    String? cuisineType,
    double? minRating,
    bool isHalal          = false,
    bool isVegetarian     = false,
    bool isVegan          = false,
    bool hasParking       = false,
    bool hasWifi          = false,
    bool hasAc            = false,
    bool hasOutdoor       = false,
    bool isAccessible     = false,
    bool isFamilyFriendly = false,
    bool isGroupFriendly  = false,
    bool isCasual         = false,
    bool isRomantic       = false,
    bool hasScenicView    = false,
    bool isWorthIt        = false,
    bool isFastService    = false,
  }) async {
    try {
      final restaurants = await repository.getFilteredRestaurants(
        municipality    : district,
        cuisineType     : cuisineType,
        minRating       : minRating,
        isHalal         : isHalal          ? true : null,
        isVegetarian    : isVegetarian      ? true : null,
        isVegan         : isVegan           ? true : null,
        hasParking      : hasParking        ? true : null,
        hasWifi         : hasWifi           ? true : null,
        hasAc           : hasAc             ? true : null,
        hasOutdoor      : hasOutdoor        ? true : null,
        isAccessible    : isAccessible      ? true : null,
        isFamilyFriendly: isFamilyFriendly  ? true : null,
        isGroupFriendly : isGroupFriendly   ? true : null,
        isCasual        : isCasual          ? true : null,
        isRomantic      : isRomantic        ? true : null,
        hasScenicView   : hasScenicView     ? true : null,
        isWorthIt       : isWorthIt         ? true : null,
        isFastService   : isFastService     ? true : null,
        limit           : 10,
      );
      log('Client-side fallback: ${restaurants.length} results');
      emit(RecPreferenceLoaded(
        recommendations : restaurants,
        filtersRelaxed  : [],
        relaxedMessage  : '',
        weighting       : '30% KBF + 70% LDA (offline)',
      ));
    } catch (e) {
      emit(RecError('Could not load recommendations. Please try again.'));
    }
  }

  // ─────────────────────────────────────────
  // LOCAL ALGORITHM (similar restaurants)
  // ─────────────────────────────────────────

  Future<List<Restaurant>> _getLocalRecommendations(Restaurant target) async {
    if (_cachedRestaurants.isEmpty) {
      _cachedRestaurants = await repository.getAllRestaurants();
    }

    final scored = _cachedRestaurants
        .where((r) => r.name != target.name)
        .map((res) {
          final double sTopic =
              (res.dominantTopic == target.dominantTopic && !target.hasNoReviews)
                  ? 1.0 : 0.0;
          final double sRating = AppUtils.normalizeRating(res.rating);

          double sDist = 0.0;
          if (target.lat != null && target.lon != null &&
              res.lat != null && res.lon != null) {
            final km = AppUtils.calculateDistance(
                target.lat!, target.lon!, res.lat!, res.lon!);
            sDist = max(0.0, 1.0 - (km / RecConfig.maxDistKm));
          } else {
            sDist = (res.municipality == target.municipality) ? 0.8 : 0.0;
          }

          double bonus = 0.0;
          if (res.isHalal && target.isHalal)                    bonus += RecConfig.booleanMatchBonus;
          if (res.isVegetarian && target.isVegetarian)          bonus += RecConfig.booleanMatchBonus;
          if (res.isVegan && target.isVegan)                    bonus += RecConfig.booleanMatchBonus;
          if (res.hasParking && target.hasParking)              bonus += RecConfig.booleanMatchBonus;
          if (res.hasWifi && target.hasWifi)                    bonus += RecConfig.booleanMatchBonus;
          if (res.hasAc && target.hasAc)                        bonus += RecConfig.booleanMatchBonus;
          if (res.hasOutdoor && target.hasOutdoor)              bonus += RecConfig.booleanMatchBonus;
          if (res.isAccessible && target.isAccessible)          bonus += RecConfig.booleanMatchBonus;
          if (res.isFamilyFriendly && target.isFamilyFriendly) bonus += RecConfig.booleanMatchBonus;
          if (res.isGroupFriendly && target.isGroupFriendly)    bonus += RecConfig.booleanMatchBonus;
          if (res.isCasual && target.isCasual)                  bonus += RecConfig.booleanMatchBonus;
          if (res.isRomantic && target.isRomantic)              bonus += RecConfig.booleanMatchBonus;
          if (res.hasScenicView && target.hasScenicView)        bonus += RecConfig.booleanMatchBonus;
          if (res.isWorthIt && target.isWorthIt)                bonus += RecConfig.booleanMatchBonus;
          if (res.isFastService && target.isFastService)        bonus += RecConfig.booleanMatchBonus;
          if (res.cuisineType.isNotEmpty &&
              res.cuisineType == target.cuisineType) {
            bonus += RecConfig.booleanMatchBonus;
          }

          final score =
              (sTopic  * RecConfig.wTopic) +
              (sRating * RecConfig.wRating) +
              (sDist   * RecConfig.wDist) +
              bonus;

          return {'restaurant': res, 'score': score};
        })
        .toList()
      ..sort((a, b) =>
          (b['score'] as double).compareTo(a['score'] as double));

    return scored.take(5).map((e) => e['restaurant'] as Restaurant).toList();
  }

  // ─────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────

  void reset() => emit(RecInitial());
}