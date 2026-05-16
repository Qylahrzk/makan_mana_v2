import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/supabase_service.dart';
import '../../models/favourite_model.dart';
import '../../models/restaurant_model.dart';

part 'favourite_state.dart';

class FavouriteCubit extends Cubit<FavouriteState> {
  final SupabaseService _supabaseService;

  FavouriteCubit(this._supabaseService) : super(FavouriteInitial());

  // ─────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────

  Future<void> loadFavourite(String userId) async {
    log('loadFavourite START — userId=$userId');
    emit(FavouriteLoading());
    try {
      final items = await _supabaseService.getFavourite(userId);
      emit(FavouriteLoaded(items));
      log('loadFavourite SUCCESS — ${items.length} items loaded');
      for (final item in items) {
        log('  → ${item.restaurantName} (id: ${item.id})');
      }
    } catch (e) {
      log('loadFavourite ERROR: $e');
      emit(const FavouriteError('Failed to load favourites.'));
    }
  }

  // Overloaded for backward compatibility with old naming
  Future<void> loadWishlist(String userId) async {
    return loadFavourite(userId);
  }

  // ─────────────────────────────────────────
  // ADD
  // ─────────────────────────────────────────

  Future<void> addToFavourite({
    required String userId,
    required Restaurant restaurant,
  }) async {
    log('addToFavourite START — ${restaurant.name}, userId=$userId');
    try {
      await _supabaseService.addToFavourite(
        userId: userId,
        restaurant: restaurant,
      );
      log('addToFavourite — Supabase insert SUCCESS');
      final items = await _supabaseService.getFavourite(userId);
      log('addToFavourite — fetched ${items.length} items after insert');
      emit(FavouriteLoaded(items));
      log(
        'addToFavourite — emitted FavouriteLoaded with ${items.length} items',
      );
    } catch (e) {
      log('addToFavourite ERROR: $e');
      final current = state;
      final msg = e.toString().replaceAll('Exception: ', '');
      emit(FavouriteError(msg));
      if (current is FavouriteLoaded) emit(current);
    }
  }

  // Overloaded for backward compatibility
  Future<void> addToWishlist({
    required String userId,
    required Restaurant restaurant,
  }) async {
    return addToFavourite(userId: userId, restaurant: restaurant);
  }

  // ─────────────────────────────────────────
  // REMOVE (optimistic)
  // ─────────────────────────────────────────

  Future<void> removeFromFavourite({
    required String userId,
    required String favouriteId,
  }) async {
    log('removeFromFavourite START — favouriteId=$favouriteId');
    final current = state;
    if (current is FavouriteLoaded) {
      emit(
        FavouriteLoaded(
          current.items.where((i) => i.id != favouriteId).toList(),
        ),
      );
      log('removeFromFavourite — optimistic remove applied');
    }
    try {
      await _supabaseService.removeFromFavourite(favouriteId);
      log('removeFromFavourite SUCCESS — $favouriteId');
    } catch (e) {
      log('removeFromFavourite ERROR: $e');
      await loadFavourite(userId);
      emit(const FavouriteError('Failed to remove. Please try again.'));
    }
  }

  // Overloaded for backward compatibility
  Future<void> removeFromWishlist({
    required String userId,
    required String wishlistId,
  }) async {
    return removeFromFavourite(userId: userId, favouriteId: wishlistId);
  }

  // ─────────────────────────────────────────
  // TOGGLE
  // ─────────────────────────────────────────

  Future<void> toggleFavourite({
    required String userId,
    required Restaurant restaurant,
  }) async {
    log(
      'toggleFavourite START — userId=$userId, restaurant=${restaurant.name}',
    );
    log('toggleFavourite — current state: ${state.runtimeType}');

    // Load favourite first if not loaded
    if (state is! FavouriteLoaded) {
      log('toggleFavourite — state not loaded, loading favourite first...');
      await loadFavourite(userId);
      log('toggleFavourite — after load, state: ${state.runtimeType}');
      if (state is FavouriteLoaded) {
        log(
          'toggleFavourite — loaded ${(state as FavouriteLoaded).items.length} items',
        );
      }
    }

    log('toggleFavourite — checking if already saved...');
    final existingId = await _supabaseService.getFavouriteEntryId(
      userId: userId,
      restaurantName: restaurant.name,
    );
    log('toggleFavourite — existingId=$existingId');

    if (existingId != null) {
      log('toggleFavourite — REMOVING from favourite');
      await removeFromFavourite(userId: userId, favouriteId: existingId);
    } else {
      log('toggleFavourite — ADDING to favourite');
      await addToFavourite(userId: userId, restaurant: restaurant);
    }

    // Force reload after toggle to confirm persistence
    log('toggleFavourite — reloading favourite after toggle...');
    await loadFavourite(userId);
    log('toggleFavourite COMPLETE — final state: ${state.runtimeType}');
    if (state is FavouriteLoaded) {
      log(
        'toggleFavourite — final items count: ${(state as FavouriteLoaded).items.length}',
      );
      for (final item in (state as FavouriteLoaded).items) {
        log('  → ${item.restaurantName}');
      }
    }
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  bool isSaved(String restaurantName) {
    final current = state;
    if (current is FavouriteLoaded) {
      final saved = current.items.any(
        (i) => i.restaurantName == restaurantName,
      );
      log(
        'isSaved($restaurantName) = $saved — ${current.items.length} items in state',
      );
      return saved;
    }
    log('isSaved($restaurantName) = false — state is ${state.runtimeType}');
    return false;
  }

  String? getFavouriteId(String restaurantName) {
    final current = state;
    if (current is FavouriteLoaded) {
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
