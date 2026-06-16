import 'dart:convert';
import 'dart:developer';
import 'package:equatable/equatable.dart';

class UserPreferencesModel extends Equatable {
  final String userId;

  // ── Dietary ───────────────────────────────────────────────────────────────
  final bool halal;
  final bool vegetarian;
  final bool vegan;
  final List<String> cuisineTypes;

  // ── Facilities ────────────────────────────────────────────────────────────
  final bool hasParking;
  final bool hasWifi;
  final bool hasAc; // NEW — maps to has_ac in DB
  final bool hasOutdoor;
  final bool accessible; // NEW — maps to is_accessible in DB

  // ── Vibes ─────────────────────────────────────────────────────────────────
  final bool familyFriendly;
  final bool groupFriendly; // NEW — maps to is_group_friendly in DB
  final bool casual; // NEW — maps to is_casual in DB
  final bool romantic;
  final bool scenicView;
  final bool isCrowded; // NEW — stored locally via SharedPreferences

  // ── Service / Value ───────────────────────────────────────────────────────
  final bool worthIt; // NEW — maps to is_worth_it in DB
  final bool fastService; // NEW — maps to is_fast_service in DB

  final double defaultRadius;
  final int? budget; // NEW — stored locally via SharedPreferences

  const UserPreferencesModel({
    required this.userId,
    this.halal = false,
    this.vegetarian = false,
    this.vegan = false,
    this.cuisineTypes = const [],
    this.hasParking = false,
    this.hasWifi = false,
    this.hasAc = false,
    this.hasOutdoor = false,
    this.accessible = false,
    this.familyFriendly = false,
    this.groupFriendly = false,
    this.casual = false,
    this.romantic = false,
    this.scenicView = false,
    this.isCrowded = false,
    this.worthIt = false,
    this.fastService = false,
    this.defaultRadius = 500.0,
    this.budget,
  });

  factory UserPreferencesModel.empty(String userId) =>
      UserPreferencesModel(userId: userId);

  // ── Parse cuisine_types from any format Supabase may return ───────────────
  static List<String> _parseCuisineTypes(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return [];
    if (str.startsWith('[')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final result = decoded
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (result.isNotEmpty) return result;
        }
      } catch (_) {}
      final cleaned = str
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .replaceAll("'", '');
      return cleaned
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return str
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  factory UserPreferencesModel.fromJson(Map<String, dynamic> json) {
    final cuisines = _parseCuisineTypes(json['cuisine_types']);

    log(
      'UserPrefsModel.fromJson: '
      'raw_cuisine="${json['cuisine_types']}" '
      'parsed=$cuisines '
      'halal=${json['halal']}',
      name: 'UserPrefs',
    );

    return UserPreferencesModel(
      userId: json['user_id']?.toString() ?? '',
      halal: json['halal'] as bool? ?? false,
      vegetarian: json['vegetarian'] as bool? ?? false,
      vegan: json['vegan'] as bool? ?? false,
      cuisineTypes: cuisines,
      hasParking: json['has_parking'] as bool? ?? false,
      hasWifi: json['has_wifi'] as bool? ?? false,
      hasAc: json['has_ac'] as bool? ?? false,
      hasOutdoor: json['outdoor'] as bool? ?? false,
      accessible: json['accessible'] as bool? ?? false,
      familyFriendly: json['family_friendly'] as bool? ?? false,
      groupFriendly: json['group_friendly'] as bool? ?? false,
      casual: json['casual'] as bool? ?? false,
      romantic: json['romantic'] as bool? ?? false,
      scenicView: json['scenic_view'] as bool? ?? false,
      isCrowded: json['is_crowded'] as bool? ?? false,
      worthIt: json['worth_it'] as bool? ?? false,
      fastService: json['fast_service'] as bool? ?? false,
      defaultRadius: (json['default_radius'] as num?)?.toDouble() ?? 500.0,
      budget: json['budget'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'halal': halal,
    'vegetarian': vegetarian,
    'vegan': vegan,
    // Always write as plain comma-separated — simplest, most reliable format
    'cuisine_types': cuisineTypes.join(','),
    'has_parking': hasParking,
    'has_wifi': hasWifi,
    'has_ac': hasAc,
    'outdoor': hasOutdoor,
    'accessible': accessible,
    'family_friendly': familyFriendly,
    'group_friendly': groupFriendly,
    'casual': casual,
    'romantic': romantic,
    'scenic_view': scenicView,
    'worth_it': worthIt,
    'fast_service': fastService,
    'default_radius': defaultRadius,
    // budget and isCrowded are NOT in user_preferences database table, so excluded from toJson()
  };

  UserPreferencesModel copyWith({
    bool? halal,
    bool? vegetarian,
    bool? vegan,
    List<String>? cuisineTypes,
    bool? hasParking,
    bool? hasWifi,
    bool? hasAc,
    bool? hasOutdoor,
    bool? accessible,
    bool? familyFriendly,
    bool? groupFriendly,
    bool? casual,
    bool? romantic,
    bool? scenicView,
    bool? isCrowded,
    bool? worthIt,
    bool? fastService,
    double? defaultRadius,
    int? budget,
    bool clearBudget = false,
  }) => UserPreferencesModel(
    userId: userId,
    halal: halal ?? this.halal,
    vegetarian: vegetarian ?? this.vegetarian,
    vegan: vegan ?? this.vegan,
    cuisineTypes: cuisineTypes ?? this.cuisineTypes,
    hasParking: hasParking ?? this.hasParking,
    hasWifi: hasWifi ?? this.hasWifi,
    hasAc: hasAc ?? this.hasAc,
    hasOutdoor: hasOutdoor ?? this.hasOutdoor,
    accessible: accessible ?? this.accessible,
    familyFriendly: familyFriendly ?? this.familyFriendly,
    groupFriendly: groupFriendly ?? this.groupFriendly,
    casual: casual ?? this.casual,
    romantic: romantic ?? this.romantic,
    scenicView: scenicView ?? this.scenicView,
    isCrowded: isCrowded ?? this.isCrowded,
    worthIt: worthIt ?? this.worthIt,
    fastService: fastService ?? this.fastService,
    defaultRadius: defaultRadius ?? this.defaultRadius,
    budget: clearBudget ? null : (budget ?? this.budget),
  );

  bool get hasAnyPreference =>
      halal ||
      vegetarian ||
      vegan ||
      hasParking ||
      hasWifi ||
      hasAc ||
      hasOutdoor ||
      accessible ||
      familyFriendly ||
      groupFriendly ||
      casual ||
      romantic ||
      scenicView ||
      isCrowded ||
      worthIt ||
      fastService ||
      cuisineTypes.isNotEmpty ||
      budget != null;

  String get dietarySummary {
    final parts = <String>[];
    if (halal) parts.add('Halal');
    if (vegetarian) parts.add('Vegetarian');
    if (vegan) parts.add('Vegan');
    return parts.isEmpty ? 'Not set' : parts.join(' · ');
  }

  String get cuisineSummary =>
      cuisineTypes.isEmpty ? 'Not set' : cuisineTypes.join(', ');

  @override
  String toString() =>
      'UserPreferencesModel(userId: $userId, cuisines: $cuisineTypes, '
      'halal: $halal, veg: $vegetarian, vegan: $vegan, '
      'parking: $hasParking, wifi: $hasWifi, ac: $hasAc, '
      'outdoor: $hasOutdoor, accessible: $accessible, '
      'family: $familyFriendly, group: $groupFriendly, casual: $casual, '
      'romantic: $romantic, scenic: $scenicView, crowded: $isCrowded, '
      'worthIt: $worthIt, fastService: $fastService, '
      'radius: $defaultRadius, budget: $budget)';

  @override
  List<Object?> get props => [
    userId,
    halal,
    vegetarian,
    vegan,
    cuisineTypes,
    hasParking,
    hasWifi,
    hasAc,
    hasOutdoor,
    accessible,
    familyFriendly,
    groupFriendly,
    casual,
    romantic,
    scenicView,
    isCrowded,
    worthIt,
    fastService,
    defaultRadius,
    budget,
  ];
}
