/// RestaurantImage
///
/// Maps cuisine types to high-quality Unsplash food photos.
/// These are stable Unsplash URLs that don't require an API key.
/// Used across all screens: home, search, wishlist, recommendation, detail.
///
/// MANUAL PHOTO MAP (priority):
///   If a restaurant has a real photo (added manually by the app developer),
///   it is stored in [_manualPhotos] keyed by restaurant ID.
///   getUrl() checks this map FIRST before falling back to cuisine category.
///
///   HOW TO ADD YOUR 19 CURATED RESTAURANTS:
///   1. Get the restaurant's ID from your Supabase table.
///   2. Add an entry: restaurantId: 'https://your-photo-url.jpg'
///   3. Preferred sources (in order): your own hosted photo, Unsplash direct
///      link, Google Photos (public), or any stable CDN URL.
///   4. Use ?w=600&q=80 on Unsplash URLs for consistent sizing.
library;

class RestaurantImage {
  RestaurantImage._();

  /// Manual photo overrides — keyed by restaurant ID (matches Restaurant.id).
  /// These take priority over the cuisine category map below.
  ///
  /// ADD YOUR 19 REAL RESTAURANT PHOTOS HERE:
  /// Example format:
  ///   42: 'https://images.unsplash.com/photo-XXXXXXXXXX?w=600&q=80',
  static const Map<int, String> _manualPhotos = {
    // ── Paste your curated restaurant IDs and photo URLs below ──
    // e.g. 42: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80',
    //      117: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80',
  };

  /// Returns the best available image URL for [cuisineType].
  /// [seed] is the restaurant ID — used both for manual photo lookup
  /// and for rotating within the cuisine category fallback list.
  static String getUrl(String cuisineType, {int seed = 0}) {
    // 1. Check manual photos first (real photos of actual restaurants)
    if (_manualPhotos.containsKey(seed)) {
      return _manualPhotos[seed]!;
    }
    // 2. Fall back to cuisine category map
    final urls = _map[cuisineType] ?? _map['Other']!;
    return urls[seed % urls.length];
  }

  static const Map<String, List<String>> _map = {
    'Malay': [
      'https://images.unsplash.com/photo-1626804475297-41608ea09aeb?w=600&q=80',
      'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&q=80',
      'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&q=80',
      'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&q=80',
      'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&q=80',
      'https://images.unsplash.com/photo-1555126634-323283e090fa?w=600&q=80',
      'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80',
      'https://images.unsplash.com/photo-1601050690597-df056fb4ce78?w=600&q=80',
    ],

    'Cafe': [
      'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600&q=80',
      'https://images.unsplash.com/photo-1445116572660-236099ec97a0?w=600&q=80',
      'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?w=600&q=80',
    ],

    'Fast Food': [
      'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80',
      'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&q=80',
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&q=80',
    ],

    'Western': [
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80',
      'https://images.unsplash.com/photo-1432139555190-58524dae6a55?w=600&q=80',
      'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=600&q=80',
    ],

    'Family': [
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80',
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80',
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80',
    ],

    'Asian': [
      'https://images.unsplash.com/photo-1512003867696-6d5ce6835040?w=600&q=80',
      'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80',
      'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&q=80',
    ],

    'Seafood': [
      'https://images.unsplash.com/photo-1534482421-64566f976cfa?w=600&q=80',
      'https://images.unsplash.com/photo-1559742811-822873691df8?w=600&q=80',
      'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=600&q=80',
    ],

    'Chinese': [
      'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&q=80',
      'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600&q=80',
      'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=600&q=80',
    ],

    'Thai': [
      'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=600&q=80',
      'https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4?w=600&q=80',
      'https://images.unsplash.com/photo-1548943487-a2e4e43b4853?w=600&q=80',
    ],

    'Indonesian': [
      'https://images.unsplash.com/photo-1574484284002-952d92456975?w=600&q=80',
      'https://images.unsplash.com/photo-1607116667981-ff9c4e3c3a6e?w=600&q=80',
      'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&q=80',
    ],

    'Japanese': [
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=600&q=80',
      'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&q=80',
      'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&q=80',
    ],

    'Indian': [
      'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80',
      'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80',
      'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&q=80',
    ],

    'Korean': [
      'https://images.unsplash.com/photo-1635363638580-c2809d049eee?w=600&q=80',
      'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=600&q=80',
      'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&q=80',
    ],

    'BBQ': [
      'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=600&q=80',
      'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&q=80',
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80',
    ],

    'Middle Eastern': [
      'https://images.unsplash.com/photo-1544550581-5f7ceaf7f992?w=600&q=80',
      'https://images.unsplash.com/photo-1561043433-aaf687c4cf04?w=600&q=80',
      'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=600&q=80',
    ],

    'Italian': [
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80',
      'https://images.unsplash.com/photo-1476124369491-e7addf5db371?w=600&q=80',
      'https://images.unsplash.com/photo-1432139555190-58524dae6a55?w=600&q=80',
    ],

    'Buffet': [
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80',
    ],

    'Vegetarian': [
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80',
      'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&q=80',
      'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=600&q=80',
    ],

    'Other': [
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
    ],
  };
}
