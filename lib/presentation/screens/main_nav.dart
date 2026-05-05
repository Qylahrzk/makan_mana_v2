import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/nav_tab_proxy.dart';
import '../../core/guest_guard.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/wishlist_cubit.dart';
import '../../logic/cubits/profile_cubit.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'wishlist_screen.dart';
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
  late final List<AnimationController> _pillControllers;
  late final List<Animation<double>> _pillAnims;

  @override
  void initState() {
    super.initState();
    _tabIndex = ValueNotifier<int>(widget.initialIndex);

    _pillControllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _pillAnims = _pillControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    _pillControllers[widget.initialIndex].value = 1.0;

    _screens = [
      const HomeScreen(),
      const RestaurantSearchScreen(),
      const ChatScreen(),
      const WishlistScreen(),
      const ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapData());
  }

  void _bootstrapData() {
    final user = context.read<AuthCubit>().currentUser;
    if (user != null) {
      context.read<WishlistCubit>().loadWishlist(user.id);
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
          featureName: 'save restaurants to your wishlist',
          onAllowed: () {},
        );
        return;
      }
    }

    _pillControllers[prev].reverse();
    _pillControllers[index].forward();
    _tabIndex.value = index;
    HapticFeedback.selectionClick();
  }

  @override
  void switchTab(int index) => _onTabTap(index);

  @override
  void dispose() {
    _tabIndex.dispose();
    for (final c in _pillControllers) {
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
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (context, currentIndex, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: IndexedStack(index: currentIndex, children: _screens),
        bottomNavigationBar: _FloatingNavBar(
          currentIndex: currentIndex,
          pillAnims: _pillAnims,
          onTap: _onTabTap,
        ),
      ),
    );
  }
}

// ─── Floating Nav Bar ─────────────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<Animation<double>> pillAnims;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.pillAnims,
    required this.onTap,
  });

  static const _leftItems = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home', index: 0),
    _NavItemData(icon: Icons.search_rounded, label: 'Explore', index: 1),
  ];
  static const _rightItems = [
    _NavItemData(
        icon: Icons.favorite_rounded, label: 'Wishlist', index: 3),
    _NavItemData(icon: Icons.person_rounded, label: 'Profile', index: 4),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChatActive = currentIndex == 2;

    // Orange is the active/CTA color in both modes
    final activePrimary = isDark
        ? AppColors.darkPrimary
        : AppColors.primary;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 0),
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
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                // Left: Home + Explore
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _leftItems
                        .map(
                          (item) => _PillItem(
                            data: item,
                            isActive: currentIndex == item.index,
                            animation: pillAnims[item.index],
                            onTap: () => onTap(item.index),
                            activePrimary: activePrimary,
                            badgeBuilder: null,
                          ),
                        )
                        .toList(),
                  ),
                ),

                const SizedBox(width: 80), // gap for center FAB

                // Right: Wishlist + Profile
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _rightItems
                        .map(
                          (item) => _PillItem(
                            data: item,
                            isActive: currentIndex == item.index,
                            animation: pillAnims[item.index],
                            onTap: () => onTap(item.index),
                            activePrimary: activePrimary,
                            badgeBuilder: item.index == 3
                                ? () => BlocBuilder<WishlistCubit,
                                        WishlistState>(
                                      builder: (ctx, state) {
                                        final authState =
                                            ctx.read<AuthCubit>().state;
                                        if (authState
                                            is! AuthAuthenticated) {
                                          return const SizedBox.shrink();
                                        }
                                        return (state is WishlistLoaded &&
                                                state.items.isNotEmpty)
                                            ? _Badge(
                                                count: state.items.length)
                                            : const SizedBox.shrink();
                                      },
                                    )
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),

            // ── Center FAB — orange CTA ──────────────────────────────
            Positioned(
              top: -20,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activePrimary,
                    boxShadow: [
                      BoxShadow(
                        color: activePrimary.withValues(
                          alpha: isChatActive ? 0.55 : 0.35,
                        ),
                        blurRadius: isChatActive ? 24 : 14,
                        offset: const Offset(0, 4),
                      ),
                      if (isChatActive)
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          blurRadius: 0,
                          spreadRadius: 3,
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner shimmer
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
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

// ─── Single Pill Item ─────────────────────────────────────────────────────────

class _PillItem extends StatelessWidget {
  final _NavItemData data;
  final bool isActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Color activePrimary;
  final Widget Function()? badgeBuilder;

  const _PillItem({
    required this.data,
    required this.isActive,
    required this.animation,
    required this.onTap,
    required this.activePrimary,
    required this.badgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final t = animation.value;
          // Orange pill background when active
          final pillColor =
              activePrimary.withValues(alpha: 0.13 * t);
          final iconColor = Color.lerp(
            Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.38),
            activePrimary,
            t,
          )!;

          return Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(data.icon, size: 22, color: iconColor),
                    if (badgeBuilder != null)
                      Positioned(
                          top: -4, right: -4, child: badgeBuilder!()),
                  ],
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: t,
                    child: Row(
                      children: [
                        const SizedBox(width: 6),
                        Opacity(
                          opacity: t,
                          child: Text(
                            data.label,
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: activePrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
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

// ─── Data ─────────────────────────────────────────────────────────────────────

class _NavItemData {
  final IconData icon;
  final String label;
  final int index;
  const _NavItemData({
    required this.icon,
    required this.label,
    required this.index,
  });
}

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}