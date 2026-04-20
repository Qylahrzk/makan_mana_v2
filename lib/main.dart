import 'package:flutter/material.dart';
import 'package:makan_mana_v2/core/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/app_colors.dart';
import 'core/app_constants.dart';
import 'data/restaurant_repository.dart';
import 'data/api_service.dart';
import 'data/supabase_service.dart';
import 'data/chat_service.dart'; // ← must be explicit
import 'logic/cubits/auth_cubit.dart';
import 'logic/cubits/recommendation_cubit.dart';
import 'logic/cubits/wishlist_cubit.dart';
import 'logic/cubits/profile_cubit.dart';
import 'logic/cubits/chat_cubit.dart'; // ← must be explicit
import 'logic/cubits/theme_cubit.dart';
import 'logic/cubits/user_preferences_cubit.dart';
import 'data/notification_service.dart';
// ignore: unused_import
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await NotificationService.instance.initialize(
    dotenv.env['ONESIGNAL_APP_ID'] ?? '',
  );

  final themeCubit = ThemeCubit();
  await themeCubit.loadSavedTheme();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(MyApp(themeCubit: themeCubit));
}

class MyApp extends StatelessWidget {
  final ThemeCubit themeCubit;
  const MyApp({super.key, required this.themeCubit});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => RestaurantRepository()),
        RepositoryProvider(create: (_) => SupabaseService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: themeCubit),

          BlocProvider(
            create: (context) => UserPreferencesCubit(Supabase.instance.client),
          ),

          BlocProvider(
            create: (context) => RecommendationCubit(
              context.read<RestaurantRepository>(),
              apiService: ApiService.instance,
            )..loadMasterList(),
          ),

          BlocProvider(
            create: (context) => AuthCubit(context.read<SupabaseService>()),
          ),

          BlocProvider(
            create: (context) => ProfileCubit(context.read<SupabaseService>()),
          ),

          BlocProvider(
            create: (context) => WishlistCubit(context.read<SupabaseService>()),
          ),

          // ChatCubit — persists across tab switches so conversation
          // is not lost when the user navigates away and comes back
          BlocProvider<ChatCubit>(
            create: (_) => ChatCubit(ChatService.instance),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Terengganu Restaurant Recommender',

            // ── LIGHT THEME ─────────────────────────────────────────
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.background,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                tertiary: AppColors.tertiary,
                surface: AppColors.surface,
                surfaceContainer: const Color(0xFFF3F4F6),
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: AppColors.textPrimary),
                bodyMedium: TextStyle(color: AppColors.textSecondary),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              dividerTheme: DividerThemeData(color: AppColors.divider),
            ),

            // ── DARK THEME ──────────────────────────────────────────
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFFF9E60),
                secondary: Color(0xFF4AABB8),
                tertiary: Color(0xFF6BA685),
                surface: Color(0xFF1E1E2E),
                surfaceContainer: Color(0xFF2A2A3E),
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Color(0xFFE8E8F0),
              ),
              scaffoldBackgroundColor: const Color(0xFF12121C),
              cardColor: const Color(0xFF1E1E2E),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFFE8E8F0)),
                bodyMedium: TextStyle(color: Color(0xFFB0B0C0)),
                titleLarge: TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontWeight: FontWeight.w800,
                ),
                titleMedium: TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontWeight: FontWeight.w700,
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E2E),
                foregroundColor: Color(0xFFFF9E60),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9E60),
                  foregroundColor: Colors.white,
                ),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFFFF9E60)
                      : null,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFFFF9E60).withValues(alpha: 0.4)
                      : null,
                ),
              ),
              dividerTheme: const DividerThemeData(color: Color(0xFF2E2E42)),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF1E1E2E),
              ),
            ),

            themeMode: themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );
  }
}
