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

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (context, currentIndex, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          extendBody: true,
          body: IndexedStack(index: currentIndex, children: _screens),
          bottomNavigationBar: isKeyboardOpen
              ? const SizedBox.shrink()
              : _FloatingNavBar(
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
    final activePrimary = isDark ? AppColors.primary : AppColors.primary;

    const double barHeight = 68.0;
    const double btnSize = 56.0;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomPad > 0 ? bottomPad + 6 : 14,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Floating navigation bar card container
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left side: Home, Discover
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavButtonWithLabel(
                        inactiveIcon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                        isActive: currentIndex == 0,
                        animation: activeAnims[0],
                        onTap: () => onTap(0),
                        activePrimary: activePrimary,
                      ),
                      _NavButtonWithLabel(
                        inactiveIcon: Icons.explore_outlined,
                        activeIcon: Icons.explore_rounded,
                        label: 'Discover',
                        isActive: currentIndex == 1,
                        animation: activeAnims[1],
                        onTap: () => onTap(1),
                        activePrimary: activePrimary,
                      ),
                    ],
                  ),
                ),

                // Center spacer placeholder for MAKANBOT label
                SizedBox(
                  width: 76,
                  child: _MakanbotLabelButton(
                    isActive: currentIndex == 2,
                    animation: activeAnims[2],
                    onTap: () => onTap(2),
                    activePrimary: activePrimary,
                  ),
                ),

                // Right side: Favourite, Profile
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavButtonWithLabel(
                        inactiveIcon: Icons.favorite_border_rounded,
                        activeIcon: Icons.favorite_rounded,
                        label: 'Favourite',
                        isActive: currentIndex == 3,
                        animation: activeAnims[3],
                        onTap: () => onTap(3),
                        activePrimary: activePrimary,
                      ),
                      _NavButtonWithLabel(
                        inactiveIcon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
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

          // 2. Raised circular Makanbot button overlapping the top border
          Positioned(
            bottom: barHeight - (btnSize / 2) - 3,
            child: _MakanbotRaisedButton(
              icon: Icons.auto_awesome_rounded,
              isActive: currentIndex == 2,
              animation: activeAnims[2],
              onTap: () => onTap(2),
              activePrimary: activePrimary,
              size: btnSize,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Makanbot Raised Button (Design overlap center) ──────────────────────────

class _MakanbotRaisedButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Color activePrimary;
  final double size;

  const _MakanbotRaisedButton({
    required this.icon,
    required this.isActive,
    required this.animation,
    required this.onTap,
    required this.activePrimary,
    required this.size,
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

          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activePrimary,
              boxShadow: [
                BoxShadow(
                  color: activePrimary.withValues(alpha: 0.35),
                  blurRadius: 10 + (t * 4),
                  offset: Offset(0, 3 + (t * 2)),
                ),
                BoxShadow(
                  color: activePrimary.withValues(alpha: 0.15),
                  blurRadius: 0,
                  spreadRadius: 3 + (t * 1),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
                Icon(icon, size: 26, color: const Color(0xFF0F172A)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Makanbot Label & Indicator Placeholder ──────────────────────────────────

class _MakanbotLabelButton extends StatelessWidget {
  final bool isActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Color activePrimary;

  const _MakanbotLabelButton({
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
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;

          final labelColor = activePrimary;

          final lineWidth = t > 0.1 ? 38.0 : 0.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Vertical space allocation for the raised circular button above
              const SizedBox(height: 24),

              Text(
                'Makanbot',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 3),

              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: lineWidth,
                height: 3,
                decoration: BoxDecoration(
                  color: activePrimary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 5),
            ],
          );
        },
      ),
    );
  }
}

// ─── Navigation Button with Label ────────────────────────────────────────

class _NavButtonWithLabel extends StatelessWidget {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Color activePrimary;

  const _NavButtonWithLabel({
    required this.inactiveIcon,
    required this.activeIcon,
    required this.label,
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
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;

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

          final lineWidth = t > 0.1 ? 38.0 : 0.0;
          final iconData = isActive ? activeIcon : inactiveIcon;

          return SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, size: 26, color: iconColor),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w500,
                    color: labelColor,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
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
