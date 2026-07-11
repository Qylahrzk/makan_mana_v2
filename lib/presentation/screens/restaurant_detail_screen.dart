// ============================================================
// FILE: lib/presentation/screens/restaurant_detail_screen.dart
// ============================================================

import 'dart:math' show pi;
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
import '../widgets/gradient_divider.dart';
import '../widgets/restaurant_card.dart';

// ─── Public entry point ───────────────────────────────────────────────────────

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

// ─── Main view (StatelessWidget) ──────────────────────────────────────────────

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
    SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: r.name),
    );
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
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeroSection(context, scaffoldBg),
          _buildStatChips(context),
          if (restaurant.priceLevel != null) _buildPriceCard(context),
          _buildCompass(context),
          _buildFeatureBadges(context),
          if (restaurant.topicLabel.isNotEmpty &&
              restaurant.topicLabel != 'No Reviews')
            _buildVibeCard(context),
          _buildDetailsCard(context),
          if (restaurant.address.isNotEmpty) _buildAddressCard(context),
          _buildSimilarSection(context),
          _buildActionButtons(context),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ),
        ],
      ),
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────

  Widget _buildHeroSection(BuildContext context, Color curveColor) {
    return SliverAppBar(
      expandedHeight: _heroHeight,
      pinned: false,
      elevation: 0,
      backgroundColor: Colors.black,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      actions: [
        // Share Button
        GestureDetector(
          onTap: () => _shareRestaurant(),
          child: Container(
            margin: const EdgeInsets.all(8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        // Favourite Button
        GestureDetector(
          onTap: () => GuestGuard.check(
            context,
            featureName: 'save restaurants to your favourites',
            onAllowed: () {
              final user = context.read<AuthCubit>().currentUser;
              if (user == null) return;
              final isAlreadySaved = context.read<FavouriteCubit>().isSaved(
                restaurant.name,
              );
              context.read<FavouriteCubit>().toggleFavourite(
                userId: user.id,
                restaurant: restaurant,
              );
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      isAlreadySaved
                          ? 'Removed from favourites'
                          : '❤️ Saved to favourites',
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 1),
                  ),
                );
            },
          ),
          child: Container(
            margin: const EdgeInsets.only(
              top: 8,
              bottom: 8,
              right: 16,
              left: 4,
            ),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: BlocBuilder<FavouriteCubit, FavouriteState>(
              builder: (ctx, state) {
                final isSaved = state is FavouriteLoaded
                    ? state.isSaved(restaurant.name)
                    : ctx.read<FavouriteCubit>().isSaved(restaurant.name);
                return Icon(
                  isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isSaved ? AppColors.favourite : Colors.white,
                  size: 18,
                );
              },
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: RestaurantImage.getUrl(
                restaurant.cuisineType,
                seed: restaurant.id,
              ),
              fit: BoxFit.cover,
              placeholder: (context, url) => _heroGradient(),
              errorWidget: (context, url, error) => _heroGradient(),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                height: 100,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, _curveHeight),
                painter: _WhiteTopCurvePainter(color: curveColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stat Chips ───────────────────────────────────────────────────────

  Widget _buildStatChips(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            Text(
              restaurant.name,
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
            // Location
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: activeSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  restaurant.municipality,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: activeSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.near_me_rounded, size: 13, color: activeSecondary),
                const SizedBox(width: 4),
                Text(
                  '${_distance.toStringAsFixed(1)} km away',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: activeSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Chips row
            Row(
              children: [
                _statChip(
                  context,
                  icon: Icons.star_rounded,
                  iconColor: AppColors.star,
                  value: AppUtils.formatRating(restaurant.rating),
                  label: restaurant.ratingBand.isNotEmpty
                      ? restaurant.ratingBand
                      : 'Rating',
                ),
                const SizedBox(width: 10),
                _statChip(
                  context,
                  icon: Icons.access_time_rounded,
                  iconColor: activeSecondary,
                  value: '~${(_distance * 3).round()} min',
                  label: 'Drive time',
                ),
                const SizedBox(width: 10),
                _statChip(
                  context,
                  icon: Icons.category_rounded,
                  iconColor: AppColors.primary,
                  value: restaurant.categories.isNotEmpty
                      ? restaurant.categories
                      : 'Restaurant',
                  label: 'Category',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Price Card ────────────────────────────────────────────────────────

  Widget _buildPriceCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: _buildPriceLevelCard(context, restaurant.priceLevel ?? 1),
      ),
    );
  }

  // ─── Compass ──────────────────────────────────────────────────────────

  Widget _buildCompass(BuildContext context) {
    if (restaurant.lat == null || restaurant.lon == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: _CompassWidget(
          userLat: userLat,
          userLon: userLon,
          restaurant: restaurant,
          distance: _distance,
        ),
      ),
    );
  }

  // ─── Feature Badges ────────────────────────────────────────────────────

  Widget _buildFeatureBadges(BuildContext context) {
    final attrs = restaurant.activeAttributes;
    if (attrs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Features'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attrs.map((a) => _attributeBadge(context, a)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Vibe Card ─────────────────────────────────────────────────────────

  Widget _buildVibeCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'The Vibe'),
            const SizedBox(height: 10),
            _vibeCard(context, restaurant),
          ],
        ),
      ),
    );
  }

  // ─── Details Card ──────────────────────────────────────────────────────

  Widget _buildDetailsCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Restaurant Details'),
            const SizedBox(height: 10),
            _detailsCard(context, restaurant),
          ],
        ),
      ),
    );
  }

  // ─── Address Card ──────────────────────────────────────────────────────

  Widget _buildAddressCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Address'),
            const SizedBox(height: 10),
            _addressCard(context, restaurant),
          ],
        ),
      ),
    );
  }

  // ─── Similar Restaurants Section ───────────────────────────────────────

  Widget _buildSimilarSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: _sectionTitle(context, 'Similar Restaurants'),
          ),
          _SimilarRestaurantsSection(
            restaurant: restaurant,
            userLat: userLat,
            userLon: userLon,
          ),
        ],
      ),
    );
  }

  // ─── Action Buttons ────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        child: Column(
          children: [
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
                      icon: const Icon(Icons.directions_rounded, size: 20),
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
                        foregroundColor: activeSecondary,
                        side: BorderSide(
                          color: activeSecondary.withValues(alpha: 0.5),
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
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00B14F),
                  side: BorderSide(
                    color: const Color(0xFF00B14F).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.delivery_dining_rounded, size: 18),
                label: const Text(
                  'Order Delivery',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                onPressed: () => _showDeliverySheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Methods ────────────────────────────────────────────────────

  Widget _heroGradient() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: AppColors.oceanGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;
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
        color: activeSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: activeSecondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[label] ?? Icons.check_circle_rounded,
            size: 14,
            color: activeSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: activeSecondary,
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
          _topicBar(
            context,
            'Ambience',
            r.topic2Pct,
            AppColors.adaptiveSecondary(context),
          ),
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: activeSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: activeSecondary),
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
  }

  Widget _divider(BuildContext context) => const GradientDivider(
    height: 1,
    thickness: 0.5,
    margin: EdgeInsets.only(left: 64, right: 16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    return BlocBuilder<RestaurantDetailCubit, RestaurantDetailState>(
      buildWhen: (_, current) =>
          current is RestaurantDetailCompassUpdated ||
          current is RestaurantDetailInitial,
      builder: (context, state) {
        if (state is! RestaurantDetailCompassUpdated) {
          return const SizedBox.shrink();
        }
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
                    color: activeSecondary,
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
                    color: activeSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${relative.toStringAsFixed(0)}°',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: activeSecondary,
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
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            itemCount: state.similar.length,
            itemBuilder: (_, i) => RestaurantCard(
              restaurant: state.similar[i],
              variant: RestaurantCardVariant.portrait,
              userLat: userLat,
              userLon: userLon,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RestaurantDetailScreen(
                    restaurant: state.similar[i],
                    userLat: userLat,
                    userLon: userLon,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
