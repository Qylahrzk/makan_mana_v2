import 'package:flutter/material.dart';
import '../core/app_constants.dart';
import '../models/restaurant_model.dart';
// ignore: unused_import
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/onboarding_screen.dart';
import '../presentation/screens/welcome_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/signup_screen.dart';
import '../presentation/screens/forgot_password_screen.dart';
import '../presentation/screens/main_nav.dart';
import '../presentation/screens/search_screen.dart';
import '../presentation/screens/restaurant_detail_screen.dart';
import '../presentation/screens/recommendation_screen.dart';
import '../presentation/screens/map_screen.dart';
import '../presentation/screens/favourite_screen.dart';
import '../presentation/screens/profile_screen.dart';

/// AppRouter
///
/// Centralised named-route handler for the app.
///
/// Usage in MaterialApp:
///   initialRoute: AppRoutes.splash,
///   onGenerateRoute: AppRouter.onGenerateRoute,
///
/// Navigating with arguments:
///   // Restaurant detail
///   Navigator.pushNamed(
///     context,
///     AppRoutes.restaurantDetail,
///     arguments: RestaurantDetailArgs(restaurant: r),
///   );
///
///   // Recommendation screen
///   Navigator.pushNamed(
///     context,
///     AppRoutes.recommendation,
///     arguments: RecommendationArgs(
///       recommendations: list,
///       isFromApi: true,
///       relaxedFilters: [],
///     ),
///   );
///
/// Place in: lib/presentation/app_router.dart

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Auth flow ────────────────────────────────────────────────────────
      case AppRoutes.splash:
        return _fade(const SplashScreen());

      case AppRoutes.onboarding:
        return _slide(const OnboardingScreen());

      case AppRoutes.welcome:
        return _fade(const WelcomeScreen());

      case AppRoutes.login:
        return _slide(const LoginScreen());

      case AppRoutes.signup:
        return _slide(const SignupScreen());

      case AppRoutes.forgotPassword:
        return _slide(const ForgotPasswordScreen());

      // ── Main shell ───────────────────────────────────────────────────────
      case AppRoutes.main:
        final args = settings.arguments;
        final initialIndex = args is int ? args : 0;
        return _fade(MainNavScreen(initialIndex: initialIndex));

      // ── Inner screens (pushed on top of MainNav) ─────────────────────────
      case AppRoutes.search:
        return _slide(const RestaurantSearchScreen());

      case AppRoutes.map:
        return _slide(const MapScreen());

      case AppRoutes.favourite:
        return _slide(const FavouriteScreen());

      case AppRoutes.profile:
        return _slide(const ProfileScreen());

      case AppRoutes.restaurantDetail:
        final args = settings.arguments as RestaurantDetailArgs?;
        if (args == null) return _error(settings.name);
        return _slide(RestaurantDetailScreen(restaurant: args.restaurant));

      case AppRoutes.recommendation:
        final args = settings.arguments as RecommendationArgs?;
        if (args == null) return _error(settings.name);
        return _slide(
          RecommendationScreen(
            recommendations: args.recommendations,
            selectedRestaurant: args.selectedRestaurant,
            isFromApi: args.isFromApi,
            relaxedFilters: args.relaxedFilters,
          ),
        );

      default:
        return _error(settings.name);
    }
  }

  // ─── Transitions ──────────────────────────────────────────────────────────

  /// Fade transition — used for root-level screens (splash, welcome, main)
  static PageRoute<T> _fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      ),
    );
  }

  /// Slide-up transition — used for detail/secondary screens
  static PageRoute<T> _slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, _, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// 404 fallback
  static PageRoute<T> _error<T>(String? name) {
    return _fade(
      Scaffold(
        body: Center(
          child: Text(
            'No route defined for "$name"',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

// ─── Route argument classes ───────────────────────────────────────────────────

/// Arguments for RestaurantDetailScreen
class RestaurantDetailArgs {
  final Restaurant restaurant;
  const RestaurantDetailArgs({required this.restaurant});
}

/// Arguments for RecommendationScreen
class RecommendationArgs {
  final List<Restaurant> recommendations;
  final Restaurant? selectedRestaurant;
  final bool isFromApi;
  final List<String> relaxedFilters;

  const RecommendationArgs({
    required this.recommendations,
    this.selectedRestaurant,
    this.isFromApi = false,
    this.relaxedFilters = const [],
  });
}
