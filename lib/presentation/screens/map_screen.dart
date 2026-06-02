// ============================================================
// FILE: lib/presentation/screens/map_screen.dart
//
// FIXES IN THIS VERSION:
//
// FIX 1 — Completer crash on widget rebuild:
//   Replaced Completer<GoogleMapController> with a nullable
//   GoogleMapController? field. onMapCreated now simply assigns
//   the controller — safe to call multiple times on rebuild.
//   All usages of _mapController.future replaced with direct
//   null-safe calls on _mapController?.
//
// FIX 2 — Price level badge in preview card (carried over).
//
// FIX 3 — Selected restaurant name overlay on map (carried over).
// ============================================================

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_utils.dart';
import '../../core/app_constants.dart';
import '../../core/restaurant_image.dart';
import '../../data/restaurant_repository.dart';
import '../../data/location_service.dart';
import '../../models/restaurant_model.dart';
import 'restaurant_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  // FIX: Use nullable controller instead of Completer.
  // Completer throws StateError if complete() is called more than once,
  // which happens when the GoogleMap widget rebuilds (e.g. on hot reload,
  // orientation change, or when setState triggers a full widget tree rebuild).
  // A nullable field is safe — assigning it multiple times is harmless.
  GoogleMapController? _mapController;

  late final AnimationController _cardController;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;

  // ── State ───────────────────────────────────────────────────────────────────
  List<Restaurant> _allRestaurants = [];
  Set<Marker> _markers = {};
  Restaurant? _selectedRestaurant;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCuisine = 'All';
  final Map<String, BitmapDescriptor> _customMarkerCache = {};

  // GPS — updated from LocationService, fallback to KT centre
  double _userLat = LocationService.fallbackLat;
  double _userLon = LocationService.fallbackLon;
  LatLng _ktCenter = LatLng(
    LocationService.fallbackLat,
    LocationService.fallbackLon,
  );

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadLocation();

    // Card slide-up animation — plays when a marker is tapped
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
        );
    _cardFade = CurvedAnimation(parent: _cardController, curve: Curves.easeOut);

    _loadRestaurants();
  }

  @override
  void dispose() {
    // FIX: Dispose the controller directly — no Completer to worry about.
    _mapController?.dispose();
    _cardController.dispose();
    super.dispose();
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────
  Future<void> _loadLocation() async {
    try {
      final pos = await LocationService.instance.getPosition();
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLon = pos.longitude;
          _ktCenter = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {}
  }

  // ── Data loading ─────────────────────────────────────────────────────────────
  Future<void> _loadRestaurants() async {
    try {
      final repo = RestaurantRepository();
      final all = await repo.getAllRestaurants();
      if (mounted) {
        setState(() {
          _allRestaurants = all;
          _isLoading = false;
        });
        _rebuildMarkers(all);
        _precacheMarkerIcons(all);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('MapScreen load error: $e');
    }
  }

  // ── Distance helper ──────────────────────────────────────────────────────────
  double _getDistance(Restaurant r) => AppUtils.calculateDistance(
    _userLat,
    _userLon,
    r.lat ?? _userLat,
    r.lon ?? _userLon,
  );

  // ── Filtered list ────────────────────────────────────────────────────────────
  List<Restaurant> get _filteredRestaurants {
    final q = _searchQuery.toLowerCase();
    return _allRestaurants.where((r) {
      final matchQuery =
          q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.cuisineType.toLowerCase().contains(q);
      final matchCuisine =
          _selectedCuisine == 'All' || r.cuisineType == _selectedCuisine;
      return matchQuery && matchCuisine && r.lat != null && r.lon != null;
    }).toList();
  }

  // ── Rebuild markers ──────────────────────────────────────────────────────────
  void _rebuildMarkers(List<Restaurant> restaurants) {
    final filtered = restaurants
        .where((r) => r.lat != null && r.lon != null)
        .toList();

    if (!mounted) return;
    setState(() {
      _markers = filtered.map((r) {
        final isSelected = _selectedRestaurant?.id == r.id;
        final cacheKey = '${r.id}_$isSelected';
        final customIcon = _customMarkerCache[cacheKey];

        return Marker(
          markerId: MarkerId('${r.id}'),
          position: LatLng(r.lat!, r.lon!),
          icon:
              customIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                isSelected
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueOrange,
              ),
          zIndexInt: isSelected ? 2 : 1,
          onTap: () => _onMarkerTap(r),
        );
      }).toSet();
    });
  }

  // ── Pre-cache Custom Rating Markers ──────────────────────────────────────────
  Future<void> _precacheMarkerIcons(List<Restaurant> restaurants) async {
    for (final r in restaurants) {
      if (r.lat == null || r.lon == null) continue;

      final ratingStr = AppUtils.formatRating(r.rating);

      // Cache normal state
      final normalKey = '${r.id}_false';
      if (!_customMarkerCache.containsKey(normalKey)) {
        final icon = await _createRatingMarkerImage(
          rating: ratingStr,
          isSelected: false,
        );
        _customMarkerCache[normalKey] = icon;
      }

      // Cache selected state
      final selectedKey = '${r.id}_true';
      if (!_customMarkerCache.containsKey(selectedKey)) {
        final icon = await _createRatingMarkerImage(
          rating: ratingStr,
          isSelected: true,
        );
        _customMarkerCache[selectedKey] = icon;
      }
    }

    // Trigger setState to draw the loaded custom markers
    if (mounted) {
      _rebuildMarkers(
        _filteredRestaurants.isEmpty ? _allRestaurants : _filteredRestaurants,
      );
    }
  }

  // ── Draw Pill-Shaped Rating Marker ──────────────────────────────────────────
  Future<BitmapDescriptor> _createRatingMarkerImage({
    required String rating,
    required bool isSelected,
  }) async {
    const double pixelRatio =
        1.0; // Draw at exact logical size to avoid giant markers on Google Maps

    const double baseWidth = 55.0;
    const double baseHeight = 26.0;

    final int width = (baseWidth * pixelRatio).toInt();
    final int height = (baseHeight * pixelRatio).toInt();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    canvas.scale(pixelRatio);

    final Color primaryColor = isSelected
        ? const Color(0xFFDC2626)
        : const Color(0xFFFF7A00);
    const Color bubbleBgColor = Colors.white;
    final Color borderColor = isSelected
        ? const Color(0xFFDC2626)
        : const Color(0xFFCBD5E1);

    final Path bubblePath = Path();
    const double r = 5.0;
    const double bubbleW = 52.0;
    const double bubbleH = 20.0;
    const double bubbleX = 1.5;
    const double bubbleY = 1.5;

    final RRect rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(bubbleX, bubbleY, bubbleW, bubbleH),
      const Radius.circular(r),
    );

    const double tailX = bubbleX + (bubbleW / 2);
    const double tailY = bubbleY + bubbleH;

    bubblePath.addRRect(rrect);

    final Path tailPath = Path();
    tailPath.moveTo(tailX - 4, tailY);
    tailPath.lineTo(tailX, tailY + 4);
    tailPath.lineTo(tailX + 4, tailY);
    tailPath.close();

    bubblePath.addPath(tailPath, Offset.zero);

    // Subtle drop shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawPath(bubblePath, shadowPaint);

    final Paint bgPaint = Paint()
      ..color = bubbleBgColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bubblePath, bgPaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1.0;
    canvas.drawPath(bubblePath, borderPaint);

    const double circleR = 6.5;
    const double circleX = bubbleX + 7.5;
    const double circleY = bubbleY + (bubbleH / 2);

    final Paint circlePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(circleX, circleY), circleR, circlePaint);

    final Paint iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    // Draw tiny fork icon
    canvas.drawLine(
      const Offset(circleX - 2, circleY - 1),
      const Offset(circleX - 2, circleY + 3),
      iconPaint,
    );
    canvas.drawLine(
      const Offset(circleX - 3.5, circleY - 3),
      const Offset(circleX - 0.5, circleY - 3),
      iconPaint,
    );
    canvas.drawLine(
      const Offset(circleX - 3.5, circleY - 3),
      const Offset(circleX - 3.5, circleY - 1),
      iconPaint,
    );
    canvas.drawLine(
      const Offset(circleX - 0.5, circleY - 3),
      const Offset(circleX - 0.5, circleY - 1),
      iconPaint,
    );
    canvas.drawLine(
      const Offset(circleX - 2, circleY - 3),
      const Offset(circleX - 2, circleY - 1),
      iconPaint,
    );

    // Draw tiny spoon icon
    canvas.drawLine(
      const Offset(circleX + 2, circleY - 1),
      const Offset(circleX + 2, circleY + 3),
      iconPaint,
    );
    final Paint spoonHeadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      const Rect.fromLTRB(
        circleX + 1.0,
        circleY - 3,
        circleX + 3.0,
        circleY - 1,
      ),
      spoonHeadPaint,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: rating,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1E293B), // Slate 800
      ),
    );

    textPainter.layout();

    const double textX = circleX + circleR + 4.0;
    final double textY = circleY - (textPainter.height / 2);

    textPainter.paint(canvas, Offset(textX, textY));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(width, height);
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }

    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  // ── Marker tap handler ───────────────────────────────────────────────────────
  void _onMarkerTap(Restaurant r) {
    setState(() => _selectedRestaurant = r);
    _rebuildMarkers(_allRestaurants);
    _cardController.forward(from: 0);
    _moveCameraTo(r);
  }

  // ── Dismiss preview card ─────────────────────────────────────────────────────
  void _dismissCard() {
    _cardController.reverse().then((_) {
      if (mounted) {
        setState(() => _selectedRestaurant = null);
        _rebuildMarkers(_allRestaurants);
      }
    });
  }

  // ── Move camera ──────────────────────────────────────────────────────────────
  // FIX: Direct null-safe call instead of awaiting Completer.future.
  // This is safe because _moveCameraTo is only called after onMapCreated
  // has fired, which means _mapController is already assigned.
  void _moveCameraTo(Restaurant r) {
    if (r.lat == null || r.lon == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(r.lat!, r.lon!), 16),
    );
  }

  // ── Recenter button ──────────────────────────────────────────────────────────
  // FIX: Same pattern — direct null-safe call, no async/await needed.
  void _recenterMap() {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_ktCenter, 13));
  }

  // ── Apply filter ─────────────────────────────────────────────────────────────
  void _applyFilter() {
    _rebuildMarkers(_filteredRestaurants);
    if (_selectedRestaurant != null &&
        !_filteredRestaurants.any((r) => r.id == _selectedRestaurant!.id)) {
      _dismissCard();
    }
  }

  // ── Price level helpers ──────────────────────────────────────────────────────
  (String, Color)? _priceInfo(int level) {
    switch (level) {
      case 1:
        return ('RM Budget', const Color(0xFF16A34A));
      case 2:
        return ('RM Moderate', const Color(0xFF2563EB));
      case 3:
        return ('RM Upscale', const Color(0xFFD97706));
      case 4:
        return ('RM Fine Dining', const Color(0xFFDC2626));
      default:
        return null;
    }
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ── 1. Full-screen Google Map ────────────────────────────────────
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _ktCenter,
                  zoom: 13,
                ),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,

                // FIX: Simply assign the controller. Safe to call on every
                // rebuild because assigning a field is idempotent, unlike
                // Completer.complete() which throws on a second call.
                onMapCreated: (controller) {
                  _mapController = controller;
                },

                // Tapping anywhere on the map dismisses the preview card
                onTap: (_) =>
                    _selectedRestaurant != null ? _dismissCard() : null,
              ),
            ),

            // ── 2. Top search bar + cuisine filter chips ─────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row: back button + search field
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Search field
                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                onChanged: (v) {
                                  setState(() => _searchQuery = v);
                                  _applyFilter();
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search on map...',
                                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.grey[400],
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: AppColors.secondary,
                                    size: 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Cuisine filter chips row
                    SizedBox(
                      height: 34,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: CuisineOptions.all.length,
                        itemBuilder: (_, i) {
                          final c = CuisineOptions.all[i];
                          final active = _selectedCuisine == c;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedCuisine = c);
                              _applyFilter();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                c,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: active
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. Restaurant count pill ─────────────────────────────────────
            if (!_isLoading)
              Positioned(
                top: MediaQuery.of(context).padding.top + 120,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      '${_filteredRestaurants.length} restaurants on map',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // ── 4. Selected restaurant name overlay ──────────────────────────
            // Shows a floating name chip when a marker is tapped.
            // Disappears when the card is dismissed.
            if (_selectedRestaurant != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 155,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Red dot matching the selected marker colour
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _selectedRestaurant!.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _dismissCard,
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── 5. Loading overlay ───────────────────────────────────────────
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text(
                          'Loading restaurants...',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── 6. Recenter FAB ─────────────────────────────────────────────
            // Moves up when the preview card is visible.
            Positioned(
              right: 16,
              bottom: _selectedRestaurant != null ? 230 : 100,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: FloatingActionButton.small(
                  heroTag: 'recenter',
                  backgroundColor: Colors.white,
                  onPressed: _recenterMap,
                  child: Icon(
                    Icons.my_location_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
              ),
            ),

            // ── 7. Restaurant preview card ───────────────────────────────────
            // Slides up from the bottom when a marker is tapped.
            if (_selectedRestaurant != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: _buildPreviewCard(_selectedRestaurant!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Preview card ─────────────────────────────────────────────────────────────
  Widget _buildPreviewCard(Restaurant r) {
    final km = _getDistance(r);
    final mins = (km * 3).round();
    final attrs = r.activeAttributes;
    final price = r.priceLevel != null ? _priceInfo(r.priceLevel!) : null;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Restaurant photo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: RestaurantImage.getUrl(
                            r.cuisineType,
                            seed: r.id,
                          ),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  AppColors.secondary.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: AppColors.primary.withValues(alpha: 0.7),
                              size: 26,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  AppColors.secondary.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: AppColors.primary.withValues(alpha: 0.7),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Category · cuisine
                            Text(
                              '${r.categories} · ${r.cuisineType}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.secondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Rating + travel time + price badge
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: AppColors.star,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      AppUtils.formatRating(r.rating),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF3A2F2F),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$mins min · ${AppUtils.formatDistance(km)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (price != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: price.$2.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: price.$2.withValues(alpha: 0.30),
                                      ),
                                    ),
                                    child: Text(
                                      price.$1,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: price.$2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Dismiss button
                      GestureDetector(
                        onTap: _dismissCard,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Attribute chips — max 3
                  if (attrs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: attrs
                          .take(3)
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.07,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Text(
                                a,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RestaurantDetailScreen(restaurant: r),
                              ),
                            ),
                            child: const Text(
                              'View Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: BorderSide(
                              color: AppColors.secondary.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RestaurantDetailScreen(restaurant: r),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_rounded,
                                size: 16,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Directions',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
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
}
