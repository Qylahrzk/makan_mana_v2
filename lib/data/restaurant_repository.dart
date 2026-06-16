import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_constants.dart';
import '../models/restaurant_model.dart';

/// RestaurantRepository
///
/// Strategy: Supabase first → fall back to assets/restaurants.json if offline.
/// Session cache: loaded once per app session, cleared on pull-to-refresh.

class RestaurantRepository {
  final _supabase = Supabase.instance.client;

  List<Restaurant>? _cache;
  Future<List<Restaurant>>? _pendingFetch;

  void clearCache() {
    _cache = null;
    _pendingFetch = null;
    log('RestaurantRepository: cache cleared');
  }

  // ── Offline fallback ──────────────────────────────────────────────────────

  Future<List<Restaurant>> _loadFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/restaurants.json');
      final decoded = json.decode(raw);
      final List<dynamic> jsonList =
          decoded is Map && decoded.containsKey('restaurants')
          ? decoded['restaurants'] as List<dynamic>
          : decoded as List<dynamic>;
      final result = jsonList
          .map((j) => Restaurant.fromJson(j as Map<String, dynamic>))
          .toList();
      log('_loadFromAssets: ✅ ${result.length} restaurants from JSON');
      return result;
    } catch (e) {
      log('_loadFromAssets error: $e');
      return [];
    }
  }

  // ── Fetch ALL ─────────────────────────────────────────────────────────────

  Future<List<Restaurant>> getAllRestaurants() async {
    if (_cache != null) {
      log('getAllRestaurants: ✅ ${_cache!.length} from cache');
      return _cache!;
    }
    if (_pendingFetch != null) {
      log('getAllRestaurants: ⏳ awaiting in-flight fetch');
      return _pendingFetch!;
    }
    _pendingFetch = _fetchFromSupabase();
    try {
      final result = await _pendingFetch!;
      _cache = result;
      return result;
    } finally {
      _pendingFetch = null;
    }
  }

  Future<List<Restaurant>> _fetchFromSupabase() async {
    try {
      const int pageSize = 500;
      int from = 0;
      final List<Restaurant> all = [];

      while (true) {
        final response = await _supabase
            .from(SupabaseTables.restaurantProfiles)
            .select()
            .range(from, from + pageSize - 1);

        final batch = (response as List)
            .map((json) => Restaurant.fromJson(json))
            .toList();

        all.addAll(batch);
        log(
          'getAllRestaurants: batch $from–${from + batch.length - 1} '
          '(${batch.length} rows)',
        );

        if (batch.length < pageSize) break;
        from += pageSize;
      }

      log('getAllRestaurants: ✅ ${all.length} total from Supabase');
      return all;
    } catch (e) {
      log('getAllRestaurants: ⚠️ Supabase failed ($e) — falling back to JSON');
      return _loadFromAssets();
    }
  }

  // ── Top rated ─────────────────────────────────────────────────────────────

  Future<List<Restaurant>> getTopRated({int limit = 50}) async {
    if (_cache != null) {
      final sorted = List<Restaurant>.from(_cache!)
        ..sort((a, b) => b.rating.compareTo(a.rating));
      return sorted.take(limit).toList();
    }
    try {
      final response = await _supabase
          .from(SupabaseTables.restaurantProfiles)
          .select()
          .order(RestaurantColumns.rating, ascending: false)
          .limit(limit);
      return (response as List)
          .map((json) => Restaurant.fromJson(json))
          .toList();
    } catch (e) {
      log('getTopRated: ⚠️ falling back to JSON');
      final all = await _loadFromAssets();
      return (List<Restaurant>.from(
        all,
      )..sort((a, b) => b.rating.compareTo(a.rating))).take(limit).toList();
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Restaurant>> searchRestaurants(String query) async {
    try {
      var request = _supabase.from(SupabaseTables.restaurantProfiles).select();
      if (query.isNotEmpty) {
        request = request.ilike(RestaurantColumns.name, '%$query%');
      }
      final response = await request
          .order(RestaurantColumns.rating, ascending: false)
          .limit(100);
      log('searchRestaurants("$query"): ${(response as List).length} results');
      return response.map((json) => Restaurant.fromJson(json)).toList();
    } catch (e) {
      log('searchRestaurants: ⚠️ falling back to cache/JSON');
      final all = _cache ?? await _loadFromAssets();
      final q = query.toLowerCase();
      return all
          .where(
            (r) =>
                r.name.toLowerCase().contains(q) ||
                r.cuisineType.toLowerCase().contains(q),
          )
          .take(100)
          .toList();
    }
  }

  // ── Filter ────────────────────────────────────────────────────────────────
  // Updated to include all new KBF columns

  Future<List<Restaurant>> getFilteredRestaurants({
    String? municipality,
    String? cuisineType,
    // Dietary
    bool? isHalal,
    bool? isVegetarian,
    bool? isVegan,
    // Facilities
    bool? hasParking,
    bool? hasWifi,
    bool? hasAc,
    bool? hasOutdoor,
    bool? isAccessible,
    // Vibes
    bool? isFamilyFriendly,
    bool? isGroupFriendly,
    bool? isCasual,
    bool? isRomantic,
    bool? hasScenicView,
    bool? isCrowded,
    // Service
    bool? isWorthIt,
    bool? isFastService,
    double? minRating,
    int? maxPriceLevel,
    int limit = 100,
  }) async {
    try {
      var request = _supabase.from(SupabaseTables.restaurantProfiles).select();

      if (municipality != null && municipality.isNotEmpty) {
        request = request.eq(RestaurantColumns.municipality, municipality);
      }
      if (cuisineType != null &&
          cuisineType != 'All' &&
          cuisineType.isNotEmpty) {
        request = request.eq(RestaurantColumns.cuisineType, cuisineType);
      }
      // Dietary
      if (isHalal == true) {
        request = request.eq(RestaurantColumns.isHalal, true);
      }
      if (isVegetarian == true) {
        request = request.eq(RestaurantColumns.isVegetarian, true);
      }
      if (isVegan == true) {
        request = request.eq(RestaurantColumns.isVegan, true);
      }
      // Facilities
      if (hasParking == true) {
        request = request.eq(RestaurantColumns.hasParking, true);
      }
      if (hasWifi == true) {
        request = request.eq(RestaurantColumns.hasWifi, true);
      }
      if (hasAc == true) {
        request = request.eq(RestaurantColumns.hasAc, true);
      }
      if (hasOutdoor == true) {
        request = request.eq(RestaurantColumns.hasOutdoor, true);
      }
      if (isAccessible == true) {
        request = request.eq(RestaurantColumns.isAccessible, true);
      }
      // Vibes
      if (isFamilyFriendly == true) {
        request = request.eq(RestaurantColumns.isFamilyFriendly, true);
      }
      if (isGroupFriendly == true) {
        request = request.eq(RestaurantColumns.isGroupFriendly, true);
      }
      if (isCasual == true) {
        request = request.eq(RestaurantColumns.isCasual, true);
      }
      if (isRomantic == true) {
        request = request.eq(RestaurantColumns.isRomantic, true);
      }
      if (hasScenicView == true) {
        request = request.eq(RestaurantColumns.hasScenicView, true);
      }
      if (isCrowded == true) {
        request = request.eq(RestaurantColumns.isCrowded, true);
      }
      // Service
      if (isWorthIt == true) {
        request = request.eq(RestaurantColumns.isWorthIt, true);
      }
      if (isFastService == true) {
        request = request.eq(RestaurantColumns.isFastService, true);
      }
      if (minRating != null) {
        request = request.gte(RestaurantColumns.rating, minRating);
      }
      if (maxPriceLevel != null) {
        request = request.lte(RestaurantColumns.priceLevel, maxPriceLevel);
      }

      final response = await request
          .order(RestaurantColumns.rating, ascending: false)
          .limit(limit);
      log('getFilteredRestaurants: ${(response as List).length} results');
      return response.map((json) => Restaurant.fromJson(json)).toList();
    } catch (e) {
      log('getFilteredRestaurants: ⚠️ falling back to cache/JSON');
      final all = _cache ?? await _loadFromAssets();
      return all
          .where((r) {
            if (municipality != null &&
                municipality.isNotEmpty &&
                r.municipality != municipality) {
              return false;
            }
            if (cuisineType != null &&
                cuisineType != 'All' &&
                cuisineType.isNotEmpty &&
                r.cuisineType != cuisineType) {
              return false;
            }
            if (isHalal == true && !r.isHalal) return false;
            if (isVegetarian == true && !r.isVegetarian) return false;
            if (isVegan == true && !r.isVegan) return false;
            if (hasParking == true && !r.hasParking) return false;
            if (hasWifi == true && !r.hasWifi) return false;
            if (hasAc == true && !r.hasAc) return false;
            if (hasOutdoor == true && !r.hasOutdoor) return false;
            if (isAccessible == true && !r.isAccessible) return false;
            if (isFamilyFriendly == true && !r.isFamilyFriendly) return false;
            if (isGroupFriendly == true && !r.isGroupFriendly) return false;
            if (isCasual == true && !r.isCasual) return false;
            if (isRomantic == true && !r.isRomantic) return false;
            if (hasScenicView == true && !r.hasScenicView) return false;
            if (isCrowded == true && !r.isCrowded) return false;
            if (isWorthIt == true && !r.isWorthIt) return false;
            if (isFastService == true && !r.isFastService) return false;
            if (minRating != null && r.rating < minRating) return false;
            if (maxPriceLevel != null &&
                (r.priceLevel == null || r.priceLevel! > maxPriceLevel)) {
              return false;
            }
            return true;
          })
          .take(limit)
          .toList();
    }
  }

  // ── By municipality ───────────────────────────────────────────────────────

  Future<List<Restaurant>> getByMunicipality(String municipality) async {
    if (_cache != null) {
      return _cache!.where((r) => r.municipality == municipality).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
    }
    try {
      final response = await _supabase
          .from(SupabaseTables.restaurantProfiles)
          .select()
          .eq(RestaurantColumns.municipality, municipality)
          .order(RestaurantColumns.rating, ascending: false);
      log(
        'getByMunicipality("$municipality"): ${(response as List).length} results',
      );
      return response.map((json) => Restaurant.fromJson(json)).toList();
    } catch (e) {
      log('getByMunicipality: ⚠️ falling back to JSON');
      final all = await _loadFromAssets();
      return all.where((r) => r.municipality == municipality).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
    }
  }

  // ── By topic ──────────────────────────────────────────────────────────────

  Future<List<Restaurant>> getByTopic(int topicId, {int limit = 50}) async {
    if (_cache != null) {
      return _cache!
          .where((r) => r.dominantTopic == topicId)
          .take(limit)
          .toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
    }
    try {
      final response = await _supabase
          .from(SupabaseTables.restaurantProfiles)
          .select()
          .eq(RestaurantColumns.dominantTopic, topicId)
          .order(RestaurantColumns.rating, ascending: false)
          .limit(limit);
      log('getByTopic($topicId): ${(response as List).length} results');
      return response.map((json) => Restaurant.fromJson(json)).toList();
    } catch (e) {
      log('getByTopic: ⚠️ falling back to JSON');
      final all = await _loadFromAssets();
      return all.where((r) => r.dominantTopic == topicId).take(limit).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
    }
  }
}
