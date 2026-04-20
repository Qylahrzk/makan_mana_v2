// ============================================================
// FILE: lib/presentation/screens/wishlist_screen.dart
//
// FIX — Pull-to-refresh now forces a real network reload:
//
// BEFORE (broken):
//   _loadWishlist() just called cubit.loadWishlist(userId).
//   WishlistCubit.loadWishlist() fetched from Supabase, but the
//   RefreshIndicator completed as soon as the cubit emitted
//   WishlistLoading — it did NOT wait for the data to arrive,
//   so the spinner disappeared before new items showed.
//
// AFTER (fixed):
//   _refresh() is a separate async method that:
//     1. Calls cubit.loadWishlist(userId) — triggers network fetch
//     2. Awaits a Future that resolves only when the cubit emits
//        WishlistLoaded or WishlistError (not Loading).
//   This keeps the pull-to-refresh spinner alive until data is
//   actually back on screen, giving the user correct feedback.
//
// Also kept: swipe-to-dismiss, full data lookup for detail screen,
// empty state with Explore button, error state with retry.
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
import '../../logic/cubits/wishlist_cubit.dart';
import '../../models/wishlist_model.dart';
import 'restaurant_detail_screen.dart';
import '../../models/restaurant_model.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  @override
  void initState() {
    super.initState();
    // Initial load on screen open — no need to await here.
    _loadWishlist();
  }

  // ── Initial load ──────────────────────────────────────────────────────────
  // Called once on initState. Does not need to wait for completion.
  Future<void> _loadWishlist() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user != null) {
      context.read<WishlistCubit>().loadWishlist(user.id);
    }
  }

  // ── Pull-to-refresh handler ───────────────────────────────────────────────
  // This is passed to RefreshIndicator.onRefresh.
  //
  // The key difference from _loadWishlist: this method AWAITS the cubit
  // until it emits a non-loading state (WishlistLoaded or WishlistError).
  // RefreshIndicator keeps the spinner visible until this Future resolves,
  // so the user sees the spinner for the full duration of the network call.
  Future<void> _refresh() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    // Kick off the network fetch
    context.read<WishlistCubit>().loadWishlist(user.id);

    // Wait until cubit is no longer in a Loading state.
    // We poll via a completer that listens to the stream.
    final completer = Completer<void>();
    late StreamSubscription sub;
    sub = context.read<WishlistCubit>().stream.listen((state) {
      if (state is WishlistLoaded || state is WishlistError) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      }
    });

    // Safety timeout — if network takes longer than 10 s, stop spinner anyway.
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
      },
    );
  }

  // ── Remove item ───────────────────────────────────────────────────────────
  // Called by swipe-to-dismiss and the Dismissible onDismissed callback.
  void _remove(WishlistModel item) {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;
    context.read<WishlistCubit>().removeFromWishlist(
      userId:     user.id,
      wishlistId: item.id,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:  Text('${item.restaurantName} removed from wishlist'),
        behavior: SnackBarBehavior.floating,
        shape:    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin:   const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
  }

  // ── Open detail screen ────────────────────────────────────────────────────
  // Fetches the full restaurant record from the repository cache so the
  // detail screen has real LDA topic data (topic percentages, vibe card etc.).
  // Falls back to reconstructing a Restaurant from the WishlistModel fields
  // if the restaurant no longer exists in the main dataset.
  Future<void> _openDetail(WishlistModel item) async {
    // Show spinner while we wait for the repo fetch
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final repo = context.read<RestaurantRepository>();
      final all  = await repo.getAllRestaurants();

      // Case-insensitive name match
      final match = all.firstWhere(
        (r) => r.name.trim().toLowerCase() ==
            item.restaurantName.trim().toLowerCase(),
        orElse: () => _fallbackRestaurant(item),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss spinner

      Navigator.push(context, MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: match),
      ));
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:  const Text(
            'Could not load restaurant details. Please try again.'),
        behavior: SnackBarBehavior.floating,
        shape:    RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin:   const EdgeInsets.all(16),
      ));
    }
  }

  // ── Fallback restaurant ───────────────────────────────────────────────────
  // Reconstructs a minimal Restaurant from WishlistModel fields when the
  // restaurant can no longer be found in the main dataset (e.g. deleted).
  Restaurant _fallbackRestaurant(WishlistModel item) {
    return Restaurant(
      id:               0,
      name:             item.restaurantName,
      address:          item.address,
      municipality:     item.municipality,
      categories:       item.categories,
      cuisineTypes:     item.cuisineTypes,
      rating:           item.rating,
      ratingBand:       item.ratingBand,
      topicLabel:       item.topicLabel,
      coordinateSource: '',
      isHalal:          item.isHalal,
      isVegetarian:     item.isVegetarian,
      isVegan:          item.isVegan,
      hasParking:       item.hasParking,
      hasWifi:          item.hasWifi,
      hasAc:            false,          // NEW — not stored in wishlists
      hasOutdoor:       item.hasOutdoor,
      isAccessible:     false,          // NEW — not stored in wishlists
      isFamilyFriendly: item.isFamilyFriendly,
      isGroupFriendly:  false,          // NEW — not stored in wishlists
      isCasual:         false,          // NEW — not stored in wishlists
      isRomantic:       item.isRomantic,
      hasScenicView:    item.hasScenicView,
      isWorthIt:        false,          // NEW — not stored in wishlists
      isFastService:    false,          // NEW — not stored in wishlists
      dominantTopic:    item.dominantTopic,
      topic1Pct:        0,
      topic2Pct:        0,
      topic3Pct:        0,
      lat:              item.lat,
      lon:              item.lon,
      priceLevel:       item.priceLevel,
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [

          // ── Header ────────────────────────────────────────────────────────
          // Shows the page title and a count badge showing number of saved items.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color:        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset:     const Offset(0, 2),
                    )],
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size:  18,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: 16),

              // Title
              Expanded(
                child: Text('My Wishlist',
                    style: TextStyle(
                      fontSize:      24,
                      fontWeight:    FontWeight.w900,
                      color:         Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    )),
              ),

              // Count badge — only shown when list is loaded and non-empty
              BlocBuilder<WishlistCubit, WishlistState>(
                builder: (context, state) {
                  if (state is! WishlistLoaded) return const SizedBox();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${state.items.length}',
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w800,
                          color:      AppColors.primary,
                        )),
                  );
                },
              ),
            ]),
          ),

          const SizedBox(height: 8),

          // ── Swipe hint ────────────────────────────────────────────────────
          // Only shown when list has items — tells user they can swipe to remove.
          BlocBuilder<WishlistCubit, WishlistState>(
            builder: (context, state) {
              if (state is! WishlistLoaded || state.items.isEmpty) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 4),
                child: Row(children: [
                  Icon(Icons.swipe_left_rounded,
                      size:  14,
                      color: Theme.of(context)
                          .colorScheme.onSurface.withValues(alpha: 0.45)),
                  const SizedBox(width: 4),
                  Text('Swipe left to remove',
                      style: TextStyle(
                          fontSize: 12,
                          color:    Theme.of(context)
                              .colorScheme.onSurface.withValues(alpha: 0.45))),
                ]),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── Main content area ─────────────────────────────────────────────
          // Handles all BLoC states: loading, error, empty, loaded.
          Expanded(
            child: BlocBuilder<WishlistCubit, WishlistState>(
              builder: (context, state) {

                // Loading skeleton spinner
                if (state is WishlistLoading) {
                  return Center(child: CircularProgressIndicator(
                      color: AppColors.primary));
                }

                // Network / server error
                if (state is WishlistError) {
                  return _ErrorState(
                      message: state.message, onRetry: _loadWishlist);
                }

                // Empty wishlist state — shows illustration + Explore button
                if (state is WishlistLoaded && state.items.isEmpty) {
                  return const _EmptyState();
                }

                // Loaded list — wrapped in RefreshIndicator for pull-to-refresh.
                // _refresh() awaits until data is back before completing,
                // so the spinner stays visible for the full network roundtrip.
                if (state is WishlistLoaded) {
                  return RefreshIndicator(
                    onRefresh: _refresh,         // ← uses the awaitable version
                    color:     AppColors.primary,
                    child: ListView.builder(
                      physics:   const AlwaysScrollableScrollPhysics(),
                      padding:   const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: state.items.length,
                      itemBuilder: (_, i) => _WishlistCard(
                        item:     state.items[i],
                        onTap:    () => _openDetail(state.items[i]),
                        onRemove: () => _remove(state.items[i]),
                      ),
                    ),
                  );
                }

                return const SizedBox();
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Wishlist Card ────────────────────────────────────────────────────────────
//
// Each saved restaurant row. Features:
//   - Swipe left (Dismissible) to remove
//   - Tap to open full detail screen with spinner
//   - Shows: thumbnail, name, location, cuisine types, topic label,
//     attribute chips (Halal, Parking etc.), rating, saved date
// ─────────────────────────────────────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  final WishlistModel item;
  final VoidCallback  onTap;
  final VoidCallback  onRemove;

  const _WishlistCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  // Gradient fallback shown while the real image loads or if it fails
  Widget _thumbnailFallback(BuildContext context) => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.15),
          AppColors.secondary.withValues(alpha: 0.1),
        ],
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14)),
    child: Icon(Icons.restaurant_rounded,
        color: AppColors.primary.withValues(alpha: 0.7), size: 24),
  );

  @override
  Widget build(BuildContext context) {
    final attrs = item.activeAttributes;

    return Dismissible(
      // Use item.id as unique key so Flutter tracks each card correctly
      key:       Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),

      // Red delete background shown as card slides away
      background: Container(
        margin:    const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color:        AppColors.error,
          borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.centerRight,
        padding:   const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded,
                color: Theme.of(context).colorScheme.surface, size: 24),
            const SizedBox(height: 4),
            Text('Remove',
                style: TextStyle(
                    color:      Theme.of(context).colorScheme.surface,
                    fontSize:   11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),

      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color:        Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color:      Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset:     const Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ── Restaurant thumbnail image ─────────────────────────────
                // Uses cuisineType string to pick a relevant food photo.
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: RestaurantImage.getUrl(
                      item.cuisineType,          // primary cuisine for image lookup
                      seed: item.id.hashCode,    // consistent image per restaurant
                    ),
                    width:          72,
                    height:         72,
                    fit:            BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    placeholder:    (_, _) => _thumbnailFallback(context),
                    errorWidget:    (_, _, _) => _thumbnailFallback(context),
                  ),
                ),

                const SizedBox(width: 14),

                // ── Restaurant info column ────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Restaurant name
                      Text(item.restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                            color:      Theme.of(context).colorScheme.onSurface,
                          )),
                      const SizedBox(height: 3),

                      // Location
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            size: 11, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(item.municipality,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:   12,
                                color:      AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                      ]),
                      const SizedBox(height: 4),

                      // Cuisine types — joined with · separator
                      if (item.cuisineTypes.isNotEmpty)
                        Text(
                          item.cuisineTypes.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize:   11,
                            color:      Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                      const SizedBox(height: 5),

                      // LDA topic label badge (e.g. "Spicy & Bold Flavours")
                      if (item.topicLabel.isNotEmpty &&
                          item.topicLabel != 'No Reviews')
                        Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:  AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.15)),
                          ),
                          child: Text('🍽️ ${item.topicLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize:   9,
                                  color:      AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),

                      // Attribute chips (Halal, Parking, WiFi etc.) — max 2 shown
                      if (attrs.isNotEmpty)
                        Wrap(
                          spacing: 4, runSpacing: 3,
                          children: attrs.take(2).map((a) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:        AppColors.secondary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6)),
                            child: Text(a,
                                style: const TextStyle(
                                    fontSize:   9,
                                    color:      Color(0xFF2F6F7E),
                                    fontWeight: FontWeight.w600)),
                          )).toList()),

                      const SizedBox(height: 6),

                      // Rating + saved date row
                      Row(children: [
                        Icon(Icons.star_rounded,
                            size: 13, color: AppColors.star),
                        const SizedBox(width: 3),
                        Text(AppUtils.formatRating(item.rating),
                            style: TextStyle(
                              fontSize:   12,
                              fontWeight: FontWeight.w700,
                              color:      Theme.of(context).colorScheme.onSurface,
                            )),
                        const SizedBox(width: 10),

                        // Saved date — shows relative ("Today", "3 days ago")
                        // or absolute (DD/MM/YYYY) for older items
                        if (item.createdAt != null) ...[
                          Icon(Icons.bookmark_rounded,
                              size:  12,
                              color: Theme.of(context)
                                  .colorScheme.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 3),
                          Text(_formatDate(item.createdAt!),
                              style: TextStyle(
                                  fontSize: 11,
                                  color:    Theme.of(context)
                                      .colorScheme.onSurface
                                      .withValues(alpha: 0.4))),
                        ],
                      ]),
                    ],
                  ),
                ),

                // ── Chevron ───────────────────────────────────────────────
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: Theme.of(context)
                        .colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Converts DateTime to a human-readable relative label
  String _formatDate(DateTime date) {
    final now  = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
//
// Shown when the user has no saved restaurants yet.
// Includes a button to jump to the Explore/Search tab.
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
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle),
              child: Icon(Icons.favorite_border_rounded,
                  size:  44,
                  color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text('No Saved Restaurants',
                style: TextStyle(
                  fontSize:      20,
                  fontWeight:    FontWeight.w800,
                  color:         Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 8),
            Text(
              'Tap the ❤️ on any restaurant card to save it here for later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:    Theme.of(context)
                    .colorScheme.onSurface.withValues(alpha: 0.5),
                height:   1.6),
            ),
            const SizedBox(height: 28),
            // Button to navigate to the Search/Explore tab
            GestureDetector(
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final proxy =
                      context.findAncestorStateOfType<NavTabProxy>();
                  proxy?.switchTab(1);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color:        AppColors.primary,
                  borderRadius: BorderRadius.circular(30)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Explore Restaurants',
                        style: TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize:   14)),
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
// Shown when WishlistCubit emits WishlistError (network failure etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String       message;
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
            Icon(Icons.wifi_off_rounded,
                size:  48,
                color: Theme.of(context)
                    .colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color:    Theme.of(context)
                        .colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.6)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color:        AppColors.secondary,
                  borderRadius: BorderRadius.circular(30)),
                child: Text('Try Again',
                    style: TextStyle(
                      color:      Theme.of(context).colorScheme.surface,
                      fontWeight: FontWeight.w700,
                      fontSize:   14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}