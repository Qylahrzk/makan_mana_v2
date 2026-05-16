import 'dart:developer';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';
import '../models/favourite_model.dart';
import '../models/restaurant_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ─────────────────────────────────────────
  // AUTH HELPERS
  // ─────────────────────────────────────────

  User? get currentAuthUser => _client.auth.currentUser;
  bool get isAuthenticated => currentAuthUser != null;
  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  // ─────────────────────────────────────────
  // AUTHENTICATION — EMAIL & PASSWORD
  // ─────────────────────────────────────────

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (response.user == null) {
        throw Exception('Sign up failed — no user returned.');
      }

      final UserModel user = UserModel(
        id: response.user!.id,
        email: email,
        fullName: fullName,
      );

      await _upsertUserProfile(user);
      log('SignUp success: ${user.email}');
      return user;
    } on AuthException catch (e) {
      log('SignUp AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      log('SignUp error: $e');
      throw Exception('Sign up failed. Please try again.');
    }
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed — no user returned.');
      }

      final UserModel user = await getUserProfile(response.user!.id);
      log('SignIn success: ${user.email}');
      return user;
    } on AuthException catch (e) {
      log('SignIn AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      log('SignIn error: $e');
      throw Exception('Login failed. Please check your credentials.');
    }
  }

  // ─────────────────────────────────────────
  // AUTHENTICATION — GOOGLE SIGN IN (NATIVE)
  // ─────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId:
            '520517959373-b5jaiplbu2h4m77jesflrt1e36177a0r.apps.googleusercontent.com',
      );

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID token received from Google.');
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      log('Google Sign-In success');
    } on AuthException catch (e) {
      log('Google Sign-In AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      log('Google Sign-In error: $e');
      if (e.toString().contains('cancelled') ||
          e.toString().contains('sign_in_canceled')) {
        throw Exception('Google sign-in cancelled.');
      }
      throw Exception('Google sign-in failed. Please try again.');
    }
  }

  // ─────────────────────────────────────────
  // AUTHENTICATION — PASSWORD RESET
  // ─────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      log('Password reset email sent to: $email');
    } on AuthException catch (e) {
      log('Password reset AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      log('Password reset error: $e');
      throw Exception('Failed to send reset email. Please try again.');
    }
  }

  // ─────────────────────────────────────────
  // AUTHENTICATION — SIGN OUT
  // ─────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}
      log('User signed out');
    } catch (e) {
      log('Sign out error: $e');
      throw Exception('Sign out failed. Please try again.');
    }
  }

  // ─────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────

  Future<UserModel> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from(SupabaseTables.users)
          .select()
          .eq(UserColumns.id, userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      log('getUserProfile error: $e');
      final authUser = currentAuthUser;
      if (authUser != null) {
        return UserModel.fromSupabaseUser(
          authUser.userMetadata ?? {},
          authUser.id,
          authUser.email ?? '',
        );
      }
      throw Exception('Failed to load user profile.');
    }
  }

  Future<void> _upsertUserProfile(UserModel user) async {
    try {
      await _client.from(SupabaseTables.users).upsert(user.toJson());
      log('User profile upserted: ${user.id}');
    } catch (e) {
      log('_upsertUserProfile error: $e');
    }
  }

  Future<UserModel> updateUserProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (fullName != null) updates[UserColumns.fullName] = fullName;
      if (avatarUrl != null) updates[UserColumns.avatarUrl] = avatarUrl;

      final response = await _client
          .from(SupabaseTables.users)
          .update(updates)
          .eq(UserColumns.id, userId)
          .select()
          .single();

      log('Profile updated for: $userId');
      return UserModel.fromJson(response);
    } catch (e) {
      log('updateUserProfile error: $e');
      throw Exception('Failed to update profile.');
    }
  }

  // ─────────────────────────────────────────
  // FAVOURITE
  // ─────────────────────────────────────────

  Future<List<FavouriteModel>> getFavourite(String userId) async {
    try {
      final response = await _client
          .from(SupabaseTables.favourites)
          .select()
          .eq(FavouriteColumns.userId, userId)
          .order(FavouriteColumns.createdAt, ascending: false);

      return (response as List)
          .map((json) => FavouriteModel.fromJson(json))
          .toList();
    } catch (e) {
      log('getFavourite error: $e');
      throw Exception('Failed to load favourites.');
    }
  }

  // Backward compatible alias
  Future<List<FavouriteModel>> getFavourites(String userId) async {
    return getFavourite(userId);
  }

  Future<FavouriteModel> addToFavourite({
    required String userId,
    required Restaurant restaurant,
  }) async {
    try {
      // Check for existing entry
      final existing = await _client
          .from(SupabaseTables.favourites)
          .select()
          .eq(FavouriteColumns.userId, userId)
          .eq(FavouriteColumns.restaurantName, restaurant.name)
          .maybeSingle();

      if (existing != null) {
        throw Exception('This restaurant is already in your favourites.');
      }

      // Build favourite entry
      final FavouriteModel entry = FavouriteModel(
        id: '',
        userId: userId,
        restaurantName: restaurant.name,
        address: restaurant.address,
        municipality: restaurant.municipality,
        categories: restaurant.categories,
        cuisineTypes: restaurant.cuisineTypes,
        rating: restaurant.rating,
        ratingBand: restaurant.ratingBand,
        topicLabel: restaurant.topicLabel,
        isHalal: restaurant.isHalal,
        isVegetarian: restaurant.isVegetarian,
        isVegan: restaurant.isVegan,
        hasParking: restaurant.hasParking,
        isFamilyFriendly: restaurant.isFamilyFriendly,
        isRomantic: restaurant.isRomantic,
        hasScenicView: restaurant.hasScenicView,
        hasOutdoor: restaurant.hasOutdoor,
        hasWifi: restaurant.hasWifi,
        lat: restaurant.lat,
        lon: restaurant.lon,
        dominantTopic: restaurant.dominantTopic,
        priceLevel: restaurant.priceLevel,
      );

      final response = await _client
          .from(SupabaseTables.favourites)
          .insert(entry.toInsertJson())
          .select()
          .single();

      log('Added to favourite: ${restaurant.name}');
      return FavouriteModel.fromJson(response);
    } catch (e) {
      log('addToFavourite error: $e');
      rethrow;
    }
  }

  // Backward compatible alias
  Future<FavouriteModel> addToFavourites({
    required String userId,
    required Restaurant restaurant,
  }) async {
    return addToFavourite(userId: userId, restaurant: restaurant);
  }

  Future<void> removeFromFavourite(String favouriteId) async {
    try {
      await _client
          .from(SupabaseTables.favourites)
          .delete()
          .eq(FavouriteColumns.id, favouriteId);

      log('Removed from favourite: $favouriteId');
    } catch (e) {
      log('removeFromFavourite error: $e');
      throw Exception('Failed to remove from favourite.');
    }
  }

  // Backward compatible alias
  Future<void> removeFromFavourites(String favouriteId) async {
    return removeFromFavourite(favouriteId);
  }

  Future<String?> getFavouriteEntryId({
    required String userId,
    required String restaurantName,
  }) async {
    try {
      final response = await _client
          .from(SupabaseTables.favourites)
          .select(FavouriteColumns.id)
          .eq(FavouriteColumns.userId, userId)
          .eq(FavouriteColumns.restaurantName, restaurantName)
          .maybeSingle();

      return response?['id']?.toString();
    } catch (e) {
      log('getFavouriteEntryId error: $e');
      return null;
    }
  }

  // Backward compatible alias
  Future<String?> getFavouritesEntryId({
    required String userId,
    required String restaurantName,
  }) async {
    return getFavouriteEntryId(userId: userId, restaurantName: restaurantName);
  }
}
