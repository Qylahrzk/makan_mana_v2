import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_utils.dart';
import '../../core/restaurant_image.dart';
import '../../models/restaurant_model.dart';
import 'restaurant_detail_screen.dart';
import '../../data/location_service.dart';

class RecommendationScreen extends StatefulWidget {
  final List<Restaurant> recommendations;
  final Restaurant? selectedRestaurant;
  final bool isFromApi;
  final List<String> relaxedFilters;

  const RecommendationScreen({
    super.key,
    required this.recommendations,
    this.selectedRestaurant,
    this.isFromApi = false,
    this.relaxedFilters = const [],
  });

  bool get _isSimilarMode => selectedRestaurant != null;

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _userLat = LocationService.fallbackLat;
  double _userLon = LocationService.fallbackLon;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final pos = await LocationService.instance.getPosition();
    if (mounted) {
      setState(() {
        _userLat = pos.latitude;
        _userLon = pos.longitude;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHeader(context),
          if (widget._isSimilarMode)
            _buildSourceCard()
          else
            _buildAlgorithmBadge(),
          if (widget.relaxedFilters.isNotEmpty) _buildRelaxedWarning(),
          _buildSectionLabel(),
          _buildResultsList(),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ─── Sliver Header ────────────────────────────────────────────────────────

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppColors.secondary,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.oceanGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: 60,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget._isSimilarMode
                              ? 'SIMILAR RESTAURANTS'
                              : 'AI RECOMMENDATIONS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget._isSimilarMode
                        ? 'Similar Vibes'
                        : 'Top Picks For You',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${widget.recommendations.length} restaurants found',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.isFromApi) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Source Card (Similar Mode) ───────────────────────────────────────────

  Widget _buildSourceCard() {
    final target = widget.selectedRestaurant!;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
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
            // ✅ Real photo for source restaurant
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: RestaurantImage.getUrl(
                  target.cuisineType,
                  seed: target.id,
                ),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: 52,
                  height: 52,
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
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  width: 52,
                  height: 52,
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
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BECAUSE YOU LIKED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    target.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          target.topicLabel.isNotEmpty
                              ? target.topicLabel
                              : target.cuisineType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded, size: 13, color: AppColors.star),
                      const SizedBox(width: 3),
                      Text(
                        AppUtils.formatRating(target.rating),
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
          ],
        ),
      ),
    );
  }

  // ─── Algorithm Badge ──────────────────────────────────────────────────────

  Widget _buildAlgorithmBadge() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.secondary.withValues(alpha: 0.08),
              AppColors.secondary.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_rounded,
                color: AppColors.secondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hybrid AI Algorithm',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '30% KBF + 70% LDA',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'LDA + KBF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Relaxed Warning ──────────────────────────────────────────────────────

  Widget _buildRelaxedWarning() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Colors.amber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Some filters were relaxed to find results: ${widget.relaxedFilters.join(', ')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section Label ────────────────────────────────────────────────────────

  Widget _buildSectionLabel() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget._isSimilarMode ? 'SIMILAR VIBES NEARBY' : 'YOUR TOP PICKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.secondary,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Results List ─────────────────────────────────────────────────────────

  Widget _buildResultsList() {
    if (widget.recommendations.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final delay = (index * 0.06).clamp(0.0, 0.8);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = Curves.easeOutCubic.transform(
              ((_controller.value - delay) / (1.0 - delay)).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - progress)),
                child: child,
              ),
            );
          },
          child: _buildRankCard(context, index, widget.recommendations[index]),
        );
      }, childCount: widget.recommendations.length),
    );
  }

  // ─── Rank Card ────────────────────────────────────────────────────────────

  Widget _buildRankCard(BuildContext context, int index, Restaurant r) {
    final km = AppUtils.calculateDistance(
      _userLat,
      _userLon,
      r.lat ?? _userLat,
      r.lon ?? _userLon,
    );
    final mins = (km * 3).round();
    final rankColor = _rankColor(index);
    final isTopThree = index < 3;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: r),
        ),
      ),
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
              // ── Rank badge ────────────────────────────────────────────
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

              // ── Thumbnail with real photo ─────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      _thumbnailFallback(isTopThree: isTopThree),
                  errorWidget: (_, _, _) =>
                      _thumbnailFallback(isTopThree: isTopThree),
                ),
              ),

              const SizedBox(width: 12),

              // ── Info ──────────────────────────────────────────────────
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

              // ── Chevron ───────────────────────────────────────────────
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

  // ── Thumbnail fallback ────────────────────────────────────────────────────
  Widget _thumbnailFallback({required bool isTopThree}) => Container(
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

  // ─── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 42,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No matches found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or\npick a different restaurant.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
