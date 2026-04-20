import 'dart:async';
import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_utils.dart';
import '../../core/restaurant_image.dart';
import '../../data/restaurant_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/restaurant_model.dart';
import '../../core/guest_guard.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/wishlist_cubit.dart';

class RestaurantDetailScreen extends StatefulWidget {
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
  State<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  Restaurant get restaurant => widget.restaurant;
  double get userLat => widget.userLat;
  double get userLon => widget.userLon;

  double get _distance => AppUtils.calculateDistance(
      userLat, userLon,
      restaurant.lat ?? userLat,
      restaurant.lon ?? userLon);

  double? _compassHeading;
  StreamSubscription<CompassEvent>? _compassSub;

  @override
  void initState() {
    super.initState();
    _startCompass();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  // ── Compass ────────────────────────────────────────────────────────────────

  void _startCompass() {
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted && event.heading != null) {
        setState(() => _compassHeading = event.heading);
      }
    });
  }

  double _bearingToRestaurant() {
    final lat1 = userLat;
    final lon1 = userLon;
    final lat2 = restaurant.lat ?? userLat;
    final lon2 = restaurant.lon ?? userLon;
    final dLon = _toRad(lon2 - lon1);
    final y = sin(dLon) * cos(_toRad(lat2));
    final x = cos(_toRad(lat1)) * sin(_toRad(lat2)) -
        sin(_toRad(lat1)) * cos(_toRad(lat2)) * cos(dLon);
    return (_toDeg(atan2(y, x)) + 360) % 360;
  }

  double _toRad(double deg) => deg * pi / 180;
  double _toDeg(double rad) => rad * 180 / pi;

  String _getDirectionLabel(double relativeBearing) {
    final b = (relativeBearing + 360) % 360;
    if (b < 22.5 || b >= 337.5) return 'North';
    if (b < 67.5) return 'North-East';
    if (b < 112.5) return 'East';
    if (b < 157.5) return 'South-East';
    if (b < 202.5) return 'South';
    if (b < 247.5) return 'South-West';
    if (b < 292.5) return 'West';
    return 'North-West';
  }

  Widget _compassWidget() {
    final bearing   = _bearingToRestaurant();
    final relative  = (bearing - _compassHeading! + 360) % 360;
    final direction = _getDirectionLabel(relative);

    return Container(
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
      child: Row(children: [
        Transform.rotate(
          angle: relative * pi / 180,
          child: Icon(Icons.navigation_rounded, color: AppColors.secondary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Head $direction',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
              Text('${_distance.toStringAsFixed(1)} km to this restaurant',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${relative.toStringAsFixed(0)}°',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary)),
        ),
      ]),
    );
  }

  // ── Share ──────────────────────────────────────────────────────────────────

  void _shareRestaurant() {
    final r = restaurant;
    final buffer = StringBuffer();
    buffer.writeln('🍽️ *${r.name}*');
    buffer.writeln('📍 ${r.municipality}, Terengganu');
    buffer.writeln('🍴 ${r.cuisineType}');
    buffer.writeln('⭐ ${AppUtils.formatRating(r.rating)} — ${r.ratingBand}');
    if (r.address.isNotEmpty) {
      buffer.writeln('🗺️ ${r.address}');
    }
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
    if (lat == null || lon == null) { _showNoCoordSnack(context); return; }
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) _showNoCoordSnack(context);
    }
  }

  Future<void> _openWaze(BuildContext context) async {
    final lat = restaurant.lat;
    final lon = restaurant.lon;
    if (lat == null || lon == null) { _showNoCoordSnack(context); return; }
    final uri      = Uri.parse('waze://?ll=$lat,$lon&navigate=yes');
    final fallback = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) _showNoCoordSnack(context);
    }
  }

  void _showNoCoordSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('No coordinates available for this restaurant.'),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showDirectionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10)),
            ),
            Text('Get Directions',
                style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 6),
            Text(restaurant.name,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 24),
            _dirBtn(
              context: context,
              icon: Icons.map_rounded,
              label: 'Open in Google Maps',
              color: const Color(0xFF4285F4),
              onTap: () { Navigator.pop(context); _openGoogleMaps(context); },
            ),
            const SizedBox(height: 12),
            _dirBtn(
              context: context,
              icon: Icons.navigation_rounded,
              label: 'Open in Waze',
              color: const Color(0xFF33CCFF),
              onTap: () { Navigator.pop(context); _openWaze(context); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dirBtn({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
          ]),
        ),
      );

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r      = restaurant;
    final attrs  = r.activeAttributes;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [

            // ── Hero App Bar ───────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: AppColors.secondary,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              actions: [
                // Share button
                GestureDetector(
                  onTap: _shareRestaurant,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                // Wishlist button
                BlocBuilder<WishlistCubit, WishlistState>(
                  builder: (context, state) {
                    final saved = state is WishlistLoaded
                        ? state.isSaved(restaurant.name)
                        : false;
                    return GestureDetector(
                      onTap: () => GuestGuard.check(
                        context,
                        featureName: 'save restaurants to your wishlist',
                        onAllowed: () {
                          final user = context.read<AuthCubit>().currentUser;
                          if (user == null) return;
                          context.read<WishlistCubit>().toggleWishlist(
                                userId: user.id,
                                restaurant: restaurant,
                              );
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: Text(saved
                                  ? 'Removed from wishlist'
                                  : '❤️ Saved to wishlist'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ));
                        },
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: saved ? Colors.red[300] : Colors.white,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                    imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.secondary,
                              AppColors.primary.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.secondary,
                              AppColors.primary.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_rounded,
                              size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(r.municipality,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Quick Stats
                    Row(children: [
                      _statCard(
                        icon: Icons.star_rounded,
                        iconColor: AppColors.star,
                        value: AppUtils.formatRating(r.rating),
                        label: r.ratingBand.isNotEmpty ? r.ratingBand : 'Rating',
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        icon: Icons.near_me_rounded,
                        iconColor: AppColors.secondary,
                        value: '${_distance.toStringAsFixed(1)} km',
                        label: 'From you',
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        icon: Icons.category_rounded,
                        iconColor: AppColors.primary,
                        value: r.cuisineType,
                        label: 'Cuisine',
                      ),
                    ]),

                    // Price Level
                    if (r.priceLevel != null) ...[
                      const SizedBox(height: 12),
                      _buildPriceLevelCard(r.priceLevel!),
                    ],

                    // Compass
                    if (_compassHeading != null &&
                        r.lat != null &&
                        r.lon != null) ...[
                      const SizedBox(height: 12),
                      _compassWidget(),
                    ],

                    const SizedBox(height: 16),

                    // Attribute Badges
                    if (attrs.isNotEmpty) ...[
                      _sectionTitle('Features'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: attrs.map((a) => _attributeBadge(a)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // The Vibe
                    _sectionTitle('The Vibe'),
                    const SizedBox(height: 10),
                    _vibeCard(r),

                    const SizedBox(height: 16),

                    // Restaurant Details
                    _sectionTitle('Restaurant Details'),
                    const SizedBox(height: 10),
                    _detailsCard(context, r),

                    const SizedBox(height: 16),

                    // Address
                    if (r.address.isNotEmpty) ...[
                      _sectionTitle('Address'),
                      const SizedBox(height: 10),
                      _addressCard(context, r),
                      const SizedBox(height: 16),
                    ],

                    // Similar Restaurants
                    // FIX: Uses _SimilarRestaurantsSection which loads from
                    // RestaurantRepository directly — does NOT touch
                    // RecommendationCubit, so it won't trigger auto-navigation.
                    _sectionTitle('Similar Restaurants'),
                    const SizedBox(height: 10),
                    _SimilarRestaurantsSection(
                      restaurant: r,
                      userLat: userLat,
                      userLon: userLon,
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.directions_rounded, size: 20),
                            label: const Text('Directions',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                            onPressed: () => _showDirectionsSheet(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: BorderSide(
                                color: AppColors.secondary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: _shareRestaurant,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Share',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ]),

                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Price Level Card ──────────────────────────────────────────────────────

  Widget _buildPriceLevelCard(int level) {
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
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(Icons.payments_rounded, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              Text(desc,
                  style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Row(
          children: List.generate(4, (i) => Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: i < level ? color : color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
          )),
        ),
      ]),
    );
  }

  (String, String, Color)? _priceInfo(int level) {
    switch (level) {
      case 1: return ('Budget',      '< RM15 per person',       const Color(0xFF16A34A));
      case 2: return ('Moderate',    'RM15 – RM40 per person',  const Color(0xFF2563EB));
      case 3: return ('Upscale',     'RM40 – RM100 per person', const Color(0xFFD97706));
      case 4: return ('Fine Dining', 'RM100+ per person',       const Color(0xFFDC2626));
      default: return null;
    }
  }

  // ── Stat Card ─────────────────────────────────────────────────────────────

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _attributeBadge(String label) {
    final Map<String, IconData> icons = {
      'Halal':           Icons.verified_rounded,
      'Vegetarian':      Icons.eco_rounded,
      'Vegan':           Icons.grass_rounded,
      'Family Friendly': Icons.family_restroom_rounded,
      'Romantic':        Icons.favorite_rounded,
      'Scenic View':     Icons.landscape_rounded,
      'Outdoor':         Icons.park_rounded,
      'Parking':         Icons.local_parking_rounded,
      'WiFi':            Icons.wifi_rounded,
    };
    final icon = icons[label] ?? Icons.check_circle_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.secondary),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.secondary)),
      ]),
    );
  }

  Widget _vibeCard(Restaurant r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.06),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🍽️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                r.topicLabel.isNotEmpty ? r.topicLabel : 'No Reviews',
                style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ]),
          if (r.topicLabel.isNotEmpty && r.topicLabel != 'No Reviews') ...[
            const SizedBox(height: 6),
            Text('Based on customer reviews',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45))),
            const SizedBox(height: 14),
            _topicBar('Food Quality', r.topic1Pct, AppColors.primary),
            const SizedBox(height: 8),
            _topicBar('Ambience', r.topic2Pct, AppColors.secondary),
            const SizedBox(height: 8),
            _topicBar('Service', r.topic3Pct, AppColors.tertiary),
          ],
        ],
      ),
    );
  }

  Widget _topicBar(String label, double pct, Color color) =>
      Row(children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600)),
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
        Text('${pct.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]);

  Widget _detailsCard(BuildContext context, Restaurant r) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        _detailRow(icon: Icons.storefront_rounded, label: 'Category', value: r.categories),
        _divider(),
        _detailRow(icon: Icons.restaurant_menu_rounded, label: 'Cuisine', value: r.cuisineType),
        _divider(),
        _detailRow(icon: Icons.place_rounded, label: 'Area', value: r.municipality),
        if (r.lat != null && r.lon != null) ...[
          _divider(),
          _detailRow(
            icon: Icons.my_location_rounded,
            label: 'Coordinates',
            value: '${r.lat!.toStringAsFixed(4)}, ${r.lon!.toStringAsFixed(4)}',
            onTap: () {
              Clipboard.setData(ClipboardData(text: '${r.lat}, ${r.lon}'));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Coordinates copied to clipboard'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ],
      ]),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 34, height: 34,
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
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.copy_rounded,
                  size: 15,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45)),
          ]),
        ),
      );

  Widget _divider() => Divider(
      height: 1,
      indent: 64,
      endIndent: 16,
      color: Theme.of(context).colorScheme.surfaceContainer);

  Widget _addressCard(BuildContext context, Restaurant r) =>
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: r.address));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Address copied to clipboard'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ));
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
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.location_on_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(r.address,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.4)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded,
                size: 15,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45)),
          ]),
        ),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: AppTextStyles.titleSmall.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface));
}

// ── Similar Restaurants Section ───────────────────────────────────────────────
//
// IMPORTANT: This widget loads similar restaurants directly from
// RestaurantRepository — it does NOT use RecommendationCubit at all.
//
// The old approach used RecommendationCubit.getHybridRecommendations(),
// which emits RecLoaded. The parent RestaurantDetailScreen's BlocListener
// (from HomeScreen) was catching that RecLoaded event and auto-pushing a
// RecommendationScreen, causing the "jumps to similar then needs 2 back presses"
// bug. Loading from repo directly avoids touching the cubit entirely.

class _SimilarRestaurantsSection extends StatefulWidget {
  final Restaurant restaurant;
  final double userLat;
  final double userLon;

  const _SimilarRestaurantsSection({
    required this.restaurant,
    required this.userLat,
    required this.userLon,
  });

  @override
  State<_SimilarRestaurantsSection> createState() =>
      _SimilarRestaurantsSectionState();
}

class _SimilarRestaurantsSectionState
    extends State<_SimilarRestaurantsSection> {
  List<Restaurant> _similar = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSimilar();
  }

  Future<void> _loadSimilar() async {
    try {
      final repo = context.read<RestaurantRepository>();
      final all  = await repo.getAllRestaurants();
      final r    = widget.restaurant;

      // Step 1: Same dominant topic + same cuisine type (most similar)
      var candidates = all
          .where((x) =>
              x.id != r.id &&
              x.dominantTopic == r.dominantTopic &&
              x.cuisineType == r.cuisineType)
          .toList();

      // Step 2: If fewer than 3, loosen to same topic only
      if (candidates.length < 3) {
        candidates = all
            .where((x) =>
                x.id != r.id &&
                x.dominantTopic == r.dominantTopic)
            .toList();
      }

      // Step 3: If still fewer than 3, loosen to same cuisine only
      if (candidates.length < 3) {
        final byCuisine = all
            .where((x) =>
                x.id != r.id &&
                x.cuisineType == r.cuisineType)
            .toList();
        // Merge without duplicates
        for (final c in byCuisine) {
          if (!candidates.any((x) => x.id == c.id)) candidates.add(c);
        }
      }

      // Sort by rating descending, take top 6
      candidates.sort((a, b) => b.rating.compareTo(a.rating));
      final result = candidates.take(6).toList();

      if (mounted) {
        setState(() {
          _similar = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }

    if (_similar.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(Icons.restaurant_rounded,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
              size: 24),
          const SizedBox(width: 12),
          Text('No similar restaurants found',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45))),
        ]),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _similar.length,
        itemBuilder: (_, i) => _SimilarCard(
          restaurant: _similar[i],
          userLat: widget.userLat,
          userLon: widget.userLon,
        ),
      ),
    );
  }
}

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
    final r  = restaurant;
    final km = AppUtils.calculateDistance(
        userLat, userLon, r.lat ?? userLat, r.lon ?? userLon);

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
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: CachedNetworkImage(
              imageUrl: RestaurantImage.getUrl(r.cuisineType, seed: r.id),
              width: 60,
              height: 130,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                width: 60, height: 130,
                color: AppColors.secondary.withValues(alpha: 0.15),
                child: Icon(Icons.restaurant_rounded,
                    color: AppColors.secondary.withValues(alpha: 0.5), size: 20),
              ),
              errorWidget: (_, _, _) => Container(
                width: 60, height: 130,
                color: AppColors.secondary.withValues(alpha: 0.15),
                child: Icon(Icons.restaurant_rounded,
                    color: AppColors.secondary.withValues(alpha: 0.5), size: 20),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(r.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.3)),
                  const SizedBox(height: 4),
                  Text(r.cuisineType,
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        size: 11, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 2),
                    Text(AppUtils.formatRating(r.rating),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${km.toStringAsFixed(1)} km',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}