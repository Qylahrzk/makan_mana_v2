import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeCubit
///
/// Controls app-wide dark / light / system theme mode.
/// Persists the user's choice to SharedPreferences so it
/// survives app restarts.
///
/// Usage:
///   context.read<ThemeCubit>().setTheme(ThemeMode.dark);
///   context.watch<ThemeCubit>().state  // → current ThemeMode
///
/// Place in: lib/logic/cubits/theme_cubit.dart

class ThemeCubit extends Cubit<ThemeMode> {
  static const _key = 'app_theme_mode';

  ThemeCubit() : super(ThemeMode.system);

  /// Load persisted theme on startup. Call in main() before runApp.
  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    switch (saved) {
      case 'light':  emit(ThemeMode.light);  break;
      case 'dark':   emit(ThemeMode.dark);   break;
      default:       emit(ThemeMode.system); break;
    }
  }

  /// Change and persist the theme mode.
  Future<void> setTheme(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:  await prefs.setString(_key, 'light');  break;
      case ThemeMode.dark:   await prefs.setString(_key, 'dark');   break;
      case ThemeMode.system: await prefs.setString(_key, 'system'); break;
    }
  }

  /// Human-readable label for the current mode.
  String get label {
    switch (state) {
      case ThemeMode.light:  return 'Light';
      case ThemeMode.dark:   return 'Dark';
      case ThemeMode.system: return 'System';
    }
  }

  bool get isDark  => state == ThemeMode.dark;
  bool get isLight => state == ThemeMode.light;
}