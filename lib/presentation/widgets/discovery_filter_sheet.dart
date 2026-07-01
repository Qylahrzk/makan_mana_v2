import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_text_styles.dart';
import '../../models/user_preferences_model.dart';
import 'gradient_divider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER RESULT MODEL
// ─────────────────────────────────────────────────────────────────────────────

class FilterResult {
  final UserPreferencesModel preferences;
  final bool applied; // True = user tapped "Apply", False = cancelled

  FilterResult({required this.preferences, required this.applied});
}

// ─────────────────────────────────────────────────────────────────────────────
// DISCOVERY FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class DiscoveryFilterSheet extends StatefulWidget {
  /// Initial preferences to display (user can modify, changes only apply on "Apply")
  final UserPreferencesModel initialPreferences;

  /// If true, shows limited filter options (quick mode)
  /// If false, shows full filter panel
  final bool isQuickMode;

  const DiscoveryFilterSheet({
    super.key,
    required this.initialPreferences,
    this.isQuickMode = false,
  });

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  late UserPreferencesModel _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialPreferences.copyWith();
  }

  void _resetFilters() {
    setState(() {
      _draft = UserPreferencesModel.empty(widget.initialPreferences.userId);
    });
  }

  void _apply() {
    Navigator.pop(context, FilterResult(preferences: _draft, applied: true));
  }

  void _cancel() {
    Navigator.pop(
      context,
      FilterResult(preferences: widget.initialPreferences, applied: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) => Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title row with reset button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: _resetFilters,
                        child: Text(
                          'Reset All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable Filter Content ──────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  // 1. Dietary Restrictions
                  _buildSection(
                    title: '🥗 Dietary Restrictions',
                    children: [
                      _buildToggle(
                        icon: Icons.mosque_rounded,
                        iconColor: AppColors.primary,
                        label: 'Halal',
                        subtitle: 'Show halal-certified only',
                        value: _draft.halal,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(halal: v)),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.eco_rounded,
                        iconColor: Colors.green,
                        label: 'Vegetarian',
                        subtitle: 'Include vegetarian options',
                        value: _draft.vegetarian,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(vegetarian: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.grass_rounded,
                        iconColor: Colors.green[700]!,
                        label: 'Vegan',
                        subtitle: 'Vegan-friendly restaurants',
                        value: _draft.vegan,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(vegan: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Facilities
                  _buildSection(
                    title: '🏢 Facilities',
                    children: [
                      _buildToggle(
                        icon: Icons.local_parking_rounded,
                        iconColor: AppColors.primary,
                        label: 'Parking',
                        subtitle: 'Restaurants with parking',
                        value: _draft.hasParking,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(hasParking: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.wifi_rounded,
                        iconColor: Colors.blue,
                        label: 'Free WiFi',
                        subtitle: 'WiFi availability',
                        value: _draft.hasWifi,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(hasWifi: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.ac_unit_rounded,
                        iconColor: Colors.lightBlue,
                        label: 'Air-Conditioned',
                        subtitle: 'Indoor AC dining',
                        value: _draft.hasAc,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(hasAc: v)),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.accessible_rounded,
                        iconColor: Colors.teal,
                        label: 'Wheelchair Accessible',
                        subtitle: 'Accessibility features',
                        value: _draft.accessible,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(accessible: v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Vibes & Occasions
                  _buildSection(
                    title: '🎭 Vibes & Occasions',
                    children: [
                      _buildToggle(
                        icon: Icons.family_restroom_rounded,
                        iconColor: AppColors.primary,
                        label: 'Family Friendly',
                        subtitle: 'Great for families',
                        value: _draft.familyFriendly,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(familyFriendly: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.groups_rounded,
                        iconColor: Colors.indigo,
                        label: 'Group Friendly',
                        subtitle: 'Good for large groups',
                        value: _draft.groupFriendly,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(groupFriendly: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.coffee_rounded,
                        iconColor: Colors.brown,
                        label: 'Casual Dining',
                        subtitle: 'Relaxed atmosphere',
                        value: _draft.casual,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(casual: v)),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.favorite_rounded,
                        iconColor: Colors.pink,
                        label: 'Romantic',
                        subtitle: 'Date night perfect',
                        value: _draft.romantic,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(romantic: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.park_rounded,
                        iconColor: Colors.green,
                        label: 'Outdoor Seating',
                        subtitle: 'Al fresco dining',
                        value: _draft.hasOutdoor,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(hasOutdoor: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.landscape_rounded,
                        iconColor: AppColors.tertiary,
                        label: 'Scenic View',
                        subtitle: 'Beautiful surroundings',
                        value: _draft.scenicView,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(scenicView: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.people_rounded,
                        iconColor: Colors.deepOrange,
                        label: 'Lively & Crowded',
                        subtitle: 'Popular buzzing spots',
                        value: _draft.isCrowded,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(isCrowded: v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Cuisines
                  _buildSection(
                    title: '🍽️ Cuisines',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: CuisineOptions.all
                              .where((c) => c != 'All')
                              .map((cuisine) {
                                final selected = _draft.cuisineTypes.contains(
                                  cuisine,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      final list = List<String>.from(
                                        _draft.cuisineTypes,
                                      );
                                      selected
                                          ? list.remove(cuisine)
                                          : list.add(cuisine);
                                      _draft = _draft.copyWith(
                                        cuisineTypes: list,
                                      );
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (selected) ...[
                                          const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          cuisine,
                                          style: TextStyle(
                                            fontFamily: 'OpenSans',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 5. Service & Value
                  _buildSection(
                    title: '⚡ Service & Value',
                    children: [
                      _buildToggle(
                        icon: Icons.thumb_up_rounded,
                        iconColor: AppColors.primary,
                        label: 'Worth It',
                        subtitle: 'Good value for money',
                        value: _draft.worthIt,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(worthIt: v),
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        icon: Icons.bolt_rounded,
                        iconColor: Colors.amber[700]!,
                        label: 'Fast Service',
                        subtitle: 'Quick orders & service',
                        value: _draft.fastService,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(fastService: v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Action Buttons (Fixed at Bottom) ───────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomSafe),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _cancel,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _apply,
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Builders ──────────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Container(
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
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const GradientDivider(
    height: 1,
    thickness: 0.5,
    margin: EdgeInsets.only(left: 64, right: 16),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Show Filter Sheet
// ─────────────────────────────────────────────────────────────────────────────

Future<FilterResult?> showDiscoveryFilterSheet(
  BuildContext context, {
  required UserPreferencesModel initialPreferences,
  bool isQuickMode = false,
}) {
  return showModalBottomSheet<FilterResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DiscoveryFilterSheet(
      initialPreferences: initialPreferences,
      isQuickMode: isQuickMode,
    ),
  );
}
