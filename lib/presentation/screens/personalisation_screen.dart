import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/user_preferences_cubit.dart';
import '../../models/user_preferences_model.dart';

class PersonalisationScreen extends StatefulWidget {
  const PersonalisationScreen({super.key});

  @override
  State<PersonalisationScreen> createState() => _PersonalisationScreenState();
}

class _PersonalisationScreenState extends State<PersonalisationScreen> {
  UserPreferencesModel? _draft;
  bool _loadStarted = false;

  String get _userId =>
      context.read<AuthCubit>().currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authState = context.read<AuthCubit>().state;
      if (authState is AuthGuest) {
        Navigator.pop(context);
        _showSignInDialog();
        return;
      }

      final cubit = context.read<UserPreferencesCubit>();
      if (cubit.current != null) {
        setState(() => _draft = cubit.current!.copyWith());
        return;
      }
      if (!_loadStarted && _userId.isNotEmpty) {
        _loadStarted = true;
        cubit.loadPreferences(_userId);
      }
    });
  }

  void _showSignInDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign In Required',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'You need to sign in or create an account to set your preferences.',
          style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            child: Text('Sign In',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/signup');
            },
            child: Text('Sign Up',
                style: TextStyle(
                    color: AppColors.secondary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_draft == null) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is AuthGuest) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please sign in to save preferences'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    if (_userId.isEmpty) return;

    context.read<UserPreferencesCubit>().savePreferences(
          _draft!, userId: _userId);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('✅ Preferences saved! Recommendations updated.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserPreferencesCubit, UserPreferencesState>(
      listenWhen: (previous, current) =>
          current is PreferencesLoaded || current is PreferencesSaving,
      listener: (context, state) {
        if (state is PreferencesLoaded && mounted) {
          setState(() => _draft = state.prefs.copyWith());
        }
      },
      builder: (context, state) {
        final authState = context.read<AuthCubit>().state;
        if (authState is AuthGuest) return _buildGuestScreen();

        if (_draft == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Personalisation',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Loading your preferences...',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
          );
        }

        return _buildEditor(state);
      },
    );
  }

  Widget _buildGuestScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Personalisation',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
                child: Icon(Icons.lock_outline_rounded,
                    size: 38, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text('Sign In Required',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(
                'Create an account or sign in to personalise your '
                'restaurant recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                  child: const Text('Sign In',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Create Account',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(UserPreferencesState state) {
    final draft  = _draft!;
    final saving = state is PreferencesSaving;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Personalisation',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color:        AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'These preferences personalise your '
                  '"Recommended For You" feed automatically.',
                  style: TextStyle(
                      fontSize:   12,
                      color:      AppColors.primary,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),

          // ── 1. Dietary Restrictions ────────────────────────────────────
          _SectionTitle(title: '🥗 Dietary Restrictions'),
          _PrefsCard(children: [
            _ToggleRow(
              icon:      Icons.mosque_rounded,
              iconColor: AppColors.primary,
              label:     'Halal',
              subtitle:  'Show only halal-certified restaurants',
              value:     draft.halal,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(halal: v)),
            ),
            _divider(),
            _ToggleRow(
              icon:      Icons.eco_rounded,
              iconColor: Colors.green,
              label:     'Vegetarian',
              subtitle:  'Include vegetarian-friendly options',
              value:     draft.vegetarian,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(vegetarian: v)),
            ),
            _divider(),
            _ToggleRow(
              icon:      Icons.grass_rounded,
              iconColor: Colors.green[700]!,
              label:     'Vegan',
              subtitle:  'Show only vegan-friendly restaurants',
              value:     draft.vegan,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(vegan: v)),
            ),
          ]),

          const SizedBox(height: 16),

          // ── 2. Favourite Cuisines ──────────────────────────────────────
          _SectionTitle(title: '🍽️ Favourite Cuisines'),
          _PrefsCard(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: CuisineOptions.all
                    .where((c) => c != 'All')
                    .map((cuisine) {
                  final selected = draft.cuisineTypes.contains(cuisine);
                  return GestureDetector(
                    onTap: () => setState(() {
                      final list = List<String>.from(draft.cuisineTypes);
                      selected ? list.remove(cuisine) : list.add(cuisine);
                      _draft = draft.copyWith(cuisineTypes: list);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(cuisine,
                              style: TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme.onSurface
                                        .withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── 3. Dining Style & Vibes ────────────────────────────────────
          _SectionTitle(title: '🎭 Dining Style & Vibes'),
          _PrefsCard(children: [
            _ToggleRow(
              icon:      Icons.family_restroom_rounded,
              iconColor: AppColors.secondary,
              label:     'Family Friendly',
              subtitle:  'Great for dining with kids',
              value:     draft.familyFriendly,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(familyFriendly: v)),
            ),
            _divider(),
            // NEW
            _ToggleRow(
              icon:      Icons.groups_rounded,
              iconColor: Colors.indigo,
              label:     'Group Friendly',
              subtitle:  'Good for large groups & gatherings',
              value:     draft.groupFriendly,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(groupFriendly: v)),
            ),
            _divider(),
            // NEW
            _ToggleRow(
              icon:      Icons.coffee_rounded,
              iconColor: Colors.brown,
              label:     'Casual Dining',
              subtitle:  'Relaxed, everyday dining atmosphere',
              value:     draft.casual,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(casual: v)),
            ),
            _divider(),
            _ToggleRow(
              icon:      Icons.favorite_rounded,
              iconColor: Colors.pink,
              label:     'Romantic',
              subtitle:  'Perfect for dates and anniversaries',
              value:     draft.romantic,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(romantic: v)),
            ),
            _divider(),
            _ToggleRow(
              icon:      Icons.park_rounded,
              iconColor: Colors.green,
              label:     'Outdoor Seating',
              subtitle:  'Restaurants with outdoor areas',
              value:     draft.hasOutdoor,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(hasOutdoor: v)),
            ),
            _divider(),
            _ToggleRow(
              icon:      Icons.landscape_rounded,
              iconColor: AppColors.tertiary,
              label:     'Scenic View',
              subtitle:  'Beautiful views while you dine',
              value:     draft.scenicView,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(scenicView: v)),
            ),
          ]),

          const SizedBox(height: 16),

          // ── 4. Facilities ──────────────────────────────────────────────
          _SectionTitle(title: '🏢 Preferred Facilities'),
          _PrefsCard(children: [
            _ToggleRow(
              icon:      Icons.local_parking_rounded,
              iconColor: AppColors.secondary,
              label:     'Parking Available',
              subtitle:  'Filter restaurants with parking',
              value:     draft.hasParking,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(hasParking: v)),
            ),
            _divider(),
            _ToggleRow(
              icon:      Icons.wifi_rounded,
              iconColor: Colors.blue,
              label:     'Free WiFi',
              subtitle:  'Restaurants with WiFi access',
              value:     draft.hasWifi,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(hasWifi: v)),
            ),
            _divider(),
            // NEW
            _ToggleRow(
              icon:      Icons.ac_unit_rounded,
              iconColor: Colors.lightBlue,
              label:     'Air-Conditioned',
              subtitle:  'Indoor air-conditioned dining',
              value:     draft.hasAc,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(hasAc: v)),
            ),
            _divider(),
            // NEW
            _ToggleRow(
              icon:      Icons.accessible_rounded,
              iconColor: Colors.teal,
              label:     'Wheelchair Accessible',
              subtitle:  'Accessible for people with disabilities',
              value:     draft.accessible,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(accessible: v)),
            ),
          ]),

          const SizedBox(height: 16),

          // ── 5. Service & Value ─────────────────────────────────────────
          // NEW SECTION
          _SectionTitle(title: '⚡ Service & Value'),
          _PrefsCard(children: [
            _ToggleRow(
              icon:      Icons.thumb_up_rounded,
              iconColor: Colors.orange,
              label:     'Worth It',
              subtitle:  'Great value for money',
              value:     draft.worthIt,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(worthIt: v)),
            ),
            _divider(),
            _ToggleRow(
              icon:      Icons.bolt_rounded,
              iconColor: Colors.amber[700]!,
              label:     'Fast Service',
              subtitle:  'Quick service, minimal wait time',
              value:     draft.fastService,
              onChanged: (v) =>
                  setState(() => _draft = draft.copyWith(fastService: v)),
            ),
          ]),

          const SizedBox(height: 16),

          // ── 6. Search Radius ───────────────────────────────────────────
          _SectionTitle(title: '📍 Default Search Radius'),
          _PrefsCard(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Max distance',
                          style: TextStyle(
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:        AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          draft.defaultRadius >= 500
                              ? 'Any distance'
                              : '${draft.defaultRadius.toInt()} km',
                          style: TextStyle(
                              fontSize:   12,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.secondary)),
                      ),
                    ],
                  ),
                  Slider(
                    value:         draft.defaultRadius,
                    min:           5,
                    max:           500,
                    divisions:     19,
                    activeColor:   AppColors.secondary,
                    inactiveColor: AppColors.secondary.withValues(alpha: 0.15),
                    onChanged: (v) =>
                        setState(() => _draft = draft.copyWith(defaultRadius: v)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('5 km', style: TextStyle(
                          fontSize: 11,
                          color:    Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.4))),
                      Text('Any', style: TextStyle(
                          fontSize: 11,
                          color:    Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.4))),
                    ],
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0),
              icon:  const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Preferences',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 0.5,
          color: Theme.of(context).dividerColor);
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title,
        style: TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w800,
            color:      Theme.of(context).colorScheme.onSurface)),
  );
}

class _PrefsCard extends StatelessWidget {
  final List<Widget> children;
  const _PrefsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color:        Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color:      Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset:     const Offset(0, 2))],
    ),
    child: Column(children: children),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData           icon;
  final Color              iconColor;
  final String             label;
  final String             subtitle;
  final bool               value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:        iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      Theme.of(context).colorScheme.onSurface)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 11,
                  color:    Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.5))),
        ],
      )),
      Switch.adaptive(
          value:       value,
          onChanged:   onChanged,
          activeColor: AppColors.primary),
    ]),
  );
}