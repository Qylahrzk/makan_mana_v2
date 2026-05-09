// ============================================================
// FILE: lib/logic/cubits/restaurant_detail_state.dart
// ============================================================

part of 'restaurant_detail_cubit.dart';

abstract class RestaurantDetailState extends Equatable {
  const RestaurantDetailState();

  @override
  List<Object?> get props => [];
}

/// Initial state — compass not yet started, similar not loaded.
class RestaurantDetailInitial extends RestaurantDetailState {
  const RestaurantDetailInitial();
}

/// Compass heading updated.
class RestaurantDetailCompassUpdated extends RestaurantDetailState {
  final double heading;
  const RestaurantDetailCompassUpdated(this.heading);

  @override
  List<Object?> get props => [heading];
}

/// Similar restaurants are being loaded.
class RestaurantDetailSimilarLoading extends RestaurantDetailState {
  const RestaurantDetailSimilarLoading();
}

/// Similar restaurants loaded successfully.
class RestaurantDetailSimilarLoaded extends RestaurantDetailState {
  final List<Restaurant> similar;
  const RestaurantDetailSimilarLoaded(this.similar);

  @override
  List<Object?> get props => [similar];
}

/// Similar restaurants failed to load.
class RestaurantDetailSimilarError extends RestaurantDetailState {
  const RestaurantDetailSimilarError();
}
