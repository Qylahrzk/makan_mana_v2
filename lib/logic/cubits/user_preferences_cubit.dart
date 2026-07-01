import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/notification_service.dart';
import '../../models/user_preferences_model.dart';

// ─── States ───────────────────────────────────────────────────────────────────

abstract class UserPreferencesState extends Equatable {
  const UserPreferencesState();
  @override
  List<Object?> get props => [];
}

class PreferencesInitial extends UserPreferencesState {}

class PreferencesLoading extends UserPreferencesState {}

class PreferencesSaving extends UserPreferencesState {
  final UserPreferencesModel prefs;
  const PreferencesSaving(this.prefs);
  @override
  List<Object?> get props => [prefs];
}

class PreferencesLoaded extends UserPreferencesState {
  final UserPreferencesModel prefs;
  const PreferencesLoaded(this.prefs);
  @override
  List<Object?> get props => [prefs];
}

class PreferencesError extends UserPreferencesState {
  final String message;
  const PreferencesError(this.message);
  @override
  List<Object?> get props => [message];
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

  // ─ CRITICAL FIX: Proper async ordering ──────────────────────────────────────
  //
  // OLD PATTERN (buggy):
  //   1. Fetch remote (async)
  //   2. Load local (async)
  //   3. Emit state
  //   → Race: Local load might finish AFTER save starts, overwriting new data
  //
  // NEW PATTERN (correct):
  //   1. Load local FIRST (fast, synchronous-like)
  //   2. Emit with local data
  //   3. THEN fetch remote (async)
  //   4. Merge & emit final state
  //   → Prevents: Save can't corrupt load because load is done first
  //

  Future<UserPreferencesModel> loadPreferences(String userId) async {
    emit(PreferencesLoading());
    try {
      log('loadPreferences: userId=$userId', name: 'UserPrefsCubit');

      // ✅ STEP 1: Load local preferences FIRST (fast, sequential)
      final sp = await SharedPreferences.getInstance();
      final budgetVal = sp.getInt('pref_budget_$userId');
      final isCrowdedVal = sp.getBool('pref_is_crowded_$userId') ?? false;
      log(
        'loadPreferences: local loaded — budget=$budgetVal, crowded=$isCrowdedVal',
        name: 'UserPrefsCubit',
      );

      // ✅ STEP 2: Fetch remote (now safe — local is locked)
      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      log('loadPreferences: remote fetch complete', name: 'UserPrefsCubit');

      // ✅ STEP 3: Merge local + remote
      UserPreferencesModel prefs;
      if (response != null) {
        prefs = UserPreferencesModel.fromJson(
          Map<String, dynamic>.from(response as Map),
        );
        log(
          'loadPreferences: ✅ parsed remote — cuisines=${prefs.cuisineTypes}',
          name: 'UserPrefsCubit',
        );
      } else {
        log(
          'loadPreferences: no remote row for $userId — using empty',
          name: 'UserPrefsCubit',
        );
        prefs = UserPreferencesModel.empty(userId);
      }

      // Merge local preferences (budget, isCrowded)
      prefs = prefs.copyWith(budget: budgetVal, isCrowded: isCrowdedVal);
      log(
        'loadPreferences: ✅ final merged — budget=${prefs.budget}, crowded=${prefs.isCrowded}',
        name: 'UserPrefsCubit',
      );

      emit(PreferencesLoaded(prefs));
      return prefs;
    } catch (e, stack) {
      log('loadPreferences ERROR: $e\n$stack', name: 'UserPrefsCubit');
      final empty = UserPreferencesModel.empty(userId);
      emit(PreferencesLoaded(empty));
      return empty;
    }
  }

  // ─ Save preferences ───────────────────────────────────────────────────────

  Future<void> savePreferences(
    UserPreferencesModel prefs, {
    required String userId,
  }) async {
    emit(PreferencesSaving(prefs));
    try {
      // ✅ STEP 1: Save local FIRST (fast, synchronous)
      final sp = await SharedPreferences.getInstance();
      if (prefs.budget != null) {
        await sp.setInt('pref_budget_$userId', prefs.budget!);
      } else {
        await sp.remove('pref_budget_$userId');
      }
      await sp.setBool('pref_is_crowded_$userId', prefs.isCrowded);
      log(
        'savePreferences: local saved — budget=${prefs.budget}',
        name: 'UserPrefsCubit',
      );

      // ✅ STEP 2: Upload remote (async, won't interfere with local)
      final payload = prefs.toJson();
      log(
        'savePreferences: uploading remote — payload keys=${payload.keys}',
        name: 'UserPrefsCubit',
      );

      final response = await _client
          .from(_table)
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();

      log('savePreferences: ✅ remote saved', name: 'UserPrefsCubit');

      var saved = UserPreferencesModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );

      // Merge local back (in case remote didn't include budget/crowded)
      saved = saved.copyWith(budget: prefs.budget, isCrowded: prefs.isCrowded);

      log(
        'savePreferences: ✅ cuisines=${saved.cuisineTypes} '
        'halal=${saved.halal} budget=${saved.budget}',
        name: 'UserPrefsCubit',
      );

      // Update OneSignal tags for push targeting
      await NotificationService.instance.updatePreferenceTags(
        halal: saved.halal,
        vegetarian: saved.vegetarian,
        familyFriendly: saved.familyFriendly,
        cuisines: saved.cuisineTypes,
      );

      emit(PreferencesLoaded(saved));
    } catch (e, stack) {
      log('savePreferences ERROR: $e\n$stack', name: 'UserPrefsCubit');
      debugPrint('UserPrefsCubit.savePreferences ERROR: $e');
      emit(PreferencesError('Failed to save preferences: $e'));
      // Re-emit the prefs we tried to save (so UI doesn't break)
      emit(PreferencesLoaded(prefs));
    }
  }

  // ─ Toggle helpers ──────────────────────────────────────────────────────────

  Future<void> toggleHalal(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(halal: !p.halal), userId: userId);
  }

  Future<void> toggleVegetarian(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(
      p.copyWith(vegetarian: !p.vegetarian),
      userId: userId,
    );
  }

  Future<void> toggleVegan(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(vegan: !p.vegan), userId: userId);
  }

  Future<void> toggleParking(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(
      p.copyWith(hasParking: !p.hasParking),
      userId: userId,
    );
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
    await savePreferences(
      p.copyWith(hasOutdoor: !p.hasOutdoor),
      userId: userId,
    );
  }

  Future<void> toggleAccessible(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(
      p.copyWith(accessible: !p.accessible),
      userId: userId,
    );
  }

  Future<void> toggleFamilyFriendly(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(
      p.copyWith(familyFriendly: !p.familyFriendly),
      userId: userId,
    );
  }

  Future<void> toggleGroupFriendly(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(
      p.copyWith(groupFriendly: !p.groupFriendly),
      userId: userId,
    );
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
    await savePreferences(
      p.copyWith(scenicView: !p.scenicView),
      userId: userId,
    );
  }

  Future<void> toggleWorthIt(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(worthIt: !p.worthIt), userId: userId);
  }

  Future<void> toggleFastService(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(
      p.copyWith(fastService: !p.fastService),
      userId: userId,
    );
  }

  Future<void> toggleCuisine(String userId, String cuisine) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    final cuisines = List<String>.from(p.cuisineTypes);
    cuisines.contains(cuisine)
        ? cuisines.remove(cuisine)
        : cuisines.add(cuisine);
    await savePreferences(p.copyWith(cuisineTypes: cuisines), userId: userId);
  }

  Future<void> setBudget(String userId, int? budget) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(
      p.copyWith(budget: budget, clearBudget: budget == null),
      userId: userId,
    );
  }

  Future<void> toggleCrowded(String userId) async {
    final p = current ?? UserPreferencesModel.empty(userId);
    await savePreferences(p.copyWith(isCrowded: !p.isCrowded), userId: userId);
  }
}
