part of 'recommendation_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Source enum — tells the UI whether results came from the API or local scoring
// ─────────────────────────────────────────────────────────────────────────────

enum RecSource { api, local }

// ─────────────────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────────────────

abstract class RecommendationState {
  // Add a const constructor to the base class
  const RecommendationState();
}

/// No recommendation has been requested yet.
class RecInitial extends RecommendationState {}

/// Algorithm is running / API call in-flight.
class RecLoading extends RecommendationState {}

/// "Similar restaurants" to a selected restaurant.
/// Triggered by getHybridRecommendations(target).
/// Used on: RestaurantDetailScreen → navigates to RecommendationScreen.
class RecLoaded extends RecommendationState {
  final List<Restaurant> recommendations;
  final Restaurant       targetRestaurant;
  final RecSource        source;
  final List<String>     relaxedFilters;

  RecLoaded({
    required this.recommendations,
    required this.targetRestaurant,
    this.source         = RecSource.local,
    this.relaxedFilters = const [],
  });

  bool get isFromApi => source == RecSource.api;
}

/// Preference-based recommendations from Flask API (or local fallback).
/// Triggered by getPreferenceRecommendations(...).
/// Used on: HomeScreen "Recommended For You" section.
class RecPreferenceLoaded extends RecommendationState {
  final List<Restaurant> recommendations;

  /// Filters the API had to drop to find enough results.
  /// Empty = all filters were satisfied.
  final List<String> filtersRelaxed;

  /// Human-readable message for UI (empty if no filters relaxed).
  final String relaxedMessage;

  /// e.g. "30% KBF + 70% LDA" or "30% KBF + 70% LDA (offline)"
  final String weighting;

  RecPreferenceLoaded({
    required this.recommendations,
    required this.filtersRelaxed,
    required this.relaxedMessage,
    required this.weighting,
  });

  bool get hadRelaxedFilters => filtersRelaxed.isNotEmpty;
}

/// Something went wrong during calculation or fetch.
class RecError extends RecommendationState {
  final String message;
  const RecError(this.message);
}