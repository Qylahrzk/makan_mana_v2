import 'dart:async';
import 'dart:math' hide log;
import 'dart:developer';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../../core/app_utils.dart';
import '../../data/restaurant_repository.dart';
import '../../models/restaurant_model.dart';

part 'restaurant_detail_state.dart';

class RestaurantDetailCubit extends Cubit<RestaurantDetailState> {
  final RestaurantRepository _repository;
  StreamSubscription<CompassEvent>? _compassSub;

  static const double maxSimilarKm = 50.0;

  RestaurantDetailCubit(this._repository)
    : super(const RestaurantDetailInitial());

  // ─ COMPASS LIFECYCLE ──────────────────────────────────────────────────────

  /// Subscribes to device compass stream.
  /// Emits [RestaurantDetailCompassUpdated] on valid heading reads.
  /// Safe to call multiple times — cancels previous subscription first.
  void startCompass() {
    log('startCompass: subscribing to compass stream', name: 'DetailCubit');

    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && !isClosed) {
        emit(RestaurantDetailCompassUpdated(event.heading!));
      }
    });
  }

  /// Explicitly cancels the compass subscription.
  /// Called from close() to ensure cleanup.
  void stopCompass() {
    log('stopCompass: cancelling compass subscription', name: 'DetailCubit');
    _compassSub?.cancel();
    _compassSub = null;
  }

  // ─ SIMILAR RESTAURANTS ────────────────────────────────────────────────────

  /// Loads similar restaurants using 3-tier fallback:
  ///   Tier 1: Same dominant topic + same cuisine within 50km
  ///   Tier 2: Same dominant topic only within 50km
  ///   Tier 3: Same cuisine only within 50km
  /// Results sorted by rating descending, capped at 6.
  Future<void> loadSimilar(
    Restaurant restaurant,
    double userLat,
    double userLon,
  ) async {
    log('loadSimilar: starting for "${restaurant.name}"', name: 'DetailCubit');

    emit(const RestaurantDetailSimilarLoading());
    try {
      final all = await _repository.getAllRestaurants();

      // Distance from the current restaurant (not user)
      double distFromTarget(Restaurant x) => AppUtils.calculateDistance(
        restaurant.lat ?? userLat,
        restaurant.lon ?? userLon,
        x.lat ?? restaurant.lat ?? userLat,
        x.lon ?? restaurant.lon ?? userLon,
      );

      bool withinCap(Restaurant x) => distFromTarget(x) <= maxSimilarKm;

      // Tier 1 — same topic + same cuisine + within cap
      var candidates = all
          .where(
            (x) =>
                x.id != restaurant.id &&
                x.dominantTopic == restaurant.dominantTopic &&
                x.cuisineType == restaurant.cuisineType &&
                withinCap(x),
          )
          .toList();

      log(
        'loadSimilar: Tier 1 candidates = ${candidates.length}',
        name: 'DetailCubit',
      );

      // Tier 2 — same topic only
      if (candidates.length < 3) {
        candidates = all
            .where(
              (x) =>
                  x.id != restaurant.id &&
                  x.dominantTopic == restaurant.dominantTopic &&
                  withinCap(x),
            )
            .toList();
        log(
          'loadSimilar: Tier 2 candidates = ${candidates.length}',
          name: 'DetailCubit',
        );
      }

      // Tier 3 — same cuisine only
      if (candidates.length < 3) {
        final byCuisine = all
            .where(
              (x) =>
                  x.id != restaurant.id &&
                  x.cuisineType == restaurant.cuisineType &&
                  withinCap(x),
            )
            .toList();
        for (final c in byCuisine) {
          if (!candidates.any((x) => x.id == c.id)) candidates.add(c);
        }
        log(
          'loadSimilar: Tier 3 candidates = ${candidates.length}',
          name: 'DetailCubit',
        );
      }

      candidates.sort((a, b) => b.rating.compareTo(a.rating));
      final final6 = candidates.take(6).toList();
      log(
        'loadSimilar: ✅ loaded ${final6.length} similar restaurants',
        name: 'DetailCubit',
      );
      emit(RestaurantDetailSimilarLoaded(final6));
    } catch (e) {
      log('loadSimilar ERROR: $e', name: 'DetailCubit');
      emit(const RestaurantDetailSimilarError());
    }
  }

  // ─ BEARING HELPERS ────────────────────────────────────────────────────────

  static double bearingTo(
    double userLat,
    double userLon,
    double destLat,
    double destLon,
  ) {
    final dLon = _toRad(destLon - userLon);
    final y = sin(dLon) * cos(_toRad(destLat));
    final x =
        cos(_toRad(userLat)) * sin(_toRad(destLat)) -
        sin(_toRad(userLat)) * cos(_toRad(destLat)) * cos(dLon);
    return (_toDeg(atan2(y, x)) + 360) % 360;
  }

  /// Returns cardinal direction label (8-point compass).
  /// ✅ FIXED: Correct angle boundaries for 8-point compass
  static String directionLabel(double relativeBearing) {
    final b = (relativeBearing + 360) % 360;
    if (b < 22.5 || b >= 337.5) return 'North'; // N: 337.5–22.5
    if (b < 67.5) return 'North-East'; // NE: 22.5–67.5
    if (b < 112.5) return 'East'; // E: 67.5–112.5
    if (b < 157.5) return 'South-East'; // SE: 112.5–157.5
    if (b < 202.5) return 'South'; // S: 157.5–202.5
    if (b < 247.5) return 'South-West'; // SW: 202.5–247.5
    if (b < 292.5) return 'West'; // W: 247.5–292.5
    return 'North-West'; // NW: 292.5–337.5
  }

  static double _toRad(double deg) => deg * pi / 180;
  static double _toDeg(double rad) => rad * 180 / pi;

  // ─ LIFECYCLE ──────────────────────────────────────────────────────────────

  /// ✅ CRITICAL: Ensure compass stops when cubit is disposed.
  /// Without this, compass stream keeps running even after screen pops.
  @override
  Future<void> close() {
    log('close: cleaning up compass subscription', name: 'DetailCubit');
    stopCompass();
    return super.close();
  }
}
