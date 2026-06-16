// ============================================================
// FILE: lib/presentation/screens/restaurant_detail_screen.dart
//
// CHANGES FROM OLD VERSION (document 11):
//
//   1. StatefulWidget → StatelessWidget split
//      · RestaurantDetailScreen is now a thin StatelessWidget that
//        creates the BlocProvider and passes data down.
//      · All UI lives in _RestaurantDetailView (StatelessWidget).
//      · Zero setState() calls anywhere in this file.
//
//   2. Compass no longer rebuilds the whole screen
//      · Old: setState() fired 10x/sec on every compass tick,
//        rebuilding hero image, stat chips, vibe card, everything.
//      · New: _CompassWidget uses BlocBuilder with buildWhen: so
//        ONLY the compass arrow repaints on each heading event.
//
//   3. Similar restaurants moved to cubit
//      · Old: _SimilarRestaurantsSection was a StatefulWidget with
//        its own initState + setState + _loading bool.
//      · New: reads RestaurantDetailSimilarLoading/Loaded/Error
//        states from the cubit. No local state at all.
//
//   4. Vibe section hidden for 'No Reviews' restaurants
//      · hasVibe guard prevents the empty vibe card from rendering
//        for the 193 restaurants with no review data.
//
//   5. Delivery buttons added
//      · 'Order Delivery' button opens a bottom sheet with
//        GrabFood and FoodPanda deep-link search URLs.
//
//   6. Similar restaurants capped at 50 km
//      · Handled inside RestaurantDetailCubit.loadSimilar().
//      · Empty state says "No similar restaurants found nearby".
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_utils.dart';
import '../../core/restaurant_image.dart';
import '../../core/guest_guard.dart';
import '../../data/restaurant_repository.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/favourite_cubit.dart';
import '../../logic/cubits/restaurant_detail_cubit.dart';
import '../../models/restaurant_model.dart';

// ─── Public entry point ───────────────────────────────────────────────────────
// Creates the cubit, starts compass, and triggers similar restaurant loading.
// Kept as a StatelessWidget — the cubit owns all mutable state.

class RestaurantDetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  final double userLat;
  final double userLon;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
    this.userLat = 5.3302,
    this.userLon = 103.1408,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RestaurantDetailCubit(context.read<RestaurantRepository>())
            ..startCompass()
            ..loadSimilar(restaurant, userLat, userLon),
      child: _RestaurantDetailView(
        restaurant: restaurant,
        userLat: userLat,
        userLon: userLon,
      ),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────
// Pure layout — no setState, no streams, no async calls.
// All state comes from cubits via BlocBuilder.

class _RestaurantDetailView extends StatelessWidget {
  final Restaurant restaurant;
  final double userLat;
  final double userLon;

  static const double _heroHeight = 280.0;
  static const double _curveHeight = 56.0;

  const _RestaurantDetailView({
    required this.restaurant,
    required this.userLat,
    required this.userLon,
  });

  double get _distance => AppUtils.calculateDistance(
    userLat,
    userLon,
    restaurant.lat ?? userLat,
    restaurant.lon ?? userLon,
  );

  // ── Share ──────────────────────────────────────────────────────────────────

  void _shareRestaurant() {
    final r = restaurant;
    final buffer = StringBuffer();
    buffer.writeln('🍽️ *${r.name}*');
    buffer.writeln('📍 ${r.municipality}, Terengganu');
    buffer.writeln('🍴 ${r.cuisineType}');
    buffer.writeln('⭐ ${AppUtils.formatRating(r.rating)} — ${r.ratingBand}');
    if (r.address.isNotEmpty) buffer.writeln('🗺️ ${r.address}');
    if (r.lat != null && r.lon != null) {
      buffer.writeln('📌 https://maps.google.com/?q=${r.lat},${r.lon}');
    }
    buffer.writeln('\nFound on Makan Mana 🇲🇾');
    Share.share(buffer.toString(), subject: r.name);
  }

  // ── Directions ─────────────────────────────────────────────────────────────

  Future<void> _openGoogleMaps(BuildContext context) async {
    final lat = restaurant.lat;
    final lon = restaurant.lon;
    if (lat == null || lon == null) {
      _showNoCoordSnack(context);
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      _showNoCoordSnack(context);
    }
  }

  Future<void> _openWaze(BuildContext context) async {
    final lat = restaurant.lat;
    final lon = restaurant.lon;
    if (lat == null || lon == null) {
      _showNoCoordSnack(context);
      return;
    }
    final uri = Uri.parse('waze://?ll=$lat,$lon&navigate=yes');
    final fallback = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      _showNoCoordSnack(context);
    }
  }

  void _showNoCoordSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No coordinates available for this restaurant.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDirectionsSheet(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomSafe),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(context),
            Text(
              'Get Directions',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              restaurant.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            _sheetBtn(
              context,
              icon: Icons.map_rounded,
              label: 'Open in Google Maps',
              color: const Color(0xFF4285F4),
              onTap: () {
                Navigator.pop(context);
                _openGoogleMaps(context);
              },
            ),
            const SizedBox(height: 12),
            _sheetBtn(
              context,
              icon: Icons.navigation_rounded,
              label: 'Open in Waze',
              color: const Color(0xFF33CCFF),
              onTap: () {
                Navigator.pop(context);
                _openWaze(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Delivery ───────────────────────────────────────────────────────────────

  Future<void> _openGrabFood(BuildContext context) async {
    final name = Uri.encodeComponent(restaurant.name);
    final uri = Uri.parse(
      'https://food.grab.com/my/en/search?searchKeyword=$name',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open GrabFood.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openFoodPanda(BuildContext context) async {
    final name = Uri.encodeComponent(restaurant.name);
    final uri = Uri.parse(
      'https://www.foodpanda.my/city/kuala-terengganu?q=$name',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open FoodPanda.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeliverySheet(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomSafe),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(context),
            Text(
              'Order Delivery',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search "${restaurant.name}" on your preferred platform',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            _sheetBtn(
              context,
              icon: Icons.delivery_dining_rounded,
              label: 'Search on GrabFood',
              color: const Color(0xFF00B14F),
              onTap: () {
                Navigator.pop(context);
                _openGrabFood(context);
              },
            ),
            const SizedBox(height: 12),
            _sheetBtn(
              context,
              icon: Icons.fastfood_rounded,
              label: 'Search on FoodPanda',
              color: const Color(0xFFD70F64),
              onTap: () {
                Navigator.pop(context);
                _openFoodPanda(context);
              },
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ Availability depends on the platform. Results may vary.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared sheet helpers ───────────────────────────────────────────────────

  Widget _sheetHandle(BuildContext context) => Container(
    width: 44,
    height: 4,
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
    ),
  );

  Widget _sheetBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            color: color.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
  );

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final attrs = r.activeAttributes;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    // Only show Vibe section when restaurant has real review data.
    // 193 restaurants have topicLabel == 'No Reviews' — hide cleanly.
    final hasVibe = r.topicLabel.isNotEmpty && r.topicLabel != 'No Reviews';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HERO ──────────────────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: _heroHeight,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: RestaurantImage.getUrl(
                        r.cuisineType,
                        seed: r.id,
                      ),
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _heroGradient(),
                      errorWidget: (_, _, _) => _heroGradient(),
                    ),
                  ),

                  // Back + share + favourite buttons
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _floatingIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            _floatingIconButton(
                              icon: Icons.share_rounded,
                              onTap: _shareRestaurant,
                            ),
                            const SizedBox(width: 10),
                            BlocBuilder<FavouriteCubit, FavouriteState>(
                              builder: (context, state) {
                                final saved = state is FavouriteLoaded
                                    ? state.isSaved(restaurant.name)
                                    : false;
                                return _floatingIconButton(
                                  icon: saved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  iconColor: saved
                                      ? AppColors.favourite
                                      : Colors.black87,
                                  onTap: () => GuestGuard.check(
                                    context,
                                    featureName:
                                        'save restaurants to your favourites',
                                    onAllowed: () {
                                      final user = context
                                          .read<AuthCubit>()
                                          .currentUser;
                                      if (user == null) return;
                                      context
                                          .read<FavouriteCubit>()
                                          .toggleFavourite(
                                            userId: user.id,
                                            restaurant: restaurant,
                                          );
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              saved
                                                  ? 'Removed from favourites'
                                                  : '❤️ Saved to favourites',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            margin: const EdgeInsets.all(16),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Curved white transition at bottom of hero
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, _curveHeight),
                      painter: _WhiteTopCurvePainter(color: scaffoldBg),
                    ),
                  ),
                ],
              ),

              // ── CONTENT ───────────────────────────────────────────
              Container(
                color: scaffoldBg,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        r.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Location + distance row
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            r.municipality,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.near_me_rounded,
                            size: 13,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_distance.toStringAsFixed(1)} km away',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Stat chips
                      Row(
                        children: [
                          _statChip(
                            context,
                            icon: Icons.star_rounded,
                            iconColor: AppColors.star,
                            value: AppUtils.formatRating(r.rating),
                            label: r.ratingBand.isNotEmpty
                                ? r.ratingBand
                                : 'Rating',
                          ),
                          const SizedBox(width: 10),
                          _statChip(
                            context,
                            icon: Icons.access_time_rounded,
                            iconColor: AppColors.secondary,
                            value: '~${(_distance * 3).round()} min',
                            label: 'Drive time',
                          ),
                          const SizedBox(width: 10),
                          _statChip(
                            context,
                            icon: Icons.category_rounded,
                            iconColor: AppColors.primary,
                            value: r.categories.isNotEmpty
                                ? r.categories
                                : 'Restaurant',
                            label: 'Category',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Price level
                      if (r.priceLevel != null) ...[
                        _buildPriceLevelCard(context, r.priceLevel!),
                        const SizedBox(height: 14),
                      ],

                      // Compass — only _CompassWidget rebuilds on heading events.
                      // The rest of this Column is completely unaffected.
                      _CompassWidget(
                        userLat: userLat,
                        userLon: userLon,
                        restaurant: restaurant,
                        distance: _distance,
                      ),

                      // Feature badges
                      if (attrs.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionTitle(context, 'Features'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attrs
                              .map((a) => _attributeBadge(context, a))
                              .toList(),
                        ),
                      ],

                      // Vibe — hidden for 'No Reviews' restaurants
                      if (hasVibe) ...[
                        const SizedBox(height: 20),
                        _sectionTitle(context, 'The Vibe'),
                        const SizedBox(height: 10),
                        _vibeCard(context, r),
                      ],

                      const SizedBox(height: 20),
                      _sectionTitle(context, 'Restaurant Details'),
                      const SizedBox(height: 10),
                      _detailsCard(context, r),

                      if (r.address.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionTitle(context, 'Address'),
                        const SizedBox(height: 10),
                        _addressCard(context, r),
                      ],

                      const SizedBox(height: 20),
                      _sectionTitle(context, 'Similar Restaurants'),
                      const SizedBox(height: 10),

                      // Similar section reads from cubit — no local setState
                      _SimilarRestaurantsSection(
                        restaurant: restaurant,
                        userLat: userLat,
                        userLon: userLon,
                      ),
                      const SizedBox(height: 24),

                      // Action row 1 — Directions + Share
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(
                                  Icons.directions_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Directions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                onPressed: () => _showDirectionsSheet(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.secondary,
                                  side: BorderSide(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: const Text(
                                  'Share',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                onPressed: _shareRestaurant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Action row 2 — Order Delivery
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00B14F),
                            side: BorderSide(
                              color: const Color(
                                0xFF00B14F,
                              ).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.delivery_dining_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Order Delivery',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: () => _showDeliverySheet(context),
                        ),
                      ),

                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _heroGradient() => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: AppColors.oceanGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );

  Widget _floatingIconButton({
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: iconColor ?? const Color(0xFF3A2F2F)),
    ),
  );

  Widget _statChip(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildPriceLevelCard(BuildContext context, int level) {
    final info = _priceInfo(level);
    if (info == null) return const SizedBox.shrink();
    final (label, desc, color) = info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(
              4,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: i < level ? color : color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, String, Color)? _priceInfo(int level) => switch (level) {
    1 => ('Budget', '< RM15 per person', const Color(0xFF16A34A)),
    2 => ('Moderate', 'RM15 – RM40 per person', const Color(0xFF2563EB)),
    3 => ('Upscale', 'RM40 – RM100 per person', const Color(0xFFD97706)),
    4 => ('Fine Dining', 'RM100+ per person', const Color(0xFFDC2626)),
    _ => null,
  };

  Widget _attributeBadge(BuildContext context, String label) {
    const icons = <String, IconData>{
      'Halal': Icons.verified_rounded,
      'Vegetarian': Icons.eco_rounded,
      'Vegan': Icons.grass_rounded,
      'Family Friendly': Icons.family_restroom_rounded,
      'Romantic': Icons.favorite_rounded,
      'Scenic View': Icons.landscape_rounded,
      'Outdoor': Icons.park_rounded,
      'Parking': Icons.local_parking_rounded,
      'WiFi': Icons.wifi_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[label] ?? Icons.check_circle_rounded,
            size: 14,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vibeCard(BuildContext context, Restaurant r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.adaptiveSecondary(context).withValues(alpha: 0.08),
            AppColors.adaptiveSecondary(context).withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.adaptiveSecondary(context).withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.topicLabel,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on customer reviews',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
          _topicBar(context, 'Food Quality', r.topic1Pct, AppColors.primary),
          const SizedBox(height: 8),
          _topicBar(context, 'Ambience', r.topic2Pct, AppColors.secondary),
          const SizedBox(height: 8),
          _topicBar(context, 'Service', r.topic3Pct, AppColors.tertiary),
        ],
      ),
    );
  }

  Widget _topicBar(
    BuildContext context,
    String label,
    double pct,
    Color color,
  ) => Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );

  Widget _detailsCard(BuildContext context, Restaurant r) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _detailRow(
            context,
            icon: Icons.storefront_rounded,
            label: 'Category',
            value: r.categories,
          ),
          _divider(context),
          _detailRow(
            context,
            icon: Icons.restaurant_menu_rounded,
            label: 'Cuisine',
            value: r.cuisineType,
          ),
          _divider(context),
          _detailRow(
            context,
            icon: Icons.place_rounded,
            label: 'Area',
            value: r.municipality,
          ),
          if (r.lat != null && r.lon != null) ...[
            _divider(context),
            _detailRow(
              context,
              icon: Icons.my_location_rounded,
              label: 'Coordinates',
              value:
                  '${r.lat!.toStringAsFixed(4)}, ${r.lon!.toStringAsFixed(4)}',
              onTap: () {
                Clipboard.setData(ClipboardData(text: '${r.lat}, ${r.lon}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Coordinates copied to clipboard'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.copy_rounded,
              size: 15,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
        ],
      ),
    ),
  );

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    indent: 64,
    endIndent: 16,
    color: Theme.of(context).colorScheme.surfaceContainer,
  );

  Widget _addressCard(BuildContext context, Restaurant r) => GestureDetector(
    onTap: () {
      Clipboard.setData(ClipboardData(text: r.address));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Address copied to clipboard'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              r.address,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.copy_rounded,
            size: 15,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(BuildContext context, String t) => Text(
    t,
    style: AppTextStyles.titleSmall.copyWith(
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

// ─── Compass Widget ────────────────────────────────────────────────────────────
//
// Standalone StatelessWidget. Rebuilds ONLY when the cubit emits
// RestaurantDetailCompassUpdated — never on similar loading events.
// The parent screen Column stays completely still during compass ticks.

class _CompassWidget extends StatelessWidget {
  final double userLat;
  final double userLon;
  final Restaurant restaurant;
  final double distance;

  const _CompassWidget({
    required this.userLat,
    required this.userLon,
    required this.restaurant,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RestaurantDetailCubit, RestaurantDetailState>(
      // KEY: only rebuild this widget when the compass heading changes.
      // Similar loading states are ignored here entirely.
      buildWhen: (_, current) =>
          current is RestaurantDetailCompassUpdated ||
          current is RestaurantDetailInitial,
      builder: (context, state) {
        // Don't render until the device sends a valid heading
        if (state is! RestaurantDetailCompassUpdated) {
          return const SizedBox.shrink();
        }
        // Don't render if the restaurant has no GPS coordinates
        if (restaurant.lat == null || restaurant.lon == null) {
          return const SizedBox.shrink();
        }

        final heading = state.heading;
        final bearing = RestaurantDetailCubit.bearingTo(
          userLat,
          userLon,
          restaurant.lat!,
          restaurant.lon!,
        );
        final relative = (bearing - heading + 360) % 360;
        final direction = RestaurantDetailCubit.directionLabel(relative);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Transform.rotate(
                  angle: relative * pi / 180,
                  child: Icon(
                    Icons.navigation_rounded,
                    color: AppColors.secondary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Head $direction',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${distance.toStringAsFixed(1)} km to this restaurant',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${relative.toStringAsFixed(0)}°',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Similar Restaurants Section ──────────────────────────────────────────────
//
// Now a StatelessWidget that reads from RestaurantDetailCubit.
// No initState, no setState, no _loading bool — all state lives in the cubit.

class _SimilarRestaurantsSection extends StatelessWidget {
  final Restaurant restaurant;
  final double userLat;
  final double userLon;

  const _SimilarRestaurantsSection({
    required this.restaurant,
    required this.userLat,
    required this.userLon,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RestaurantDetailCubit, RestaurantDetailState>(
      // Only rebuild when similar loading state changes — never on compass ticks
      buildWhen: (_, current) =>
          current is RestaurantDetailSimilarLoading ||
          current is RestaurantDetailSimilarLoaded ||
          current is RestaurantDetailSimilarError,
      builder: (context, state) {
        if (state is RestaurantDetailSimilarLoading) {
          return const SizedBox(
            height: 160,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        }

        if (state is RestaurantDetailSimilarError ||
            (state is RestaurantDetailSimilarLoaded && state.similar.isEmpty)) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No similar restaurants found nearby',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          );
        }

        if (state is! RestaurantDetailSimilarLoaded) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: state.similar.length,
            itemBuilder: (_, i) => _SimilarCard(
              restaurant: state.similar[i],
              userLat: userLat,
              userLon: userLon,
            ),
          ),
        );
      },
    );
  }
}

// ─── Similar Card ──────────────────────────────────────────────────────────────

class _SimilarCard extends StatelessWidget {
  final Restaurant restaurant;
  final double userLat;
  final double userLon;

  const _SimilarCard({
    required this.restaurant,
    required this.userLat,
    required this.userLon,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final km = AppUtils.calculateDistance(
      userLat,
      userLon,
      r.lat ?? userLat,
      r.lon ?? userLon,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(
            restaurant: r,
            userLat: userLat,
            userLon: userLon,
          ),
        ),
      ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              child: CachedNetworkImage(
                imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
                width: 90,
                height: 170,
                fit: BoxFit.cover,
                placeholder: (_, _) => _imgPlaceholder(context),
                errorWidget: (_, _, _) => _imgPlaceholder(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      r.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.cuisineType,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          AppUtils.formatRating(r.rating),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.near_me_rounded,
                          size: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${km.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
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

  Widget _imgPlaceholder(BuildContext context) => Container(
    width: 90,
    height: 170,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.18),
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Icon(
      Icons.restaurant_rounded,
      color: AppColors.adaptiveSecondary(context).withValues(alpha: 0.5),
      size: 26,
    ),
  );
}

// ─── Wave Painter ──────────────────────────────────────────────────────────────

class _WhiteTopCurvePainter extends CustomPainter {
  const _WhiteTopCurvePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final dy in const [0.0, 1.5, -1.5]) {
      final path = Path()
        ..moveTo(0, size.height)
        ..lineTo(0, size.height * 0.55 + dy)
        ..cubicTo(
          size.width * 0.20,
          size.height * 0.55 + dy - 6,
          size.width * 0.80,
          size.height * 0.55 + dy - 6,
          size.width,
          size.height * 0.55 + dy,
        )
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WhiteTopCurvePainter old) => old.color != color;
}
