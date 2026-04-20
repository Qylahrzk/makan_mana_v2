import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:equatable/equatable.dart';

class Restaurant extends Equatable {
  final int id;
  final String name;
  final String address;
  final String municipality;
  final String categories;

  // cuisineTypes = full parsed list e.g. ["Malay","Seafood"]
  // cuisineType  = first/primary value for display e.g. "Malay"
  final List<String> cuisineTypes;

  final double rating;
  final String ratingBand;
  final double? lat;
  final double? lon;
  final String coordinateSource;

  // ── Dietary ──────────────────────────────────────────────────────────────
  final bool isHalal;
  final bool isVegetarian;
  final bool isVegan;

  // ── Facilities ────────────────────────────────────────────────────────────
  final bool hasParking;
  final bool hasWifi;
  final bool hasAc;          // NEW
  final bool hasOutdoor;
  final bool isAccessible;   // NEW

  // ── Vibes ─────────────────────────────────────────────────────────────────
  final bool isFamilyFriendly;
  final bool isGroupFriendly; // NEW
  final bool isCasual;        // NEW
  final bool isRomantic;
  final bool hasScenicView;

  // ── Service / Value ───────────────────────────────────────────────────────
  final bool isWorthIt;       // NEW
  final bool isFastService;   // NEW

  // ── Topics ────────────────────────────────────────────────────────────────
  final int dominantTopic;
  final String topicLabel;
  final double topic1Pct;
  final double topic2Pct;
  final double topic3Pct;

  final int? priceLevel;

  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.municipality,
    required this.categories,
    required this.cuisineTypes,
    required this.rating,
    required this.ratingBand,
    this.lat,
    this.lon,
    required this.coordinateSource,
    required this.isHalal,
    required this.isVegetarian,
    required this.isVegan,
    required this.hasParking,
    required this.hasWifi,
    required this.hasAc,
    required this.hasOutdoor,
    required this.isAccessible,
    required this.isFamilyFriendly,
    required this.isGroupFriendly,
    required this.isCasual,
    required this.isRomantic,
    required this.hasScenicView,
    required this.isWorthIt,
    required this.isFastService,
    required this.dominantTopic,
    required this.topicLabel,
    required this.topic1Pct,
    required this.topic2Pct,
    required this.topic3Pct,
    this.priceLevel,
  });

  // Primary cuisine for display (first item in list, or 'Other')
  String get cuisineType =>
      cuisineTypes.isNotEmpty ? cuisineTypes.first : 'Other';

  // ── Parse cuisine_type from Supabase ──────────────────────────────────────
  // Supabase may return: plain string 'Malay', JSON array '["Malay"]', or List
  static List<String> _parseCuisineType(dynamic raw) {
    if (raw == null) return ['Other'];

    if (raw is List) {
      final result = raw
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return result.isEmpty ? ['Other'] : result;
    }

    final str = raw.toString().trim();
    if (str.isEmpty) return ['Other'];

    if (str.startsWith('[')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final result = decoded
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          return result.isEmpty ? ['Other'] : result;
        }
      } catch (_) {}
    }

    return [str];
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id:           (json['id'] as num?)?.toInt() ?? 0,
      name:         json['name']?.toString() ?? 'Unknown Restaurant',
      address:      json['address']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? 'Terengganu',
      categories:   json['categories']?.toString() ?? 'General',
      cuisineTypes: _parseCuisineType(json['cuisine_type']),
      rating:           (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingBand:       json['rating_band']?.toString() ?? '',
      lat:              (json['latitude'] as num?)?.toDouble()
                        ?? double.tryParse(json['latitude']?.toString() ?? ''),
      lon:              (json['longitude'] as num?)?.toDouble()
                        ?? double.tryParse(json['longitude']?.toString() ?? ''),
      coordinateSource: json['coordinate_source']?.toString() ?? '',
      // Dietary
      isHalal:          json['is_halal']          as bool? ?? false,
      isVegetarian:     json['is_vegetarian']     as bool? ?? false,
      isVegan:          json['is_vegan']           as bool? ?? false,
      // Facilities
      hasParking:       json['has_parking']        as bool? ?? false,
      hasWifi:          json['has_wifi']           as bool? ?? false,
      hasAc:            json['has_ac']             as bool? ?? false,
      hasOutdoor:       json['has_outdoor']        as bool? ?? false,
      isAccessible:     json['is_accessible']      as bool? ?? false,
      // Vibes
      isFamilyFriendly: json['is_family_friendly'] as bool? ?? false,
      isGroupFriendly:  json['is_group_friendly']  as bool? ?? false,
      isCasual:         json['is_casual']           as bool? ?? false,
      isRomantic:       json['is_romantic']         as bool? ?? false,
      hasScenicView:    json['has_scenic_view']     as bool? ?? false,
      // Service
      isWorthIt:        json['is_worth_it']         as bool? ?? false,
      isFastService:    json['is_fast_service']     as bool? ?? false,
      // Topics
      dominantTopic: (json['dominant_topic'] as num?)?.toInt() ?? 0,
      topicLabel:    json['topic_label']?.toString() ?? 'No Reviews',
      topic1Pct:     (json['topic_1_pct'] as num?)?.toDouble() ?? 0.0,
      topic2Pct:     (json['topic_2_pct'] as num?)?.toDouble() ?? 0.0,
      topic3Pct:     (json['topic_3_pct'] as num?)?.toDouble() ?? 0.0,
      priceLevel:    (json['price_level'] as num?)?.toInt(),
    );
  }

  bool get hasNoReviews => topicLabel == 'No Reviews';
  double get dominantTopicPct => topic1Pct;

  bool matchesCuisine(String cuisine) {
    final c = cuisine.toLowerCase();
    return cuisineTypes.any((t) => t.toLowerCase() == c);
  }

  bool matchesAnyCuisine(List<String> preferences) {
    if (preferences.isEmpty) return true;
    return preferences.any((pref) => matchesCuisine(pref));
  }

  String? get priceLevelLabel {
    switch (priceLevel) {
      case 1: return 'Budget';
      case 2: return 'Moderate';
      case 3: return 'Upscale';
      case 4: return 'Fine Dining';
      default: return null;
    }
  }

  String? get priceLevelRange {
    switch (priceLevel) {
      case 1: return '< RM15 per person';
      case 2: return 'RM15 – RM40 per person';
      case 3: return 'RM40 – RM100 per person';
      case 4: return 'RM100+ per person';
      default: return null;
    }
  }

  Color get priceLevelColor {
    switch (priceLevel) {
      case 1: return const Color(0xFF16A34A);
      case 2: return const Color(0xFF2563EB);
      case 3: return const Color(0xFFD97706);
      case 4: return const Color(0xFFDC2626);
      default: return const Color(0xFF9CA3AF);
    }
  }

  /// All active attribute labels — used by UI chips
  List<String> get activeAttributes {
    return [
      if (isHalal)          'Halal',
      if (isVegetarian)     'Vegetarian',
      if (isVegan)          'Vegan',
      if (hasParking)       'Parking',
      if (hasWifi)          'WiFi',
      if (hasAc)            'Air-Cond',
      if (hasOutdoor)       'Outdoor',
      if (isAccessible)     'Accessible',
      if (isFamilyFriendly) 'Family Friendly',
      if (isGroupFriendly)  'Group Friendly',
      if (isCasual)         'Casual',
      if (isRomantic)       'Romantic',
      if (hasScenicView)    'Scenic View',
      if (isWorthIt)        'Worth It',
      if (isFastService)    'Fast Service',
    ];
  }

  @override
  List<Object?> get props => [
    id, name, address, municipality, categories, cuisineTypes,
    rating, ratingBand, lat, lon, coordinateSource,
    isHalal, isVegetarian, isVegan,
    hasParking, hasWifi, hasAc, hasOutdoor, isAccessible,
    isFamilyFriendly, isGroupFriendly, isCasual, isRomantic, hasScenicView,
    isWorthIt, isFastService,
    dominantTopic, topicLabel, topic1Pct, topic2Pct, topic3Pct,
    priceLevel,
  ];
}