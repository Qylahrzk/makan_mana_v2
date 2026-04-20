import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/notification_service.dart';
import '../../models/user_preferences_model.dart';

// ─── States ───────────────────────────────────────────────────────────────────

abstract class UserPreferencesState extends Equatable {
  const UserPreferencesState();
  @override List<Object?> get props => [];
}

class PreferencesInitial extends UserPreferencesState {}
class PreferencesLoading extends UserPreferencesState {}

class PreferencesSaving extends UserPreferencesState {
  final UserPreferencesModel prefs;
  const PreferencesSaving(this.prefs);
  @override List<Object?> get props => [prefs];
}

class PreferencesLoaded extends UserPreferencesState {
  final UserPreferencesModel prefs;
  const PreferencesLoaded(this.prefs);
  @override List<Object?> get props => [prefs];
}

class PreferencesError extends UserPreferencesState {
  final String message;
  const PreferencesError(this.message);
  @override List<Object?> get props => [message];
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

class UserPreferencesCubit extends Cubit<UserPreferencesState> {
  final SupabaseClient _client;
  static const _table = 'user_preferences';

  UserPreferencesCubit(this._client) : super(PreferencesInitial());

  UserPreferencesModel? get current {
    final s = state;
    if (s is PreferencesLoaded) return s.prefs;
    if (s is PreferencesSaving) return s.prefs;
    return null;
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<UserPreferencesModel> loadPreferences(String userId) async {
    emit(PreferencesLoading());
    try {
      log('loadPreferences: fetching userId=$userId', name: 'UserPrefsCubit');

      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      log('loadPreferences: raw response = $response', name: 'UserPrefsCubit');

      final UserPreferencesModel prefs;
      if (response != null) {
        prefs = UserPreferencesModel.fromJson(
            Map<String, dynamic>.from(response as Map));
        log('loadPreferences: ✅ parsed cuisines=${prefs.cuisineTypes}',
            name: 'UserPrefsCubit');
      } else {
        log('loadPreferences: no row found for $userId — using empty',
            name: 'UserPrefsCubit');
        prefs = UserPreferencesModel.empty(userId);
      }

      emit(PreferencesLoaded(prefs));
      return prefs;
    } catch (e, stack) {
      log('loadPreferences ERROR: $e\n$stack', name: 'UserPrefsCubit');
      final empty = UserPreferencesModel.empty(userId);
      emit(PreferencesLoaded(empty));
      return empty;
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  // State sequence: PreferencesSaving → PreferencesLoaded
  // HomeScreen.listenWhen catches this transition to re-fetch recommendations.

  Future<void> savePreferences(
    UserPreferencesModel prefs, {
    required String userId,
  }) async {
    emit(PreferencesSaving(prefs));
    try {
      final payload = prefs.toJson();
      log('savePreferences: upserting payload=$payload',
          name: 'UserPrefsCubit');
      debugPrint('UserPrefsCubit.savePreferences: cuisines=${prefs.cuisineTypes}');

      final response = await _client
          .from(_table)
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();

      log('savePreferences: raw response = $response', name: 'UserPrefsCubit');

      final saved = UserPreferencesModel.fromJson(
          Map<String, dynamic>.from(response as Map));

      log('savePreferences: ✅ cuisines=${saved.cuisineTypes} '
          'halal=${saved.halal}', name: 'UserPrefsCubit');

      // Update OneSignal tags for push notification targeting
      await NotificationService.instance.updatePreferenceTags(
        halal:          saved.halal,
        vegetarian:     saved.vegetarian,
        familyFriendly: saved.familyFriendly,
        cuisines:       saved.cuisineTypes,
      );

      emit(PreferencesLoaded(saved));
    } catch (e, stack) {
      log('savePreferences ERROR: $e\n$stack', name: 'UserPrefsCubit');
      debugPrint('UserPrefsCubit.savePreferences ERROR: $e');
      emit(PreferencesError('Failed to save preferences: $e'));
      emit(PreferencesLoaded(prefs));
    }
  }

  // ── Toggle helpers ────────────────────────────────────────────────────────
  // Dietary
  Future<void> toggleHalal(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(halal: !p.halal), userId: userId);
  }

  Future<void> toggleVegetarian(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(vegetarian: !p.vegetarian), userId: userId);
  }

  Future<void> toggleVegan(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(vegan: !p.vegan), userId: userId);
  }

  // Facilities
  Future<void> toggleParking(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(hasParking: !p.hasParking), userId: userId);
  }

  Future<void> toggleWifi(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(hasWifi: !p.hasWifi), userId: userId);
  }

  Future<void> toggleAc(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(hasAc: !p.hasAc), userId: userId);
  }

  Future<void> toggleOutdoor(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(hasOutdoor: !p.hasOutdoor), userId: userId);
  }

  Future<void> toggleAccessible(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(accessible: !p.accessible), userId: userId);
  }

  // Vibes
  Future<void> toggleFamilyFriendly(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(familyFriendly: !p.familyFriendly), userId: userId);
  }

  Future<void> toggleGroupFriendly(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(groupFriendly: !p.groupFriendly), userId: userId);
  }

  Future<void> toggleCasual(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(casual: !p.casual), userId: userId);
  }

  Future<void> toggleRomantic(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(romantic: !p.romantic), userId: userId);
  }

  Future<void> toggleScenicView(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(scenicView: !p.scenicView), userId: userId);
  }

  // Service
  Future<void> toggleWorthIt(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(worthIt: !p.worthIt), userId: userId);
  }

  Future<void> toggleFastService(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(fastService: !p.fastService), userId: userId);
  }

  // Cuisine
  Future<void> toggleCuisine(String userId, String cuisine) async {
    final p        = current ?? UserPreferencesModel.empty(userId);
    final cuisines = List<String>.from(p.cuisineTypes);
    cuisines.contains(cuisine)
        ? cuisines.remove(cuisine)
        : cuisines.add(cuisine);
    await savePreferences(p.copyWith(cuisineTypes: cuisines), userId: userId);
  }
}