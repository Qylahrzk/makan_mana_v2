// ============================================================
// FILE: lib/presentation/screens/favourite_screen.dart
//
// UPDATED FOR FAVOURITES:
//
// Key changes:
// 1. Renamed from Wishlist to Favourite throughout
// 2. Tap heart icon on cards to unfavourite (instead of swipe-to-dismiss)
// 3. Removed bookmark icon, using love/heart icon consistently
// 4. Removed back button (uses navigation bar)
// 5. Added favourite logo image asset for empty state
// 6. Uses consistent restaurant card styling from other screens
// 7. Pull-to-refresh awaits proper network completion
//
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/app_utils.dart';
import '../../core/nav_tab_proxy.dart';
import '../../core/restaurant_image.dart';
import '../../data/restaurant_repository.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/favourite_cubit.dart';
import '../../models/favourite_model.dart';
import 'restaurant_detail_screen.dart';
import '../../models/restaurant_model.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen> {
  @override
  void initState() {
    super.initState();
    // Initial load on screen open
    _loadFavourite();
  }

  // ── Initial load ──────────────────────────────────────────────────────────
  Future<void> _loadFavourite() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user != null) {
      context.read<FavouriteCubit>().loadWishlist(user.id);
    }
  }

  // ── Pull-to-refresh handler ───────────────────────────────────────────────
  // Awaits until the cubit emits a non-loading state (FavouriteLoaded or FavouriteError)
  Future<void> _refresh() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    context.read<FavouriteCubit>().loadWishlist(user.id);

    final completer = Completer<void>();
    late StreamSubscription sub;
    sub = context.read<FavouriteCubit>().stream.listen((state) {
      if (state is FavouriteLoaded || state is FavouriteError) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      }
    });

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
      },
    );
  }

  // ── Remove item ───────────────────────────────────────────────────────────
  void _removeFavourite(FavouriteModel item) {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;
    context.read<FavouriteCubit>().removeFromWishlist(
      userId: user.id,
      wishlistId: item.id,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.restaurantName} removed from favourites'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ── Open detail screen ────────────────────────────────────────────────────
  Future<void> _openDetail(FavouriteModel item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final repo = context.read<RestaurantRepository>();
      final all = await repo.getAllRestaurants();

      final match = all.firstWhere(
        (r) =>
            r.name.trim().toLowerCase() ==
            item.restaurantName.trim().toLowerCase(),
        orElse: () => _fallbackRestaurant(item),
      );

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: match),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not load restaurant details. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Fallback restaurant ───────────────────────────────────────────────────
  Restaurant _fallbackRestaurant(FavouriteModel item) {
    return Restaurant(
      id: 0,
      name: item.restaurantName,
      address: item.address,
      municipality: item.municipality,
      categories: item.categories,
      cuisineTypes: item.cuisineTypes,
      rating: item.rating,
      ratingBand: item.ratingBand,
      topicLabel: item.topicLabel,
      coordinateSource: '',
      isHalal: item.isHalal,
      isVegetarian: item.isVegetarian,
      isVegan: item.isVegan,
      hasParking: item.hasParking,
      hasWifi: item.hasWifi,
      hasAc: false,
      hasOutdoor: item.hasOutdoor,
      isAccessible: false,
      isFamilyFriendly: item.isFamilyFriendly,
      isGroupFriendly: false,
      isCasual: false,
      isRomantic: item.isRomantic,
      hasScenicView: item.hasScenicView,
      isCrowded: item.isCrowded,
      isWorthIt: false,
      isFastService: false,
      dominantTopic: item.dominantTopic,
      topic1Pct: 0,
      topic2Pct: 0,
      topic3Pct: 0,
      lat: item.lat,
      lon: item.lon,
      priceLevel: item.priceLevel,
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  // Title (no back button — using nav bar)
                  Expanded(
                    child: Text(
                      'My Favourites',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // Count badge
                  BlocBuilder<FavouriteCubit, FavouriteState>(
                    builder: (context, state) {
                      if (state is! FavouriteLoaded) return const SizedBox();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.items.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Hint text ─────────────────────────────────────────────────────
            BlocBuilder<FavouriteCubit, FavouriteState>(
              builder: (context, state) {
                if (state is! FavouriteLoaded || state.items.isEmpty) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap the heart to unfavourite',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // ── Main content area ─────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<FavouriteCubit, FavouriteState>(
                builder: (context, state) {
                  if (state is FavouriteLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (state is FavouriteError) {
                    return _ErrorState(
                      message: state.message,
                      onRetry: _loadFavourite,
                    );
                  }

                  if (state is FavouriteLoaded && state.items.isEmpty) {
                    return const _EmptyState();
                  }

                  if (state is FavouriteLoaded) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      color: AppColors.primary,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: state.items.length,
                        itemBuilder: (_, i) => _FavouriteCard(
                          item: state.items[i],
                          onTap: () => _openDetail(state.items[i]),
                          onRemove: () => _removeFavourite(state.items[i]),
                        ),
                      ),
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Favourite Card ───────────────────────────────────────────────────────────
//
// Restaurant card for favourite list. Features:
//   - Tap heart icon to remove from favourites
//   - Tap card to open detail screen
//   - Shows: thumbnail, name, location, cuisine types, topic label,
//     attribute chips (Halal, Parking etc.), rating
// ─────────────────────────────────────────────────────────────────────────────

class _FavouriteCard extends StatelessWidget {
  final FavouriteModel item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavouriteCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  Widget _thumbnailFallback(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.18),
          AppColors.secondary.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(
      Icons.restaurant_rounded,
      color: AppColors.primary.withValues(alpha: 0.7),
      size: 24,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final attrs = item.activeAttributes;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.20
                    : 0.04,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Restaurant thumbnail image ─────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: RestaurantImage.getUrl(
                    item.cuisineType,
                    seed: item.id.hashCode,
                  ),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 300),
                  placeholder: (_, _) => _thumbnailFallback(context),
                  errorWidget: (_, _, _) => _thumbnailFallback(context),
                ),
              ),

              const SizedBox(width: 14),

              // ── Restaurant info column ────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant name
                    Text(
                      item.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            item.municipality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Cuisine types
                    if (item.cuisineTypes.isNotEmpty)
                      Text(
                        item.cuisineTypes.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    const SizedBox(height: 5),

                    // LDA topic label badge
                    if (item.topicLabel.isNotEmpty &&
                        item.topicLabel != 'No Reviews')
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          '🍽️ ${item.topicLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Attribute chips — max 2 shown
                    if (attrs.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: attrs
                            .take(2)
                            .map(
                              (a) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  a,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF2F6F7E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 6),

                    // Rating
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.star,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          AppUtils.formatRating(item.rating),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Favourite heart button ─────────────────────────────────
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
//
// Shown when no favourites are saved.
// Includes image asset and button to explore restaurants.
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Favourite logo image from assets
            Image.asset(
              'assets/images/favourite_logo.png',
              width: 190,
              height: 190,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 3),
            Text(
              'No Saved Favourites',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the ❤️ on any restaurant to save it here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            // Button to navigate to search/explore
            GestureDetector(
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final proxy = context.findAncestorStateOfType<NavTabProxy>();
                  proxy?.switchTab(1);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Explore Restaurants',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────
//
// Shown when loading fails
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Try Again',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
