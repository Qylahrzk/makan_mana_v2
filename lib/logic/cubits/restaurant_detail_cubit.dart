// ============================================================
// FILE: lib/logic/cubits/restaurant_detail_cubit.dart
//
// Manages two independent concerns for the restaurant detail screen:
//   1. Compass heading (streamed from FlutterCompass, emitted as state)
//   2. Similar restaurants loading (async, from RestaurantRepository)
//
// WHY A CUBIT:
//   The old _RestaurantDetailScreenState called setState() on every
//   compass event (up to 10x per second), rebuilding the ENTIRE screen
//   tree including hero image, stat chips, vibe card, etc.
//   By moving compass + similar loading into this cubit, the screen
//   uses BlocBuilder with buildWhen: to rebuild ONLY the compass widget
//   and the similar section — not the whole page.
//
// USAGE in restaurant_detail_screen.dart:
//   BlocProvider(
//     create: (_) => RestaurantDetailCubit(repository)
//       ..startCompass()
//       ..loadSimilar(restaurant, userLat, userLon),
//     child: const RestaurantDetailScreen(...),
//   )
// ============================================================

import 'dart:async';
import 'dart:math';
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

  // 50 km cap — similar restaurants further than this from the
  // current restaurant are excluded regardless of topic/cuisine match.
  static const double maxSimilarKm = 50.0;

  RestaurantDetailCubit(this._repository)
    : super(const RestaurantDetailInitial());

  // ── Compass ───────────────────────────────────────────────────────────────

  /// Subscribes to the device compass stream.
  /// Emits [RestaurantDetailCompassUpdated] on every valid heading reading.
  /// Safe to call multiple times — cancels previous subscription first.
  void startCompass() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && !isClosed) {
        emit(RestaurantDetailCompassUpdated(event.heading!));
      }
    });
  }

  /// Cancels the compass subscription. Called from dispose().
  void stopCompass() {
    _compassSub?.cancel();
    _compassSub = null;
  }

  // ── Similar restaurants ───────────────────────────────────────────────────

  /// Loads up to 6 similar restaurants using a 3-tier fallback strategy:
  ///   1. Same dominant topic AND same cuisine within 50km
  ///   2. Same dominant topic only within 50km
  ///   3. Same cuisine only within 50km
  /// Results are sorted by rating descending.
  Future<void> loadSimilar(
    Restaurant restaurant,
    double userLat,
    double userLon,
  ) async {
    emit(const RestaurantDetailSimilarLoading());
    try {
      final all = await _repository.getAllRestaurants();

      // Distance from the current restaurant (not the user) — keeps
      // "nearby similar" meaningful even when the user is far away.
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
      }

      candidates.sort((a, b) => b.rating.compareTo(a.rating));
      emit(RestaurantDetailSimilarLoaded(candidates.take(6).toList()));
    } catch (_) {
      emit(const RestaurantDetailSimilarError());
    }
  }

  // ── Bearing helpers (used by the compass widget) ──────────────────────────

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

  static String directionLabel(double relativeBearing) {
    final b = (relativeBearing + 360) % 360;
    if (b < 22.5 || b >= 337.5) return 'North';
    if (b < 67.5) return 'North-East';
    if (b < 112.5) return 'East';
    if (b < 157.5) return 'South-East';
    if (b < 202.5) return 'South';
    if (b < 247.5) return 'South-West';
    if (b < 292.5) return 'West';
    return 'North-West';
  }

  static double _toRad(double deg) => deg * pi / 180;
  static double _toDeg(double rad) => rad * 180 / pi;

  @override
  Future<void> close() {
    _compassSub?.cancel();
    return super.close();
  }
}
