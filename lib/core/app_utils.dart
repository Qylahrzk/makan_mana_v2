import 'dart:math';

/// Utility functions for Terengganu Restaurant Recommender.
/// Place this file in: lib/core/app_utils.dart

class AppUtils {
  AppUtils._(); // Prevent instantiation

  // ─────────────────────────────────────────
  // LOCATION UTILITIES
  // ─────────────────────────────────────────

  /// Haversine Formula — calculates the straight-line distance
  /// between two GPS coordinates in kilometres.
  ///
  /// Usage:
  /// ```dart
  /// double km = AppUtils.calculateDistance(
  ///   target.lat!, target.lon!, nearby.lat!, nearby.lon!
  /// );
  /// ```
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double p = 0.017453292519943295; // PI / 180
    final double a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R * asin(sqrt(a)), R = 6371 km
  }

  /// Formats a distance in km to a readable string.
  /// e.g. 0.3 → "300 m", 1.5 → "1.5 km"
  static String formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  // ─────────────────────────────────────────
  // RATING UTILITIES
  // ─────────────────────────────────────────

  /// Normalizes a raw rating (0–5) to a 0.0–1.0 score.
  static double normalizeRating(double rating, {double maxRating = 5.0}) {
    if (maxRating == 0) return 0.0;
    return (rating / maxRating).clamp(0.0, 1.0);
  }

  /// Formats a rating double to 1 decimal place string.
  /// e.g. 4.333 → "4.3"
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  // ─────────────────────────────────────────
  // PRICE UTILITIES
  // ─────────────────────────────────────────

  /// Maps a priceRange string from the database to a
  /// BudgetOptions label used in filters.
  /// e.g. "RM5 - RM15" → "Budget"
  static String formatPriceLabel(String priceRange) {
    final lower = priceRange.toLowerCase();
    if (lower.contains('rm5') || lower.contains('rm10')) return 'Budget';
    if (lower.contains('rm15') ||
        lower.contains('rm20') ||
        lower.contains('rm30') ||
        lower.contains('rm50')) {
      return 'Mid-Range';
    }
    if (lower.contains('rm50') || lower.contains('rm100')) return 'Fine Dining';
    return priceRange; // fallback — return raw string if no match
  }

  // ─────────────────────────────────────────
  // TAG UTILITIES
  // ─────────────────────────────────────────

  /// Formats a list of tags into a readable comma-separated string.
  /// e.g. ['Halal', 'Vegetarian'] → "Halal, Vegetarian"
  static String formatTags(List<String> tags) {
    if (tags.isEmpty) return '-';
    return tags.join(', ');
  }

  /// Returns true if the tag list contains a specific tag (case-insensitive).
  static bool hasTag(List<String> tags, String tag) {
    return tags.any((t) => t.toLowerCase() == tag.toLowerCase());
  }

  // ─────────────────────────────────────────
  // STRING UTILITIES
  // ─────────────────────────────────────────

  /// Capitalizes the first letter of a string.
  /// e.g. "malay food" → "Malay food"
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Capitalizes the first letter of each word.
  /// e.g. "nasi lemak special" → "Nasi Lemak Special"
  static String titleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isEmpty ? word : capitalize(word))
        .join(' ');
  }

  /// Truncates text to a max length with ellipsis.
  /// e.g. "A very long restaurant name" → "A very long..."
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // ─────────────────────────────────────────
  // VALIDATION UTILITIES
  // ─────────────────────────────────────────

  /// Returns true if the string is a valid email address.
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Returns true if the password meets minimum requirements.
  /// (At least 6 characters)
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}
