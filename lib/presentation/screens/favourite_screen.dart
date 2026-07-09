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
import '../widgets/curved_header_painter.dart';
import '../../data/location_service.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen> {
  // ─── Named constants for padding/layout ─────────────────────────────────
  static const double _headerHeight = 110.0;

  @override
  void initState() {
    super.initState();
    _loadFavourite();
  }

  Future<void> _loadFavourite() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user != null) {
      context.read<FavouriteCubit>().loadWishlist(user.id);
    }
  }

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
      onTimeout: () => sub.cancel(),
    );
  }

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

      final pos = await LocationService.instance.getPosition();
      if (!mounted) return;
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(
            restaurant: match,
            userLat: pos.latitude,
            userLon: pos.longitude,
          ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.read<AuthCubit>().currentUser;
    final isGuest = user == null;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(isGuest),
    );
  }

  /// Build the body content based on auth state and favourite state
  Widget _buildBody(bool isGuest) {
    if (isGuest) {
      return _LockedGuestState(
        onAuth: () => Navigator.pushNamed(context, '/welcome'),
      );
    }

    return BlocBuilder<FavouriteCubit, FavouriteState>(
      builder: (context, state) {
        if (state is FavouriteLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (state is FavouriteError) {
          return _ErrorState(message: state.message, onRetry: _loadFavourite);
        }

        if (state is FavouriteLoaded && state.items.isEmpty) {
          return const _EmptyState();
        }

        if (state is FavouriteLoaded) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Account for header height
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + _headerHeight,
                  ),
                ),

                // Hint text — fades in when list is populated
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: Padding(
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
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // List of favourite items
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _FavouriteCard(
                        item: state.items[i],
                        onTap: () => _openDetail(state.items[i]),
                        onRemove: () => _removeFavourite(state.items[i]),
                      ),
                      childCount: state.items.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: true,
      titleSpacing: 0,
      toolbarHeight: _headerHeight,
      title: const Padding(
        padding: EdgeInsets.only(left: 18),
        child: Text(
          'My Favourites',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                offset: Offset(0, 1.5),
                blurRadius: 4.0,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ),
      actions: [
        BlocBuilder<FavouriteCubit, FavouriteState>(
          builder: (context, state) {
            if (state is! FavouriteLoaded) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(right: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.items.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ],
      flexibleSpace: Stack(
        children: [
          ClipPath(
            clipper: const HeaderCurveClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.oceanGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -1,
            left: -1,
            right: -1,
            child: CustomPaint(
              size: const Size(double.infinity, 48),
              painter: CurvedHeaderPainter.adaptive(context),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }
}

// ─── Favourite Card ───────────────────────────────────────────────────────────

class _FavouriteCard extends StatefulWidget {
  final FavouriteModel item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavouriteCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_FavouriteCard> createState() => _FavouriteCardState();
}

class _FavouriteCardState extends State<_FavouriteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attrs = widget.item.activeAttributes;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        onTap: widget.onTap,
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
                // Restaurant thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: RestaurantImage.getUrl(
                      widget.item.cuisineType,
                      seed: widget.item.id.hashCode,
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

                // Restaurant info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
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
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              widget.item.municipality,
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

                      if (widget.item.cuisineTypes.isNotEmpty)
                        Text(
                          widget.item.cuisineTypes.join(' · '),
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

                      if (widget.item.topicLabel.isNotEmpty &&
                          widget.item.topicLabel != 'No Reviews')
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
                            '🍽️ ${widget.item.topicLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

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

                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: AppColors.star,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            AppUtils.formatRating(widget.item.rating),
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

                // Heart button
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 0.85).animate(
                      CurvedAnimation(
                        parent: _scaleController,
                        curve: Curves.easeInOut,
                      ),
                    ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
}

// ─── Locked Guest State ────────────────────────────────────────────────────────
/// Content widget for when guest user tries to access favourites
/// NO Scaffold — just content that sits in the main FavouriteScreen's body
class _LockedGuestState extends StatelessWidget {
  final VoidCallback onAuth;

  const _LockedGuestState({required this.onAuth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Locked illustration
            Image.asset(
              'assets/images/favourite_locked.png',
              width: 190,
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 3),

            // Heading
            Text(
              'Your Favourites are Locked!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              "You're using a guest account. Sign up or log in to save your favourites and access them anytime!",
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

            // Sign Up / Login button
            GestureDetector(
              onTap: onAuth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Sign Up / Login',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
/// Content widget for when authenticated user has no saved favourites
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            GestureDetector(
              onTap: () {
                final proxy = context.findAncestorStateOfType<NavTabProxy>();
                if (proxy != null) {
                  proxy.switchTab(1);
                } else {
                  Navigator.pushNamed(context, '/search');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
/// Content widget for when there's an error loading favourites
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
