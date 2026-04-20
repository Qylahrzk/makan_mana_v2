/// RestaurantImage
///
/// Maps cuisine types to high-quality Unsplash food photos.
/// These are stable Unsplash URLs that don't require an API key.
/// Used across all screens: home, search, wishlist, recommendation, detail.
library;

class RestaurantImage {
  RestaurantImage._();

  /// Returns a cuisine-appropriate image URL for the given restaurant.
  static String getUrl(String cuisineType, {int seed = 0}) {
    final urls = _map[cuisineType] ?? _map['Other']!;
    return urls[seed % urls.length];
  }

  static const Map<String, List<String>> _map = {

    'Malay': [
      'https://images.unsplash.com/photo-1626804475297-41608ea09aeb?w=600&q=80', // nasi lemak
      'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&q=80', // malaysian food
      'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&q=80', // rice dish
    ],

    'Cafe': [
      'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600&q=80', // cafe interior
      'https://images.unsplash.com/photo-1445116572660-236099ec97a0?w=600&q=80', // coffee and cake
      'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?w=600&q=80', // latte art
    ],

    'Fast Food': [
      'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80', // burger
      'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&q=80', // fried chicken
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&q=80', // fast food
    ],

    'Western': [
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80', // steak
      'https://images.unsplash.com/photo-1432139555190-58524dae6a55?w=600&q=80', // pasta
      'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=600&q=80', // western food
    ],

    'Family': [
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80', // family restaurant
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80', // restaurant interior
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80', // dining
    ],

    'Asian': [
      'https://images.unsplash.com/photo-1512003867696-6d5ce6835040?w=600&q=80', // asian food
      'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80', // asian cuisine
      'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&q=80', // noodles
    ],

    'Seafood': [
      'https://images.unsplash.com/photo-1534482421-64566f976cfa?w=600&q=80', // seafood spread
      'https://images.unsplash.com/photo-1559742811-822873691df8?w=600&q=80', // grilled fish
      'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=600&q=80', // prawns
    ],

    'Chinese': [
      'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&q=80', // dim sum
      'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600&q=80', // chinese food
      'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=600&q=80', // chinese cuisine
    ],

    'Thai': [
      'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=600&q=80', // thai food
      'https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4?w=600&q=80', // pad thai
      'https://images.unsplash.com/photo-1548943487-a2e4e43b4853?w=600&q=80', // thai curry
    ],

    'Indonesian': [
      'https://images.unsplash.com/photo-1574484284002-952d92456975?w=600&q=80', // indonesian food
      'https://images.unsplash.com/photo-1607116667981-ff9c4e3c3a6e?w=600&q=80', // rendang
      'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&q=80', // rice dish
    ],

    'Japanese': [
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=600&q=80', // sushi
      'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&q=80', // ramen
      'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&q=80', // japanese food
    ],

    'Indian': [
      'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80', // indian curry
      'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80', // naan
      'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&q=80', // indian food
    ],

    'Korean': [
      'https://images.unsplash.com/photo-1635363638580-c2809d049eee?w=600&q=80', // korean bbq
      'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=600&q=80', // bibimbap
      'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&q=80', // korean food
    ],

    'BBQ': [
      'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=600&q=80', // bbq grill
      'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&q=80', // grilled meat
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80', // bbq ribs
    ],

    'Middle Eastern': [
      'https://images.unsplash.com/photo-1544550581-5f7ceaf7f992?w=600&q=80', // shawarma
      'https://images.unsplash.com/photo-1561043433-aaf687c4cf04?w=600&q=80', // middle eastern
      'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=600&q=80', // kebab
    ],

    'Italian': [
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80', // pizza
      'https://images.unsplash.com/photo-1476124369491-e7addf5db371?w=600&q=80', // pasta
      'https://images.unsplash.com/photo-1432139555190-58524dae6a55?w=600&q=80', // italian food
    ],

    'Buffet': [
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80', // buffet spread
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80', // food spread
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80', // buffet restaurant
    ],

    'Vegetarian': [
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80', // vegetarian food
      'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&q=80', // salad bowl
      'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=600&q=80', // healthy food
    ],

    'Other': [
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80', // restaurant
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80', // food
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80', // dining
    ],
  };
}