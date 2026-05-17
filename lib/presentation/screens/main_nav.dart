import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/nav_tab_proxy.dart';
import '../../core/guest_guard.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/favourite_cubit.dart';
import '../../logic/cubits/profile_cubit.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'favourite_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends NavTabProxy<MainNavScreen>
    with TickerProviderStateMixin {
  late final ValueNotifier<int> _tabIndex;
  late final List<Widget> _screens;
  late final List<AnimationController> _activeControllers;
  late final List<Animation<double>> _activeAnims;

  @override
  void initState() {
    super.initState();
    _tabIndex = ValueNotifier<int>(widget.initialIndex);

    _activeControllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _activeAnims = _activeControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    _activeControllers[widget.initialIndex].value = 1.0;

    _screens = [
      const HomeScreen(),
      const RestaurantSearchScreen(),
      const ChatScreen(),
      const FavouriteScreen(),
      const ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapData());
  }

  void _bootstrapData() {
    final user = context.read<AuthCubit>().currentUser;
    if (user != null) {
      context.read<FavouriteCubit>().loadFavourite(user.id);
      context.read<ProfileCubit>().loadProfile(user.id);
    }
  }

  void _onTabTap(int index) {
    final prev = _tabIndex.value;
    if (prev == index) return;

    if (index == 3) {
      final authState = context.read<AuthCubit>().state;
      if (authState is! AuthAuthenticated) {
        GuestGuard.check(
          context,
          featureName: 'save restaurants to your favourites',
          onAllowed: () {},
        );
        return;
      }
    }

    _activeControllers[prev].reverse();
    _activeControllers[index].forward();
    _tabIndex.value = index;
    HapticFeedback.selectionClick();
  }

  @override
  void switchTab(int index) => _onTabTap(index);

  @override
  void dispose() {
    _tabIndex.dispose();
    for (final c in _activeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (context, currentIndex, _) {
        final isChatTab = currentIndex == 2;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          extendBody: !isChatTab,
          body: IndexedStack(index: currentIndex, children: _screens),
          bottomNavigationBar: _FloatingNavBar(
            currentIndex: currentIndex,
            activeAnims: _activeAnims,
            onTap: _onTabTap,
          ),
        );
      },
    );
  }
}

// ─── Floating Nav Bar ────────────────────────────────────────────────────
//
// Refined Design:
//   - Center button: Green circle only (no label, no line)
//   - Side buttons: Icon + compact label + indicator line
//   - Reduced spacing between icon and label
//   - Clean, minimal aesthetic
//   - NO BADGE on Saved button (removed for consistency)

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<Animation<double>> activeAnims;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.activeAnims,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activePrimary = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 80,
        child: Column(
          children: [
            // Top separator line
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                ),
              ),
            ),

            // Navigation buttons
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Home
                  _NavButtonWithLabel(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isActive: currentIndex == 0,
                    animation: activeAnims[0],
                    onTap: () => onTap(0),
                    activePrimary: activePrimary,
                  ),

                  // Search / Explore
                  _NavButtonWithLabel(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    isActive: currentIndex == 1,
                    animation: activeAnims[1],
                    onTap: () => onTap(1),
                    activePrimary: activePrimary,
                  ),

                  // Chat (Design 1 - Green circle only, no label or line)
                  _ChatButton(
                    icon: Icons.auto_awesome_rounded,
                    isActive: currentIndex == 2,
                    animation: activeAnims[2],
                    onTap: () => onTap(2),
                    activePrimary: activePrimary,
                  ),

                  // Saved / Favourite - FIXED: NO BADGE (removed for consistency)
                  _NavButtonWithLabel(
                    icon: Icons.favorite_rounded,
                    label: 'Saved',
                    isActive: currentIndex == 3,
                    animation: activeAnims[3],
                    onTap: () => onTap(3),
                    activePrimary: activePrimary,
                    // badgeBuilder: null - no badge shown
                  ),

                  // Profile
                  _NavButtonWithLabel(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    isActive: currentIndex == 4,
                    animation: activeAnims[4],
                    onTap: () => onTap(4),
                    activePrimary: activePrimary,
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

// ─── Chat Button (Design 1 - Green Circle Only) ──────────────────────────
//
// Clean green circle with white icon
// No label, no indicator line
// Just the icon centered for focus

class _ChatButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Color activePrimary;

  const _ChatButton({
    required this.icon,
    required this.isActive,
    required this.animation,
    required this.onTap,
    required this.activePrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activePrimary,
              boxShadow: [
                // Main shadow
                BoxShadow(
                  color: activePrimary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                // Glow ring
                BoxShadow(
                  color: activePrimary.withValues(alpha: 0.15),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer gradient overlay
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
                // White icon
                Icon(icon, size: 26, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Navigation Button with Label ────────────────────────────────────────
//
// Home, Explore, Saved, Profile buttons
// Icon + compact label + indicator line
// Reduced gap between icon and label

class _NavButtonWithLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Color activePrimary;
  final Widget Function()? badgeBuilder;

  const _NavButtonWithLabel({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.animation,
    required this.onTap,
    required this.activePrimary,
    this.badgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;

          // Color transition
          final iconColor = Color.lerp(
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            activePrimary,
            t,
          )!;

          final labelColor = Color.lerp(
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            activePrimary,
            t,
          )!;

          // Indicator line animation
          final lineWidth = t > 0.1 ? 38.0 : 0.0;

          return SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with badge (if provided)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Icon
                    Icon(icon, size: 26, color: iconColor),

                    // Badge (only if badgeBuilder provided)
                    // For Saved button: badgeBuilder is null, so no badge shown
                    if (badgeBuilder != null)
                      Positioned(top: -2, right: -2, child: badgeBuilder!()),
                  ],
                ),

                // Reduced gap between icon and label (2px instead of 4px)
                const SizedBox(height: 2),

                // Label (10px instead of 11px)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w500,
                    color: labelColor,
                    height: 1.0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Space before indicator line (2px)
                const SizedBox(height: 2),

                // Indicator line (animated)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: lineWidth,
                  height: 3,
                  decoration: BoxDecoration(
                    color: activePrimary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
