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
import 'data/chat_service.dart';
import 'logic/cubits/auth_cubit.dart';
import 'logic/cubits/recommendation_cubit.dart';
import 'logic/cubits/favourite_cubit.dart';
import 'logic/cubits/profile_cubit.dart';
import 'logic/cubits/chat_cubit.dart';
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
            create: (context) =>
                AuthCubit(context.read<SupabaseService>())..checkSession(),
          ),

          BlocProvider(
            create: (context) => ProfileCubit(context.read<SupabaseService>()),
          ),

          BlocProvider(
            create: (context) =>
                FavouriteCubit(context.read<SupabaseService>()),
          ),

          BlocProvider<ChatCubit>(
            create: (_) => ChatCubit(ChatService.instance),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Makan Mana',

            // ── LIGHT THEME ──────────────────────────────────────────
            // 60% #F9FAFB neutral base
            // 20% #FF8C42 Discovery Orange  ← primary / CTA
            // 20% #2F6F7E Terengganu Teal   ← secondary / structure
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.background,
              fontFamily: 'OpenSans',

              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                // Orange drives buttons, selected states, FAB
                primary: AppColors.primary,
                onPrimary: AppColors.onPrimary,
                // Teal drives structural chrome — headers, chips, tags
                secondary: AppColors.secondary,
                onSecondary: AppColors.onSecondary,
                tertiary: AppColors.tertiary,
                onTertiary: Colors.white,
                surface: AppColors.surface,
                surfaceContainer: const Color.fromARGB(255, 221, 221, 221),
                onSurface: AppColors.onSurface,
                error: AppColors.error,
              ),

              textTheme: const TextTheme(
                displayLarge: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                ),
                displayMedium: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                ),
                headlineLarge: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                ),
                headlineMedium: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                ),
                headlineSmall: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                ),
                titleLarge: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                ),
                titleMedium: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                ),
                titleSmall: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                ),
                bodyLarge: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.textPrimary,
                ),
                bodyMedium: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.textSecondary,
                ),
                bodySmall: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.textSecondary,
                ),
                labelLarge: TextStyle(
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.w600,
                ),
                labelMedium: TextStyle(fontFamily: 'OpenSans'),
                labelSmall: TextStyle(fontFamily: 'OpenSans'),
              ),

              appBarTheme: const AppBarTheme(
                // Teal AppBar — structural brand surface
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
                titleTextStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  // Orange — primary CTA
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  // Orange outline button — secondary CTA
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  // Orange focus ring — consistent with primary CTA
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                hintStyle: const TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.disabledText,
                  fontSize: 15,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),

              chipTheme: ChipThemeData(
                // Teal tint chip — structural / filter chips
                backgroundColor: AppColors.secondaryTint,
                selectedColor: AppColors.secondary,
                labelStyle: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),

              dividerTheme: const DividerThemeData(color: AppColors.divider),

              cardTheme: CardThemeData(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.divider, width: 1),
                ),
              ),
            ),

            // ── DARK THEME ───────────────────────────────────────────
            // 60% #12121C deep charcoal
            // 20% #FF9E60 Soft Orange    ← primary / CTA
            // 20% #6AEBFC Cyan-Teal      ← secondary / structure
            darkTheme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.darkBackground,
              fontFamily: 'OpenSans',

              colorScheme: ColorScheme.dark(
                primary: AppColors.darkPrimary,
                onPrimary: Colors.white,
                secondary: AppColors.darkSecondary,
                onSecondary: AppColors.darkBackground,
                tertiary: AppColors.darkTertiary,
                onTertiary: Colors.white,
                surface: AppColors.darkSurface,
                surfaceContainer: AppColors.darkSurfaceVariant,
                onSurface: AppColors.darkOnSurface,
                error: AppColors.error,
              ),

              textTheme: const TextTheme(
                displayLarge: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkOnSurface,
                ),
                displayMedium: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkOnSurface,
                ),
                headlineLarge: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkOnSurface,
                ),
                headlineMedium: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkOnSurface,
                ),
                headlineSmall: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkOnSurface,
                ),
                titleLarge: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkOnSurface,
                ),
                titleMedium: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkOnSurface,
                ),
                titleSmall: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkOnSurface,
                ),
                bodyLarge: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.darkOnSurface,
                ),
                bodyMedium: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.darkTextSecondary,
                ),
                bodySmall: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.darkTextSecondary,
                ),
                labelLarge: TextStyle(
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkOnSurface,
                ),
                labelMedium: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.darkTextSecondary,
                ),
                labelSmall: TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.darkTextSecondary,
                ),
              ),

              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.darkSurface,
                foregroundColor: AppColors.darkSecondary,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                titleTextStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkSecondary,
                ),
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkPrimary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkPrimary,
                  side: const BorderSide(
                    color: AppColors.darkPrimary,
                    width: 1.5,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.darkSurfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.darkPrimary,
                    width: 1.5,
                  ),
                ),
                hintStyle: const TextStyle(
                  fontFamily: 'OpenSans',
                  color: AppColors.darkTextSecondary,
                  fontSize: 15,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),

              chipTheme: ChipThemeData(
                backgroundColor: const Color(0xFF1A3A3A),
                selectedColor: AppColors.darkSecondary,
                labelStyle: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkOnSurface,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),

              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.darkPrimary
                      : null,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.darkPrimary.withValues(alpha: 0.4)
                      : null,
                ),
              ),

              dividerTheme: DividerThemeData(
                color: Colors.white.withValues(alpha: 0.08),
              ),

              cardTheme: CardThemeData(
                color: AppColors.darkSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),

              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: AppColors.darkSurface,
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
