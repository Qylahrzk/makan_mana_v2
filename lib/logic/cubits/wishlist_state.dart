part of 'wishlist_cubit.dart';

abstract class WishlistState {
  const WishlistState();
}

/// No wishlist loaded yet.
class WishlistInitial extends WishlistState {}

/// Fetching wishlist from Supabase.
class WishlistLoading extends WishlistState {}

/// Wishlist loaded successfully.
class WishlistLoaded extends WishlistState {
  final List<WishlistModel> items;

  const WishlistLoaded(this.items);

  /// O(1) lookup — is this restaurant saved?
  bool isSaved(String restaurantName) =>
      items.any((i) => i.restaurantName == restaurantName);
}

/// An operation failed.
class WishlistError extends WishlistState {
  final String message;
  const WishlistError(this.message);
}