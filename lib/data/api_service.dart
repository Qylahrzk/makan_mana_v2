import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../core/app_constants.dart';
import '../models/restaurant_model.dart';

/// ApiService
///
/// Handles all calls to the Flask hybrid recommendation API
/// hosted on Render.com (30% KBF + 70% LDA scoring).
///
/// This complements RestaurantRepository (which handles direct
/// Supabase queries). Use this for the /recommend endpoint only.
///
/// Place this file in: lib/data/api_service.dart

class ApiService {
  // Singleton pattern — same as supabase_service.dart style
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── HEALTH CHECK ──────────────────────────────────────────────────────────

  /// Returns true if the Flask API is reachable.
  /// Call this on app start to decide whether to use API or
  /// fall back to client-side Supabase scoring.
  Future<bool> isApiAlive() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.health))
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      log('ApiService.isApiAlive: API unreachable — $e');
      return false;
    }
  }

  // ── HYBRID RECOMMEND ──────────────────────────────────────────────────────

  /// Calls POST /recommend on the Flask API.
  /// Returns a list of up to 10 restaurants scored by
  /// 30% KBF + 70% LDA hybrid algorithm.
  ///
  /// Parameters map directly to the API's flat JSON body:
  ///   preferredTopic  → "Seafood & Local Snacks" etc.
  ///   district        → "Kuala Terengganu" etc.
  ///   cuisineType     → "Malay", "Chinese" etc.
  ///   minRating       → 3.0, 4.0 etc.
  ///   userLat/userLon → user GPS for distance boost
  ///   distanceKm      → radius filter (optional)
  ///   Boolean flags   → halal, parking, familyFriendly etc.
  ///
  /// Returns null if the API is unreachable (caller should
  /// fall back to client-side scoring via RestaurantRepository).
  Future<ApiRecommendResult?> getRecommendations({
    // LDA topic preference
    String? preferredTopic,

    // Location filters
    String? district,
    double? userLat,
    double? userLon,
    double? distanceKm,

    // Cuisine & rating filters
    String? cuisineType,
    double? minRating,

    // ── KBF boolean preferences ───────────────────────────────────────────
    /// Dietary
    bool halal          = false,
    bool vegetarian     = false,
    bool vegan          = false,
    /// Facilities
    bool parking        = false,
    bool wifi           = false,
    bool ac             = false,       // NEW — has_ac
    bool outdoor        = false,
    bool accessible     = false,       // NEW — is_accessible
    /// Vibes
    bool familyFriendly = false,
    bool groupFriendly  = false,       // NEW — is_group_friendly
    bool casual         = false,       // NEW — is_casual
    bool romantic       = false,
    bool scenicView     = false,
    /// Service / Value
    bool worthIt        = false,       // NEW — is_worth_it
    bool fastService    = false,       // NEW — is_fast_service
  }) async {
    try {
      // Build flat JSON body matching Flask API expectations
      final Map<String, dynamic> body = {};

      // Only include non-null / non-false values to keep payload clean
      if (preferredTopic != null && preferredTopic.isNotEmpty) {
        body['preferred_topic'] = preferredTopic;
      }
      if (district != null && district.isNotEmpty) {
        body['district'] = district;
      }
      if (cuisineType != null && cuisineType != 'All' && cuisineType.isNotEmpty) {
        body['cuisine'] = cuisineType;
      }
      if (minRating != null) body['min_rating']   = minRating;
      if (userLat   != null) body['latitude']     = userLat;
      if (userLon   != null) body['longitude']    = userLon;
      if (distanceKm != null) body['distance_km'] = distanceKm;

      // Boolean KBF flags — only send true values
      // Dietary
      if (halal)       body['halal']       = true;
      if (vegetarian)  body['vegetarian']  = true;
      if (vegan)       body['vegan']       = true;
      // Facilities
      if (parking)     body['parking']     = true;
      if (wifi)        body['wifi']        = true;
      if (ac)          body['ac']          = true;
      if (outdoor)     body['outdoor']     = true;
      if (accessible)  body['accessible']  = true;
      // Vibes
      if (familyFriendly) body['family_friendly'] = true;
      if (groupFriendly)  body['group_friendly']  = true;
      if (casual)         body['casual']          = true;
      if (romantic)       body['romantic']        = true;
      if (scenicView)     body['scenic_view']     = true;
      // Service
      if (worthIt)     body['worth_it']    = true;
      if (fastService) body['fast_service'] = true;

      log('ApiService.getRecommendations → POST ${ApiConfig.recommend}');
      log('Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse(ApiConfig.recommend),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data   = jsonDecode(response.body) as Map<String, dynamic>;
        final result = ApiRecommendResult.fromJson(data);
        log('ApiService: got ${result.restaurants.length} recommendations');
        log('Filters relaxed: ${result.filtersRelaxed}');
        return result;
      } else {
        log('ApiService error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      log('ApiService.getRecommendations error: $e');
      return null; // Caller falls back to client-side scoring
    }
  }

  // ── NEARBY RESTAURANTS ────────────────────────────────────────────────────

  /// Calls GET /restaurants/nearby on the Flask API.
  /// Returns restaurants within [radiusKm] of the user's GPS.
  /// Sorted by distance (nearest first).
  Future<List<Restaurant>> getNearbyRestaurants({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.nearby).replace(
        queryParameters: {
          'lat'    : lat.toString(),
          'lon'    : lon.toString(),
          'radius' : radiusKm.toString(),
          'limit'  : limit.toString(),
        },
      );

      log('ApiService.getNearbyRestaurants → GET $uri');

      final response = await http
          .get(uri)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data        = jsonDecode(response.body) as Map<String, dynamic>;
        final list        = data['restaurants'] as List<dynamic>;
        final restaurants = list
            .map((json) => Restaurant.fromJson(json as Map<String, dynamic>))
            .toList();

        log('ApiService.getNearbyRestaurants: ${restaurants.length} results');
        return restaurants;
      } else {
        log('ApiService.getNearbyRestaurants error ${response.statusCode}');
        return [];
      }
    } catch (e) {
      log('ApiService.getNearbyRestaurants error: $e');
      return [];
    }
  }
}

// ── RESULT MODEL ──────────────────────────────────────────────────────────────
// Wraps the /recommend response including
// which filters were relaxed by the API.

class ApiRecommendResult {
  final List<Restaurant> restaurants;
  final List<String>     filtersRelaxed;
  final String           weighting;
  final int              total;

  const ApiRecommendResult({
    required this.restaurants,
    required this.filtersRelaxed,
    required this.weighting,
    required this.total,
  });

  factory ApiRecommendResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['recommendations'] as List<dynamic>? ?? [];

    // Parse each recommendation — add hybrid_score to the restaurant JSON
    final restaurants = rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return Restaurant.fromJson(map);
    }).toList();

    // filters_relaxed can be a List or empty Map {} from Flask
    List<String> filtersRelaxed = [];
    final raw = json['filters_relaxed'];
    if (raw is List) {
      filtersRelaxed = raw.map((e) => e.toString()).toList();
    }

    return ApiRecommendResult(
      restaurants    : restaurants,
      filtersRelaxed : filtersRelaxed,
      weighting      : json['weighting'] as String? ?? '30% KBF + 70% LDA',
      total          : json['total']     as int?    ?? 0,
    );
  }

  /// Returns true if the API had to drop some filters to find results.
  bool get hadRelaxedFilters => filtersRelaxed.isNotEmpty;

  /// Human-readable message about relaxed filters for UI display.
  String get relaxedFiltersMessage {
    if (!hadRelaxedFilters) return '';
    final readable = filtersRelaxed.map((f) {
      switch (f) {
        case 'halal':           return 'Halal';
        case 'vegetarian':      return 'Vegetarian';
        case 'vegan':           return 'Vegan';
        case 'parking':         return 'Parking';
        case 'wifi':            return 'WiFi';
        case 'ac':              return 'Air-Cond';
        case 'outdoor':         return 'Outdoor';
        case 'accessible':      return 'Accessible';
        case 'family_friendly': return 'Family Friendly';
        case 'group_friendly':  return 'Group Friendly';
        case 'casual':          return 'Casual';
        case 'romantic':        return 'Romantic';
        case 'scenic_view':     return 'Scenic View';
        case 'worth_it':        return 'Worth It';
        case 'fast_service':    return 'Fast Service';
        case 'cuisine':         return 'Cuisine type';
        case 'min_rating':      return 'Minimum rating';
        default:                return f;
      }
    }).join(', ');
    return 'Some filters were relaxed to find results: $readable';
  }
}