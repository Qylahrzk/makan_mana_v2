import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/supabase_service.dart';
import '../../models/wishlist_model.dart';
import '../../models/restaurant_model.dart';

part 'wishlist_state.dart';

class WishlistCubit extends Cubit<WishlistState> {
  final SupabaseService _supabaseService;

  WishlistCubit(this._supabaseService) : super(WishlistInitial());

  // ─────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────

  Future<void> loadWishlist(String userId) async {
    log('loadWishlist START — userId=$userId');
    emit(WishlistLoading());
    try {
      final items = await _supabaseService.getWishlist(userId);
      emit(WishlistLoaded(items));
      log('loadWishlist SUCCESS — ${items.length} items loaded');
      for (final item in items) {
        log('  → ${item.restaurantName} (id: ${item.id})');
      }
    } catch (e) {
      log('loadWishlist ERROR: $e');
      emit(const WishlistError('Failed to load wishlist.'));
    }
  }

  // ─────────────────────────────────────────
  // ADD
  // ─────────────────────────────────────────

  Future<void> addToWishlist({
    required String userId,
    required Restaurant restaurant,
  }) async {
    log('addToWishlist START — ${restaurant.name}, userId=$userId');
    try {
      await _supabaseService.addToWishlist(
        userId: userId,
        restaurant: restaurant,
      );
      log('addToWishlist — Supabase insert SUCCESS');
      final items = await _supabaseService.getWishlist(userId);
      log('addToWishlist — fetched ${items.length} items after insert');
      emit(WishlistLoaded(items));
      log('addToWishlist — emitted WishlistLoaded with ${items.length} items');
    } catch (e) {
      log('addToWishlist ERROR: $e');
      final current = state;
      final msg = e.toString().replaceAll('Exception: ', '');
      emit(WishlistError(msg));
      if (current is WishlistLoaded) emit(current);
    }
  }

  // ─────────────────────────────────────────
  // REMOVE (optimistic)
  // ─────────────────────────────────────────

  Future<void> removeFromWishlist({
    required String userId,
    required String wishlistId,
  }) async {
    log('removeFromWishlist START — wishlistId=$wishlistId');
    final current = state;
    if (current is WishlistLoaded) {
      emit(WishlistLoaded(
          current.items.where((i) => i.id != wishlistId).toList()));
      log('removeFromWishlist — optimistic remove applied');
    }
    try {
      await _supabaseService.removeFromWishlist(wishlistId);
      log('removeFromWishlist SUCCESS — $wishlistId');
    } catch (e) {
      log('removeFromWishlist ERROR: $e');
      await loadWishlist(userId);
      emit(const WishlistError('Failed to remove. Please try again.'));
    }
  }

  // ─────────────────────────────────────────
  // TOGGLE
  // ─────────────────────────────────────────

  Future<void> toggleWishlist({
    required String userId,
    required Restaurant restaurant,
  }) async {
    log('toggleWishlist START — userId=$userId, restaurant=${restaurant.name}');
    log('toggleWishlist — current state: ${state.runtimeType}');

    // ✅ Load wishlist first if not loaded
    if (state is! WishlistLoaded) {
      log('toggleWishlist — state not loaded, loading wishlist first...');
      await loadWishlist(userId);
      log('toggleWishlist — after load, state: ${state.runtimeType}');
      if (state is WishlistLoaded) {
        log('toggleWishlist — loaded ${(state as WishlistLoaded).items.length} items');
      }
    }

    log('toggleWishlist — checking if already saved...');
    final existingId = await _supabaseService.getWishlistEntryId(
      userId: userId,
      restaurantName: restaurant.name,
    );
    log('toggleWishlist — existingId=$existingId');

    if (existingId != null) {
      log('toggleWishlist — REMOVING from wishlist');
      await removeFromWishlist(userId: userId, wishlistId: existingId);
    } else {
      log('toggleWishlist — ADDING to wishlist');
      await addToWishlist(userId: userId, restaurant: restaurant);
    }

    // ✅ Force reload after toggle to confirm persistence
    log('toggleWishlist — reloading wishlist after toggle...');
    await loadWishlist(userId);
    log('toggleWishlist COMPLETE — final state: ${state.runtimeType}');
    if (state is WishlistLoaded) {
      log('toggleWishlist — final items count: ${(state as WishlistLoaded).items.length}');
      for (final item in (state as WishlistLoaded).items) {
        log('  → ${item.restaurantName}');
      }
    }
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  bool isSaved(String restaurantName) {
    final current = state;
    if (current is WishlistLoaded) {
      final saved = current.items.any(
          (i) => i.restaurantName == restaurantName);
      log('isSaved($restaurantName) = $saved — '
          '${current.items.length} items in state');
      return saved;
    }
    log('isSaved($restaurantName) = false — state is ${state.runtimeType}');
    return false;
  }

  String? getWishlistId(String restaurantName) {
    final current = state;
    if (current is WishlistLoaded) {
      try {
        return current.items
            .firstWhere((i) => i.restaurantName == restaurantName)
            .id;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}