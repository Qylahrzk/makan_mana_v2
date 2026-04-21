/// Central constants file for Terengganu Restaurant Recommender.
library;

// ─────────────────────────────────────────
// RECOMMENDATION ALGORITHM CONFIG
// ─────────────────────────────────────────

class RecConfig {
  RecConfig._();

  static const double wTopic = 0.7;
  static const double wRating = 0.1;
  static const double wDist = 0.2;
  static const double maxDistKm = 10.0;
  static const double booleanMatchBonus = 0.1;
}

// ─────────────────────────────────────────
// APP INFO
// ─────────────────────────────────────────

class AppInfo {
  AppInfo._();

  static const String appName = 'Terengganu Restaurant Recommender';
  static const String appVersion = '1.0.0';
  static const String appTagline = "Let's Find Something Delicious For You.";
}

// ─────────────────────────────────────────
// ROUTE NAMES
// ─────────────────────────────────────────

class AppRoutes {
  AppRoutes._();
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String preferenceSetup = '/preference-setup';
  static const String home = '/home';
  static const String main = '/main';
  static const String search = '/search';
  static const String recommendation = '/recommendation';
  static const String restaurantDetail = '/restaurant-detail';
  static const String map = '/map';
  static const String wishlist = '/wishlist';
  static const String profile = '/profile';
}

// ─────────────────────────────────────────
// SUPABASE TABLE NAMES
// ─────────────────────────────────────────

class SupabaseTables {
  SupabaseTables._();

  static const String users = 'users';
  static const String wishlists = 'wishlists';
  static const String restaurantProfiles = 'restaurant_profiles';
}

// ─────────────────────────────────────────
// SUPABASE COLUMN NAMES — restaurant_profiles
// ─────────────────────────────────────────

class RestaurantColumns {
  RestaurantColumns._();

  // Identity
  static const String id = 'id';

  // Basic info
  static const String name = 'name';
  static const String address = 'address';
  static const String municipality = 'municipality';
  static const String categories = 'categories';
  static const String cuisineType = 'cuisine_type';

  // Rating
  static const String rating = 'rating';
  static const String ratingBand = 'rating_band';

  // Coordinates
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String coordinateSource = 'coordinate_source';

  // Price
  static const String priceLevel = 'price_level';

  // Dietary booleans
  static const String isHalal = 'is_halal';
  static const String isVegetarian = 'is_vegetarian';
  static const String isVegan = 'is_vegan';

  // Facility booleans
  static const String hasParking = 'has_parking';
  static const String hasWifi = 'has_wifi';
  static const String hasAc = 'has_ac'; // air-conditioned
  static const String hasOutdoor = 'has_outdoor'; // outdoor seating
  static const String isAccessible = 'is_accessible'; // wheelchair

  // Vibe & Occasion booleans
  static const String isFamilyFriendly = 'is_family_friendly';
  static const String isGroupFriendly = 'is_group_friendly';
  static const String isCasual = 'is_casual';
  static const String isRomantic = 'is_romantic';
  static const String hasScenicView = 'has_scenic_view';

  // Service quality booleans
  static const String isWorthIt = 'is_worth_it';
  static const String isFastService = 'is_fast_service';

  // LDA topic fields
  static const String dominantTopic = 'dominant_topic';
  static const String topicLabel = 'topic_label';
  static const String topic1Pct = 'topic_1_pct';
  static const String topic2Pct = 'topic_2_pct';
  static const String topic3Pct = 'topic_3_pct';

  // Metadata
  static const String createdAt = 'created_at';
}

// ─────────────────────────────────────────
// SUPABASE COLUMN NAMES — users
// ─────────────────────────────────────────

class UserColumns {
  UserColumns._();

  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String userId = 'user_id';
  static const String email = 'email';
  static const String fullName = 'full_name';
  static const String avatarUrl = 'avatar_url';
}

// ─────────────────────────────────────────
// SUPABASE COLUMN NAMES — wishlists
// ─────────────────────────────────────────

class WishlistColumns {
  WishlistColumns._();

  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String userId = 'user_id';
  static const String restaurantId = 'restaurant_id';
  static const String restaurantName = 'restaurant_name';
}

// ─────────────────────────────────────────
// SHARED PREFERENCES KEYS
// ─────────────────────────────────────────

class PrefKeys {
  PrefKeys._();

  static const String hasSeenOnboarding = 'has_seen_onboarding';
  static const String isBiometricEnabled = 'is_biometric_enabled';
  static const String lastKnownLat = 'last_known_lat';
  static const String lastKnownLng = 'last_known_lng';
}

// ─────────────────────────────────────────
// SEARCH / FILTER OPTIONS
// ─────────────────────────────────────────

class SearchDefaults {
  SearchDefaults._();

  static const double defaultRadiusKm = 10.0;
  static const int maxResults = 20;
  static const int minResults = 1;
}

class CuisineOptions {
  CuisineOptions._();

  static const List<String> all = [
    'All',
    'Malay',
    'Western',
    'Other',
    'Seafood',
    'Asian',
    'Cafe',
    'Fast Food',
    'Chinese',
    'Thai',
    'Family',
    'Dessert',
    'Japanese',
    'Middle Eastern',
    'Indonesian',
    'Korean',
    'BBQ',
    'Buffet',
    'Indian',
    'Italian',
    'Vegetarian',
  ];
}

class DietaryOptions {
  DietaryOptions._();

  static const String halal = 'Halal';
  static const String vegetarian = 'Vegetarian';
  static const String vegan = 'Vegan';
  static const List<String> all = [halal, vegetarian, vegan];
}

class FacilityOptions {
  FacilityOptions._();

  static const String parking = 'Parking';
  static const String wifi = 'WiFi';
  static const String ac = 'Air-Cond';
  static const String accessible = 'Accessible';
  static const String outdoor = 'Outdoor';

  static const List<String> all = [parking, wifi, ac, accessible, outdoor];
}

class OccasionOptions {
  OccasionOptions._();

  static const String family = 'Family Friendly';
  static const String group = 'Group Friendly';
  static const String casual = 'Casual';
  static const String romantic = 'Romantic';
  static const String scenicView = 'Scenic View';

  static const List<String> all = [family, group, casual, romantic, scenicView];
}

class ServiceOptions {
  ServiceOptions._();

  static const String worthIt = 'Worth It';
  static const String fastService = 'Fast Service';
  static const List<String> all = [worthIt, fastService];
}

class DistanceOptions {
  DistanceOptions._();

  static const List<double> radiusChoicesKm = [1.0, 3.0, 5.0, 10.0];
  static const List<String> radiusLabels = ['1 km', '3 km', '5 km', '10 km'];
}

// ─────────────────────────────────────────
// UI CONSTANTS
// ─────────────────────────────────────────

class AppSizes {
  AppSizes._();

  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 24.0;
  static const double paddingXL = 32.0;

  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 100.0;

  static const double iconSM = 16.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;

  static const double cardElevation = 2.0;
  static const double cardImageHeight = 160.0;

  static const double buttonHeight = 52.0;
  static const double buttonHeightSM = 40.0;

  static const double bottomNavHeight = 60.0;

  static const double avatarSM = 36.0;
  static const double avatarMD = 56.0;
  static const double avatarLG = 80.0;

  static const double onboardingImageHeight = 280.0;
}

// ─────────────────────────────────────────
// DURATION CONSTANTS
// ─────────────────────────────────────────

class AppDurations {
  AppDurations._();

  static const Duration splashDelay = Duration(seconds: 2);
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration snackbarDuration = Duration(seconds: 3);
  static const Duration pageTransition = Duration(milliseconds: 300);
}

// ─────────────────────────────────────────
// ERROR & VALIDATION MESSAGES
// ─────────────────────────────────────────

class AppMessages {
  AppMessages._();

  static const String emailRequired = 'Email is required.';
  static const String emailInvalid = 'Please enter a valid email address.';
  static const String passwordRequired = 'Password is required.';
  static const String passwordTooShort =
      'Password must be at least 6 characters.';
  static const String nameRequired = 'Full name is required.';
  static const String loginSuccess = 'Welcome back!';
  static const String signupSuccess = 'Account created successfully!';
  static const String logoutSuccess = 'You have been logged out.';
  static const String passwordResetSent =
      'Password reset email sent. Check your inbox.';

  static const String wishlistAdded = 'Added to your wishlist!';
  static const String wishlistRemoved = 'Removed from wishlist.';
  static const String wishlistEmpty =
      'Your wishlist is empty. Start exploring!';

  static const String noResultsFound =
      'No restaurants found. Try adjusting your filters.';
  static const String searchError = 'Something went wrong. Please try again.';

  static const String locationPermissionDenied =
      'Location permission denied. Using default location.';
  static const String locationUnavailable = 'Unable to get your location.';

  static const String networkError =
      'No internet connection. Please check your network.';
  static const String unknownError =
      'Something went wrong. Please try again later.';
  static const String guestRestricted = 'Sign up to access this feature.';
}

// ─────────────────────────────────────────
// API CONFIG
// ─────────────────────────────────────────

class ApiConfig {
  ApiConfig._();

  // Flask API hosted on Render.com
  static const String baseUrl =
      'https://terengganu-restaurant-api.onrender.com';

  // Endpoints
  static const String health = '$baseUrl/health';
  static const String restaurants = '$baseUrl/restaurants';
  static const String nearby = '$baseUrl/restaurants/nearby';
  static const String recommend = '$baseUrl/recommend';
  static const String chat = '$baseUrl/chat';

  // Timeout — Render free tier may take up to 50s to wake from cold start
  static const Duration timeout = Duration(seconds: 60);
}
