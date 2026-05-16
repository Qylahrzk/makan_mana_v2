part of 'favourite_cubit.dart';

abstract class FavouriteState {
  const FavouriteState();
}

/// No favourite loaded yet.
class FavouriteInitial extends FavouriteState {}

/// Fetching favourite from Supabase.
class FavouriteLoading extends FavouriteState {}

/// Favourite loaded successfully.
class FavouriteLoaded extends FavouriteState {
  final List<FavouriteModel> items;

  const FavouriteLoaded(this.items);

  /// O(1) lookup — is this restaurant saved?
  bool isSaved(String restaurantName) =>
      items.any((i) => i.restaurantName == restaurantName);
}

/// An operation failed.
class FavouriteError extends FavouriteState {
  final String message;
  const FavouriteError(this.message);
}
