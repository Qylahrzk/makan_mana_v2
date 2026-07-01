import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_utils.dart';
import '../../core/restaurant_image.dart';
import '../../models/restaurant_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RESTAURANT CARD VARIANTS
// ─────────────────────────────────────────────────────────────────────────────

enum RestaurantCardVariant {
  rank, // RecommendationScreen: large, with rank badge (#1, #2, #3)
  compact, // ChatScreen: horizontal, small thumbnail
  similar, // RestaurantDetailScreen: horizontal scroll card
  standard, // HomeScreen, SearchScreen: NEW horizontal compact layout
  portrait, // SearchScreen horizontal rows: vertical compact layout matching home screen nearby
}

/// Unified restaurant card component used across all screens.
/// Eliminates ~1000 lines of duplicate card code.
class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final RestaurantCardVariant variant;
  final VoidCallback onTap;

  // Variant-specific optional params
  final int? rankIndex; // For variant.rank — used to show #1, #2, etc.
  final double? userLat; // For distance calculation
  final double? userLon;
  final List<String>? matchedFilters; // For compact variant — chat results

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.variant,
    required this.onTap,
    this.rankIndex,
    this.userLat,
    this.userLon,
    this.matchedFilters,
  });

  double get _distance {
    if (userLat == null || userLon == null) return 0.0;
    return AppUtils.calculateDistance(
      userLat!,
      userLon!,
      restaurant.lat ?? userLat!,
      restaurant.lon ?? userLon!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      RestaurantCardVariant.rank => _buildRankCard(context),
      RestaurantCardVariant.compact => _buildCompactCard(context),
      RestaurantCardVariant.similar => _buildSimilarCard(context),
      RestaurantCardVariant.standard => _buildStandardCard(context),
      RestaurantCardVariant.portrait => _buildPortraitCard(context),
    };
  }

  // ─── RANK VARIANT (RecommendationScreen) ──────────────────────────────────

  Widget _buildRankCard(BuildContext context) {
    final r = restaurant;
    final km = _distance;
    final mins = (km * 3).round();
    final index = rankIndex ?? 999;
    final rankColor = _rankColor(index);
    final isTopThree = index < 3;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: _rankBg(index, context),
          borderRadius: BorderRadius.circular(20),
          border: isTopThree
              ? Border.all(color: rankColor.withValues(alpha: 0.3), width: 1.5)
              : Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.05),
                ),
          boxShadow: [
            BoxShadow(
              color: isTopThree
                  ? rankColor.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.20
                          : 0.10,
                    )
                  : Colors.black.withValues(
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
            children: [
              // Rank badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isTopThree
                      ? rankColor
                      : Theme.of(context).colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                  boxShadow: isTopThree
                      ? [
                          BoxShadow(
                            color: rankColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: isTopThree ? 11 : 10,
                      fontWeight: FontWeight.w900,
                      color: isTopThree
                          ? Colors.white
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _thumbnailFallback(isTopThree),
                  errorWidget: (_, _, _) => _thumbnailFallback(isTopThree),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.categories} · ${r.cuisineType}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (r.topicLabel.isNotEmpty && r.topicLabel != 'No Reviews')
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r.topicLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.star,
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
                        const SizedBox(width: 10),
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$mins min · ${km.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isTopThree
                      ? rankColor.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isTopThree
                      ? rankColor
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── COMPACT VARIANT (ChatScreen) ────────────────────────────────────────

  Widget _buildCompactCard(BuildContext context) {
    final r = restaurant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    final mainCuisine = r.cuisineTypes.isNotEmpty
        ? r.cuisineTypes.first
        : 'Other';
    final imageUrl = RestaurantImage.getUrl(mainCuisine, seed: r.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activeSecondary.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Left Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 72,
                  height: 72,
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 72,
                  height: 72,
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 24,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Middle Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                      const SizedBox(width: 4),
                      Text(
                        AppUtils.formatRating(r.rating),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (r.isHalal) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Text(
                            'Halal',
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 8,
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: activeSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          r.municipality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 11,
                            color: activeSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: activeSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SIMILAR VARIANT (RestaurantDetailScreen) ────────────────────────────

  Widget _buildSimilarCard(BuildContext context) {
    final r = restaurant;
    final km = _distance;

    return GestureDetector(
      onTap: onTap,
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

  // ─── STANDARD VARIANT (HomeScreen, SearchScreen) — NEW HORIZONTAL DESIGN ──

  Widget _buildStandardCard(BuildContext context) {
    final r = restaurant;
    final km = _distance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: activeSecondary.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left Image (Square Thumbnail)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _standardPlaceholder(context),
                  errorWidget: (_, _, _) => _standardPlaceholder(context),
                ),
              ),
              const SizedBox(width: 14),

              // Middle Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant Name
                    Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Category & Cuisine
                    Text(
                      '${r.categories} · ${r.cuisineType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: activeSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Rating & Distance
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.star,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppUtils.formatRating(r.rating),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.near_me_rounded,
                          size: 12,
                          color: activeSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${km.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: activeSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Badges (Halal, Parking, etc.)
                    if (r.isHalal || r.hasParking)
                      Wrap(
                        spacing: 6,
                        children: [
                          if (r.isHalal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Text(
                                'Halal',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (r.hasParking)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: activeSecondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: activeSecondary.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Parking',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: activeSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right Icon (Chevron)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: activeSecondary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: activeSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _heroGradient() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: AppColors.oceanGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );

  Widget _thumbnailFallback(bool isTopThree) => Container(
    width: 68,
    height: 68,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: isTopThree ? 0.18 : 0.10),
          AppColors.secondary.withValues(alpha: isTopThree ? 0.05 : 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(
      Icons.restaurant_rounded,
      color: isTopThree
          ? AppColors.primary
          : AppColors.primary.withValues(alpha: 0.5),
      size: 24,
    ),
  );

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

  Widget _standardPlaceholder(BuildContext context) => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.12),
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(
      Icons.restaurant_rounded,
      color: AppColors.adaptiveSecondary(context).withValues(alpha: 0.4),
      size: 28,
    ),
  );

  Color _rankColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFF8C42);
      case 1:
        return const Color(0xFF7B8FA1);
      case 2:
        return const Color(0xFFB87333);
      default:
        return const Color(0xFFCBD5E0);
    }
  }

  Color? _rankBg(int index, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return Theme.of(context).colorScheme.surfaceContainer;
    switch (index) {
      case 0:
        return const Color(0xFFFFF3E8);
      case 1:
        return const Color(0xFFF2F4F6);
      case 2:
        return const Color(0xFFF7EFE8);
      default:
        return Theme.of(context).colorScheme.surface;
    }
  }

  Widget _buildPortraitCard(BuildContext context) {
    final r = restaurant;
    final km = _distance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 14),
        clipBehavior: Clip.antiAlias,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: RestaurantImage.getUrl(
                      r.cuisineType.isNotEmpty ? r.cuisineType : 'Other',
                      seed: r.id,
                    ),
                    height: 108,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    placeholder: (_, _) => _portraitPlaceholder(context),
                    errorWidget: (_, _, _) => _portraitPlaceholder(context),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      r.cuisineType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          AppUtils.formatRating(r.rating),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: activeSecondary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          r.municipality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      if (userLat != null && userLon != null)
                        Text(
                          '${km.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: activeSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (r.activeAttributes.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: r.activeAttributes
                          .take(2)
                          .map(
                            (a) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: activeSecondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: activeSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portraitPlaceholder(BuildContext context) => Container(
    height: 108,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.8),
          AppColors.adaptiveSecondary(context).withValues(alpha: 0.4),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 4),
          Text(
            restaurant.cuisineType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
