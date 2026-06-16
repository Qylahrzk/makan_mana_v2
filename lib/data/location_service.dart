import 'package:geolocator/geolocator.dart';

/// LocationService
///
/// Singleton that provides the user's current GPS position.
///
/// Behaviour:
///   1. Checks/requests permission on first call.
///   2. Caches the last known position — subsequent calls return instantly
///      unless [forceRefresh] is true.
///   3. If permission is denied or location is unavailable, silently falls
///      back to the centre of Kuala Terengganu so the app never crashes.
///
/// Usage:
///   final pos = await LocationService.instance.getPosition();
///   double lat = pos.latitude;
///   double lon = pos.longitude;
///
/// Place in: lib/data/location_service.dart

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // Fallback: centre of Kuala Terengganu
  static const double fallbackLat = 5.3302;
  static const double fallbackLon = 103.1408;

  Position? _cached;

  /// Returns the current [Position].
  /// Falls back to [fallbackLat]/[fallbackLon] on any error.
  Future<Position> getPosition({bool forceRefresh = false}) async {
    if (_cached != null && !forceRefresh) return _cached!;

    try {
      // 1. Check if location services are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _fallback();

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _fallback();
      }
      if (permission == LocationPermission.deniedForever) return _fallback();

      // 3. Get current position
      // LocationAccuracy.medium is a good balance — fast + battery-friendly
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );

      _cached = pos;
      return pos;
    } catch (_) {
      return _fallback();
    }
  }

  /// Convenience getters
  Future<double> getLat({bool forceRefresh = false}) async =>
      (await getPosition(forceRefresh: forceRefresh)).latitude;

  Future<double> getLon({bool forceRefresh = false}) async =>
      (await getPosition(forceRefresh: forceRefresh)).longitude;

  /// True if we have a real GPS fix (not the fallback)
  bool get hasCachedPosition => _cached != null;

  /// Cached latitude or fallback
  double get cachedLat => _cached?.latitude ?? fallbackLat;

  /// Cached longitude or fallback
  double get cachedLon => _cached?.longitude ?? fallbackLon;

  /// Clear the cache — forces a fresh GPS read next call
  void clearCache() => _cached = null;

  // ─── Private ──────────────────────────────────────────────────────────────

  Position _fallback() => Position(
    latitude: fallbackLat,
    longitude: fallbackLon,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
