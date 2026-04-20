import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a single wishlist entry in the app.
/// Maps to the 'wishlists' table in Supabase.
///
/// cuisine_type is stored as a JSON array string e.g. '["Malay","Seafood"]'
/// matching the format in restaurant_profiles.cuisine_type.

class WishlistModel extends Equatable {
  final String id;
  final String userId;
  final String restaurantName;
  final String address;
  final String municipality;
  final String categories;

  // Stored as JSON array string in DB, exposed as List<String> in Dart
  final List<String> cuisineTypes;

  final double rating;
  final String ratingBand;
  final String topicLabel;

  // Dietary & facility booleans
  final bool isHalal;
  final bool isVegetarian;
  final bool isVegan;
  final bool hasParking;
  final bool isFamilyFriendly;
  final bool isRomantic;
  final bool hasScenicView;
  final bool hasOutdoor;
  final bool hasWifi;

  // Coordinates (stored in wishlists table for future use)
  final double? lat;
  final double? lon;

  // LDA topic
  final int dominantTopic;

  // Price level
  final int? priceLevel;

  final DateTime? createdAt;

  const WishlistModel({
    required this.id,
    required this.userId,
    required this.restaurantName,
    required this.address,
    required this.municipality,
    required this.categories,
    required this.cuisineTypes,
    required this.rating,
    required this.ratingBand,
    required this.topicLabel,
    required this.isHalal,
    required this.isVegetarian,
    required this.isVegan,
    required this.hasParking,
    required this.isFamilyFriendly,
    required this.isRomantic,
    required this.hasScenicView,
    required this.hasOutdoor,
    required this.hasWifi,
    this.lat,
    this.lon,
    this.dominantTopic = 0,
    this.priceLevel,
    this.createdAt,
  });

  // ── Parse cuisine_type from DB (same format as restaurant_profiles) ────────
  // Handles: JSON array '["Malay","Seafood"]', plain string 'Malay',
  // comma-separated 'Malay,Seafood', null/empty.
  static List<String> _parseCuisineTypes(dynamic raw) {
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

    // JSON array string: '["Malay","Seafood"]'
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

    // Comma-separated or single value
    return str.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  // ── Primary cuisine for display (first item) ──────────────────────────────
  String get cuisineType =>
      cuisineTypes.isNotEmpty ? cuisineTypes.first : 'Other';

  // ─────────────────────────────────────────
  // FACTORY — from Supabase JSON
  // ─────────────────────────────────────────

  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    return WishlistModel(
      id:             json['id']?.toString() ?? '',
      userId:         json['user_id']?.toString() ?? '',
      restaurantName: json['restaurant_name']?.toString() ?? '',
      address:        json['address']?.toString() ?? '',
      municipality:   json['municipality']?.toString() ?? '',
      categories:     json['categories']?.toString() ?? '',
      cuisineTypes:   _parseCuisineTypes(json['cuisine_type']),
      rating:         (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingBand:     json['rating_band']?.toString() ?? '',
      topicLabel:     json['topic_label']?.toString() ?? '',
      isHalal:          json['is_halal']           as bool? ?? false,
      isVegetarian:     json['is_vegetarian']      as bool? ?? false,
      isVegan:          json['is_vegan']            as bool? ?? false,
      hasParking:       json['has_parking']         as bool? ?? false,
      isFamilyFriendly: json['is_family_friendly']  as bool? ?? false,
      isRomantic:       json['is_romantic']         as bool? ?? false,
      hasScenicView:    json['has_scenic_view']     as bool? ?? false,
      hasOutdoor:       json['has_outdoor']         as bool? ?? false,
      hasWifi:          json['has_wifi']            as bool? ?? false,
      lat:           (json['latitude'] as num?)?.toDouble(),
      lon:           (json['longitude'] as num?)?.toDouble(),
      dominantTopic: (json['dominant_topic'] as num?)?.toInt() ?? 0,
      priceLevel:    (json['price_level'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  // ─────────────────────────────────────────
  // SERIALIZATION — for Supabase insert
  // ─────────────────────────────────────────

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id':           userId,
      'restaurant_name':   restaurantName,
      'address':           address,
      'municipality':      municipality,
      'categories':        categories,
      // Store as JSON array string, same format as restaurant_profiles
      'cuisine_type':      jsonEncode(cuisineTypes),
      'rating':            rating,
      'rating_band':       ratingBand,
      'topic_label':       topicLabel,
      'is_halal':          isHalal,
      'is_vegetarian':     isVegetarian,
      'is_vegan':          isVegan,
      'has_parking':       hasParking,
      'is_family_friendly': isFamilyFriendly,
      'is_romantic':       isRomantic,
      'has_scenic_view':   hasScenicView,
      'has_outdoor':       hasOutdoor,
      'has_wifi':          hasWifi,
      'latitude':          lat,
      'longitude':         lon,
      'dominant_topic':    dominantTopic,
      'price_level':       priceLevel,
    };
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  List<String> get activeAttributes {
    return [
      if (isHalal)          'Halal',
      if (isVegetarian)     'Vegetarian',
      if (isVegan)          'Vegan',
      if (hasParking)       'Parking',
      if (isFamilyFriendly) 'Family Friendly',
      if (isRomantic)       'Romantic',
      if (hasScenicView)    'Scenic View',
      if (hasOutdoor)       'Outdoor',
      if (hasWifi)          'WiFi',
    ];
  }

  @override
  List<Object?> get props => [
    id, userId, restaurantName, address, municipality, categories,
    cuisineTypes, rating, ratingBand, topicLabel,
    isHalal, isVegetarian, isVegan, hasParking, isFamilyFriendly,
    isRomantic, hasScenicView, hasOutdoor, hasWifi,
    lat, lon, dominantTopic, priceLevel, createdAt,
  ];

  @override
  String toString() =>
      'WishlistModel(id: $id, restaurantName: $restaurantName, '
      'cuisines: $cuisineTypes)';
}