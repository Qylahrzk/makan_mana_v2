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
import '../widgets/curved_header_painter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late final AnimationController _cardController;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;

  List<Restaurant> _allRestaurants = [];
  Set<Marker> _markers = {};
  Restaurant? _selectedRestaurant;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCuisine = 'All';
  final Map<String, BitmapDescriptor> _customMarkerCache = {};
  final TextEditingController _searchController = TextEditingController();

  double _userLat = LocationService.fallbackLat;
  double _userLon = LocationService.fallbackLon;
  LatLng _ktCenter = LatLng(
    LocationService.fallbackLat,
    LocationService.fallbackLon,
  );

  @override
  void initState() {
    super.initState();
    _loadLocation();

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
    _searchController.dispose();
    _mapController?.dispose();
    _cardController.dispose();
    super.dispose();
  }

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

  double _getDistance(Restaurant r) => AppUtils.calculateDistance(
    _userLat,
    _userLon,
    r.lat ?? _userLat,
    r.lon ?? _userLon,
  );

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

  Future<void> _precacheMarkerIcons(List<Restaurant> restaurants) async {
    for (final r in restaurants) {
      if (r.lat == null || r.lon == null) continue;

      final ratingStr = AppUtils.formatRating(r.rating);

      final normalKey = '${r.id}_false';
      if (!_customMarkerCache.containsKey(normalKey)) {
        final icon = await _createRatingMarkerImage(
          rating: ratingStr,
          isSelected: false,
        );
        _customMarkerCache[normalKey] = icon;
      }

      final selectedKey = '${r.id}_true';
      if (!_customMarkerCache.containsKey(selectedKey)) {
        final icon = await _createRatingMarkerImage(
          rating: ratingStr,
          isSelected: true,
        );
        _customMarkerCache[selectedKey] = icon;
      }
    }

    if (mounted) {
      _rebuildMarkers(
        _filteredRestaurants.isEmpty ? _allRestaurants : _filteredRestaurants,
      );
    }
  }

  Future<BitmapDescriptor> _createRatingMarkerImage({
    required String rating,
    required bool isSelected,
  }) async {
    const double pixelRatio = 1.0;
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
        color: Color(0xFF1E293B),
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

    if (byteData == null) return BitmapDescriptor.defaultMarker;

    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  void _onMarkerTap(Restaurant r) {
    setState(() => _selectedRestaurant = r);
    _rebuildMarkers(_allRestaurants);
    _cardController.forward(from: 0);
    _moveCameraTo(r);
  }

  void _dismissCard() {
    _cardController.reverse().then((_) {
      if (mounted) {
        setState(() => _selectedRestaurant = null);
        _rebuildMarkers(_allRestaurants);
      }
    });
  }

  void _moveCameraTo(Restaurant r) {
    if (r.lat == null || r.lon == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(r.lat!, r.lon!), 16),
    );
  }

  void _recenterMap() {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_ktCenter, 13));
  }

  void _applyFilter() {
    _rebuildMarkers(_filteredRestaurants);
    if (_selectedRestaurant != null &&
        !_filteredRestaurants.any((r) => r.id == _selectedRestaurant!.id)) {
      _dismissCard();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.of(context).padding.top + 178;
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: SizedBox.expand(
        child: Stack(
          children: [
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
                onMapCreated: (controller) => _mapController = controller,
                onTap: (_) =>
                    _selectedRestaurant != null ? _dismissCard() : null,
              ),
            ),

            if (!_isLoading)
              Positioned(
                top: topOffset + 8,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(18),
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
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            if (_selectedRestaurant != null)
              Positioned(
                top: topOffset + 40,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
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
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              _selectedRestaurant!.name,
                              style: const TextStyle(
                                fontSize: 12,
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
                              size: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: true,
      toolbarHeight: 56,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Text(
          'Map Explorer',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Colors.black12,
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(126),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        onChanged: (v) {
                          setState(() => _searchQuery = v);
                          _applyFilter();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search on map...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFAAAAAA),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _applyFilter();
                        },
                      ),
                    const SizedBox(width: 14),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
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
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
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
      flexibleSpace: Stack(
        children: [
          ClipPath(
            clipper: const HeaderCurveClipper(curveRadius: 24),
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
                                  AppColors.secondary.withValues(alpha: 0.15),
                                  AppColors.secondary.withValues(alpha: 0.04),
                                ],
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
                                  AppColors.secondary.withValues(alpha: 0.15),
                                  AppColors.secondary.withValues(alpha: 0.04),
                                ],
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
                            Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.categories} · ${r.cuisineType}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.secondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 5),
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
                                builder: (_) => RestaurantDetailScreen(
                                  restaurant: r,
                                  userLat: _userLat,
                                  userLon: _userLon,
                                ),
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
                              builder: (_) => RestaurantDetailScreen(
                                restaurant: r,
                                userLat: _userLat,
                                userLon: _userLon,
                              ),
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
