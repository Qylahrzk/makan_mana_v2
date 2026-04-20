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

class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends NavTabProxy<MainNavScreen>
    with TickerProviderStateMixin {
  late final ValueNotifier<int> _tabIndex;
  late final List<AnimationController> _pillControllers;
  late final List<Animation<double>> _pillAnims;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _tabIndex = ValueNotifier<int>(widget.initialIndex);

    _pillControllers = List.generate(4, (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    ));
    _pillAnims = _pillControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    _pillControllers[widget.initialIndex].value = 1.0;

    _screens = [
      const HomeScreen(),
      const RestaurantSearchScreen(),
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

    // ✅ Block wishlist tab (index 2) for guests
    if (index == 2) {
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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (context, currentIndex, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(index: currentIndex, children: _screens),
        bottomNavigationBar: _PillNavBar(
          currentIndex: currentIndex,
          pillAnims: _pillAnims,
          onTap: _onTabTap,
        ),
      ),
    );
  }
}

// ─── Pill Nav Bar ─────────────────────────────────────────────────────────────

class _PillNavBar extends StatelessWidget {
  final int currentIndex;
  final List<Animation<double>> pillAnims;
  final ValueChanged<int> onTap;

  const _PillNavBar({
    required this.currentIndex,
    required this.pillAnims,
    required this.onTap,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_rounded,    label: 'Home'),
    _NavItemData(icon: Icons.search_rounded,  label: 'Explore'),
    _NavItemData(icon: Icons.favorite_rounded, label: 'Wishlist'),
    _NavItemData(icon: Icons.person_rounded,  label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 10,
            bottom: bottomPad > 0 ? 4 : 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) => _PillItem(
              data: _items[i],
              index: i,
              isActive: currentIndex == i,
              animation: pillAnims[i],
              onTap: () => onTap(i),
              badgeBuilder: i == 2
                  ? () => BlocBuilder<WishlistCubit, WishlistState>(
                        builder: (_, state) {
                          // ✅ Only show badge for authenticated users
                          final authState =
                              context.read<AuthCubit>().state;
                          if (authState is! AuthAuthenticated) {
                            return const SizedBox.shrink();
                          }
                          return (state is WishlistLoaded &&
                                  state.items.isNotEmpty)
                              ? _Badge(count: state.items.length)
                              : const SizedBox.shrink();
                        },
                      )
                  : null,
            )),
          ),
        ),
      ),
    );
  }
}

// ─── Single Pill Item ─────────────────────────────────────────────────────────

class _PillItem extends StatelessWidget {
  final _NavItemData data;
  final int index;
  final bool isActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final Widget Function()? badgeBuilder;

  const _PillItem({
    required this.data,
    required this.index,
    required this.isActive,
    required this.animation,
    required this.onTap,
    this.badgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final t         = animation.value;
          final pillColor = AppColors.primary.withValues(alpha: 0.12 * t);
          final iconColor = Color.lerp(
            Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35),
            AppColors.primary,
            t,
          )!;

          return Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                        top: -4, right: -4,
                        child: badgeBuilder!(),
                      ),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
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
  const _NavItemData({required this.icon, required this.label});
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
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}